#!/usr/bin/env python3
"""Export the voicing library as MusicXML 4.0 files with chord diagrams.

Generates all voicings in all 12 keys (or a single key) as MusicXML files
with <frame> elements inside <harmony> for chord diagram rendering.

Usage:
    python export_musicxml.py                          # all voicings, all 12 keys
    python export_musicxml.py --root F                 # single key only
    python export_musicxml.py --by-quality -o exports/ # one file per quality
"""

import argparse
import json
import re
import sys
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, ElementTree, indent

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"

ROOTS = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

SEMITONE_MAP = {
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
    "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
    "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11,
}

# MusicXML <kind> mapping: quality -> (kind_text_content, text_attribute)
QUALITY_TO_KIND = {
    "dom7":     ("dominant",              "7"),
    "maj7":     ("major-seventh",         "maj7"),
    "min7":     ("minor-seventh",         "m7"),
    "min7b5":   ("half-diminished",       "m7b5"),
    "dim7":     ("diminished-seventh",    "dim7"),
    "maj6":     ("major-sixth",           "6"),
    "min6":     ("minor-sixth",           "m6"),
    "dom9":     ("dominant-ninth",        "9"),
    "dom13":    ("dominant-13th",         "13"),
    "sus4":     ("suspended-fourth",      "sus4"),
    "sus2":     ("suspended-second",      "sus2"),
    "aug7":     ("augmented-seventh",     "aug7"),
    "dom7alt":  ("dominant",              "7alt"),
}

# MusicXML root-step must be a plain letter; accidentals go in root-alter
# root-alter: -1 = flat, +1 = sharp
ROOT_STEP_ALTER = {
    "C":  ("C", None),
    "C#": ("C", "1"),
    "Db": ("D", "-1"),
    "D":  ("D", None),
    "D#": ("D", "1"),
    "Eb": ("E", "-1"),
    "E":  ("E", None),
    "F":  ("F", None),
    "F#": ("F", "1"),
    "Gb": ("G", "-1"),
    "G":  ("G", None),
    "G#": ("G", "1"),
    "Ab": ("A", "-1"),
    "A":  ("A", None),
    "A#": ("A", "1"),
    "Bb": ("B", "-1"),
    "B":  ("B", None),
}


def semitone_offset(source: str, target: str) -> int:
    return (SEMITONE_MAP[target] - SEMITONE_MAP[source]) % 12


def transpose_name(name: str, target_root: str) -> str:
    """Replace leading C in voicing name with target root."""
    if target_root == "C":
        return name
    return re.sub(r"^C(?=[^a-z]|maj|min|dim|aug|sus|m[^a-z]|$)", target_root, name)


def build_harmony(voicing: dict, target_root: str) -> Element:
    """Build a MusicXML <harmony> element with <frame> for a voicing."""
    offset = semitone_offset("C", target_root)
    transposed_fret = voicing["fret_number"] + offset
    num_strings = voicing.get("strings", 6)
    visible_frets = voicing.get("visible_frets", 4)
    quality = voicing.get("chord_quality", "")

    harmony = Element("harmony")

    # <root>
    root_el = SubElement(harmony, "root")
    step, alter = ROOT_STEP_ALTER.get(target_root, (target_root[0], None))
    SubElement(root_el, "root-step").text = step
    if alter is not None:
        SubElement(root_el, "root-alter").text = alter

    # <kind>
    if quality in QUALITY_TO_KIND:
        kind_value, kind_text = QUALITY_TO_KIND[quality]
    else:
        kind_value, kind_text = "other", quality
    kind_el = SubElement(harmony, "kind")
    kind_el.text = kind_value
    kind_el.set("text", kind_text)

    # <frame>
    frame = SubElement(harmony, "frame")
    SubElement(frame, "frame-strings").text = str(num_strings)
    SubElement(frame, "frame-frets").text = str(visible_frets)

    # first-fret (only if > 1, i.e. not open position)
    if transposed_fret > 0:
        first_fret_el = SubElement(frame, "first-fret")
        first_fret_el.text = str(transposed_fret)
        first_fret_el.set("text", str(transposed_fret))
        first_fret_el.set("location", "right")

    # Open strings: fret 0
    open_strings = set(voicing.get("open", []))

    # Muted strings: omitted entirely from frame-note list
    muted_strings = set(voicing.get("mutes", []))

    # Add open strings as frame-notes with fret 0
    for s in sorted(open_strings):
        fn = SubElement(frame, "frame-note")
        SubElement(fn, "string").text = str(s)
        SubElement(fn, "fret").text = "0"

    # Add fretted dots as frame-notes with absolute fret numbers
    for dot in voicing.get("dots", []):
        absolute_fret = transposed_fret + (dot["fret"] - 1)
        fn = SubElement(frame, "frame-note")
        SubElement(fn, "string").text = str(dot["string"])
        SubElement(fn, "fret").text = str(absolute_fret)

    return harmony


def build_document(voicings: list[dict], target_root: str) -> Element:
    """Build a complete MusicXML score-partwise document."""
    score = Element("score-partwise")
    score.set("version", "4.0")

    # Part list
    part_list = SubElement(score, "part-list")
    score_part = SubElement(part_list, "score-part")
    score_part.set("id", "P1")
    SubElement(score_part, "part-name").text = "Guitar"

    # Part
    part = SubElement(score, "part")
    part.set("id", "P1")

    for i, voicing in enumerate(voicings):
        measure = SubElement(part, "measure")
        measure.set("number", str(i + 1))

        # Attributes only on first measure
        if i == 0:
            attrs = SubElement(measure, "attributes")
            SubElement(attrs, "divisions").text = "1"
            time_el = SubElement(attrs, "time")
            SubElement(time_el, "beats").text = "4"
            SubElement(time_el, "beat-type").text = "4"
            clef = SubElement(attrs, "clef")
            SubElement(clef, "sign").text = "G"
            SubElement(clef, "line").text = "2"

        # Harmony with frame
        harmony = build_harmony(voicing, target_root)
        measure.append(harmony)

        # Whole note placeholder
        note = SubElement(measure, "note")
        pitch = SubElement(note, "pitch")
        SubElement(pitch, "step").text = "C"
        SubElement(pitch, "octave").text = "4"
        SubElement(note, "duration").text = "4"
        SubElement(note, "type").text = "whole"

    return score


def write_musicxml(score: Element, path: Path) -> None:
    """Write a MusicXML document to file with proper DOCTYPE."""
    indent(score, space="  ")
    tree = ElementTree(score)

    with open(path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write(
            '<!DOCTYPE score-partwise PUBLIC '
            '"-//Recordare//DTD MusicXML 4.0 Partwise//EN" '
            '"http://www.musicxml.org/dtds/partwise.dtd">\n'
        )
        tree.write(f, encoding="unicode", xml_declaration=False)


def main():
    parser = argparse.ArgumentParser(
        description="Export voicing library as MusicXML 4.0 files with chord diagrams"
    )
    parser.add_argument(
        "--data", type=Path, default=DEFAULT_DATA,
        help="Path to voicings.json",
    )
    parser.add_argument(
        "--root", default=None,
        help="Export for a single root only (e.g., F). Default: all 12 keys.",
    )
    parser.add_argument(
        "--by-quality", action="store_true",
        help="Generate one file per chord quality instead of one big file",
    )
    parser.add_argument(
        "-o", "--output", type=Path, default=Path("exports/musicxml"),
        help="Output directory (default: exports/musicxml/)",
    )
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)
    voicings = data["voicings"]

    roots = [args.root] if args.root else ROOTS
    args.output.mkdir(parents=True, exist_ok=True)

    if args.by_quality:
        by_quality: dict[str, list] = {}
        for v in voicings:
            q = v["chord_quality"]
            by_quality.setdefault(q, []).append(v)

        total = 0
        for quality, vlist in sorted(by_quality.items()):
            for root in roots:
                score = build_document(vlist, root)
                out_file = args.output / f"{quality}_{root}.musicxml"
                write_musicxml(score, out_file)
                total += 1
        print(f"Generated {total} MusicXML files in {args.output}/")
    else:
        for root in roots:
            score = build_document(voicings, root)
            out_file = args.output / f"chord-library_{root}.musicxml"
            write_musicxml(score, out_file)
            print(f"  {out_file} ({len(voicings)} voicings)")
        print(f"\nGenerated {len(roots)} MusicXML files in {args.output}/")


if __name__ == "__main__":
    main()
