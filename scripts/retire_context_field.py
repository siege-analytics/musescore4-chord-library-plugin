#!/usr/bin/env python3
"""Retire the legacy `context` field from voicings.json (#174 Stage 3).

Mode + tuning now cover what context was trying to say. The `suitableModes`
field (added by migrate_context_to_modes.py in v2.1) replaces it. Strip
`context` and `also_contexts` from every voicing.

Idempotent — re-running on already-retired data produces no diff.

Usage:
    python scripts/retire_context_field.py
    python scripts/retire_context_field.py --dry-run
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "plugin" / "data" / "voicings.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    with args.data.open() as f:
        payload = json.load(f)

    voicings = payload.get("voicings", [])
    changed = 0
    missing_modes: list[str] = []

    for v in voicings:
        had = ("context" in v) or ("also_contexts" in v)
        v.pop("context", None)
        v.pop("also_contexts", None)
        if had:
            changed += 1
        if not v.get("suitableModes"):
            missing_modes.append(v.get("id", "<no id>"))

    if missing_modes:
        print(
            f"Refusing to retire context: {len(missing_modes)} voicings have no suitableModes. "
            "Run migrate_context_to_modes.py first.",
            file=sys.stderr,
        )
        for mid in missing_modes[:10]:
            print(f"  {mid}", file=sys.stderr)
        return 2

    print(f"{changed} of {len(voicings)} voicings had context/also_contexts removed")

    if args.dry_run:
        print("Dry run — no file written")
        return 0
    if changed == 0:
        print("No changes — file not rewritten")
        return 0

    payload["voicings"] = voicings
    with args.data.open("w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    print(f"Wrote {args.data}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
