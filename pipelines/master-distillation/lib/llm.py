"""LLM call interface for pipeline stages.

Two backends, tried in order:

  1. **Ollama** at OLLAMA_URL (default http://localhost:11434).
     Reached via HTTP POST to /api/generate with `format: "json"` for
     structured-output stages. The Anthropic SDK is intentionally not
     used here; local Ollama on the maintainer's machine is the
     autonomous path. Configured per-stage in the per-book TOML
     (`[stages.sN] model = "qwen2.5:72b"`).

  2. **File-dance fallback** when Ollama is unreachable. `request_llm`
     writes the prompt to `runs/<ts>/llm-calls/<stage>-<scope>.request.json`
     and raises PendingLLMOutput. The agent runs the LLM out-of-band
     (e.g. via call_llm), drops the parsed JSON response at the
     expected path, and re-runs the orchestrator.

Every LLM call — whether served by Ollama or the file-dance — also
saves its request and response payloads alongside, so the
`runs/<id>/llm-calls/` audit trail is uniform regardless of backend.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class PendingLLMOutput(Exception):
    """Raised when a stage needs an LLM call whose response hasn't
    arrived yet. The orchestrator catches and surfaces this."""

    def __init__(self, request_path: Path, response_path: Path, scope: str):
        self.request_path = request_path
        self.response_path = response_path
        self.scope = scope
        super().__init__(
            f"awaiting LLM output for scope='{scope}'.\n"
            f"  request: {request_path}\n"
            f"  drop response at: {response_path}"
        )


@dataclass
class LLMRequest:
    """What a pipeline stage hands off to the LLM."""

    stage: str  # "s2" | "s3" | "s4"
    scope: str  # e.g. "ch01" or "toc-detect"
    model: str  # e.g. "claude-haiku-4-5-20251001" or "claude-sonnet-4-6"
    system_prompt: str
    user_prompt: str
    response_schema: dict[str, Any] | None  # JSON Schema for the response (None = free-form)
    notes: str | None = None  # human-facing context, surfaces in --status

    def to_dict(self) -> dict:
        return {
            "stage": self.stage,
            "scope": self.scope,
            "model": self.model,
            "system_prompt": self.system_prompt,
            "user_prompt": self.user_prompt,
            "response_schema": self.response_schema,
            "notes": self.notes,
        }


OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
OLLAMA_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT", "1800"))  # 30 min


def request_llm(
    req: LLMRequest,
    request_path: Path,
    response_path: Path,
) -> Any:
    """Drive an LLM call. Tries Ollama first; falls back to file-dance.

    Always writes the request file. If Ollama is reachable and the
    response_path doesn't exist yet, calls Ollama and writes the parsed
    response to response_path. If Ollama is not reachable, raises
    PendingLLMOutput so the agent can fulfill the request out-of-band.

    On subsequent calls (response file exists either from a prior
    Ollama call or from the agent dropping it manually): loads,
    schema-validates if requested, returns parsed content.
    """
    request_path.parent.mkdir(parents=True, exist_ok=True)
    # Always (re)write the request file so the audit trail is current.
    request_path.write_text(json.dumps(req.to_dict(), indent=2) + "\n")

    if not response_path.exists():
        # Try Ollama. If it's not running or the call fails for any
        # reason, fall back to the file-dance so the agent can fulfill.
        try:
            response = _call_ollama(req)
        except _OllamaUnreachable:
            raise PendingLLMOutput(request_path, response_path, req.scope)
        response_path.write_text(json.dumps(response, indent=2) + "\n")
    else:
        response_text = response_path.read_text()
        try:
            response = json.loads(response_text)
        except json.JSONDecodeError as e:
            raise ValueError(
                f"response at {response_path} is not valid JSON: {e}"
            ) from e

    if req.response_schema is not None:
        try:
            from jsonschema import Draft202012Validator
        except ImportError:
            raise RuntimeError(
                "jsonschema is required for response validation. "
                "pip install jsonschema"
            )
        validator = Draft202012Validator(req.response_schema)
        errors = sorted(
            validator.iter_errors(response), key=lambda e: list(e.path)
        )
        if errors:
            msgs = []
            for err in errors[:5]:
                where = " > ".join(str(p) for p in err.absolute_path) or "(root)"
                msgs.append(f"[{where}] {err.message}")
            raise ValueError(
                f"response at {response_path} failed schema validation: "
                + "; ".join(msgs)
            )

    return response


class _OllamaUnreachable(Exception):
    """Internal: raised when Ollama isn't running or can't be reached."""


def _call_ollama(req: LLMRequest) -> Any:
    """POST to Ollama /api/generate and return parsed response.

    For structured stages (req.response_schema is not None), uses
    `format: "json"` so Ollama constrains the output to valid JSON.
    For free-form prose stages, returns the raw text wrapped in
    {"text": ...} so downstream code can treat all responses uniformly
    as dicts.
    """
    body: dict[str, Any] = {
        "model": req.model,
        "prompt": req.user_prompt,
        "system": req.system_prompt,
        "stream": False,
    }
    if req.response_schema is not None:
        # Ollama 0.5+ supports JSON Schema directly via `format`; the model
        # is constrained to produce output matching the schema rather than
        # merely valid JSON. Earlier behaviour (format: "json") let the
        # model invent an arbitrary JSON shape — verified bad against
        # qwen2.5:72b which returned {"document": {...}} when asked for a
        # {"chapters": [...]} shape.
        body["format"] = req.response_schema

    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=OLLAMA_TIMEOUT) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
        raise _OllamaUnreachable(f"Ollama at {OLLAMA_URL}: {e}") from e

    raw = payload.get("response", "")
    if req.response_schema is not None:
        # Ollama with format=json returns a JSON string in `response`.
        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:
            raise ValueError(
                f"Ollama returned non-JSON despite format=json for "
                f"scope='{req.scope}': {e}; first 200 chars: {raw[:200]!r}"
            ) from e
    return {"text": raw}
