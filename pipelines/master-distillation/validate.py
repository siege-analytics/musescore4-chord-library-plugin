#!/usr/bin/env python3
"""Quote-fidelity validator.

Re-checks every blockquote in plugin/data/masters-corpus/<master>/<work>/chapters/*.md
against the run's raw transcript. Fails if any quote isn't a verbatim
substring (whitespace-normalized).

Used by Stage 2 internally and useful standalone after manual edits or
in CI.

Usage:
  validate.py <run-id>
  validate.py --master <master> --work <work> --run <run-id>
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(PIPELINE_DIR))

from lib import paths, text  # noqa: E402

BLOCKQUOTE_RE = re.compile(r"^>\s?(.*)$", re.MULTILINE)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("run_id", help="run id (date-prefixed dir name)")
    args = p.parse_args()

    run_dir = paths.RUNS_ROOT / args.run_id
    raw_transcript = run_dir / "raw-transcript.txt"
    state_path = run_dir / "stage-state.json"

    if not raw_transcript.exists():
        print(
            f"raw transcript missing at {raw_transcript}. The pipeline "
            f"gitignores it; re-run Stage 1 to regenerate.",
            file=sys.stderr,
        )
        return 2
    if not state_path.exists():
        print(f"no run state at {state_path}", file=sys.stderr)
        return 2

    # Resolve which master / work this run targets via the state file's
    # config path.
    import json
    import tomllib

    state = json.loads(state_path.read_text())
    cfg = tomllib.loads(Path(state["config"]).read_text())
    master_id = cfg["master"]["id"]
    work_id = cfg["work"]["id"]

    book = paths.BookPaths(master_id=master_id, work_id=work_id, run_id=args.run_id)
    chapters_dir = book.committed_chapters_dir
    if not chapters_dir.exists():
        print(f"no chapters dir at {chapters_dir}", file=sys.stderr)
        return 2

    transcript = text.load_transcript(raw_transcript)

    failures: list[tuple[str, str]] = []
    checked = 0
    for ch_file in sorted(chapters_dir.glob("ch*.md")):
        body = ch_file.read_text()
        # Strip the frontmatter so we don't validate run_id etc.
        if body.startswith("---"):
            parts = body.split("---", 2)
            if len(parts) == 3:
                body = parts[2]

        # Only consider blockquotes that appear AFTER the first `## `
        # heading — that's where topic-organized quotes live. The
        # document-level callout block (Verbatim-quote constraint) sits
        # before any `## ` and gets skipped.
        first_topic = body.find("\n## ")
        if first_topic == -1:
            # No topic sections (chapter with no extracted quotes).
            continue
        body = body[first_topic:]

        # Collect contiguous blockquote spans (the body of one quote may
        # be multiple `>` lines). Group consecutive blockquote lines.
        current: list[str] = []
        quotes: list[str] = []
        for line in body.splitlines():
            m = BLOCKQUOTE_RE.match(line)
            if m:
                current.append(m.group(1))
            else:
                if current:
                    quotes.append("\n".join(current).strip())
                    current = []
        if current:
            quotes.append("\n".join(current).strip())

        for q in quotes:
            checked += 1
            if not text.verify_quote_in_transcript(q, transcript):
                failures.append((ch_file.name, q))

    if failures:
        print(f"FAIL — {len(failures)} of {checked} quotes don't match transcript:")
        for fname, q in failures[:10]:
            preview = q[:80].replace("\n", " ")
            print(f"  {fname}: {preview!r}")
        if len(failures) > 10:
            print(f"  ... and {len(failures) - 10} more")
        return 1

    print(f"OK — {checked} quotes match the raw transcript verbatim.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
