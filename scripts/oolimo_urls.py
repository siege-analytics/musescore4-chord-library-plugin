#!/usr/bin/env python3
"""Generate Oolimo verification URLs for all voicings.

Produces a checklist of Oolimo chord calculator links grouped by chord quality,
so you can visually verify each voicing against Oolimo's reference shapes.

Usage:
    python scripts/oolimo_urls.py
    python scripts/oolimo_urls.py --data path/to/voicings.json
    python scripts/oolimo_urls.py --format markdown
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"

# Standard tuning MIDI values (same as validate.py)
STANDARD_TUNING = {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40, 7: 33}
CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Oolimo URL format: https://www.oolimo.com/en/guitar-chords/{root}{quality}
# Sharps use ~ instead of # in URLs (e.g., F#m7 → F~m7)
# Flats use lowercase b (e.g., Bb7 → Bb7)
# No public API. No way to deep-link to specific voicings/fret positions.
# Pages show up to 50 voicings per chord quality for visual comparison.
OOLIMO_BASE = "https://www.oolimo.com/en/guitar-chords"

# Map our chord_quality values to Oolimo URL suffixes
QUALITY_TO_OOLIMO = {
    "dom7": "7",
    "maj7": "maj7",
    "min7": "m7",
    "min7b5": "m7b5",
    "dim7": "dim7",
    "maj6": "6",
    "min6": "m6",
    "dom7sharp5": "7~5",
    "dom7flat5": "7b5",
    "dom7b9": "7b9",
    "dom7alt": "7alt",
    "aug7": "aug",
    "min-maj7": "m(maj7)",
    "dom9": "9",
    "maj9": "maj9",
    "min9": "m9",
    "dom13": "13",
    "sus4": "7sus4",
    "sus2": "sus2",
}


def _midi_to_note(midi: int) -> str:
    return CHROMATIC[midi % 12]


def _compute_fretboard(voicing: dict) -> str:
    """Build a human-readable fretboard position string like 'x-8-x-8-9-8'."""
    strings = voicing.get("strings", 6)
    fret_number = voicing.get("fret_number", 0)
    dots = {d["string"]: d["fret"] for d in voicing.get("dots", [])}
    mutes = set(voicing.get("mutes", []))
    opens = set(voicing.get("open", []))

    positions = []
    for s in range(strings, 0, -1):  # low to high
        if s in dots:
            abs_fret = fret_number + (dots[s] - 1)
            positions.append(str(abs_fret))
        elif s in opens:
            positions.append("0")
        elif s in mutes:
            positions.append("x")
        else:
            positions.append("?")

    return "-".join(positions)


def _compute_notes_str(voicing: dict) -> str:
    """Compute actual notes from fret positions."""
    fret_number = voicing.get("fret_number", 0)
    notes = []
    for dot in voicing.get("dots", []):
        s = dot["string"]
        f = dot["fret"]
        if s in STANDARD_TUNING:
            midi = STANDARD_TUNING[s] + fret_number + (f - 1)
            notes.append(_midi_to_note(midi))
    return " ".join(notes)


def generate_urls(data_path: Path, fmt: str = "text") -> None:
    with open(data_path) as f:
        data = json.load(f)

    voicings = data.get("voicings", [])

    # Group by chord quality
    by_quality: dict[str, list] = {}
    for v in voicings:
        q = v.get("chord_quality", "?")
        by_quality.setdefault(q, []).append(v)

    if fmt == "markdown":
        print("# Oolimo Verification Checklist\n")

    for quality, vlist in sorted(by_quality.items()):
        root = vlist[0].get("root", "C")
        oolimo_suffix = QUALITY_TO_OOLIMO.get(quality, quality)
        # Encode root for URL: # → ~
        url_root = root.replace("#", "~")
        chord_name = f"{root}{oolimo_suffix.replace('~', '#')}"
        chord_url = f"{OOLIMO_BASE}/{url_root}{oolimo_suffix}"
        analyze_url = f"{OOLIMO_BASE}/analyze"

        if fmt == "markdown":
            print(f"## {chord_name} ({quality})\n")
            print(f"Oolimo: [{chord_name}]({chord_url}) | [Analyzer]({analyze_url})\n")
            for v in vlist:
                vid = v["id"]
                fretboard = _compute_fretboard(v)
                notes = _compute_notes_str(v)
                verified = "needs_verification" not in v.get("tags", [])
                check = "x" if verified else " "
                print(f"- [{check}] `{vid}` — {fretboard} — {notes}")
            print()
        else:
            print(f"\n{'=' * 60}")
            print(f"  {chord_name} ({quality})")
            print(f"  Oolimo: {chord_url}")
            print(f"{'=' * 60}")
            for v in vlist:
                vid = v["id"]
                fretboard = _compute_fretboard(v)
                notes = _compute_notes_str(v)
                tags = v.get("tags", [])
                status = "NEEDS VERIFY" if "needs_verification" in tags else "OK"
                if "needs_rework" in tags:
                    status = "NEEDS REWORK"
                print(f"  [{status:>13}] {vid}")
                print(f"                  Frets: {fretboard}")
                print(f"                  Notes: {notes}")

    # Summary
    total = len(voicings)
    needs_verify = sum(
        1 for v in voicings if "needs_verification" in v.get("tags", [])
    )
    needs_rework = sum(
        1 for v in voicings if "needs_rework" in v.get("tags", [])
    )
    verified = total - needs_verify - needs_rework

    if fmt == "markdown":
        print(f"\n---\n**Summary:** {verified}/{total} verified, "
              f"{needs_verify} need verification, {needs_rework} need rework")
    else:
        print(f"\n{'=' * 60}")
        print(f"  Summary: {verified}/{total} verified, "
              f"{needs_verify} need verification, {needs_rework} need rework")


def main():
    parser = argparse.ArgumentParser(
        description="Generate Oolimo verification URLs for voicings"
    )
    parser.add_argument(
        "--data", type=Path, default=DEFAULT_DATA, help="Path to voicings.json"
    )
    parser.add_argument(
        "--format", choices=["text", "markdown"], default="text",
        help="Output format"
    )
    args = parser.parse_args()

    if not args.data.exists():
        print(f"Data not found: {args.data}", file=sys.stderr)
        sys.exit(1)

    generate_urls(args.data, args.format)


if __name__ == "__main__":
    main()
