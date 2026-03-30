#!/usr/bin/env python3
"""Calculate practical chord voicings for any guitar tuning.

For each chord quality and root, finds playable voicings where:
- The root is the lowest sounding note (bass note = root)
- At least 3 notes are sounding (4 for 7th chords)
- Fret stretch is within human hand limits
- Voicings are deduplicated by pitch class set + bass note
- Results ranked by playability (fewer mutes, smaller stretch)

Usage:
    python chord_calculator.py                                    # standard tuning
    python chord_calculator.py --tuning config/tunings/dadgad.json
    python chord_calculator.py --tuning config/tunings/dadgad.json --root D
    python chord_calculator.py --tuning config/tunings/dadgad.json -o dadgad-chords.json
    python chord_calculator.py --tuning config/tunings/dadgad.json --export  # voicings.json format
"""

import argparse
import itertools
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Chord quality definitions: name → (required semitones, display name, min notes)
CHORD_QUALITIES = {
    "maj":      (frozenset({0, 4, 7}), "maj", 3),
    "min":      (frozenset({0, 3, 7}), "min", 3),
    "dom7":     (frozenset({0, 4, 7, 10}), "7", 3),
    "maj7":     (frozenset({0, 4, 7, 11}), "maj7", 3),
    "min7":     (frozenset({0, 3, 7, 10}), "m7", 3),
    "min7b5":   (frozenset({0, 3, 6, 10}), "m7b5", 3),
    "dim7":     (frozenset({0, 3, 6, 9}), "dim7", 3),
    "dom7b9":   (frozenset({0, 1, 4, 10}), "7b9", 4),
    "sus4":     (frozenset({0, 5, 7}), "sus4", 3),
    "sus2":     (frozenset({0, 2, 7}), "sus2", 3),
    "maj6":     (frozenset({0, 4, 7, 9}), "6", 3),
    "min6":     (frozenset({0, 3, 7, 9}), "m6", 3),
    "aug":      (frozenset({0, 4, 8}), "aug", 3),
    "dim":      (frozenset({0, 3, 6}), "dim", 3),
}

MAX_FRET = 15
MAX_STRETCH = 4


def load_tuning(path: Path) -> tuple[str, dict[int, int]]:
    with open(path) as f:
        data = json.load(f)
    return data.get("name", path.stem), {int(k): v for k, v in data["strings"].items()}


def note_name(midi: int) -> str:
    return CHROMATIC[midi % 12]


def pc(midi: int) -> int:
    return midi % 12


def interval_label(root_pc: int, note_pc: int) -> str:
    """Get the interval name from root to note."""
    semitones = (note_pc - root_pc) % 12
    labels = {
        0: "1", 1: "b9", 2: "9", 3: "b3", 4: "3", 5: "4",
        6: "b5", 7: "5", 8: "#5", 9: "6", 10: "b7", 11: "7",
    }
    return labels.get(semitones, "?")


def find_practical_voicings(
    tuning: dict[int, int],
    target_root: str | None = None,
    max_fret: int = MAX_FRET,
    max_stretch: int = MAX_STRETCH,
) -> list[dict]:
    """Find practical chord voicings with root in bass."""
    strings = sorted(tuning.keys())  # 1=highest, 6=lowest (or 7)
    strings_low_to_high = list(reversed(strings))  # 6,5,4,3,2,1

    results = []
    # Deduplicate: (root_pc, quality, pitch_class_tuple_sorted) → best voicing
    best_voicings: dict[tuple, dict] = {}

    roots_to_check = range(12) if not target_root else [CHROMATIC.index(target_root)]

    for root_pc in roots_to_check:
        root_name = CHROMATIC[root_pc]

        for quality_id, (required_intervals, display, min_notes) in CHORD_QUALITIES.items():
            # Target pitch classes for this chord
            target_pcs = {(root_pc + iv) % 12 for iv in required_intervals}

            # Find which strings can produce which target notes at which frets
            # Also track which strings can produce the root for bass
            string_options: dict[int, list[tuple[int, int]]] = {}  # string → [(fret, pc)]

            for s in strings:
                opts = []
                # Open string
                open_pc = pc(tuning[s])
                if open_pc in target_pcs:
                    opts.append((0, open_pc))
                # Fretted positions
                for f in range(1, max_fret + 1):
                    fret_pc = pc(tuning[s] + f)
                    if fret_pc in target_pcs:
                        opts.append((f, fret_pc))
                # Muted
                opts.append((-1, -1))
                string_options[s] = opts

            # Find bass strings that can produce the root
            bass_candidates = []
            for s in strings_low_to_high:  # lowest string first
                for fret, fret_pc in string_options[s]:
                    if fret >= 0 and fret_pc == root_pc:
                        bass_candidates.append((s, fret))
                if bass_candidates:
                    break  # only use the lowest string that can play the root

            if not bass_candidates:
                continue

            for bass_string, bass_fret in bass_candidates:
                # Now find voicings for the remaining strings
                # Strings below the bass string are muted
                remaining_strings = [s for s in strings if s < bass_string]  # higher-pitched
                muted_below = [s for s in strings if s > bass_string]  # lower strings, muted

                # For each remaining string, filter options by fret stretch from bass
                if bass_fret > 0:
                    fret_range = range(
                        max(0, bass_fret - max_stretch),
                        bass_fret + max_stretch + 1,
                    )
                else:
                    fret_range = range(0, max_stretch + 2)  # open bass, fretted up to stretch

                filtered_options = []
                for s in remaining_strings:
                    opts = []
                    for fret, fret_pc in string_options[s]:
                        if fret == -1:
                            opts.append((-1, -1))
                        elif fret == 0:
                            opts.append((0, fret_pc))
                        elif fret in fret_range:
                            opts.append((fret, fret_pc))
                    if not opts:
                        opts = [(-1, -1)]
                    filtered_options.append((s, opts))

                # Limit combinations: max 5 remaining strings × ~6 options = manageable
                option_lists = [opts for _, opts in filtered_options]
                if not option_lists:
                    continue

                for combo in itertools.product(*option_lists):
                    # Build the full voicing: bass + combo + muted below
                    all_notes = [(bass_string, bass_fret, root_pc)]
                    fretted = [bass_fret] if bass_fret > 0 else []

                    for i, (fret, fret_pc) in enumerate(combo):
                        s = filtered_options[i][0]
                        if fret >= 0:
                            all_notes.append((s, fret, fret_pc))
                            if fret > 0:
                                fretted.append(fret)

                    # Check minimum notes
                    if len(all_notes) < min_notes:
                        continue

                    # Check stretch
                    if fretted and (max(fretted) - min(fretted)) > max_stretch:
                        continue

                    # Check that we have the required pitch classes
                    sounding_pcs = {n_pc for _, _, n_pc in all_notes}
                    if not required_intervals.issubset(
                        {(p - root_pc) % 12 for p in sounding_pcs}
                    ):
                        continue

                    # Verify root is the lowest sounding note
                    bass_midi = tuning[bass_string] + bass_fret
                    is_root_lowest = True
                    for s, f, _ in all_notes:
                        if s != bass_string:
                            note_midi = tuning[s] + f
                            if note_midi < bass_midi:
                                is_root_lowest = False
                                break
                    if not is_root_lowest:
                        continue

                    # Deduplicate by sound (pitch class set + bass)
                    pc_tuple = tuple(sorted(sounding_pcs))
                    dedup_key = (root_pc, quality_id, pc_tuple)

                    # Score: fewer mutes = better, smaller stretch = better
                    n_muted = sum(1 for _, (f, _) in zip(
                        [filtered_options[i][0] for i in range(len(combo))],
                        combo,
                    ) if f == -1) + len(muted_below)
                    stretch = (max(fretted) - min(fretted)) if fretted else 0
                    score = n_muted * 10 + stretch

                    if dedup_key in best_voicings:
                        if score >= best_voicings[dedup_key]["_score"]:
                            continue

                    # Build the voicing
                    fn = min(fretted) if fretted else 1
                    dots = []
                    notes = []
                    intervals = []
                    mutes = list(muted_below)
                    opens = []

                    for s, f, n_pc in sorted(all_notes, key=lambda x: -x[0]):
                        notes.append(note_name(tuning[s] + f))
                        intervals.append(interval_label(root_pc, n_pc))
                        if f == 0:
                            opens.append(s)
                        elif f > 0:
                            dots.append({"string": s, "fret": f - fn + 1})

                    for i, (fret, _) in enumerate(combo):
                        s = filtered_options[i][0]
                        if fret == -1 and s not in mutes:
                            mutes.append(s)

                    voicing = {
                        "root": root_name,
                        "quality": quality_id,
                        "display": f"{root_name}{display}",
                        "fret_number": fn,
                        "dots": dots,
                        "mutes": sorted(mutes),
                        "open": sorted(opens),
                        "notes": notes,
                        "intervals": intervals,
                        "strings": len(tuning),
                        "sounding": len(all_notes),
                        "stretch": stretch,
                        "_score": score,
                    }
                    best_voicings[dedup_key] = voicing

    # Collect and sort results
    for v in best_voicings.values():
        del v["_score"]
        results.append(v)

    results.sort(key=lambda v: (v["quality"], CHROMATIC.index(v["root"]), v["fret_number"]))
    return results


def export_as_voicings_json(voicings: list[dict], tuning_name: str) -> dict:
    """Convert calculator output to voicings.json format."""
    exported = []
    for v in voicings:
        slug = v["display"].lower().replace("#", "s").replace("/", "-")
        slug = slug.replace(" ", "-")
        vid = f"{slug}-calc-{v['fret_number']}-{v['strings']}"

        exported.append({
            "id": vid,
            "name": f"{v['display']} — Fret {v['fret_number']}",
            "chord_quality": v["quality"],
            "root": "C" if v["root"] == "C" else v["root"],
            "category": "calculated",
            "context": "CV6",
            "strings": v["strings"],
            "fret_number": v["fret_number"],
            "visible_frets": 4,
            "dots": v["dots"],
            "mutes": v["mutes"],
            "open": v["open"],
            "notes": v["notes"],
            "intervals": v["intervals"],
            "tags": ["calculated", tuning_name.lower().replace(" ", "-")],
        })
    return {"voicings": exported}


def main():
    parser = argparse.ArgumentParser(
        description="Calculate practical chord voicings for a tuning"
    )
    parser.add_argument(
        "--tuning", type=Path,
        default=REPO_ROOT / "config" / "tunings" / "standard.json",
    )
    parser.add_argument("--root", default=None, help="Single root (e.g., D)")
    parser.add_argument("--max-fret", type=int, default=12)
    parser.add_argument("--max-stretch", type=int, default=4)
    parser.add_argument("-o", "--output", type=Path, help="Output JSON file")
    parser.add_argument("--export", action="store_true", help="Output in voicings.json format")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    tuning_name, tuning = load_tuning(args.tuning)

    print(f"Tuning: {tuning_name} ({len(tuning)} strings)")
    print(f"Frets 0-{args.max_fret}, max stretch {args.max_stretch}")
    print(f"Constraints: root in bass, deduplicated by sound")

    voicings = find_practical_voicings(
        tuning,
        target_root=args.root,
        max_fret=args.max_fret,
        max_stretch=args.max_stretch,
    )

    # Summary
    from collections import Counter
    quality_counts = Counter(v["quality"] for v in voicings)
    root_counts = Counter(v["root"] for v in voicings)

    print(f"\nFound {len(voicings)} practical voicings")
    print(f"\nBy quality:")
    for q, c in sorted(quality_counts.items(), key=lambda x: -x[1]):
        print(f"  {q:10s}: {c}")
    print(f"\nBy root:")
    for r in CHROMATIC:
        if r in root_counts:
            print(f"  {r:3s}: {root_counts[r]}")

    if args.output:
        if args.export:
            out = export_as_voicings_json(voicings, tuning_name)
        else:
            out = {
                "tuning": tuning_name,
                "total": len(voicings),
                "by_quality": dict(quality_counts),
                "voicings": voicings,
            }
        with open(args.output, "w") as f:
            json.dump(out, f, indent=2)
        print(f"\nSaved to {args.output}")

    if args.verbose:
        print(f"\nSample voicings:")
        seen_q = set()
        for v in voicings:
            if v["quality"] not in seen_q:
                seen_q.add(v["quality"])
                print(f"  {v['display']:12s} fret {v['fret_number']:2d}: "
                      f"{' '.join(v['notes']):20s} ({' '.join(v['intervals'])})")


if __name__ == "__main__":
    main()
