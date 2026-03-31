#!/usr/bin/env python3
"""Analyze a MuseScore file and report chord coverage from the voicing library.

Extracts all chord symbols from a score, matches them against the library,
and reports coverage: which chords are covered, which have gaps, and
suggests voicing paths for the progression.

Usage:
    python analyze_score.py arrangement.mscz
    python analyze_score.py arrangement.mscz --context CV6
    python analyze_score.py arrangement.mscz -o coverage-report.json
    python analyze_score.py arrangement.mscz --pdf -o report.pdf
"""

import argparse
import json
import sys
import zipfile
from collections import Counter, OrderedDict
from pathlib import Path
from xml.etree import ElementTree as ET

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
SEMITONE_MAP = {n: i for i, n in enumerate(CHROMATIC)}
# Add enharmonic aliases
SEMITONE_MAP.update({"C#": 1, "D#": 3, "Gb": 6, "G#": 8, "A#": 10})

# MuseScore TPC (Tonal Pitch Class) → note name mapping
# TPC is fifths-based: ...Fbb=-1, Cbb=0, Gbb=1, ..., F=13, C=14, G=15, D=16, ...
# Range typically 0-33 in practice
TPC_TO_NOTE = {
    6: "Fbb", 7: "Cbb", 8: "Gbb", 9: "Dbb", 10: "Abb", 11: "Ebb", 12: "Bbb",
    13: "F", 14: "C", 15: "G", 16: "D", 17: "A", 18: "E", 19: "B",
    20: "F#", 21: "C#", 22: "G#", 23: "D#", 24: "A#", 25: "E#", 26: "B#",
    27: "F##", 28: "C##", 29: "G##", 30: "D##", 31: "A##", 32: "E##", 33: "B##",
    0: "Fbb", 1: "Cbb", 2: "Gbb", 3: "Dbb", 4: "Abb", 5: "Ebb",
}
# Simplified: also handle flats (TPC < 13)
for tpc_val in range(6):
    pass  # already covered above
# Add flat spellings
TPC_TO_NOTE.update({
    6: "Fb", 7: "Cb", 8: "Gb", 9: "Db", 10: "Ab", 11: "Eb", 12: "Bb",
})

QUALITY_MAP = {
    "7": "dom7", "maj7": "maj7", "M7": "maj7", "Δ7": "maj7", "Δ": "maj7",
    "m7": "min7", "-7": "min7", "min7": "min7",
    "m7b5": "min7b5", "-7b5": "min7b5", "ø7": "min7b5", "ø": "min7b5",
    "dim7": "dim7", "o7": "dim7", "°7": "dim7",
    "6": "maj6", "m6": "min6", "-6": "min6",
    "9": "dom9", "maj9": "maj9", "m9": "min9", "-9": "min9",
    "11": "dom11", "m11": "min11",
    "13": "dom13", "maj13": "maj13",
    "7b9": "dom7b9", "7#9": "dom7sharp9",
    "7#11": "dom7sharp11", "7b13": "dom7b13",
    "7b5": "dom7flat5", "7#5": "dom7sharp5",
    "7alt": "dom7alt", "alt": "dom7alt",
    "sus4": "sus4", "sus2": "sus2",
    "9sus4": "9sus4", "13sus4": "13sus4",
    "aug7": "aug7", "+7": "aug7",
    "mMaj7": "min-maj7", "m(maj7)": "min-maj7", "mM7": "min-maj7",
    "maj69": "maj69", "6/9": "maj69", "69": "maj69",
    "maj7#11": "maj7sharp11",
    "": "maj7",  # bare chord name in jazz context = major 7th
}


def parse_chord_symbol(text):
    """Parse a chord symbol into root + quality.

    Returns (root, quality_id, original_text) or None.
    """
    if not text or not text.strip():
        return None

    text = text.strip()
    # Handle slash chords — use the chord before the slash
    if "/" in text:
        text = text.split("/")[0]

    # Extract root
    root = None
    for r in sorted(CHROMATIC, key=len, reverse=True):
        if text.startswith(r):
            root = r
            break
    # Try sharps/flats
    if not root:
        for r in ["C#", "D#", "G#", "A#", "Gb"]:
            if text.startswith(r):
                root = r
                break
    if not root:
        return None

    suffix = text[len(root):]
    # Clean up common notation
    suffix = (suffix.replace("Δ", "maj").replace("△", "maj")
              .replace("°", "dim").replace("ø", "m7b5")
              .replace("+", "aug").replace("−", "-").strip())

    # Exact match
    quality = QUALITY_MAP.get(suffix)

    # Partial match (longest first)
    if not quality:
        for k, v in sorted(QUALITY_MAP.items(), key=lambda x: -len(x[0])):
            if k and suffix.startswith(k):
                quality = v
                break

    if not quality:
        quality = "unknown"

    return (root, quality, text)


def extract_progression_from_mscx(mscx_path):
    """Extract chord progression with positions from a MuseScore file.

    Returns dict with:
        title, composer, time_sig, chords: list of {tick, text, root, quality}
    """
    if mscx_path.suffix == ".mscz":
        with zipfile.ZipFile(mscx_path) as zf:
            mscx_names = [n for n in zf.namelist() if n.endswith(".mscx")]
            if not mscx_names:
                raise ValueError(f"No .mscx file found inside {mscx_path}")
            xml_data = zf.read(mscx_names[0])
            root = ET.fromstring(xml_data)
    else:
        tree = ET.parse(str(mscx_path))
        root = tree.getroot()

    # Metadata
    title = ""
    composer = ""
    for meta in root.iter("metaTag"):
        name = meta.get("name", "")
        if name == "workTitle":
            title = meta.text or ""
        elif name == "composer":
            composer = meta.text or ""

    # Extract chord symbols with tick positions
    chords = []
    tick = 0
    measure_num = 0

    for measure in root.iter("Measure"):
        measure_num += 1
        local_tick = 0

        for elem in measure.iter():
            if elem.tag == "Harmony":
                chord_text = None

                # MuseScore 4 format: <harmonyInfo><root>TPC</root><name>suffix</name></harmonyInfo>
                hi = elem.find("harmonyInfo")
                if hi is not None:
                    root_elem = hi.find("root")
                    name_elem = hi.find("name")
                    if root_elem is not None:
                        tpc = int(root_elem.text or "14")
                        chord_root = TPC_TO_NOTE.get(tpc, "C")
                        suffix = name_elem.text if name_elem is not None and name_elem.text else ""
                        chord_text = chord_root + suffix
                else:
                    # MuseScore 3 format: <root>0-11</root> <name>suffix</name>
                    root_elem = elem.find("root")
                    name_elem = elem.find("name")
                    if root_elem is not None:
                        root_val = int(root_elem.text or "0")
                        chord_root = CHROMATIC[root_val % 12]
                        suffix = name_elem.text if name_elem is not None and name_elem.text else ""
                        chord_text = chord_root + suffix
                    else:
                        # Fallback: try text content
                        for sub in elem.iter():
                            if sub.text and sub.text.strip():
                                chord_text = sub.text.strip()
                                break

                if chord_text:
                    parsed = parse_chord_symbol(chord_text)
                    if parsed:
                        chords.append({
                            "tick": tick + local_tick,
                            "measure": measure_num,
                            "text": chord_text,
                            "root": parsed[0],
                            "quality": parsed[1],
                        })

            elif elem.tag == "Chord" or elem.tag == "Rest":
                dur_elem = elem.find("durationType")
                if dur_elem is not None:
                    dur_map = {
                        "whole": 1920, "half": 960, "quarter": 480,
                        "eighth": 240, "16th": 120, "32nd": 60,
                    }
                    local_tick += dur_map.get(dur_elem.text, 480)

        tick += local_tick or 1920  # fallback to whole measure

    return {
        "title": title,
        "composer": composer,
        "total_measures": measure_num,
        "chords": chords,
    }


def analyze_coverage(chords, voicings, context="CV6"):
    """Analyze how well the voicing library covers a chord progression.

    Returns a coverage report dict.
    """
    # Group voicings by quality
    voicings_by_quality = {}
    for v in voicings:
        q = v["chord_quality"]
        ctx = v["context"]
        if ctx == context or context == "all":
            voicings_by_quality.setdefault(q, []).append(v)

    # Unique chord symbols in order of appearance
    unique_chords = list(OrderedDict.fromkeys(
        (c["root"], c["quality"], c["text"]) for c in chords
    ))

    covered = []
    gaps = []
    report_chords = []

    for root, quality, text in unique_chords:
        available = voicings_by_quality.get(quality, [])
        by_category = {}
        for v in available:
            by_category.setdefault(v["category"], []).append(v)

        entry = {
            "chord": text,
            "root": root,
            "quality": quality,
            "total_voicings": len(available),
            "categories": {cat: len(vs) for cat, vs in sorted(by_category.items())},
        }

        if available:
            covered.append(entry)
        else:
            gaps.append(entry)

        report_chords.append(entry)

    # Summary stats
    quality_counts = Counter(c["quality"] for c in chords)

    return {
        "total_chord_changes": len(chords),
        "unique_chords": len(unique_chords),
        "covered": len(covered),
        "gaps": len(gaps),
        "coverage_pct": round(len(covered) / len(unique_chords) * 100, 1) if unique_chords else 0,
        "context": context,
        "quality_frequency": dict(quality_counts.most_common()),
        "chords": report_chords,
        "gap_details": gaps,
    }


def print_report(info, coverage):
    """Print a human-readable coverage report."""
    print(f"\n{'=' * 60}")
    print(f"  Score Analysis: {info['title'] or 'Untitled'}")
    if info["composer"]:
        print(f"  {info['composer']}")
    print(f"{'=' * 60}")
    print(f"\n  Measures: {info['total_measures']}")
    print(f"  Chord changes: {coverage['total_chord_changes']}")
    print(f"  Unique chords: {coverage['unique_chords']}")
    print(f"  Context: {coverage['context']}")
    print(f"\n  Coverage: {coverage['covered']}/{coverage['unique_chords']}"
          f" ({coverage['coverage_pct']}%)")

    if coverage["gap_details"]:
        print(f"\n  GAPS ({len(coverage['gap_details'])} chords with no voicings):")
        for gap in coverage["gap_details"]:
            print(f"    - {gap['chord']} (quality: {gap['quality']})")

    print(f"\n  Quality frequency:")
    for quality, count in coverage["quality_frequency"].items():
        available = sum(1 for c in coverage["chords"]
                       if c["quality"] == quality and c["total_voicings"] > 0)
        total_q = sum(1 for c in coverage["chords"] if c["quality"] == quality)
        status = "✓" if available == total_q else "⚠"
        print(f"    {status} {quality:20s}: {count} occurrence(s), "
              f"{available}/{total_q} chord(s) covered")

    print(f"\n  Chord details:")
    print(f"  {'Chord':<12s} {'Quality':<16s} {'Voicings':<10s} {'Categories'}")
    print(f"  {'-'*12} {'-'*16} {'-'*10} {'-'*30}")
    for c in coverage["chords"]:
        cats = ", ".join(f"{cat}({n})" for cat, n in c["categories"].items()) if c["categories"] else "—"
        count_str = str(c["total_voicings"]) if c["total_voicings"] > 0 else "NONE"
        print(f"  {c['chord']:<12s} {c['quality']:<16s} {count_str:<10s} {cats}")

    print(f"\n{'=' * 60}")


def load_chords_from_json(chords_path):
    """Load chord data from a JSON file (exported by the plugin).

    The plugin extracts chords from the open score and writes them as:
    {"title": "...", "composer": "...", "total_measures": N, "chords": [...]}
    Each chord: {"text": "Dm7", "tick": 0, "measure": 1}
    """
    with open(chords_path) as f:
        data = json.load(f)

    # Parse each chord text into root + quality
    parsed_chords = []
    for c in data.get("chords", []):
        result = parse_chord_symbol(c["text"])
        if result:
            parsed_chords.append({
                "tick": c.get("tick", 0),
                "measure": c.get("measure", 0),
                "text": c["text"],
                "root": result[0],
                "quality": result[1],
            })

    return {
        "title": data.get("title", ""),
        "composer": data.get("composer", ""),
        "total_measures": data.get("total_measures", 0),
        "chords": parsed_chords,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Analyze a MuseScore file and report chord coverage"
    )
    parser.add_argument("score", nargs="?", type=Path,
                        help="MuseScore file (.mscx/.mscz)")
    parser.add_argument("--chords", type=Path,
                        help="JSON file of extracted chords (from plugin)")
    parser.add_argument("--context", default="CV6", help="Context to check coverage for")
    parser.add_argument("-o", "--output", type=Path, help="Save report as JSON")
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "data" / "voicings.json")
    args = parser.parse_args()

    if not args.score and not args.chords:
        parser.error("Provide a score file or --chords JSON file")

    with open(args.data) as f:
        voicings = json.load(f)["voicings"]

    if args.chords:
        info = load_chords_from_json(args.chords)
    else:
        if not args.score.exists():
            print(f"File not found: {args.score}", file=sys.stderr)
            sys.exit(1)
        info = extract_progression_from_mscx(args.score)

    if not info["chords"]:
        print("No chord symbols found in the score.", file=sys.stderr)
        sys.exit(1)

    coverage = analyze_coverage(info["chords"], voicings, args.context)

    print_report(info, coverage)

    if args.output:
        report = {
            "score": {
                "title": info["title"],
                "composer": info["composer"],
                "measures": info["total_measures"],
                "file": str(args.score),
            },
            "coverage": coverage,
            "progression": info["chords"],
        }
        with open(args.output, "w") as f:
            json.dump(report, f, indent=2)
        print(f"\nJSON report saved: {args.output}")


if __name__ == "__main__":
    main()
