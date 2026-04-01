#!/usr/bin/env python3
"""Suggest optimal finger assignments for chord voicings.

Uses heuristics based on fret position, hand span, barre detection,
and common fingering patterns to recommend which finger plays each note.

Algorithm
---------
The fingering engine applies these rules in order:

1. **Absolute fret calculation**: Each dot's fret position is converted
   from relative (within the diagram) to absolute (on the neck) by
   adding the diagram's fret_number offset.

2. **Barre detection**: If two or more notes share the same absolute
   fret, the index finger (1) barres across those strings. This is how
   guitarists actually play — a single finger lays flat across adjacent
   strings at the same fret.

3. **Fret-to-finger mapping**: The remaining fretted notes are assigned
   fingers based on their position relative to the lowest fret:
     - Index (1) → lowest fret (or barre fret)
     - Middle (2) → next fret up
     - Ring (3) → next fret up
     - Pinky (4) → highest fret

   This follows the "one finger per fret" principle taught in classical
   and jazz guitar technique.

4. **Stretch handling**: For voicings spanning more than 4 frets, the
   algorithm still assigns sequentially but flags the stretch. Voicings
   with a stretch > 4 frets are noted as potentially difficult.

5. **Two-fret voicings**: When only two frets are used, the index
   anchors the lower fret and middle/ring/pinky cover the upper fret,
   assigned from the lowest (bass) string upward.

Limitations:
- The algorithm does not consider finger independence or strength
- It does not detect partial barres (barre across 2-3 strings only)
- Thumb fretting (common on some bass notes) is not suggested
- Some voicings have multiple valid fingerings; only one is returned
- The Uberchord API (issue #61) provides human-verified fingerings
  that could supplement or replace these suggestions

Usage:
    python suggest_fingerings.py                           # suggest for all voicings
    python suggest_fingerings.py --voicing c7-shell-e-shape-6
    python suggest_fingerings.py --apply                   # write fingerings to voicings.json
    python suggest_fingerings.py --quality dom7 --context CV6
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Finger names for display
FINGER_NAMES = {0: "T", 1: "1", 2: "2", 3: "3", 4: "4"}
FINGER_LABELS = {0: "thumb", 1: "index", 2: "middle", 3: "ring", 4: "pinky"}


def suggest_fingering(voicing):
    """Suggest finger assignments for a voicing.

    Returns a list of {"string": int, "finger": int} entries,
    or None if no reasonable fingering can be determined.

    Finger numbering: 0=thumb, 1=index, 2=middle, 3=ring, 4=pinky
    """
    dots = voicing.get("dots", [])
    if not dots:
        return []

    fret_number = voicing.get("fret_number", 1)

    # Convert to absolute frets
    fretted = []
    for dot in dots:
        abs_fret = fret_number + (dot["fret"] - 1)
        fretted.append({
            "string": dot["string"],
            "rel_fret": dot["fret"],
            "abs_fret": abs_fret,
        })

    if not fretted:
        return []

    # Sort by fret (low to high), then by string (low to high = bass first)
    fretted.sort(key=lambda x: (x["abs_fret"], -x["string"]))

    min_fret = min(f["abs_fret"] for f in fretted)
    max_fret = max(f["abs_fret"] for f in fretted)
    stretch = max_fret - min_fret

    # Detect barre: multiple notes on the same fret
    fret_groups = defaultdict(list)
    for f in fretted:
        fret_groups[f["abs_fret"]].append(f)

    # Strategy selection based on stretch and note count
    fingering = {}

    # Case 1: All notes on the same fret (barre or single fret)
    if stretch == 0:
        if len(fretted) == 1:
            fingering[fretted[0]["string"]] = 1  # index
        elif len(fretted) == 2:
            # Two notes same fret: index barres or index + middle
            strings = sorted([f["string"] for f in fretted], reverse=True)
            fingering[strings[0]] = 1  # lower string = index
            fingering[strings[1]] = 2  # higher string = middle
        else:
            # Barre across multiple strings
            for f in fretted:
                fingering[f["string"]] = 1  # index barre

    # Case 2: Two-fret span
    elif stretch == 1:
        low_fret_notes = fret_groups[min_fret]
        high_fret_notes = fret_groups[max_fret]

        if len(low_fret_notes) >= 2:
            # Barre on low fret
            for f in low_fret_notes:
                fingering[f["string"]] = 1
            # Higher fret: assign 2, 3, 4
            for i, f in enumerate(sorted(high_fret_notes, key=lambda x: -x["string"])):
                fingering[f["string"]] = min(2 + i, 4)
        else:
            # Index on low fret, others on high fret
            for f in low_fret_notes:
                fingering[f["string"]] = 1
            fingers = [2, 3, 4]
            for i, f in enumerate(sorted(high_fret_notes, key=lambda x: -x["string"])):
                fingering[f["string"]] = fingers[min(i, len(fingers) - 1)]

    # Case 3: Three or four fret span (common jazz voicings)
    elif stretch <= 4:
        # Assign fingers based on fret position relative to lowest
        # Index = lowest fret, then middle, ring, pinky for subsequent frets
        fret_to_finger = {}
        unique_frets = sorted(set(f["abs_fret"] for f in fretted))

        if len(unique_frets) <= 4:
            # Simple mapping: each fret gets a finger
            finger_assignment = [1, 2, 3, 4]
            for i, fret in enumerate(unique_frets):
                fret_to_finger[fret] = finger_assignment[min(i, 3)]

            # Check for barre: if lowest fret has multiple notes, barre with index
            for f in fretted:
                assigned = fret_to_finger.get(f["abs_fret"], 1)
                fingering[f["string"]] = assigned
        else:
            # More than 4 unique frets — unusual, just assign sequentially
            for i, f in enumerate(fretted):
                fingering[f["string"]] = min(1 + i, 4)

    else:
        # Stretch > 4: likely unplayable or needs thumb
        for i, f in enumerate(fretted):
            fingering[f["string"]] = min(1 + i, 4)

    # Build result in the same order as dots
    result = []
    for dot in dots:
        finger = fingering.get(dot["string"], 1)
        result.append({"string": dot["string"], "finger": finger})

    return result


def format_fingering(voicing, fingering):
    """Format a fingering for human display."""
    num_strings = voicing.get("strings", 6)
    fret_number = voicing.get("fret_number", 1)

    # Build string display
    string_info = {}
    for dot, fg in zip(voicing["dots"], fingering):
        abs_fret = fret_number + (dot["fret"] - 1)
        string_info[dot["string"]] = f"f{abs_fret}={FINGER_NAMES[fg['finger']]}"

    for m in voicing.get("mutes", []):
        string_info[m] = "X"
    for o in voicing.get("open", []):
        string_info[o] = "O"

    parts = []
    for s in range(num_strings, 0, -1):
        parts.append(string_info.get(s, "·"))

    return " ".join(parts)


def match_chord_to_voicing(chord_text, all_voicings, context="CV6", category=None):
    """Match a chord symbol to the best library voicing."""
    from analyze_score import parse_chord_symbol
    parsed = parse_chord_symbol(chord_text)
    if not parsed:
        return None
    root, quality, _ = parsed
    candidates = [v for v in all_voicings
                  if v["chord_quality"] == quality
                  and (v["context"] == context or context == "all")]
    if category:
        filtered = [v for v in candidates if v["category"] == category]
        if filtered:
            candidates = filtered
    return candidates[0] if candidates else None


def main():
    parser = argparse.ArgumentParser(
        description="Suggest finger assignments for chord voicings"
    )
    parser.add_argument("--voicing", help="Specific voicing ID")
    parser.add_argument("--quality", help="Filter by chord quality")
    parser.add_argument("--context", help="Filter by context")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--chords", type=Path,
                        help="JSON file of extracted chords (from plugin)")
    parser.add_argument("--apply", action="store_true",
                        help="Write fingerings to voicings.json")
    parser.add_argument("--data", type=Path,
                        default=REPO_ROOT / "data" / "voicings.json")
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)

    all_voicings = data["voicings"]

    # If --chords is provided, match score chords to library voicings
    if args.chords:
        with open(args.chords) as f:
            chord_data = json.load(f)

        title = chord_data.get("title", "")
        if title:
            print(f"Score: {title}")
            print(f"{'=' * 60}\n")

        ctx = args.context or "CV6"
        seen_chords = set()
        voicings = []
        for c in chord_data.get("chords", []):
            text = c.get("text", "")
            if text in seen_chords:
                continue
            seen_chords.add(text)
            v = match_chord_to_voicing(text, all_voicings, ctx, args.category)
            if v:
                voicings.append((text, v))
            else:
                print(f"  {text:12s} — no matching voicing in library")

        if not voicings:
            print("No voicings matched the score's chords.", file=sys.stderr)
            sys.exit(1)

        for chord_text, v in voicings:
            fg = suggest_fingering(v)
            if fg:
                display = format_fingering(v, fg)
                print(f"  {chord_text:12s} {v['name'][:35]:35s} {display}")

        print(f"\n{len(voicings)} chords with fingering suggestions.")
    else:
        # Filter mode (original behavior)
        voicings_list = all_voicings
        if args.voicing:
            voicings_list = [v for v in voicings_list if v["id"] == args.voicing]
        if args.quality:
            voicings_list = [v for v in voicings_list if v["chord_quality"] == args.quality]
        if args.context:
            voicings_list = [v for v in voicings_list if v["context"] == args.context]
        if args.category:
            voicings_list = [v for v in voicings_list if v["category"] == args.category]

        if not voicings_list:
            print("No voicings match the filter", file=sys.stderr)
            sys.exit(1)

        applied = 0
        for v in voicings_list:
            fg = suggest_fingering(v)
            if fg:
                display = format_fingering(v, fg)
                if not args.apply:
                    print(f"{v['id']:40s} {v['name'][:35]:35s} {display}")
                else:
                    v["fingering"] = fg
                    applied += 1

        if args.apply:
            fingerings_by_id = {v["id"]: v.get("fingering") for v in voicings_list if "fingering" in v}
            for v in data["voicings"]:
                if v["id"] in fingerings_by_id:
                    v["fingering"] = fingerings_by_id[v["id"]]
            with open(args.data, "w") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            print(f"Applied fingerings to {applied} voicings in {args.data}")
        else:
            print(f"\n{len(voicings_list)} voicings displayed. Use --apply to write to voicings.json.")


if __name__ == "__main__":
    main()
