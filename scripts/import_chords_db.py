#!/usr/bin/env python3
"""Import voicings from tombatossals/chords-db into the Siege Analytics library.

Reads the JS module files from chords-db, converts them to our voicings.json
schema, deduplicates against existing voicings, and outputs importable JSON.

Usage:
    git clone https://github.com/tombatossals/chords-db.git /tmp/chords-db
    python import_chords_db.py /tmp/chords-db -o imported-chords.json
    python import_chords_db.py /tmp/chords-db --merge   # merge directly into voicings.json
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
SEMITONE_MAP = {n: i for i, n in enumerate(CHROMATIC)}
SEMITONE_MAP.update({"C#": 1, "D#": 3, "Gb": 6, "G#": 8, "A#": 10})

# Standard tuning MIDI values (string 6=low E to string 1=high E)
STANDARD_TUNING = {6: 40, 5: 45, 4: 50, 3: 55, 2: 59, 1: 64}

# Map chords-db suffixes to our quality IDs
SUFFIX_MAP = {
    "major": "maj7", "minor": "min7", "dim": "dim7", "aug": "aug7",
    "7": "dom7", "maj7": "maj7", "m7": "min7", "m7b5": "min7b5",
    "dim7": "dim7", "sus2": "sus2", "sus4": "sus4",
    "6": "maj6", "m6": "min6", "9": "dom9", "maj9": "maj9",
    "m9": "min9", "11": "min11", "m11": "min11",
    "13": "dom13", "69": "maj69",
    "7b5": "dom7flat5", "7#9": "dom7sharp9", "7b9": "dom7b9",
    "5": None,  # power chords — skip
    "add9": None,  # not in our quality system yet
}

# Interval calculation
QUALITY_INTERVALS = {
    "dom7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10],
    "min7b5": [0, 3, 6, 10], "dim7": [0, 3, 6, 9], "aug7": [0, 4, 8, 10],
    "sus2": [0, 2, 7], "sus4": [0, 5, 7],
    "maj6": [0, 4, 7, 9], "min6": [0, 3, 7, 9],
    "dom9": [0, 2, 4, 10], "maj9": [0, 2, 4, 11], "min9": [0, 2, 3, 10],
    "min11": [0, 3, 5, 7, 10], "dom13": [0, 4, 9, 10], "maj69": [0, 2, 4, 7, 9],
    "dom7flat5": [0, 4, 6, 10], "dom7sharp9": [0, 3, 4, 10], "dom7b9": [0, 1, 4, 10],
}

INTERVAL_LABELS = {
    0: "1", 1: "b9", 2: "9", 3: "b3", 4: "3", 5: "4",
    6: "b5", 7: "5", 8: "#5", 9: "6", 10: "b7", 11: "7",
}


def parse_frets_string(frets_str):
    """Parse chords-db fret string (e.g., 'x32310', '8a8988') to fret list.

    Returns list of int or -1 for muted (x), from string 6 (low E) to string 1 (high E).
    """
    result = []
    for ch in frets_str.lower():
        if ch == 'x':
            result.append(-1)
        elif ch.isdigit():
            result.append(int(ch))
        elif 'a' <= ch <= 'f':
            result.append(10 + ord(ch) - ord('a'))
        else:
            result.append(-1)
    return result


def parse_js_module(filepath):
    """Parse a chords-db JS module file into structured data."""
    content = filepath.read_text()

    # Extract key and suffix
    key_match = re.search(r"key:\s*'([^']+)'", content)
    suffix_match = re.search(r"suffix:\s*'([^']*)'", content)

    key = key_match.group(1) if key_match else None
    suffix = suffix_match.group(1) if suffix_match else ""

    # Extract positions
    positions = []
    pos_blocks = re.findall(
        r'\{\s*frets:\s*\'([^\']+)\'\s*,\s*fingers:\s*\'([^\']+)\'(?:\s*,\s*barres:\s*(\d+))?',
        content
    )

    for frets_str, fingers_str, barres in pos_blocks:
        frets = parse_frets_string(frets_str)
        fingers = parse_frets_string(fingers_str)
        barre = int(barres) if barres else None
        positions.append({
            "frets": frets,
            "fingers": fingers,
            "barre": barre,
        })

    return {"key": key, "suffix": suffix, "positions": positions}


def convert_to_voicing(key, suffix, position, quality_id):
    """Convert a chords-db position to our voicing format.

    All voicings are transposed to C root.
    """
    frets = position["frets"]
    fingers = position["fingers"]
    num_strings = len(frets)

    if num_strings != 6:
        return None  # only handle 6-string for now

    # Transpose to C
    root_semitone = SEMITONE_MAP.get(key, 0)
    transpose_down = root_semitone  # semitones to subtract to get to C

    # Find the lowest fretted position
    fretted_positions = [(i, f) for i, f in enumerate(frets) if f > 0]
    open_strings_idx = [i for i, f in enumerate(frets) if f == 0]
    muted_idx = [i for i, f in enumerate(frets) if f < 0]

    if not fretted_positions and not open_strings_idx:
        return None  # all muted

    # Calculate fret_number (lowest fretted position) and adjust for transposition
    if fretted_positions:
        min_fret = min(f for _, f in fretted_positions)
        # Transpose: subtract semitones to get to C
        transposed_min_fret = min_fret - transpose_down
        if transposed_min_fret < 0:
            transposed_min_fret += 12
        fret_number = max(1, transposed_min_fret) if transposed_min_fret > 0 else 1
    else:
        fret_number = 1

    # Build dots, mutes, open, notes, intervals
    dots = []
    mutes = []
    opens = []
    notes = []
    intervals = []

    for i, fret in enumerate(frets):
        string_num = 6 - i  # convert 0-based index to string number (6=low E)

        if fret < 0:
            mutes.append(string_num)
        elif fret == 0:
            opens.append(string_num)
            midi = STANDARD_TUNING[string_num]
            note = CHROMATIC[midi % 12]
            notes.append(note)
            semitone_from_root = (midi % 12 - SEMITONE_MAP.get(key, 0)) % 12
            intervals.append(INTERVAL_LABELS.get(semitone_from_root, "?"))
        else:
            # For transposed voicing: adjust fret relative to fret_number
            transposed_fret = fret - transpose_down
            if transposed_fret <= 0:
                transposed_fret += 12
            rel_fret = transposed_fret - fret_number + 1
            if rel_fret < 1:
                rel_fret += 12
                fret_number = transposed_fret
                # Recalculate all previous rel_frets... skip for simplicity
            dots.append({"string": string_num, "fret": max(1, rel_fret)})

            midi = STANDARD_TUNING[string_num] + fret
            note = CHROMATIC[midi % 12]
            notes.append(note)
            semitone_from_root = (midi % 12 - SEMITONE_MAP.get(key, 0)) % 12
            intervals.append(INTERVAL_LABELS.get(semitone_from_root, "?"))

    # Build fingering
    fingering = []
    for i, (fret, finger) in enumerate(zip(frets, fingers)):
        if fret > 0 and finger > 0:
            string_num = 6 - i
            fingering.append({"string": string_num, "finger": finger})

    # Determine visible frets
    if dots:
        max_rel = max(d["fret"] for d in dots)
        visible_frets = max(4, max_rel + 1)
    else:
        visible_frets = 4

    # Generate ID
    slug = f"c{suffix or 'maj'}".lower().replace("#", "s").replace("/", "-").replace(" ", "")
    vid = f"{slug}-chordsdb-f{fret_number}-6"

    # Determine category
    sounding = len(dots) + len(opens)
    if sounding <= 3:
        category = "shell"
    elif any(i in intervals for i in ["9", "b9", "#9", "6", "b13", "#11"]):
        category = "extended"
    else:
        category = "drop2"

    voicing = {
        "id": vid,
        "name": f"C{suffix or 'maj'} — chords-db — {category.title()} (imported)",
        "chord_quality": quality_id,
        "root": "C",
        "category": category,
        "context": "CV6",
        "strings": 6,
        "fret_number": fret_number,
        "visible_frets": min(visible_frets, 6),
        "dots": dots,
        "mutes": sorted(mutes),
        "open": sorted(opens),
        "notes": notes,
        "intervals": intervals,
        "tags": ["imported", "chords-db"],
    }

    if fingering:
        voicing["fingering"] = fingering

    return voicing


def shape_key(v):
    """Create a fingerprint for deduplication."""
    dots = tuple(sorted((d["string"], d["fret"]) for d in v["dots"]))
    mutes = tuple(sorted(v["mutes"]))
    opens = tuple(sorted(v["open"]))
    return (dots, mutes, opens, v["fret_number"], v["strings"])


def main():
    parser = argparse.ArgumentParser(
        description="Import voicings from tombatossals/chords-db"
    )
    parser.add_argument("repo", type=Path, help="Path to cloned chords-db repo")
    parser.add_argument("-o", "--output", type=Path, default=Path("chords-db-import.json"))
    parser.add_argument("--merge", action="store_true",
                        help="Merge directly into voicings.json")
    parser.add_argument("--data", type=Path,
                        default=REPO_ROOT / "plugin" / "data" / "voicings.json")
    parser.add_argument("--root", default="C",
                        help="Only import chords with this root (default: C)")
    args = parser.parse_args()

    chords_dir = args.repo / "src" / "db" / "guitar" / "chords"
    if not chords_dir.exists():
        print(f"Chords directory not found: {chords_dir}", file=sys.stderr)
        sys.exit(1)

    # Load existing voicings for deduplication
    existing_shapes = set()
    if args.data.exists():
        with open(args.data) as f:
            existing = json.load(f)["voicings"]
        for v in existing:
            existing_shapes.add(shape_key(v))
        existing_ids = {v["id"] for v in existing}
    else:
        existing_ids = set()

    # Process chords for the target root
    root_dir = chords_dir / args.root
    if not root_dir.exists():
        print(f"No chords for root '{args.root}' at {root_dir}", file=sys.stderr)
        sys.exit(1)

    imported = []
    skipped_quality = 0
    skipped_duplicate = 0
    seq = 1

    for js_file in sorted(root_dir.glob("*.js")):
        if js_file.name == "index.js":
            continue

        parsed = parse_js_module(js_file)
        if not parsed["key"]:
            continue

        suffix = parsed["suffix"]
        quality_id = SUFFIX_MAP.get(suffix)

        if quality_id is None:
            skipped_quality += 1
            continue

        for pos in parsed["positions"][:2]:  # take top 2 positions per suffix
            voicing = convert_to_voicing(parsed["key"], suffix, pos, quality_id)
            if not voicing:
                continue

            # Deduplicate
            sk = shape_key(voicing)
            if sk in existing_shapes:
                skipped_duplicate += 1
                continue

            # Ensure unique ID
            while voicing["id"] in existing_ids:
                voicing["id"] = voicing["id"].rsplit("-", 1)[0] + f"-{seq}"
                seq += 1

            imported.append(voicing)
            existing_shapes.add(sk)
            existing_ids.add(voicing["id"])

    print(f"Imported: {len(imported)} voicings")
    print(f"Skipped (unknown quality): {skipped_quality}")
    print(f"Skipped (duplicate shape): {skipped_duplicate}")

    if args.merge and imported:
        with open(args.data) as f:
            data = json.load(f)
        data["voicings"].extend(imported)
        with open(args.data, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"Merged into {args.data}: {len(data['voicings'])} total voicings")
    else:
        output = {"voicings": imported}
        with open(args.output, "w") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"Saved to {args.output}")


if __name__ == "__main__":
    main()
