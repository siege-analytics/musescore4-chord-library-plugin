#!/usr/bin/env python3
"""Validate voicings.json against the JSON schema.

Usage:
    python scripts/validate.py
    python scripts/validate.py --data path/to/voicings.json
    python scripts/validate.py --verbose
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import jsonschema
    from jsonschema import Draft202012Validator
except ImportError:
    print("Missing dependency: pip install jsonschema", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SCHEMA = REPO_ROOT / "schema" / "voicings.schema.json"
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"


def validate(schema_path: Path, data_path: Path, verbose: bool = False) -> bool:
    with open(schema_path) as f:
        schema = json.load(f)
    with open(data_path) as f:
        data = json.load(f)

    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))

    if not errors:
        count = len(data.get("voicings", []))
        print(f"Valid. {count} voicing(s) passed schema validation.")
        if verbose:
            _print_summary(data)
        return True

    print(f"INVALID. {len(errors)} error(s) found:\n", file=sys.stderr)
    for i, error in enumerate(errors, 1):
        path = " > ".join(str(p) for p in error.absolute_path) or "(root)"
        print(f"  {i}. [{path}] {error.message}", file=sys.stderr)
    return False


def _check_consistency(data: dict) -> list[str]:
    """Run additional consistency checks beyond schema validation."""
    warnings = []
    seen_ids = set()

    for i, v in enumerate(data.get("voicings", [])):
        vid = v.get("id", f"<index {i}>")

        # Duplicate ID check
        if vid in seen_ids:
            warnings.append(f"Duplicate id: {vid}")
        seen_ids.add(vid)

        # Mutes + dots + open should cover all strings
        strings = v.get("strings", 6)
        all_strings = set(range(1, strings + 1))
        dotted = {d["string"] for d in v.get("dots", [])}
        muted = set(v.get("mutes", []))
        opened = set(v.get("open", []))
        accounted = dotted | muted | opened
        unaccounted = all_strings - accounted
        if unaccounted:
            warnings.append(
                f"{vid}: strings {sorted(unaccounted)} not in dots/mutes/open"
            )

        # Dot/mute/open overlap check
        overlap = dotted & muted
        if overlap:
            warnings.append(
                f"{vid}: strings {sorted(overlap)} in both dots and mutes"
            )
        overlap = dotted & opened
        if overlap:
            warnings.append(
                f"{vid}: strings {sorted(overlap)} in both dots and open"
            )

        # Notes and intervals length match
        if len(v.get("notes", [])) != len(v.get("intervals", [])):
            warnings.append(
                f"{vid}: notes ({len(v['notes'])}) and intervals "
                f"({len(v['intervals'])}) count mismatch"
            )

        # Notes count should match dots count
        if len(v.get("notes", [])) != len(v.get("dots", [])):
            warnings.append(
                f"{vid}: notes ({len(v['notes'])}) and dots "
                f"({len(v['dots'])}) count mismatch"
            )

    return warnings


def _print_summary(data: dict) -> None:
    voicings = data.get("voicings", [])
    contexts = {}
    categories = {}
    qualities = {}

    for v in voicings:
        ctx = v.get("context", "?")
        contexts[ctx] = contexts.get(ctx, 0) + 1
        cat = v.get("category", "?")
        categories[cat] = categories.get(cat, 0) + 1
        qual = v.get("chord_quality", "?")
        qualities[qual] = qualities.get(qual, 0) + 1

    print(f"\n--- Summary ---")
    print(f"Total voicings: {len(voicings)}")
    print(f"By context:  {contexts}")
    print(f"By category: {categories}")
    print(f"By quality:  {qualities}")


def main():
    parser = argparse.ArgumentParser(description="Validate voicings.json")
    parser.add_argument(
        "--schema", type=Path, default=DEFAULT_SCHEMA, help="Path to JSON schema"
    )
    parser.add_argument(
        "--data", type=Path, default=DEFAULT_DATA, help="Path to voicings.json"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Show summary")
    args = parser.parse_args()

    if not args.schema.exists():
        print(f"Schema not found: {args.schema}", file=sys.stderr)
        sys.exit(1)
    if not args.data.exists():
        print(f"Data not found: {args.data}", file=sys.stderr)
        sys.exit(1)

    valid = validate(args.schema, args.data, args.verbose)

    # Run consistency checks regardless
    with open(args.data) as f:
        data = json.load(f)
    warnings = _check_consistency(data)
    if warnings:
        print(f"\n{len(warnings)} consistency warning(s):", file=sys.stderr)
        for w in warnings:
            print(f"  - {w}", file=sys.stderr)

    sys.exit(0 if valid else 1)


if __name__ == "__main__":
    main()
