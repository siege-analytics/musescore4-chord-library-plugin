#!/usr/bin/env python3
"""Generate a complete importable voicing library for an alternate tuning.

Runs the chord calculator for all supported qualities, filters for the best
voicings per quality, and outputs a voicings.json-compatible file that can
be imported directly into the Chord Library plugin.

Usage:
    python generate_tuning_library.py --tuning config/tunings/dadgad.json
    python generate_tuning_library.py --tuning config/tunings/dadgad.json -o dadgad-library.json
    python generate_tuning_library.py --tuning config/tunings/dadgad.json --max-per-quality 3
    python generate_tuning_library.py --all-tunings  # generate for every non-standard tuning

Output is a JSON file with the same schema as data/voicings.json. Import it
via the plugin's Settings > Import Voicings.
"""

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from chord_calculator import (
    CHORD_QUALITIES,
    CHROMATIC,
    find_practical_voicings,
    interval_label,
    load_tuning,
    note_name,
)

TUNINGS_DIR = REPO_ROOT / "plugin" / "tunings"

# Interval display names for voicing naming
INTERVAL_NAMES = {
    "1": "root", "b9": "b9th", "9": "9th", "#9": "#9th",
    "b3": "b3rd", "3": "3rd", "4": "4th", "#11": "#11th",
    "b5": "b5th", "5": "5th", "#5": "#5th", "6": "6th",
    "b7": "b7th", "7": "7th", "b13": "b13th",
}


def generate_library(
    tuning_path: Path,
    max_per_quality: int = 3,
    max_fret: int = 12,
    max_stretch: int = 4,
) -> dict:
    """Generate a voicing library for a tuning."""
    tuning_name, tuning = load_tuning(tuning_path)
    num_strings = len(tuning)
    tuning_slug = tuning_path.stem  # e.g. "dadgad"

    # Determine context prefix based on string count
    if num_strings <= 4:
        contexts = ["CV4", "CM4"]
    elif num_strings <= 6:
        contexts = ["CV6", "CM6"]
    else:
        contexts = ["CV7", "CM7"]

    print(f"Generating library for {tuning_name} ({num_strings} strings)")
    print(f"  Max {max_per_quality} voicings per quality, frets 0-{max_fret}")

    # Generate C-root voicings
    all_voicings = find_practical_voicings(
        tuning,
        target_root="C",
        max_fret=max_fret,
        max_stretch=max_stretch,
    )

    # Group by quality and take the best N per quality
    by_quality = defaultdict(list)
    for v in all_voicings:
        by_quality[v["quality"]].append(v)

    exported = []
    seq = 1

    for quality_id in sorted(by_quality.keys()):
        voicings = by_quality[quality_id][:max_per_quality]
        _, display, _ = CHORD_QUALITIES[quality_id]

        for v in voicings:
            # Determine category
            if any(q in quality_id for q in ["7b5", "7sharp5", "sharp9", "b9", "b13", "alt"]):
                category = "altered"
            elif any(q in quality_id for q in ["9", "13", "11", "sus"]):
                category = "extended"
            elif "dim" in quality_id:
                category = "shell"
            elif quality_id in ("maj", "min", "aug", "dim"):
                category = "shell"
            else:
                category = "drop2"  # default for 7th chords

            # Top note for naming
            top_interval = v["intervals"][-1] if v["intervals"] else ""
            top_label = INTERVAL_NAMES.get(top_interval, top_interval)

            slug = display.lower().replace("#", "s").replace("(", "").replace(")", "").replace(" ", "")

            for context in contexts:
                vid = f"c{slug}-{tuning_slug}-{context.lower()}-{seq}"

                exported.append({
                    "id": vid,
                    "name": f"C{display} — {tuning_name} — {category.title()} ({top_label} on top)",
                    "chord_quality": quality_id,
                    "root": "C",
                    "category": category,
                    "context": context,
                    "strings": num_strings,
                    "fret_number": v["fret_number"],
                    "visible_frets": 4,
                    "dots": v["dots"],
                    "mutes": v["mutes"],
                    "open": v["open"],
                    "notes": v["notes"],
                    "intervals": v["intervals"],
                    "tuning": tuning_slug,
                    "tags": ["calculated", tuning_slug],
                })
                seq += 1

    # Summary
    quality_counts = Counter(v["chord_quality"] for v in exported)
    print(f"  Generated {len(exported)} voicings across {len(quality_counts)} qualities")
    for q, c in sorted(quality_counts.items()):
        print(f"    {q}: {c}")

    return {"voicings": exported}


def main():
    parser = argparse.ArgumentParser(
        description="Generate importable voicing library for an alternate tuning"
    )
    parser.add_argument(
        "--tuning", type=Path,
        help="Path to a tuning JSON file",
    )
    parser.add_argument(
        "--all-tunings", action="store_true",
        help="Generate for all non-standard tunings",
    )
    parser.add_argument(
        "--max-per-quality", type=int, default=3,
        help="Max voicings per chord quality (default: 3)",
    )
    parser.add_argument("--max-fret", type=int, default=12)
    parser.add_argument("--max-stretch", type=int, default=4)
    parser.add_argument("-o", "--output", type=Path, help="Output directory or file")
    args = parser.parse_args()

    if not args.tuning and not args.all_tunings:
        parser.error("Specify --tuning or --all-tunings")

    if args.all_tunings:
        # Generate for every tuning except standard and 7-string (already in main library)
        skip = {"standard.json", "7string-van-eps.json", "7string-low-b.json"}
        tuning_files = sorted(f for f in TUNINGS_DIR.glob("*.json") if f.name not in skip)

        output_dir = args.output or REPO_ROOT / "plugin" / "data" / "tuning-libraries"
        output_dir.mkdir(exist_ok=True)

        for tf in tuning_files:
            print(f"\n{'=' * 50}")
            library = generate_library(
                tf,
                max_per_quality=args.max_per_quality,
                max_fret=args.max_fret,
                max_stretch=args.max_stretch,
            )
            out_file = output_dir / f"{tf.stem}-library.json"
            with open(out_file, "w") as f:
                json.dump(library, f, indent=2, ensure_ascii=False)
                f.write("\n")
            print(f"  Saved to {out_file}")

        print(f"\nGenerated {len(tuning_files)} tuning libraries in {output_dir}")

    else:
        library = generate_library(
            args.tuning,
            max_per_quality=args.max_per_quality,
            max_fret=args.max_fret,
            max_stretch=args.max_stretch,
        )

        if args.output:
            out_file = args.output
        else:
            out_file = REPO_ROOT / "plugin" / "data" / f"{args.tuning.stem}-library.json"

        with open(out_file, "w") as f:
            json.dump(library, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"\nSaved to {out_file}")


if __name__ == "__main__":
    main()
