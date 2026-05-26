#!/usr/bin/env python3
"""Re-ingest a Stage 1 OCR run from its local ocr-output/raw-transcript.txt.

Use this when:
  - the in-flight Stage 1 was running with stale code that had a buggy
    indexer (e.g. the pre-fix FF-strip bug that collapsed pages), or
  - the orchestrator died mid-ingest after the rsync-down completed, or
  - you want to re-apply an updated indexer to an existing OCR outbox
    without re-OCRing on cyberpower.

The cyberpower outbox (ocr-output/raw-transcript.txt) is the authoritative
artifact. This script reads it, runs the current `_index_form_feed_transcript`
helper, and rewrites raw-transcript.txt + pages.json at the run-dir root.
Stage state is bumped to awaiting-review for s1.

Usage:
  python3 pipelines/master-distillation/ocr/reingest.py <run_id>
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PIPELINE_DIR = REPO_ROOT / "pipelines" / "master-distillation"
sys.path.insert(0, str(PIPELINE_DIR))

from lib.paths import RUNS_ROOT  # noqa: E402
from stages.s1_extract import OCR_DEFAULTS  # noqa: E402
from stages.s1_extract import _index_form_feed_transcript  # noqa: E402


def main(run_id: str) -> int:
    run_dir = RUNS_ROOT / run_id
    if not run_dir.exists():
        print(f"run dir not found: {run_dir}", file=sys.stderr)
        return 2

    output_dir = run_dir / "ocr-output"
    raw_file = output_dir / "raw-transcript.txt"

    # If the local outbox is empty, try to rsync from cyberpower. This
    # handles the case where the orchestrator died after the remote runner
    # finished but before the rsync-down step.
    if not raw_file.exists():
        output_dir.mkdir(parents=True, exist_ok=True)
        remote = f"{OCR_DEFAULTS['user']}@{OCR_DEFAULTS['host']}"
        remote_outbox = f"~/jazz-ocr/outbox/{run_id}/"
        print(f"local outbox empty; rsyncing from {remote}:{remote_outbox} ...")
        try:
            subprocess.run(
                ["rsync", "-a", f"{remote}:{remote_outbox}", f"{output_dir}/"],
                check=True,
            )
        except subprocess.CalledProcessError as exc:
            print(f"rsync from cyberpower failed: {exc}", file=sys.stderr)
            return 2

    if not raw_file.exists():
        print(
            f"OCR output not found at {raw_file} after attempted rsync; "
            f"check that cyberpower:{f'~/jazz-ocr/outbox/{run_id}/'} has a "
            f"raw-transcript.txt.",
            file=sys.stderr,
        )
        return 2

    transcript, pages_index = _index_form_feed_transcript(raw_file.read_text())

    (run_dir / "raw-transcript.txt").write_text(transcript)
    (run_dir / "pages.json").write_text(json.dumps(pages_index, indent=2) + "\n")

    # Update stage-state so s1 is awaiting-review and s2 is unblocked
    # on --advance. We don't touch upstream/downstream stages.
    state_file = run_dir / "stage-state.json"
    if state_file.exists():
        state = json.loads(state_file.read_text())
        s1 = state["stages"].get("s1", {})
        s1["status"] = "awaiting-review"
        s1["outputs"] = [
            f"pipelines/master-distillation/runs/{run_id}/raw-transcript.txt",
            f"pipelines/master-distillation/runs/{run_id}/pages.json",
            f"re-ingested: {len(pages_index['pages'])} pages, {len(transcript):,} characters",
        ]
        s1["error_message"] = None
        state_file.write_text(json.dumps(state, indent=2) + "\n")

    print(
        f"re-ingested {len(pages_index['pages'])} pages "
        f"({len(transcript):,} chars) for run {run_id}"
    )
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: reingest.py <run_id>", file=sys.stderr)
        sys.exit(64)
    sys.exit(main(sys.argv[1]))
