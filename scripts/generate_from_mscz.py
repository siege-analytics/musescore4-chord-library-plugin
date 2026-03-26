#!/usr/bin/env python3
"""Extract voicing data from MuseScore (.mscz) files to populate voicings.json.

MuseScore .mscz files are ZIP archives containing .mscx (MusicXML-like) XML.
This script parses fretboard diagram elements from the XML and converts them
to the voicings.json format.

Usage:
    python scripts/generate_from_mscz.py path/to/file.mscz
    python scripts/generate_from_mscz.py path/to/directory/ --recursive
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "data" / "voicings.json"


def extract_mscx_from_mscz(mscz_path: Path) -> str:
    """Extract the .mscx XML content from a .mscz ZIP archive."""
    with zipfile.ZipFile(mscz_path, "r") as zf:
        for name in zf.namelist():
            if name.endswith(".mscx"):
                return zf.read(name).decode("utf-8")
    raise ValueError(f"No .mscx file found in {mscz_path}")


def parse_fretboard_diagrams(mscx_xml: str) -> list[dict]:
    """Parse fretboard diagram elements from MusicXML-like content.

    This is a stub — the actual XML structure depends on MuseScore's
    internal format and needs to be verified against real .mscz files.
    """
    voicings = []
    root = ET.fromstring(mscx_xml)

    # MuseScore 4 uses <FretDiagram> elements
    # Structure needs verification against actual files
    for fret_diagram in root.iter("FretDiagram"):
        voicing = {
            "id": "",
            "name": "",
            "chord_quality": "",
            "root": "C",
            "category": "",
            "context": "",
            "strings": 6,
            "fret_number": 0,
            "visible_frets": 4,
            "dots": [],
            "mutes": [],
            "open": [],
            "notes": [],
            "intervals": [],
            "tags": [],
        }

        # Extract fret offset
        fret_offset = fret_diagram.find("fretOffset")
        if fret_offset is not None and fret_offset.text:
            voicing["fret_number"] = int(fret_offset.text)

        # Extract string count
        strings_elem = fret_diagram.find("strings")
        if strings_elem is not None and strings_elem.text:
            voicing["strings"] = int(strings_elem.text)

        # Extract dots from string elements
        for string_elem in fret_diagram.iter("string"):
            string_no = string_elem.get("no")
            if string_no is None:
                continue
            # MuseScore uses 0-based string numbering internally
            # Convert to 1-based (1=high e)
            string_num = int(string_no) + 1

            for marker in string_elem.iter("marker"):
                marker_type = marker.get("id", "")
                if marker_type == "normal":
                    fret = marker.get("fret", "0")
                    voicing["dots"].append({
                        "string": string_num,
                        "fret": int(fret),
                    })
                elif marker_type == "cross":
                    voicing["mutes"].append(string_num)
                elif marker_type == "circle":
                    voicing["open"].append(string_num)

        if voicing["dots"]:
            voicings.append(voicing)

    return voicings


def main():
    parser = argparse.ArgumentParser(
        description="Extract voicing data from MuseScore files"
    )
    parser.add_argument("path", type=Path, help="Path to .mscz file or directory")
    parser.add_argument("--recursive", "-r", action="store_true",
                        help="Search directory recursively")
    parser.add_argument("--output", "-o", type=Path, default=DEFAULT_OUTPUT,
                        help="Output JSON file path")
    parser.add_argument("--merge", action="store_true",
                        help="Merge with existing voicings.json instead of overwriting")
    args = parser.parse_args()

    files = []
    if args.path.is_file():
        files = [args.path]
    elif args.path.is_dir():
        pattern = "**/*.mscz" if args.recursive else "*.mscz"
        files = sorted(args.path.glob(pattern))
    else:
        print(f"Path not found: {args.path}", file=sys.stderr)
        sys.exit(1)

    if not files:
        print("No .mscz files found", file=sys.stderr)
        sys.exit(1)

    all_voicings = []
    for f in files:
        print(f"Processing: {f}")
        try:
            xml_content = extract_mscx_from_mscz(f)
            voicings = parse_fretboard_diagrams(xml_content)
            print(f"  Found {len(voicings)} fretboard diagram(s)")
            all_voicings.extend(voicings)
        except Exception as e:
            print(f"  Error: {e}", file=sys.stderr)

    if args.merge and args.output.exists():
        with open(args.output) as existing:
            data = json.load(existing)
        existing_ids = {v["id"] for v in data.get("voicings", [])}
        new_voicings = [v for v in all_voicings if v["id"] not in existing_ids]
        data["voicings"].extend(new_voicings)
        print(f"\nMerged {len(new_voicings)} new voicing(s)")
    else:
        data = {"voicings": all_voicings}

    with open(args.output, "w") as out:
        json.dump(data, out, indent=2)
    print(f"\nWrote {len(data['voicings'])} voicing(s) to {args.output}")


if __name__ == "__main__":
    main()
