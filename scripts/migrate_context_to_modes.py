#!/usr/bin/env python3
"""Migrate voicings.json: add suitableModes derived from legacy context.

Mapping:
    CM6, CM7 -> ["chord-melody"]
    CV6, CV7 -> ["comping"]

The legacy `context` field is preserved for one release (grace period).
Script is idempotent — re-running on already-migrated data produces no diff.
Fails loud on any voicing whose context can't be mapped.

Usage:
    python scripts/migrate_context_to_modes.py
    python scripts/migrate_context_to_modes.py --data path/to/voicings.json
    python scripts/migrate_context_to_modes.py --dry-run
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "plugin" / "data" / "voicings.json"

CONTEXT_TO_MODES = {
    "CM6": ["chord-melody"],
    "CM7": ["chord-melody"],
    "CV6": ["comping"],
    "CV7": ["comping"],
}


def migrate(voicing: dict) -> tuple[dict, bool]:
    """Return (updated_voicing, changed). Raises ValueError on unmappable context."""
    if "suitableModes" in voicing and voicing["suitableModes"]:
        return voicing, False

    ctx = voicing.get("context")
    if not ctx:
        raise ValueError(
            f"voicing {voicing.get('id', '<no id>')} has neither suitableModes nor context"
        )
    if ctx not in CONTEXT_TO_MODES:
        raise ValueError(
            f"voicing {voicing.get('id', '<no id>')} has unknown context {ctx!r}; "
            f"add a mapping to CONTEXT_TO_MODES"
        )

    voicing = dict(voicing)
    voicing["suitableModes"] = list(CONTEXT_TO_MODES[ctx])
    return voicing, True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    with args.data.open() as f:
        payload = json.load(f)

    voicings = payload.get("voicings", [])
    migrated = []
    changed_count = 0
    errors: list[str] = []

    for v in voicings:
        try:
            new_v, changed = migrate(v)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        migrated.append(new_v)
        if changed:
            changed_count += 1

    if errors:
        print("Migration failed — unmappable voicings:", file=sys.stderr)
        for msg in errors:
            print(f"  {msg}", file=sys.stderr)
        return 2

    total = len(voicings)
    print(f"{changed_count} of {total} voicings updated "
          f"({total - changed_count} already migrated)")

    if args.dry_run:
        print("Dry run — no file written")
        return 0

    if changed_count == 0:
        print("No changes — file not rewritten")
        return 0

    payload["voicings"] = migrated
    with args.data.open("w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    print(f"Wrote {args.data}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
