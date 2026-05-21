#!/usr/bin/env python3
"""Derive curated-shapes.json from voicings.json (#194).

The 820 curated voicings in voicings.json collapse to ~167 unique
root-relative fingering signatures after stripping per-root variants.
This script computes the signatures and emits two files the plugin
loads at runtime:

  plugin/data/curated-shapes.json    — signature -> boost metadata
  plugin/data/additional-shapes.json — entries we want to surface
                                       but whose signature the
                                       calculator may not regenerate
                                       under default constraints

The signature is root-relative: it captures the interval played on
each string (plus mutes/opens/strings count), not the absolute frets.
So "C7 shell on strings 6/4/3" and "F7 shell on strings 6/4/3" share
the same signature.

Calculator output also exposes `intervals` parallel to `notes`, so
matching at runtime is symmetric: compute the candidate's signature,
look up in the signature map.

Usage:
    python scripts/derive_curated_shapes.py
    python scripts/derive_curated_shapes.py --dry-run
    python scripts/derive_curated_shapes.py --report
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE = REPO_ROOT / "plugin" / "data" / "voicings.json"
DEST_CURATED = REPO_ROOT / "plugin" / "data" / "curated-shapes.json"
DEST_ADDITIONAL = REPO_ROOT / "plugin" / "data" / "additional-shapes.json"


def signature_of(voicing: dict) -> tuple:
    """Compute a root-relative fingering signature.

    Returns a tuple of:
      (strings, frozenset(mutes), frozenset(opens), tuple((string, interval), ...))
    """
    strings = voicing.get("strings", 6)
    mutes = frozenset(voicing.get("mutes", []))
    opens = frozenset(voicing.get("open", []))
    dots = voicing.get("dots", [])
    intervals = voicing.get("intervals", [])
    # dots[i] aligns with intervals[i]
    pairs = []
    for i, dot in enumerate(dots):
        if i >= len(intervals):
            continue  # malformed data; skip
        pairs.append((dot["string"], intervals[i]))
    pairs.sort()
    return (strings, mutes, opens, tuple(pairs))


def signature_to_json(sig: tuple) -> dict:
    """Serialize a signature tuple as a JSON-friendly dict.

    The runtime side (ChordSelector._signatureKey) builds the same
    shape and stringifies it; keep the two implementations in sync.
    """
    strings, mutes, opens, pairs = sig
    return {
        "strings": strings,
        "mutes": sorted(mutes),
        "opens": sorted(opens),
        "pairs": [list(p) for p in pairs],
    }


def boost_for(entries: list[dict]) -> int:
    """Pick a boost magnitude based on the curated entry's tags.

    Range +40 to +80 per think-v2.4-design.md assumption (above mode
    +25, below the +500 melody/bass-lock bonus). Higher boost for
    famous traditions; lower for routine shapes.
    """
    tags = set()
    for e in entries:
        for t in e.get("tags", []):
            tags.add(t)
    # Traditions get strong boost
    if any(t in tags for t in ("freddie-green", "ted-greene-ninth",
                                "barry-harris-sixth-diminished")):
        return 80
    # Named idiomatic patterns
    if any(t in tags for t in ("van-eps", "guide-tone", "shell")):
        return 60
    # Generic curated entries
    return 40


def primary_entry(entries: list[dict]) -> dict:
    """Pick the deterministic 'primary' entry from a signature group.

    Tie-breakers: shortest name, then alphabetical id.
    """
    return sorted(entries, key=lambda e: (len(e.get("name", "")),
                                           e.get("id", "")))[0]


def aggregate_traditions(entries: list[dict]) -> list[str]:
    """Union the tradition-shaped tags across a signature group."""
    tradition_keys = {
        "freddie-green", "ted-greene", "ted-greene-ninth",
        "barry-harris-sixth-diminished", "van-eps",
        "guide-tone", "caged-a", "caged-d", "caged-e",
        "laukens-coverage", "laukens-p37", "chords-db",
    }
    found = set()
    for e in entries:
        for t in e.get("tags", []):
            if t in tradition_keys:
                found.add(t)
    return sorted(found)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report", action="store_true",
                        help="Print signature group sizes and exit")
    args = parser.parse_args()

    with args.source.open() as f:
        payload = json.load(f)

    voicings = payload.get("voicings", [])
    by_signature: dict[tuple, list[dict]] = defaultdict(list)

    for v in voicings:
        sig = signature_of(v)
        by_signature[sig].append(v)

    if args.report:
        sizes = sorted((len(v), sig) for sig, v in by_signature.items())
        print(f"{len(voicings)} voicings collapse to {len(by_signature)} signatures")
        print(f"  largest group: {sizes[-1][0]} entries")
        print(f"  smallest group: {sizes[0][0]} entries")
        from collections import Counter
        dist = Counter(len(v) for v in by_signature.values())
        for size, count in sorted(dist.items()):
            print(f"  {count} signature(s) with {size} entries each")
        return 0

    # Build curated shapes — one entry per signature
    curated = []
    for sig, entries in sorted(by_signature.items()):
        primary = primary_entry(entries)
        traditions = aggregate_traditions(entries)
        sig_json = signature_to_json(sig)
        # Use the primary entry's name but strip the leading "C7 — " /
        # "Cmaj7 — " portion since the shape is root-relative.
        name = primary.get("name", primary.get("id", "unnamed"))
        if " — " in name:
            # "C13b9 — Fret 5 — Altered (6th on top)" -> drop the first segment
            name = " — ".join(name.split(" — ")[1:])
        curated.append({
            "signature": sig_json,
            "name": name,
            "category": primary.get("category", ""),
            "chord_quality": primary.get("chord_quality", ""),
            "traditions": traditions,
            "boost": boost_for(entries),
            "intervals": list(primary.get("intervals", [])),
            "sourceCount": len(entries),
        })

    additional: list[dict] = []
    # For v0 of the migration we don't yet split additional-shapes;
    # ALL curated shapes go to curated-shapes.json. The split is a
    # follow-up once we measure calculator regeneration rate against
    # the curated set (see acceptance criteria for #194).

    print(f"{len(voicings)} curated voicings -> {len(curated)} signature groups")
    print(f"  boost distribution:")
    from collections import Counter
    boost_dist = Counter(c["boost"] for c in curated)
    for boost, count in sorted(boost_dist.items()):
        print(f"    {boost}: {count} shapes")

    if args.dry_run:
        print("Dry run — no files written")
        return 0

    payload_curated = {
        "version": "v1",
        "schemaNote": "signature is root-relative; ChordSelector computes the same shape per candidate at runtime",
        "shapes": curated,
    }
    with DEST_CURATED.open("w") as f:
        json.dump(payload_curated, f, indent=2)
        f.write("\n")
    print(f"Wrote {DEST_CURATED}")

    payload_additional = {
        "version": "v1",
        "schemaNote": "shapes the calculator may not regenerate under default constraints — empty until we measure",
        "shapes": additional,
    }
    with DEST_ADDITIONAL.open("w") as f:
        json.dump(payload_additional, f, indent=2)
        f.write("\n")
    print(f"Wrote {DEST_ADDITIONAL}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
