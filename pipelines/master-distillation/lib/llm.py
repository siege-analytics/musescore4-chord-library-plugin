"""LLM call interface for pipeline stages.

**The code layer is demonstrably free.** This module makes no network
calls, depends on no LLM SDK, and contains no API keys. Stages that
need LLM work hand off via the filesystem: they write a request file
describing what they need (prompt + JSON Schema + scope), then exit in
`awaiting-llm` status. A human or agent — using whatever LLM interface
they choose (Claude CLI, Craft Agents, a local Ollama wrapper, manual
typing) — fills the corresponding response file. The pipeline picks
back up on the next `resume`.

Why this shape:
  - No surprise spend: nothing in this code can rack up an Anthropic
    bill or call any service. Cost lives at the human/agent layer.
  - Backend-agnostic: the file-dance contract is the same whether the
    response was produced by Sonnet via the API, by a subagent, by a
    local model, or pasted in by hand. The audit trail is uniform.
  - Reproducible: the request files alone, replayed against any LLM,
    produce a comparable run. Move runs/ to another machine and resume.

The contract is exactly:
  - `runs/<id>/llm-calls/<stage>-<scope>.request.json` carries:
      { stage, scope, model, system_prompt, user_prompt,
        response_schema, notes }
    `model` is informational — the responder picks the model. `notes`
    is human-facing.
  - `runs/<id>/llm-calls/<stage>-<scope>.response.json` is the parsed
    JSON the stage will validate against `response_schema`.

That's the entire LLM dependency in this codebase.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class PendingLLMOutput(Exception):
    """Raised when a stage needs an LLM call whose response hasn't been
    written yet. The orchestrator catches and surfaces this so the user
    or agent can fulfill the request."""

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
    """What a pipeline stage hands off via the request file."""

    stage: str  # "s2" | "s3" | "s4"
    scope: str  # e.g. "ch01" or "toc"
    model: str  # informational; the responder picks the actual model
    system_prompt: str
    user_prompt: str
    response_schema: dict[str, Any] | None  # None = free-form prose response
    notes: str | None = None  # human-facing context, shows in --status

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
    """Write the request, then either consume an existing response or
    raise PendingLLMOutput.

    On first call: writes the request file, raises PendingLLMOutput.
    On subsequent call (after a human or agent has written the response
    file): loads, validates against response_schema if provided, returns
    the parsed content.

    Response shape:
      - If response_schema is provided: response must be a JSON object
        matching the schema. Validation errors raise ValueError.
      - If response_schema is None (prose stages): response is a JSON
        object with a "text" field. Wrap your prose in
        `{"text": "..."}` when filling the response file.
    """
    request_path.parent.mkdir(parents=True, exist_ok=True)
    # Always (re)write the request file so the audit trail reflects the
    # most recent prompt formulation.
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
