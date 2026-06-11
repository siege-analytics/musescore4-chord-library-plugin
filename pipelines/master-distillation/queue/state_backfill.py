#!/usr/bin/env python3
"""Backfill queue daemon `.done` state markers from orchestrator runs.

Why: the bash queue daemon (queue_runner.sh) considers a book eligible if
no `state/<slug>.done` marker exists. Markers are written ONLY by
process_one.sh on its own successful completion — runs completed via the
direct `run.py new-run <config>` orchestration path (the standard manual
flow) never touch the daemon state dir, so the daemon considers those
books eligible and would re-OCR them. See #452.

This script scans every stage-state.json under
`pipelines/master-distillation/runs/<run_id>/` and, for any run whose s1
stage is `accepted` (s1 has produced the canonical outputs and the
operator/curator advanced past it), writes a matching `.done` marker into
the daemon's STATE_DIR so the daemon will skip that book on next poll.

Idempotent. Re-run after every direct orchestrator session.

Usage (on cyberpower):
    python3 pipelines/master-distillation/queue/state_backfill.py

    # Custom paths:
    python3 .../state_backfill.py --runs-root /path/to/runs --state-dir /path/to/state

    # Dry run — print what would be written, don't write:
    python3 .../state_backfill.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tomllib
from datetime import datetime, timezone
from pathlib import Path


def _config_slug(config_path_str: str, configs_root: Path) -> str | None:
    """Derive the queue slug from a config path string.

    The run's `config` field is the repo-relative path to the toml, e.g.
    `pipelines/master-distillation/configs/laukens-complete-chord-melody.toml`.
    The slug is the stem of the basename.

    Returns None if the path doesn't look like a config under the
    expected configs/ tree.
    """
    p = Path(config_path_str)
    if p.suffix != ".toml":
        return None
    return p.stem


def _read_s1_status(state_file: Path) -> str | None:
    """Return s1.status from a stage-state.json, or None if unreadable."""
    try:
        data = json.loads(state_file.read_text())
    except (json.JSONDecodeError, OSError):
        return None
    stages = data.get("stages") or {}
    s1 = stages.get("s1") or {}
    return s1.get("status")


def _read_config_field(state_file: Path) -> str | None:
    """Return the run's `config` field from a stage-state.json."""
    try:
        data = json.loads(state_file.read_text())
    except (json.JSONDecodeError, OSError):
        return None
    cfg = data.get("config")
    if isinstance(cfg, str) and cfg:
        return cfg
    return None


def collect_completed_slugs(runs_root: Path, configs_root: Path) -> dict[str, Path]:
    """Walk runs_root, return {slug: state_file} for every run whose s1
    is `accepted`. If the same slug has multiple runs (re-runs), the
    most-recently-modified state file wins.
    """
    out: dict[str, Path] = {}
    if not runs_root.exists():
        return out
    for state_file in sorted(runs_root.glob("*/stage-state.json")):
        s1 = _read_s1_status(state_file)
        if s1 != "accepted":
            continue
        cfg = _read_config_field(state_file)
        if not cfg:
            continue
        slug = _config_slug(cfg, configs_root)
        if not slug:
            continue
        # Prefer the most-recently-modified record if duplicate slugs.
        prior = out.get(slug)
        if prior is None or state_file.stat().st_mtime > prior.stat().st_mtime:
            out[slug] = state_file
    return out


def write_marker(state_dir: Path, slug: str, source_file: Path) -> Path:
    """Write `<state_dir>/<slug>.done`. Body is an ISO-8601 timestamp plus
    the source stage-state.json path for audit. Returns the written path.
    """
    state_dir.mkdir(parents=True, exist_ok=True)
    marker = state_dir / f"{slug}.done"
    body = (
        datetime.now(timezone.utc).isoformat(timespec="seconds")
        + "\n"
        + f"BACKFILLED_FROM: {source_file}\n"
    )
    marker.write_text(body)
    return marker


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--runs-root",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "runs",
        help="root of run dirs; default: ../runs/ relative to this script",
    )
    p.add_argument(
        "--configs-root",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "configs",
        help="root of config tomls; default: ../configs/ relative to this script",
    )
    p.add_argument(
        "--state-dir",
        type=Path,
        default=Path(os.environ.get("STATE_DIR")
                     or Path.home() / "jazz-pipeline" / "state"),
        help="queue daemon STATE_DIR; default: ~/jazz-pipeline/state",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="print what would be written without touching disk",
    )
    args = p.parse_args(argv)

    completed = collect_completed_slugs(args.runs_root, args.configs_root)
    print(f"scanned {args.runs_root}; found {len(completed)} runs with s1=accepted")
    if not completed:
        return 0

    written = 0
    skipped_already = 0
    for slug, source in completed.items():
        marker = args.state_dir / f"{slug}.done"
        if marker.exists():
            skipped_already += 1
            print(f"  ALREADY: {slug}.done exists ({marker})")
            continue
        if args.dry_run:
            print(f"  WOULD WRITE: {marker} <- {source}")
        else:
            written_path = write_marker(args.state_dir, slug, source)
            print(f"  WROTE: {written_path} <- {source}")
            written += 1
    print(
        f"backfill complete: wrote {written}, skipped {skipped_already} "
        f"(already present), total eligible {len(completed)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
