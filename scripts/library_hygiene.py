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
        # Triads
        "maj": frozenset({0, 4, 7}),
        "min": frozenset({0, 3, 7}),
        "dim": frozenset({0, 3, 6}),
        "aug": frozenset({0, 4, 8}),
        "sus4": frozenset({0, 5, 7}),
        "sus2": frozenset({0, 2, 7}),
        # 7th chords
        "dom7": frozenset({0, 4, 7, 10}),
        "maj7": frozenset({0, 4, 7, 11}),
        "min7": frozenset({0, 3, 7, 10}),
        "min7b5": frozenset({0, 3, 6, 10}),
        "dim7": frozenset({0, 3, 6, 9}),
        "min-maj7": frozenset({0, 3, 7, 11}),
        "aug7": frozenset({0, 4, 8, 10}),
        # 6th chords
        "maj6": frozenset({0, 4, 7, 9}),
        "min6": frozenset({0, 3, 7, 9}),
        # Altered dominants (match with subset — these omit the 5th)
        "dom7sharp5": frozenset({0, 4, 8, 10}),
        "dom7flat5": frozenset({0, 4, 6, 10}),
        "dom7b9": frozenset({0, 1, 4, 10}),
        "dom7sharp11": frozenset({0, 4, 6, 10}),
        "dom7b13": frozenset({0, 4, 8, 10}),
        # Extensions (match with core tones — 5th often omitted)
        "dom9": frozenset({0, 2, 4, 10}),
        "maj9": frozenset({0, 2, 4, 11}),
        "min9": frozenset({0, 2, 3, 10}),
        "dom13": frozenset({0, 4, 9, 10}),
        "maj13": frozenset({0, 4, 9, 11}),
        "min11": frozenset({0, 3, 5, 10}),
        "maj69": frozenset({0, 2, 4, 9}),
        "maj7sharp11": frozenset({0, 4, 6, 11}),
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
        "suspicious_names": [],
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

    # 5. Suspicious names: declared quality doesn't match detected quality
    # Map our quality names to the identify_chord_quality names
    quality_aliases = {
        "dom7": "dom7", "maj7": "maj7", "min7": "min7",
        "min7b5": "min7b5", "dim7": "dim7",
        "maj6": "maj6", "min6": "min6",
        "dom7sharp5": "dom7",  # shell might not have #5
        "dom7flat5": "dom7",   # shell might not have b5
        "dom7alt": "dom7",     # alt is dom7 with alterations
        "dom7b9": "dom7",      # dom7 with b9
        "dom7sharp11": "dom7", # dom7 with #11
        "dom7b13": "dom7",     # dom7 with b13
        "aug7": "maj7",        # aug7 shell without #5 looks like maj7
        "dom9": "dom7",        # dom9 is dom7 + 9
        "maj9": "maj7",        # maj9 is maj7 + 9
        "min9": "min7",        # min9 is min7 + 9
        "dom13": "dom7",       # dom13 is dom7 + 13
        "min11": "min7",       # min11 is min7 + 11
        "min-maj7": "min-maj7",
        "sus4": "sus4", "sus2": "sus2",
        "quartal": None,       # quartal is ambiguous by definition
        "maj69": "maj6",       # 6/9 is maj6 + 9
        "maj13": "maj7",       # maj13 is maj7 + 13
        "maj7sharp11": "maj7", # maj7#11 is maj7 + #11
    }

    for v in voicings:
        pcs = pitch_class_set(v, tuning)
        if not pcs or len(pcs) < 3:
            continue

        declared = v["chord_quality"]
        if declared == "quartal":
            continue  # quartal voicings are intentionally ambiguous

        # Shell voicings (3 notes) deliberately omit distinguishing tones
        # (e.g., dom7 shell = 1-3-b7, no 5th — can't distinguish from dom7#5)
        # Only flag 4+ note voicings
        sounding_count = len(v.get("dots", [])) + len(v.get("open", []))
        if sounding_count <= 3:
            continue

        # What does identify_chord_quality think this is?
        detected = identify_chord_quality(pcs)
        detected_with_c_root = {q for r, q in detected if r == "C"}

        # What should it match?
        expected_base = quality_aliases.get(declared)
        if expected_base is None:
            continue

        # Check if the detected qualities include the expected base
        if expected_base not in detected_with_c_root:
            # Also check if the declared quality itself matches
            if declared not in detected_with_c_root:
                report["suspicious_names"].append({
                    "id": v["id"],
                    "name": v["name"],
                    "declared_quality": declared,
                    "detected_qualities": sorted(detected_with_c_root),
                    "pitch_classes": [CHROMATIC[pc] for pc in sorted(pcs)],
                    "notes": v.get("notes", []),
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

    # Suspicious names
    suspect = report.get("suspicious_names", [])
    print(f"\n5. Suspicious Names (declared quality ≠ detected): {len(suspect)}")
    for s in suspect:
        detected = ", ".join(s["detected_qualities"]) or "unknown"
        print(f"   {s['id']}: declared '{s['declared_quality']}', detected [{detected}]")
        print(f"      notes: {' '.join(s['notes'])}, pcs: {' '.join(s['pitch_classes'])}")

    # Summary
    total_issues = len(dupes) + len(enharm) + len(xctx) + len(xtype) + len(suspect)
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
