"""Stage-gate state machine for a pipeline run.

stage-state.json shape (per run):
  {
    "run_id": "2026-05-22T13-04-12-benson-vol-1",
    "config": "configs/benson-vol-1.yaml",
    "stages": {
      "s1": { "status": "accepted", ... },
      "s2": { "status": "awaiting-review", ... },
      "s3": { "status": "pending" },
      "s4": { "status": "pending" }
    }
  }

Stage statuses:
  pending          — has not run
  running          — actively executing (mostly informational; the
                     orchestrator runs synchronously, so this state is
                     brief)
  awaiting-llm     — stage paused because it needs an LLM response that
                     hasn't arrived yet. The request file is written;
                     the agent runs the LLM and drops the response file,
                     then `resume` picks back up.
  awaiting-review  — stage completed, outputs written, waiting for user
                     `advance`
  accepted         — user advanced past this stage; next stage may run
  rejected         — user `redo`'d; outputs cleared; back to pending
  error            — stage raised; see error_message
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

STAGE_ORDER = ["s1", "s2", "s3", "s4"]

Status = Literal[
    "pending",
    "running",
    "awaiting-llm",
    "awaiting-review",
    "accepted",
    "rejected",
    "error",
]


@dataclass
class StageRecord:
    status: Status = "pending"
    started_at: str | None = None
    ended_at: str | None = None
    outputs: list[str] = field(default_factory=list)
    error_message: str | None = None

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "started_at": self.started_at,
            "ended_at": self.ended_at,
            "outputs": self.outputs,
            "error_message": self.error_message,
        }

    @classmethod
    def from_dict(cls, d: dict) -> StageRecord:
        return cls(
            status=d.get("status", "pending"),
            started_at=d.get("started_at"),
            ended_at=d.get("ended_at"),
            outputs=d.get("outputs", []),
            error_message=d.get("error_message"),
        )


@dataclass
class RunState:
    run_id: str
    config: str
    stages: dict[str, StageRecord] = field(default_factory=dict)

    @classmethod
    def new(cls, run_id: str, config_path: str) -> RunState:
        return cls(
            run_id=run_id,
            config=config_path,
            stages={s: StageRecord() for s in STAGE_ORDER},
        )

    @classmethod
    def load(cls, path: Path) -> RunState:
        data = json.loads(path.read_text())
        return cls(
            run_id=data["run_id"],
            config=data["config"],
            stages={
                k: StageRecord.from_dict(v) for k, v in data["stages"].items()
            },
        )

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "run_id": self.run_id,
                    "config": self.config,
                    "stages": {
                        k: v.to_dict() for k, v in self.stages.items()
                    },
                },
                indent=2,
            )
            + "\n"
        )

    def next_runnable_stage(self) -> str | None:
        """Return the next stage that should run. None if the pipeline
        is complete or blocked on review.

        Special handling:
          - `running` means a prior run crashed mid-stage (process died,
            laptop reset, kernel panic, etc.). The stage's outputs may
            be partially written; the stage's `run()` is expected to be
            idempotent (skip already-written per-chapter files, etc.).
            Re-runnable from the current position.
          - `awaiting-llm` is a paused mid-stage state; also re-runnable
            (the stage's `run()` re-tries the request, which the Ollama
            backend serves directly or the file-dance picks up).
        """
        for stage in STAGE_ORDER:
            rec = self.stages[stage]
            if rec.status in ("pending", "awaiting-llm", "running"):
                if rec.status in ("awaiting-llm", "running"):
                    return stage  # resume mid-stage
                earlier_ok = all(
                    self.stages[s].status == "accepted"
                    for s in STAGE_ORDER[: STAGE_ORDER.index(stage)]
                )
                return stage if earlier_ok else None
            if rec.status == "awaiting-review":
                return None  # blocked on user
            if rec.status == "error":
                return None  # blocked on user
        return None  # all accepted

    def mark_running(self, stage: str) -> None:
        rec = self.stages[stage]
        rec.status = "running"
        rec.started_at = _now()
        rec.error_message = None

    def mark_awaiting_review(self, stage: str, outputs: list[str]) -> None:
        rec = self.stages[stage]
        rec.status = "awaiting-review"
        rec.ended_at = _now()
        rec.outputs = outputs

    def mark_error(self, stage: str, message: str) -> None:
        rec = self.stages[stage]
        rec.status = "error"
        rec.ended_at = _now()
        rec.error_message = message

    def advance(self, stage: str) -> None:
        rec = self.stages[stage]
        if rec.status != "awaiting-review":
            raise ValueError(
                f"cannot advance stage {stage}: status is {rec.status}, "
                f"expected awaiting-review"
            )
        rec.status = "accepted"

    def redo(self, stage: str) -> None:
        rec = self.stages[stage]
        rec.status = "pending"
        rec.started_at = None
        rec.ended_at = None
        rec.outputs = []
        rec.error_message = None
        # Reset downstream stages too — they're invalidated.
        idx = STAGE_ORDER.index(stage)
        for downstream in STAGE_ORDER[idx + 1 :]:
            self.stages[downstream] = StageRecord()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def make_run_id(slug: str) -> str:
    """e.g. '2026-05-22T13-04-12-benson-vol-1'"""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%S")
    return f"{ts}-{slug}"
