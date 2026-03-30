#!/usr/bin/env python3
"""Calculate all playable chord voicings for a given tuning.

For each root note and each fret window, finds all combinations of
fretted/muted/open strings that produce recognized chord qualities.
Useful for alternate tunings where the chord vocabulary is different
from standard tuning.

Usage:
    python chord_calculator.py                              # standard tuning
    python chord_calculator.py --tuning config/tunings/dadgad.json
    python chord_calculator.py --tuning config/tunings/dadgad.json --root D
    python chord_calculator.py --tuning config/tunings/dadgad.json --output dadgad-chords.json
"""

import argparse
import itertools
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Chord quality definitions: name → set of semitone intervals from root
CHORD_QUALITIES = {
    "maj":      {0, 4, 7},
    "min":      {0, 3, 7},
    "dom7":     {0, 4, 7, 10},
    "maj7":     {0, 4, 7, 11},
    "min7":     {0, 3, 7, 10},
    "min7b5":   {0, 3, 6, 10},
    "dim7":     {0, 3, 6, 9},
    "aug":      {0, 4, 8},
    "dom7#5":   {0, 4, 8, 10},
    "dom7b5":   {0, 4, 6, 10},
    "maj6":     {0, 4, 7, 9},
    "min6":     {0, 3, 7, 9},
    "dom9":     {0, 2, 4, 10},       # root, 9, 3, b7 (no 5)
    "maj9":     {0, 2, 4, 11},       # root, 9, 3, 7 (no 5)
    "min9":     {0, 2, 3, 10},       # root, 9, b3, b7 (no 5)
    "dom7b9":   {0, 1, 4, 10},       # root, b9, 3, b7
    "sus4":     {0, 5, 7},
    "sus2":     {0, 2, 7},
    "dim":      {0, 3, 6},
    "min-maj7": {0, 3, 7, 11},
    "aug7":     {0, 4, 8, 10},
}

# Minimum notes required to identify a chord (3 for triads, 3-4 for 7ths)
MIN_NOTES = 3
MAX_FRET = 15
MAX_STRETCH = 4  # max fret distance between lowest and highest fretted note


def load_tuning(path: Path) -> dict[int, int]:
    """Load tuning: returns {string_number: midi_note}."""
    with open(path) as f:
        data = json.load(f)
    return {int(k): v for k, v in data["strings"].items()}


def note_name(midi: int) -> str:
    return CHROMATIC[midi % 12]


def pitch_class(midi: int) -> int:
    return midi % 12


def identify_chord(pitch_classes: set[int]) -> list[tuple[str, str]]:
    """Given a set of pitch classes, identify all matching chord qualities.
    Returns list of (root_name, quality_name) tuples."""
    results = []
    for root_pc in range(12):
        intervals = {(pc - root_pc) % 12 for pc in pitch_classes}
        for quality_name, required in CHORD_QUALITIES.items():
            if required.issubset(intervals):
                results.append((CHROMATIC[root_pc], quality_name))
    return results


def find_voicings(
    tuning: dict[int, int],
    target_root: str | None = None,
    max_fret: int = MAX_FRET,
    max_stretch: int = MAX_STRETCH,
    min_notes: int = MIN_NOTES,
) -> list[dict]:
    """Find all playable chord voicings for the given tuning."""
    strings = sorted(tuning.keys())
    num_strings = len(strings)
    voicings = []
    seen = set()  # deduplicate by (root, quality, fret_pattern)

    # For each fret window position
    for start_fret in range(0, max_fret + 1):
        # Each string can be: muted (-1), open (0), or fretted (start_fret to start_fret+max_stretch)
        options_per_string = []
        for s in strings:
            opts = [-1, 0]  # muted, open
            for f in range(start_fret, min(start_fret + max_stretch + 1, max_fret + 1)):
                if f > 0:
                    opts.append(f)
            options_per_string.append(opts)

        # Iterate all combinations (but limit to avoid explosion)
        # For 6 strings with ~7 options each = ~117k combos per window
        for combo in itertools.product(*options_per_string):
            # Get sounding notes
            sounding = []
            fretted_positions = []
            for i, fret in enumerate(combo):
                s = strings[i]
                if fret == -1:
                    continue  # muted
                midi = tuning[s] + fret
                sounding.append((s, fret, midi))
                if fret > 0:
                    fretted_positions.append(fret)

            # Need minimum notes
            if len(sounding) < min_notes:
                continue

            # Check stretch
            if fretted_positions:
                stretch = max(fretted_positions) - min(fretted_positions)
                if stretch > max_stretch:
                    continue

            # Get pitch classes
            pcs = {pitch_class(m) for _, _, m in sounding}

            # Identify chords
            chords = identify_chord(pcs)
            if not chords:
                continue

            # Filter to target root if specified
            if target_root:
                chords = [(r, q) for r, q in chords if r == target_root]
                if not chords:
                    continue

            for root, quality in chords:
                # Build a fingerprint for deduplication
                fret_tuple = tuple(combo)
                fp = (root, quality, fret_tuple)
                if fp in seen:
                    continue
                seen.add(fp)

                # Build voicing dict
                dots = []
                mutes = []
                opens = []
                notes = []
                for s_idx, fret in enumerate(combo):
                    s = strings[s_idx]
                    if fret == -1:
                        mutes.append(s)
                    elif fret == 0:
                        opens.append(s)
                        notes.append(note_name(tuning[s]))
                    else:
                        notes.append(note_name(tuning[s] + fret))

                # Calculate fret_number (lowest fretted position)
                fn = min(fretted_positions) if fretted_positions else 1

                for s_idx, fret in enumerate(combo):
                    s = strings[s_idx]
                    if fret > 0:
                        dots.append({"string": s, "fret": fret - fn + 1})

                voicings.append({
                    "root": root,
                    "quality": quality,
                    "fret_number": fn,
                    "dots": dots,
                    "mutes": mutes,
                    "open": opens,
                    "notes": notes,
                    "strings": num_strings,
                    "sounding_notes": len(sounding),
                })

    return voicings


def main():
    parser = argparse.ArgumentParser(
        description="Calculate playable chord voicings for a tuning"
    )
    parser.add_argument(
        "--tuning", type=Path,
        default=REPO_ROOT / "config" / "tunings" / "standard.json",
        help="Path to tuning JSON",
    )
    parser.add_argument("--root", default=None, help="Filter to a specific root (e.g., D)")
    parser.add_argument("--max-fret", type=int, default=12, help="Max fret to search")
    parser.add_argument("--max-stretch", type=int, default=4, help="Max fret stretch")
    parser.add_argument("--min-notes", type=int, default=3, help="Min sounding notes")
    parser.add_argument("-o", "--output", type=Path, help="Output JSON file")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    tuning_data = json.load(open(args.tuning))
    tuning = {int(k): v for k, v in tuning_data["strings"].items()}
    tuning_name = tuning_data.get("name", args.tuning.stem)

    print(f"Tuning: {tuning_name}")
    print(f"Strings: {len(tuning)}")
    print(f"Searching frets 0-{args.max_fret}, max stretch {args.max_stretch}...")

    voicings = find_voicings(
        tuning,
        target_root=args.root,
        max_fret=args.max_fret,
        max_stretch=args.max_stretch,
        min_notes=args.min_notes,
    )

    # Summarize
    from collections import Counter
    quality_counts = Counter(v["quality"] for v in voicings)
    root_counts = Counter(v["root"] for v in voicings)

    print(f"\nFound {len(voicings)} voicings")
    print(f"\nBy quality:")
    for q, c in sorted(quality_counts.items(), key=lambda x: -x[1]):
        print(f"  {q}: {c}")
    print(f"\nBy root:")
    for r, c in sorted(root_counts.items(), key=lambda x: CHROMATIC.index(x[0])):
        print(f"  {r}: {c}")

    if args.output:
        out = {
            "tuning": tuning_name,
            "tuning_file": str(args.tuning),
            "total": len(voicings),
            "by_quality": dict(quality_counts),
            "voicings": voicings,
        }
        with open(args.output, "w") as f:
            json.dump(out, f, indent=2)
        print(f"\nSaved to {args.output}")

    if args.verbose and voicings:
        print(f"\nSample voicings:")
        for v in voicings[:10]:
            print(f"  {v['root']}{v['quality']} fret {v['fret_number']}: "
                  f"notes={v['notes']} dots={v['dots']}")


if __name__ == "__main__":
    main()
