#!/usr/bin/env python3
"""Bridge: queue Stage 1 outputs → canonical runs/<ts>-<slug>/ layout.

The queue runner (#336) writes Stage 1 outputs to
  $OUTPUT_DIR/<slug>/raw-transcript.txt

The Stages 2-4 orchestrator expects the canonical layout
  runs/<UTC-timestamp>-<slug>/ocr-output/raw-transcript.txt
plus a seeded stage-state.json so reingest.py (or run.py resume) can
take over from "awaiting-review" on s1.

This script creates that layout for one or many slugs without re-OCRing
on cyberpower. The queue output is the authoritative Stage 1 artifact;
no laptop-side re-extraction.

Ticket: #346
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PIPELINE_DIR = REPO_ROOT / "pipelines" / "master-distillation"
RUNS_DIR = PIPELINE_DIR / "runs"
CONFIGS_DIR = PIPELINE_DIR / "configs"
STATE_DIR_DEFAULT = Path.home() / "jazz-pipeline" / "state"
OUTPUT_DIR_DEFAULT = Path.home() / "jazz-pipeline" / "outputs"


def now_iso_compact() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%S")


def now_iso_full() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def queue_done_slugs(state_dir: Path) -> list[str]:
    return sorted(p.stem for p in state_dir.glob("*.done"))


def find_config_for_slug(slug: str) -> Path | None:
    p = CONFIGS_DIR / f"{slug}.toml"
    return p if p.exists() else None


def ingest_one(
    slug: str,
    output_dir: Path,
    state_dir: Path,
    *,
    dry_run: bool = False,
) -> Path | None:
    """Create a canonical run dir for one slug. Returns the run dir path."""
    transcript_src = output_dir / slug / "raw-transcript.txt"
    if not transcript_src.exists():
        print(f"  SKIP {slug}: no transcript at {transcript_src}", file=sys.stderr)
        return None

    cfg = find_config_for_slug(slug)
    if cfg is None:
        print(f"  SKIP {slug}: no config at configs/{slug}.toml", file=sys.stderr)
        return None

    run_id = f"{now_iso_compact()}-{slug}"
    run_dir = RUNS_DIR / run_id

    if dry_run:
        print(f"  WOULD create {run_dir} ← {transcript_src}")
        return run_dir

    (run_dir / "ocr-output").mkdir(parents=True, exist_ok=False)
    shutil.copy2(transcript_src, run_dir / "ocr-output" / "raw-transcript.txt")

    # Also copy page-confidence.json if the queue produced it
    pc = output_dir / slug / "page-confidence.json"
    if pc.exists():
        shutil.copy2(pc, run_dir / "ocr-output" / "page-confidence.json")

    state = {
        "run_id": run_id,
        "config": str(cfg.relative_to(REPO_ROOT)),
        "stages": {
            "s1": {
                "status": "awaiting-review",
                "started_at": now_iso_full(),
                "ended_at": None,
                "outputs": [
                    f"ingested from queue output ({transcript_src.stat().st_size} bytes)",
                ],
                "error_message": None,
            },
            "s2": {"status": "pending", "started_at": None, "ended_at": None, "outputs": [], "error_message": None},
            "s3": {"status": "pending", "started_at": None, "ended_at": None, "outputs": [], "error_message": None},
            "s4": {"status": "pending", "started_at": None, "ended_at": None, "outputs": [], "error_message": None},
            "sB": {"status": "pending", "started_at": None, "ended_at": None, "outputs": [], "error_message": None},
        },
    }
    (run_dir / "stage-state.json").write_text(
        json.dumps(state, indent=2) + "\n", encoding="utf-8"
    )

    print(f"  OK   {run_id}")
    return run_dir


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("slugs", nargs="*", help="Slugs to ingest. If empty, use --all.")
    p.add_argument("--all", action="store_true", help="Ingest every queue .done slug.")
    p.add_argument("--state-dir", type=Path, default=STATE_DIR_DEFAULT)
    p.add_argument("--output-dir", type=Path, default=OUTPUT_DIR_DEFAULT)
    p.add_argument("--dry-run", action="store_true", help="Print actions; don't write.")
    args = p.parse_args()

    if args.all and args.slugs:
        print("error: use either positional slugs or --all, not both", file=sys.stderr)
        return 2

    if args.all:
        slugs = queue_done_slugs(args.state_dir)
        if not slugs:
            print(f"no .done markers in {args.state_dir}", file=sys.stderr)
            return 1
    else:
        slugs = args.slugs

    if not slugs:
        print("usage: ingest_to_runs.py <slug> [<slug>...] | --all", file=sys.stderr)
        return 2

    print(f"{'DRY-RUN: ' if args.dry_run else ''}ingesting {len(slugs)} slug(s)")
    created = 0
    skipped = 0
    for slug in slugs:
        result = ingest_one(slug, args.output_dir, args.state_dir, dry_run=args.dry_run)
        if result is not None:
            created += 1
        else:
            skipped += 1

    print(f"\n{created} created, {skipped} skipped")
    return 0 if skipped == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
