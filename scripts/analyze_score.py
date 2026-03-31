#!/usr/bin/env python3
"""Analyze a MuseScore file and report chord coverage from the voicing library.

Extracts all chord symbols from a score, maps them to library qualities,
and reports which chords have voicings available and which are gaps.

Usage:
    python analyze_score.py myscore.mscz
    python analyze_score.py myscore.mscz --context CV6
    python analyze_score.py myscore.mscz -o coverage-report.json
"""

import argparse
import json
import re
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from xml.etree import ElementTree as ET

REPO_ROOT = Path(__file__).resolve().parent.parent

# Map common chord symbol suffixes to our quality IDs
SUFFIX_TO_QUALITY = {
    "7": "dom7", "maj7": "maj7", "Maj7": "maj7", "M7": "maj7", "Δ7": "maj7",
    "m7": "min7", "min7": "min7", "-7": "min7",
    "m7b5": "min7b5", "-7b5": "min7b5", "ø7": "min7b5", "ø": "min7b5",
    "dim7": "dim7", "o7": "dim7", "°7": "dim7",
    "6": "maj6", "maj6": "maj6",
    "m6": "min6", "min6": "min6", "-6": "min6",
    "9": "dom9", "maj9": "maj9", "m9": "min9",
    "13": "dom13",
    "7b9": "dom7b9", "7#9": "dom7sharp9",
    "7#11": "dom7sharp11", "7b13": "dom7b13",
    "7alt": "dom7alt", "alt": "dom7alt",
    "7#5": "dom7sharp5", "7b5": "dom7flat5",
    "sus4": "sus4", "sus2": "sus2",
    "aug7": "aug7", "+7": "aug7",
    "mMaj7": "min-maj7", "m(maj7)": "min-maj7",
    "maj7#11": "maj7sharp11",
    "69": "maj69", "6/9": "maj69",
    "m11": "min11", "min11": "min11",
    "maj13": "maj13",
    "": "dom7",  # bare root = major, but we default to dom7 in jazz context
}

ROOT_PATTERN = re.compile(r"^([A-G][b#]?)")


def parse_chord_symbol(text: str) -> dict | None:
    """Parse a chord symbol into root + quality."""
    if not text:
        return None
    text = text.strip().replace("Δ", "maj").replace("△", "maj").replace("°", "dim").replace("ø", "m7b5").replace("+", "aug").replace("−", "-")

    m = ROOT_PATTERN.match(text)
    if not m:
        return None
    root = m.group(1)
    suffix = text[len(root):].strip()

    quality = SUFFIX_TO_QUALITY.get(suffix)
    if not quality:
        # Try partial matches
        if "maj7" in suffix:
            quality = "maj7"
        elif "m7b5" in suffix or "-7b5" in suffix:
            quality = "min7b5"
        elif "m7" in suffix or "-7" in suffix:
            quality = "min7"
        elif "7b9" in suffix:
            quality = "dom7b9"
        elif "7#9" in suffix:
            quality = "dom7sharp9"
        elif "7" in suffix:
            quality = "dom7"
        elif "m" in suffix or "min" in suffix:
            quality = "min7"  # default minor to min7 in jazz
        else:
            quality = None

    return {"root": root, "quality": quality, "text": text, "suffix": suffix}


def extract_chords_from_mscx(content: str) -> list[dict]:
    """Extract chord symbols with positions from .mscx XML."""
    root = ET.fromstring(content)
    chords = []

    for harmony in root.iter("Harmony"):
        chord_text = ""
        # Try to reconstruct from sub-elements
        root_el = harmony.find("root")
        name_el = harmony.find("name")

        if root_el is not None:
            root_case = root_el.text if root_el.text else ""
            # Look for alteration
            root_case_el = harmony.find("rootCase")
            if root_case_el is not None and root_case_el.text:
                root_case = root_case_el.text

        if name_el is not None and name_el.text:
            chord_text = name_el.text
        else:
            # Build from harmony attributes
            for text_el in harmony.iter():
                if text_el.text and text_el.tag not in ("root", "rootCase"):
                    chord_text += text_el.text

        if chord_text:
            parsed = parse_chord_symbol(chord_text)
            if parsed:
                chords.append(parsed)

    return chords


def extract_chords_from_file(path: Path) -> list[dict]:
    """Extract chords from .mscz or .mscx file."""
    if path.suffix == ".mscz":
        with zipfile.ZipFile(path) as zf:
            mscx_names = [n for n in zf.namelist() if n.endswith(".mscx")]
            if not mscx_names:
                return []
            content = zf.read(mscx_names[0]).decode("utf-8")
    else:
        content = path.read_text()

    return extract_chords_from_mscx(content)


def analyze_coverage(
    chords: list[dict],
    library: list[dict],
    context: str | None = None,
) -> dict:
    """Analyze which chords have library coverage."""
    # Build coverage index from library
    coverage = defaultdict(lambda: {"count": 0, "categories": Counter(), "voicing_ids": []})
    for v in library:
        if context and v.get("context") != context:
            continue
        q = v.get("chord_quality", "")
        coverage[q]["count"] += 1
        coverage[q]["categories"][v.get("category", "unknown")] += 1
        coverage[q]["voicing_ids"].append(v["id"])

    # Analyze each chord
    unique_chords = {}
    for c in chords:
        key = c["text"]
        if key not in unique_chords:
            unique_chords[key] = c
            unique_chords[key]["occurrences"] = 0
        unique_chords[key]["occurrences"] += 1

    report = {
        "total_chord_symbols": len(chords),
        "unique_chords": len(unique_chords),
        "covered": 0,
        "gaps": 0,
        "unknown_quality": 0,
        "chords": [],
    }

    for text, c in sorted(unique_chords.items()):
        quality = c.get("quality")
        entry = {
            "symbol": text,
            "root": c["root"],
            "quality": quality,
            "occurrences": c["occurrences"],
        }

        if quality is None:
            entry["status"] = "unknown_quality"
            entry["voicings_available"] = 0
            report["unknown_quality"] += 1
        elif quality in coverage:
            cov = coverage[quality]
            entry["status"] = "covered"
            entry["voicings_available"] = cov["count"]
            entry["categories"] = dict(cov["categories"])
            report["covered"] += 1
        else:
            entry["status"] = "gap"
            entry["voicings_available"] = 0
            report["gaps"] += 1

        report["chords"].append(entry)

    return report


def main():
    parser = argparse.ArgumentParser(
        description="Analyze a score's chord coverage against the voicing library"
    )
    parser.add_argument("score", type=Path, help="MuseScore file (.mscz or .mscx)")
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "data" / "voicings.json")
    parser.add_argument("--context", help="Filter library by context (CV6, CM6, etc.)")
    parser.add_argument("-o", "--output", type=Path, help="Save report as JSON")
    args = parser.parse_args()

    if not args.score.exists():
        print(f"File not found: {args.score}", file=sys.stderr)
        sys.exit(1)

    # Extract chords from score
    chords = extract_chords_from_file(args.score)
    if not chords:
        print(f"No chord symbols found in {args.score}")
        sys.exit(0)

    # Load library
    with open(args.data) as f:
        library = json.load(f)["voicings"]

    # Analyze
    report = analyze_coverage(chords, library, context=args.context)

    # Display
    ctx_label = f" ({args.context})" if args.context else ""
    print(f"Score: {args.score.name}")
    print(f"Library coverage{ctx_label}:")
    print(f"  Total chord symbols: {report['total_chord_symbols']}")
    print(f"  Unique chords: {report['unique_chords']}")
    print(f"  Covered: {report['covered']}")
    print(f"  Gaps: {report['gaps']}")
    if report["unknown_quality"] > 0:
        print(f"  Unknown quality: {report['unknown_quality']}")
    print()

    # Detail table
    print(f"{'Chord':<15} {'Quality':<15} {'Status':<10} {'Voicings':<10} {'Occurs'}")
    print("-" * 60)
    for c in report["chords"]:
        status_sym = {"covered": "✓", "gap": "✗", "unknown_quality": "?"}
        sym = status_sym.get(c["status"], " ")
        q = c["quality"] or "(unknown)"
        print(f"{c['symbol']:<15} {q:<15} {sym:<10} {c['voicings_available']:<10} {c['occurrences']}")

    if report["gaps"] > 0:
        print(f"\nGaps — these chords have no voicings in the library:")
        for c in report["chords"]:
            if c["status"] == "gap":
                print(f"  {c['symbol']} (quality: {c['quality']})")

    if args.output:
        with open(args.output, "w") as f:
            json.dump(report, f, indent=2)
        print(f"\nReport saved to {args.output}")


if __name__ == "__main__":
    main()
