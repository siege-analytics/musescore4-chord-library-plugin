"""Provenance frontmatter for every committed artifact.

Lesson from #290: invented names that pass schema validation still fail
design provenance. Every committed artifact carries a frontmatter block
naming the run, stage, source, and model that produced it. Editing an
artifact by hand keeps a pointer back to the run that generated the
draft.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

SCHEMA_VERSION = "0.1"


@dataclass
class Provenance:
    run_id: str
    stage: str  # "s1" | "s2" | "s3" | "s4"
    source_pdf: str
    source_pages: str | None = None  # e.g. "12-34"
    model: str | None = None  # null for non-LLM stages
    extracted_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat(
            timespec="seconds"
        )
    )
    schema_version: str = SCHEMA_VERSION

    def yaml_block(self) -> str:
        lines = [
            "---",
            f"run_id: {self.run_id}",
            f"stage: {self.stage}",
            f"source_pdf: {self.source_pdf}",
        ]
        if self.source_pages is not None:
            lines.append(f"source_pages: {self.source_pages}")
        if self.model is not None:
            lines.append(f"model: {self.model}")
        lines.append(f"extracted_at: {self.extracted_at}")
        lines.append(f"schema_version: {self.schema_version}")
        lines.append("---")
        return "\n".join(lines)

    def json_block(self) -> dict:
        out = {
            "run_id": self.run_id,
            "stage": self.stage,
            "source_pdf": self.source_pdf,
            "extracted_at": self.extracted_at,
            "schema_version": self.schema_version,
        }
        if self.source_pages is not None:
            out["source_pages"] = self.source_pages
        if self.model is not None:
            out["model"] = self.model
        return out
