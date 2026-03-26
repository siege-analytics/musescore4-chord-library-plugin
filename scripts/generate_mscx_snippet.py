#!/usr/bin/env python3
"""Generate .mscx XML FretDiagram snippets from voicings.json.

Usage:
    python generate_mscx_snippet.py --voicing c7-shell-137-e-str-7 --root F
    python generate_mscx_snippet.py --voicing cmaj7-shell-137-e-str-7  # defaults to C
    python generate_mscx_snippet.py --all --root Bb --output snippets/
"""

import argparse
import json
import os
import sys
from pathlib import Path

SEMITONE_MAP = {
    "C": 0, "B#": 0,
    "C#": 1, "Db": 1,
    "D": 2,
    "D#": 3, "Eb": 3,
    "E": 4, "Fb": 4,
    "F": 5, "E#": 5,
    "F#": 6, "Gb": 6,
    "G": 7,
    "G#": 8, "Ab": 8,
    "A": 9,
    "A#": 10, "Bb": 10,
    "B": 11, "Cb": 11,
}


def semitone_offset(source_root: str, target_root: str) -> int:
    src = SEMITONE_MAP.get(source_root)
    tgt = SEMITONE_MAP.get(target_root)
    if src is None or tgt is None:
        raise ValueError(f"Unknown root note: {source_root} or {target_root}")
    return (tgt - src) % 12


def generate_snippet(voicing: dict, target_root: str = "C") -> str:
    offset = semitone_offset(voicing["root"], target_root)
    transposed_fret = voicing["fret_number"] + offset
    num_strings = voicing.get("strings", 6)

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<FretDiagram>",
        f"  <fretDiagramStrings>{num_strings}</fretDiagramStrings>",
        f"  <fretDiagramFrets>{voicing.get('visible_frets', 4)}</fretDiagramFrets>",
        f"  <fretDiagramFret>{transposed_fret}</fretDiagramFret>",
    ]

    # Dots: convert our string numbering (1=high e) to MS numbering (0=highest)
    for dot in voicing.get("dots", []):
        ms_string = num_strings - dot["string"]
        lines.append(f'  <FretDot string="{ms_string}" fret="{dot["fret"]}"/>')

    # Muted strings
    for mute_str in voicing.get("mutes", []):
        ms_string = num_strings - mute_str
        lines.append(f'  <FretMarker string="{ms_string}" marker="cross"/>')

    # Open strings
    for open_str in voicing.get("open", []):
        ms_string = num_strings - open_str
        lines.append(f'  <FretMarker string="{ms_string}" marker="circle"/>')

    lines.append("</FretDiagram>")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate .mscx FretDiagram XML snippets")
    parser.add_argument("--voicing", help="Voicing ID from voicings.json")
    parser.add_argument("--root", default="C", help="Target root note (default: C)")
    parser.add_argument("--all", action="store_true", help="Generate for all voicings")
    parser.add_argument("--output", "-o", help="Output directory (for --all) or file")
    parser.add_argument(
        "--data",
        default=str(Path(__file__).parent.parent / "data" / "voicings.json"),
        help="Path to voicings.json",
    )
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)

    voicings = {v["id"]: v for v in data["voicings"]}

    if args.all:
        out_dir = Path(args.output) if args.output else Path("snippets")
        out_dir.mkdir(parents=True, exist_ok=True)
        for vid, v in voicings.items():
            snippet = generate_snippet(v, args.root)
            out_file = out_dir / f"{vid}_{args.root}.xml"
            out_file.write_text(snippet)
            print(f"  {out_file}")
        print(f"\nGenerated {len(voicings)} snippets in {out_dir}/")
    elif args.voicing:
        if args.voicing not in voicings:
            print(f"Error: voicing '{args.voicing}' not found.", file=sys.stderr)
            print(f"Available: {', '.join(sorted(voicings.keys()))}", file=sys.stderr)
            sys.exit(1)
        snippet = generate_snippet(voicings[args.voicing], args.root)
        if args.output:
            Path(args.output).write_text(snippet)
            print(f"Written to {args.output}")
        else:
            print(snippet)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
