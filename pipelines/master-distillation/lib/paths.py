"""Canonical paths for pipeline outputs.

Two destinations per artifact:
  - COMMITTED — under plugin/data/masters-corpus/<master>/<work>/
  - GITIGNORED — under pipelines/master-distillation/runs/<run_id>/

Every stage writes to both. The committed path is the authoritative
artifact. The run dir is the audit trail for that specific run.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PIPELINE_ROOT = REPO_ROOT / "pipelines" / "master-distillation"
RUNS_ROOT = PIPELINE_ROOT / "runs"
CORPUS_ROOT = REPO_ROOT / "plugin" / "data" / "masters-corpus"
CONFIGS_ROOT = PIPELINE_ROOT / "configs"


@dataclass(frozen=True)
class BookPaths:
    """All canonical paths for one (master, work, run) tuple."""

    master_id: str
    work_id: str
    run_id: str

    @property
    def run_dir(self) -> Path:
        return RUNS_ROOT / self.run_id

    @property
    def state_file(self) -> Path:
        return self.run_dir / "stage-state.json"

    @property
    def raw_transcript(self) -> Path:
        return self.run_dir / "raw-transcript.txt"

    @property
    def pages_json(self) -> Path:
        return self.run_dir / "pages.json"

    @property
    def chapter_bounds(self) -> Path:
        return self.run_dir / "chapter-bounds.json"

    @property
    def llm_calls_dir(self) -> Path:
        return self.run_dir / "llm-calls"

    @property
    def committed_work_dir(self) -> Path:
        return CORPUS_ROOT / self.master_id / self.work_id

    @property
    def committed_chapters_dir(self) -> Path:
        return self.committed_work_dir / "chapters"

    @property
    def committed_summaries_dir(self) -> Path:
        return self.committed_work_dir / "summaries"

    @property
    def committed_derived_dir(self) -> Path:
        return self.committed_work_dir / "derived"

    @property
    def book_summary(self) -> Path:
        return self.committed_work_dir / f"{self.work_id}-book-summary.md"

    @property
    def systems_draft(self) -> Path:
        return self.committed_derived_dir / "systems-draft.json"

    @property
    def statement(self) -> Path:
        return self.committed_derived_dir / "STATEMENT.md"

    def chapter_file(self, chapter_n: int) -> Path:
        return self.committed_chapters_dir / f"ch{chapter_n:02d}.md"

    def chapter_summary(self, chapter_n: int) -> Path:
        return self.committed_summaries_dir / f"ch{chapter_n:02d}-summary.md"

    def llm_call_file(self, stage: str, scope: str, kind: str) -> Path:
        """`kind` is 'request' or 'response'."""
        return self.llm_calls_dir / f"{stage}-{scope}.{kind}.json"

    def ensure_dirs(self) -> None:
        for d in (
            self.run_dir,
            self.llm_calls_dir,
            self.committed_work_dir,
            self.committed_chapters_dir,
            self.committed_summaries_dir,
            self.committed_derived_dir,
        ):
            d.mkdir(parents=True, exist_ok=True)


def rel_to_repo(p: Path) -> str:
    """Render `p` relative to the repo root for orchestrator output.

    Falls back to the absolute path if `p` is outside the repo. Uses the
    canonical REPO_ROOT anchor rather than magic-counting parents from
    the run dir, which is fragile to directory restructures.
    """
    try:
        return str(p.relative_to(REPO_ROOT))
    except ValueError:
        return str(p)
