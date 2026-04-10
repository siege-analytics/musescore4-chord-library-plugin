#!/usr/bin/env python3
"""Normalize the voicing library: deduplicate and add shape cross-references.

Actions:
1. Remove true duplicates (same shape + quality + context)
2. Add shape_id to every voicing, linking identical physical shapes
3. Report normalization statistics

Usage:
    python normalize.py              # dry run — show what would change
    python normalize.py --apply      # write changes to voicings.json
"""

import argparse
import json
import hashlib
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = REPO_ROOT / "plugin" / "data" / "voicings.json"


def shape_fingerprint(v: dict) -> str:
    """Compute a stable fingerprint for a voicing's physical shape."""
    dots = tuple(sorted((d["string"], d["fret"]) for d in v.get("dots", [])))
    mutes = tuple(sorted(v.get("mutes", [])))
    opens = tuple(sorted(v.get("open", [])))
    key = f"{v.get('strings', 6)}:{dots}:{mutes}:{opens}"
    return hashlib.md5(key.encode()).hexdigest()[:12]


def exact_fingerprint(v: dict) -> tuple:
    """Fingerprint including fret_number (exact position on neck)."""
    dots = tuple(sorted((d["string"], d["fret"]) for d in v.get("dots", [])))
    mutes = tuple(sorted(v.get("mutes", [])))
    return (v.get("strings", 6), v.get("fret_number", 0), dots, mutes)


def normalize(data: dict, apply: bool = False) -> dict:
    voicings = data["voicings"]
    print(f"Input: {len(voicings)} voicings")

    # Step 1: Remove true duplicates (same exact shape + quality + context)
    seen = {}
    deduped = []
    removed = 0
    for v in voicings:
        key = (exact_fingerprint(v), v["chord_quality"], v["context"])
        if key in seen:
            removed += 1
            print(f"  DUP REMOVED: {v['id']} (duplicate of {seen[key]})")
        else:
            seen[key] = v["id"]
            deduped.append(v)

    print(f"Step 1: Removed {removed} true duplicates → {len(deduped)} voicings")

    # Step 2: Assign shape_id to link related voicings
    by_shape = defaultdict(list)
    for v in deduped:
        sid = shape_fingerprint(v)
        by_shape[sid].append(v)

    shapes_with_multiple = sum(1 for g in by_shape.values() if len(g) > 1)
    print(f"Step 2: {len(by_shape)} unique shapes ({shapes_with_multiple} shared across entries)")

    for sid, group in by_shape.items():
        contexts = sorted({v["context"] for v in group})
        qualities = sorted({v["chord_quality"] for v in group})
        for v in group:
            v["shape_id"] = sid
            # Add cross-reference: what other contexts use this shape
            v["also_contexts"] = [c for c in contexts if c != v["context"]]
            # Add cross-reference: what other qualities share this shape
            v["also_qualities"] = [q for q in qualities if q != v["chord_quality"]]

    # Step 3: Sort by quality → context → category → fret for stability
    deduped.sort(key=lambda v: (
        v["chord_quality"], v["context"], v["category"],
        v.get("fret_number", 0), v["id"]
    ))

    result = {**data, "voicings": deduped}

    # Stats
    print(f"\nSummary:")
    print(f"  Before: {len(voicings)} voicings")
    print(f"  After:  {len(deduped)} voicings ({removed} removed)")
    print(f"  Shapes: {len(by_shape)} unique physical shapes")
    print(f"  Cross-context shapes: {shapes_with_multiple}")

    if apply:
        with open(DATA_FILE, "w") as f:
            json.dump(result, f, indent=2)
            f.write("\n")
        print(f"\n✓ Written to {DATA_FILE}")
    else:
        print(f"\nDry run — use --apply to write changes")

    return result


def main():
    parser = argparse.ArgumentParser(description="Normalize the voicing library")
    parser.add_argument("--apply", action="store_true", help="Write changes to voicings.json")
    args = parser.parse_args()

    with open(DATA_FILE) as f:
        data = json.load(f)

    normalize(data, apply=args.apply)


if __name__ == "__main__":
    main()
