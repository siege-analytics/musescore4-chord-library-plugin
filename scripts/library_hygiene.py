#!/usr/bin/env python3
"""Audit the voicing library for duplicates, enharmonic equivalents, and redundancies.

Checks:
1. Exact duplicates (same dots + fret_number + strings)
2. Enharmonic equivalents (same pitch class set, different root — e.g., C6/Am7)
3. Cross-context duplicates (same shape in CM6 vs CV6)
4. Cross-type redundancy (same shape labeled as different categories)

Usage:
    python library_hygiene.py                    # full audit
    python library_hygiene.py --fix              # auto-tag related voicings
    python library_hygiene.py --tuning config/tunings/standard.json
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"
DEFAULT_TUNING = REPO_ROOT / "config" / "tunings" / "7string-van-eps.json"

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Standard tuning with Van Eps 7th string
DEFAULT_MIDI = {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40, 7: 33}


def load_tuning(path: Path) -> dict[int, int]:
    with open(path) as f:
        data = json.load(f)
    return {int(k): v for k, v in data["strings"].items()}


def pitch_class_set(voicing: dict, tuning: dict[int, int]) -> frozenset[int]:
    """Compute the set of pitch classes sounded by a voicing."""
    pcs = set()
    fn = voicing["fret_number"]
    for dot in voicing.get("dots", []):
        s = dot["string"]
        if s in tuning:
            midi = tuning[s] + fn + (dot["fret"] - 1)
            pcs.add(midi % 12)
    for s in voicing.get("open", []):
        if s in tuning:
            pcs.add(tuning[s] % 12)
    return frozenset(pcs)


def dot_fingerprint(voicing: dict) -> tuple:
    """Fingerprint based on physical shape: sorted dots + mutes + strings."""
    dots = tuple(sorted((d["string"], d["fret"]) for d in voicing.get("dots", [])))
    mutes = tuple(sorted(voicing.get("mutes", [])))
    return (voicing.get("strings", 6), voicing.get("fret_number", 0), dots, mutes)


def shape_fingerprint(voicing: dict) -> tuple:
    """Fingerprint based on shape only (ignoring fret_number = transposition)."""
    dots = tuple(sorted((d["string"], d["fret"]) for d in voicing.get("dots", [])))
    mutes = tuple(sorted(voicing.get("mutes", [])))
    opens = tuple(sorted(voicing.get("open", [])))
    return (voicing.get("strings", 6), dots, mutes, opens)


def identify_chord_quality(pcs: frozenset[int]) -> list[tuple[str, str]]:
    """Identify possible chord qualities from a pitch class set."""
    qualities = {
        "maj": frozenset({0, 4, 7}),
        "min": frozenset({0, 3, 7}),
        "dom7": frozenset({0, 4, 7, 10}),
        "maj7": frozenset({0, 4, 7, 11}),
        "min7": frozenset({0, 3, 7, 10}),
        "min7b5": frozenset({0, 3, 6, 10}),
        "dim7": frozenset({0, 3, 6, 9}),
        "maj6": frozenset({0, 4, 7, 9}),
        "min6": frozenset({0, 3, 7, 9}),
        "sus4": frozenset({0, 5, 7}),
        "sus2": frozenset({0, 2, 7}),
    }
    results = []
    for root_pc in range(12):
        intervals = frozenset((pc - root_pc) % 12 for pc in pcs)
        for qname, required in qualities.items():
            if required.issubset(intervals):
                results.append((CHROMATIC[root_pc], qname))
    return results


def audit(data: dict, tuning: dict[int, int]) -> dict:
    """Run all hygiene checks on the voicing library."""
    voicings = data["voicings"]
    report = {
        "exact_duplicates": [],
        "enharmonic_equivalents": [],
        "cross_context": [],
        "cross_type": [],
        "total": len(voicings),
    }

    # 1. Exact duplicates: same dots + fret_number + strings
    by_fingerprint: dict[tuple, list] = defaultdict(list)
    for v in voicings:
        fp = dot_fingerprint(v)
        by_fingerprint[fp].append(v["id"])

    for fp, ids in by_fingerprint.items():
        if len(ids) > 1:
            report["exact_duplicates"].append({
                "ids": ids,
                "fingerprint": str(fp),
            })

    # 2. Enharmonic equivalents: same pitch class set, different root/quality
    by_pcs: dict[frozenset, list] = defaultdict(list)
    for v in voicings:
        pcs = pitch_class_set(v, tuning)
        if pcs:
            by_pcs[pcs].append({
                "id": v["id"],
                "name": v["name"],
                "quality": v["chord_quality"],
                "root": v["root"],
                "fret": v["fret_number"],
            })

    for pcs, group in by_pcs.items():
        if len(group) > 1:
            # Check if they have different qualities
            qualities = {g["quality"] for g in group}
            if len(qualities) > 1:
                alt_names = identify_chord_quality(pcs)
                report["enharmonic_equivalents"].append({
                    "pitch_classes": [CHROMATIC[pc] for pc in sorted(pcs)],
                    "voicings": group,
                    "possible_names": [f"{r}{q}" for r, q in alt_names],
                })

    # 3. Cross-context: same shape in different contexts
    by_shape_context: dict[tuple, list] = defaultdict(list)
    for v in voicings:
        shape = shape_fingerprint(v)
        by_shape_context[shape].append({
            "id": v["id"],
            "context": v["context"],
            "category": v["category"],
        })

    for shape, group in by_shape_context.items():
        contexts = {g["context"] for g in group}
        if len(contexts) > 1:
            report["cross_context"].append({
                "shape": str(shape),
                "voicings": group,
            })

    # 4. Cross-type: same shape labeled as different categories
    by_shape_type: dict[tuple, list] = defaultdict(list)
    for v in voicings:
        shape = shape_fingerprint(v)
        by_shape_type[shape].append({
            "id": v["id"],
            "category": v["category"],
            "context": v["context"],
        })

    for shape, group in by_shape_type.items():
        categories = {g["category"] for g in group}
        if len(categories) > 1:
            report["cross_type"].append({
                "shape": str(shape),
                "voicings": group,
                "categories": sorted(categories),
            })

    return report


def print_report(report: dict):
    print(f"Library Hygiene Report ({report['total']} voicings)")
    print("=" * 60)

    # Exact duplicates
    dupes = report["exact_duplicates"]
    print(f"\n1. Exact Duplicates: {len(dupes)} groups")
    for d in dupes:
        print(f"   {' = '.join(d['ids'])}")

    # Enharmonic equivalents
    enharm = report["enharmonic_equivalents"]
    print(f"\n2. Enharmonic Equivalents: {len(enharm)} groups")
    for e in enharm:
        notes = " ".join(e["pitch_classes"])
        names = ", ".join(e["possible_names"][:5])
        print(f"   [{notes}] → {names}")
        for v in e["voicings"]:
            print(f"      {v['id']} ({v['quality']})")

    # Cross-context
    xctx = report["cross_context"]
    print(f"\n3. Cross-Context (same shape, different context): {len(xctx)} groups")
    for x in xctx[:5]:
        ids = [f"{v['id']}({v['context']})" for v in x["voicings"]]
        print(f"   {' | '.join(ids)}")

    # Cross-type
    xtype = report["cross_type"]
    print(f"\n4. Cross-Type (same shape, different category): {len(xtype)} groups")
    for x in xtype[:5]:
        ids = [f"{v['id']}({v['category']})" for v in x["voicings"]]
        print(f"   {' | '.join(ids)}")

    # Summary
    total_issues = len(dupes) + len(enharm) + len(xctx) + len(xtype)
    if total_issues == 0:
        print("\nLibrary is clean.")
    else:
        print(f"\nTotal: {total_issues} groups flagged for review")


def main():
    parser = argparse.ArgumentParser(description="Audit the voicing library")
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--tuning", type=Path, default=DEFAULT_TUNING)
    parser.add_argument("--fix", action="store_true", help="Auto-tag related voicings")
    parser.add_argument("-o", "--output", type=Path, help="Save report as JSON")
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)

    tuning = load_tuning(args.tuning)
    report = audit(data, tuning)
    print_report(report)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(report, f, indent=2)
        print(f"\nReport saved to {args.output}")


if __name__ == "__main__":
    main()
