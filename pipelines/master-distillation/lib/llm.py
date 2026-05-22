"""LLM call interface for pipeline stages.

For the first iteration (Benson Vol 1), the pipeline does not call the
Anthropic API directly. Instead:

  1. A stage that needs an LLM call invokes `request_llm(scope, prompt,
     schema, model)`.
  2. `request_llm` writes the prompt + schema to
     `runs/<ts>/llm-calls/<stage>-<scope>.request.json` and looks for a
     matching `.response.json`.
  3. If the response file exists, it's loaded, JSON-Schema validated,
     and returned.
  4. If not, `PendingLLMOutput` is raised carrying the request path. The
     orchestrator catches this, prints a clear instruction to the user
     ("run call_llm with the prompt at <path>, drop the response at
     <path>"), and marks the stage `awaiting-llm`.

The agent in-session reads the request, invokes `call_llm` (or any
Anthropic client), writes the response, and reruns the pipeline; the
stage picks up where it left off.

A follow-up ticket will add direct Anthropic SDK support so the
pipeline can run autonomously when ANTHROPIC_API_KEY is in env.
"""

from __future__ import annotations

import json
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


def request_llm(
    req: LLMRequest,
    request_path: Path,
    response_path: Path,
) -> Any:
    """Drive the request/response file dance.

    On first call: writes request file, raises PendingLLMOutput.
    On subsequent call (after response file exists): loads response,
    validates against req.response_schema if provided, returns parsed
    content.
    """
    request_path.parent.mkdir(parents=True, exist_ok=True)
    # Always (re)write the request file so the user has the latest.
    request_path.write_text(json.dumps(req.to_dict(), indent=2) + "\n")

    if not response_path.exists():
        raise PendingLLMOutput(request_path, response_path, req.scope)

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
