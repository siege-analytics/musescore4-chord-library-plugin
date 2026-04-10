#!/usr/bin/env python3
"""Voice leading advisor: find optimal voicing paths for chord progressions.

Given a sequence of chord symbols, finds the voicing for each chord that
minimizes total voice movement across the progression. Uses dynamic
programming to find the globally optimal path, not just greedy pairwise.

Usage:
    python voice_leading.py Dm7 G7 Cmaj7
    python voice_leading.py Dm7 G7 Cmaj7 --context CV6 --category shell
    python voice_leading.py --score arrangement.mscz
    python voice_leading.py Dm7 G7 Cmaj7 --top 3   # show top 3 paths
"""

import argparse
import json
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
SEMITONE_MAP = {n: i for i, n in enumerate(CHROMATIC)}
SEMITONE_MAP.update({"C#": 1, "D#": 3, "Gb": 6, "G#": 8, "A#": 10})

STANDARD_TUNING = {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40, 7: 33}

QUALITY_MAP = {
    "7": "dom7", "maj7": "maj7", "M7": "maj7",
    "m7": "min7", "-7": "min7", "min7": "min7",
    "m7b5": "min7b5", "-7b5": "min7b5",
    "dim7": "dim7", "o7": "dim7",
    "6": "maj6", "m6": "min6",
    "9": "dom9", "maj9": "maj9", "m9": "min9",
    "13": "dom13", "7b9": "dom7b9", "7#9": "dom7sharp9",
    "7#11": "dom7sharp11", "7b13": "dom7b13",
    "sus4": "sus4", "sus2": "sus2",
    "": "maj7",
}


def parse_chord(text):
    """Parse chord symbol into (root, quality_id)."""
    text = text.strip().replace("Δ", "maj").replace("°", "dim").replace("ø", "m7b5")
    root = None
    for r in sorted(CHROMATIC + ["C#", "D#", "G#", "A#"], key=len, reverse=True):
        if text.startswith(r):
            root = r
            break
    if not root:
        return None
    suffix = text[len(root):]
    quality = QUALITY_MAP.get(suffix)
    if not quality:
        for k, v in sorted(QUALITY_MAP.items(), key=lambda x: -len(x[0])):
            if k and suffix.startswith(k):
                quality = v
                break
    return (root, quality or "dom7") if root else None


def voicing_midi_notes(voicing, target_root):
    """Calculate MIDI note numbers for a voicing transposed to target_root."""
    offset = (SEMITONE_MAP.get(target_root, 0) - SEMITONE_MAP.get(voicing["root"], 0)) % 12
    fret_offset = offset  # semitones to add to fret_number

    notes = []
    for dot in voicing.get("dots", []):
        string = dot["string"]
        if string not in STANDARD_TUNING:
            continue
        abs_fret = voicing["fret_number"] + fret_offset + (dot["fret"] - 1)
        midi = STANDARD_TUNING[string] + abs_fret
        notes.append(midi)

    for open_str in voicing.get("open", []):
        if open_str in STANDARD_TUNING:
            notes.append(STANDARD_TUNING[open_str])

    return sorted(notes)


def voice_distance(notes_a, notes_b):
    """Calculate total semitone distance between two voicings.

    Uses minimum-cost matching: for each note in B, find the closest
    note in A and sum the distances.
    """
    if not notes_a or not notes_b:
        return 100  # penalty for empty voicings

    total = 0
    for nb in notes_b:
        min_dist = min(abs(nb - na) for na in notes_a)
        total += min_dist
    return total


def common_tones(notes_a, notes_b):
    """Count pitch classes shared between two voicings."""
    pcs_a = {n % 12 for n in notes_a}
    pcs_b = {n % 12 for n in notes_b}
    return len(pcs_a & pcs_b)


def find_optimal_path(chord_sequence, voicings, context="CV6", category=None, top_n=1):
    """Find the voicing path that minimizes total voice movement.

    Uses dynamic programming: for each chord, track the best path
    ending at each candidate voicing.

    Args:
        chord_sequence: list of (root, quality_id) tuples
        voicings: all available voicings
        context: context filter
        category: optional category filter
        top_n: number of top paths to return

    Returns:
        list of paths, each path is a list of (voicing, target_root, score) tuples
    """
    # Build candidate lists for each chord
    candidates = []
    for root, quality in chord_sequence:
        matches = [v for v in voicings
                   if v["chord_quality"] == quality
                   and (v["context"] == context or context == "all")]
        if category:
            matches = [v for v in matches if v["category"] == category]
        if not matches:
            # Try without category filter
            matches = [v for v in voicings
                       if v["chord_quality"] == quality
                       and (v["context"] == context or context == "all")]
        candidates.append((root, quality, matches[:20]))  # limit candidates for speed

    if not candidates:
        return []

    # DP: best_paths[i][j] = (total_cost, path) for chord i, voicing j
    n = len(candidates)

    # Initialize first chord
    first_root, first_quality, first_voicings = candidates[0]
    current_paths = {}
    for j, v in enumerate(first_voicings):
        midi = voicing_midi_notes(v, first_root)
        current_paths[j] = [(0, [(v, first_root, midi)])]

    # Process remaining chords
    for i in range(1, n):
        root, quality, chord_voicings = candidates[i]
        if not chord_voicings:
            continue

        next_paths = {}
        for j, v in enumerate(chord_voicings):
            midi_j = voicing_midi_notes(v, root)
            best_for_j = []

            for prev_j, paths in current_paths.items():
                for cost, path in paths:
                    prev_midi = path[-1][2]
                    dist = voice_distance(prev_midi, midi_j)
                    # Bonus for common tones
                    ct = common_tones(prev_midi, midi_j)
                    adjusted_cost = cost + dist - (ct * 2)
                    best_for_j.append((adjusted_cost, path + [(v, root, midi_j)]))

            # Keep top N paths for this voicing
            best_for_j.sort(key=lambda x: x[0])
            next_paths[j] = best_for_j[:top_n]

        current_paths = next_paths

    # Collect all final paths and sort by total cost
    all_paths = []
    for j, paths in current_paths.items():
        all_paths.extend(paths)
    all_paths.sort(key=lambda x: x[0])

    return all_paths[:top_n]


def print_path(path, cost):
    """Pretty-print a voicing path."""
    print(f"\n  Voice leading path (total distance: {cost}):")
    print(f"  {'Chord':<10s} {'Voicing':<40s} {'Notes'}")
    print(f"  {'-'*10} {'-'*40} {'-'*20}")
    for v, root, midi in path:
        # Transpose the name for display
        from fretboard_renderer import INTERVAL_COLORS  # just to verify import works
        display_name = v["name"].replace("C", root, 1) if root != "C" else v["name"]
        display_name = display_name[:38]
        note_names = [CHROMATIC[m % 12] for m in midi]
        print(f"  {root + v['chord_quality'][:6]:<10s} {display_name:<40s} {' '.join(note_names)}")


def main():
    parser = argparse.ArgumentParser(
        description="Find optimal voice leading paths for chord progressions"
    )
    parser.add_argument("chord_args", nargs="*", help="Chord symbols (e.g., Dm7 G7 Cmaj7)")
    parser.add_argument("--score", type=Path, help="Read chords from MuseScore file (.mscz)")
    parser.add_argument("--chords", type=Path, help="Read chords from JSON file (plugin export)")
    parser.add_argument("--context", default="CV6")
    parser.add_argument("--category", help="Filter by category (shell, drop2, etc.)")
    parser.add_argument("--top", type=int, default=3, help="Number of paths to show")
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "plugin" / "data" / "voicings.json")
    args = parser.parse_args()

    with open(args.data) as f:
        voicings = json.load(f)["voicings"]

    chord_sequence = []

    if args.chords:
        from analyze_score import load_chords_from_json
        info = load_chords_from_json(args.chords)
        for c in info["chords"]:
            parsed = parse_chord(c["text"])
            if parsed:
                chord_sequence.append(parsed)
        print(f"Score: {info['title']} ({len(chord_sequence)} chords)")
    elif args.score:
        from analyze_score import extract_progression_from_mscx
        info = extract_progression_from_mscx(args.score)
        for c in info["chords"]:
            parsed = parse_chord(c["text"])
            if parsed:
                chord_sequence.append(parsed)
        print(f"Score: {info['title']} ({len(chord_sequence)} chords)")
    elif args.chord_args:
        for chord_text in args.chord_args:
            parsed = parse_chord(chord_text)
            if parsed:
                chord_sequence.append(parsed)
            else:
                print(f"Warning: could not parse '{chord_text}'", file=sys.stderr)
    else:
        parser.error("Provide chord symbols, --score, or --chords")

    if not chord_sequence:
        print("No valid chords to analyze", file=sys.stderr)
        sys.exit(1)

    print(f"\nProgression: {' → '.join(r + q[:4] for r, q in chord_sequence)}")
    print(f"Context: {args.context}" + (f", Category: {args.category}" if args.category else ""))

    paths = find_optimal_path(
        chord_sequence, voicings,
        context=args.context,
        category=args.category,
        top_n=args.top,
    )

    if not paths:
        print("\nNo voicing paths found. Check that the library has voicings for these qualities.")
        sys.exit(1)

    for i, (cost, path) in enumerate(paths):
        if len(paths) > 1:
            print(f"\n{'='*60}")
            print(f"  Path {i+1} of {len(paths)}")
        print_path(path, cost)

    print()


if __name__ == "__main__":
    main()
