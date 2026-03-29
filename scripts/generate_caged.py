#!/usr/bin/env python3
"""Generate all CAGED Drop 2 voicings mathematically.

Computes fret positions from first principles using standard tuning,
then validates every voicing with note-computation verification.

Usage:
    python scripts/generate_caged.py
    python scripts/generate_caged.py --output ~/Desktop/voicings-caged.json
    python scripts/generate_caged.py --qualities dom7,maj7,min7
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Standard tuning: string number -> MIDI note of open string
TUNING = {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40}

CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Chord quality definitions: intervals as semitones from root
QUALITIES = {
    "dom7":       {"intervals": [0, 4, 7, 10], "names": ["1", "3", "5", "b7"]},
    "maj7":       {"intervals": [0, 4, 7, 11], "names": ["1", "3", "5", "7"]},
    "min7":       {"intervals": [0, 3, 7, 10], "names": ["1", "b3", "5", "b7"]},
    "min7b5":     {"intervals": [0, 3, 6, 10], "names": ["1", "b3", "b5", "b7"]},
    "dim7":       {"intervals": [0, 3, 6, 9],  "names": ["1", "b3", "b5", "bb7"]},
    "dom7sharp5": {"intervals": [0, 4, 8, 10], "names": ["1", "3", "#5", "b7"]},
    "dom7b9":     {"intervals": [0, 4, 7, 10, 1], "names": ["1", "3", "5", "b7", "b9"]},
}

# CAGED string groups for Drop 2 voicings
# Each group: (bass_string, string_list, caged_name)
STRING_GROUPS = [
    (6, [6, 4, 3, 2], "E"),   # E shape: root on string 6
    (5, [5, 4, 3, 2], "A"),   # A shape: root on string 5
    (4, [4, 3, 2, 1], "D"),   # D shape: root on string 4
]

# Shell voicing string groups (3-note: root, 3rd/b3, 7th/b7)
SHELL_GROUPS = [
    (6, [6, 4, 3], "E"),      # E shape shell
    (5, [5, 3, 2], "A"),      # A shape shell
    (4, [4, 3, 2], "D"),      # D shape shell (root on D, 3rd on G, 7th on B)
]

# C root = MIDI 60 (middle C). We work in pitch classes (0-11).
ROOT_PC = 0  # C


def midi_to_note(midi):
    """MIDI note number to note name."""
    return CHROMATIC[midi % 12]


def note_for_string_fret(string, fret):
    """Compute the note at a given string and absolute fret."""
    return midi_to_note(TUNING[string] + fret)


def fret_for_note_on_string(string, target_pc, min_fret=0, max_fret=15):
    """Find the lowest fret on a string that produces the target pitch class."""
    open_midi = TUNING[string]
    for fret in range(min_fret, max_fret + 1):
        if (open_midi + fret) % 12 == target_pc:
            return fret
    return None


def generate_drop2_voicing(quality_name, quality_def, string_group, caged_name):
    """Generate a root-position Drop 2 voicing for a given quality and string group.

    Drop 2: take close-position voicing (R 3 5 7 from bottom),
    drop the 2nd voice from the top down one octave.

    Close position (high to low): 7th, 5th, 3rd, Root
    Drop 2 (high to low): 7th, 3rd, Root, 5th(dropped)

    So on strings [bass, mid-low, mid-high, high]:
    bass = 5th (dropped), mid-low = root, mid-high = 3rd, high = 7th
    """
    intervals = quality_def["intervals"][:4]  # Only first 4 for Drop 2
    interval_names = quality_def["names"][:4]

    # Root, 3rd, 5th, 7th pitch classes
    pcs = [(ROOT_PC + i) % 12 for i in intervals]

    # Drop 2 arrangement on strings (from lowest string to highest):
    # Bass string: 5th (dropped voice)
    # Next: Root
    # Next: 3rd
    # Highest: 7th
    drop2_order = [2, 0, 1, 3]  # indices into pcs: 5th, root, 3rd, 7th
    drop2_interval_order = [interval_names[i] for i in drop2_order]

    strings = string_group
    bass_string = strings[0]

    # Find fret positions. Start by finding root position on the bass string's next string
    # Actually, for root position, the ROOT is in the bass, not the 5th.
    # Let me reconsider:
    #
    # Root position Drop 2:
    # Close voicing bottom to top: R, 3, 5, 7
    # Drop 2nd from top (5th) down one octave
    # Result bottom to top: 5(dropped), R, 3, 7
    #
    # BUT "root position" in jazz means the root is the lowest note.
    # So root-position Drop 2 on 4 strings (low to high): R, 5, 3, 7?
    # No. Let me think again.
    #
    # Standard Drop 2 construction:
    # 1. Start with close voicing: 7, 5, 3, R (top to bottom)
    #    Which is: R(bottom), 3, 5, 7(top)
    # 2. "Drop 2" = take the 2nd voice from the TOP and drop it an octave
    #    2nd from top = 5
    #    Result (top to bottom): 7, 3, R, 5(dropped)
    #    Or bottom to top: 5(dropped), R, 3, 7
    #
    # So root position Drop 2, bottom to top: 5, R, 3, 7
    # This is NOT root in bass — 5th is in bass.
    #
    # For ROOT in bass, we need to use a different inversion:
    # Start from 1st inversion close: R(bottom), 3, 5, 7
    # -> top to bottom: 7, 5, 3, R
    # Wait, that's the same as root position close.
    #
    # Let me look at this from Laukens:
    # C7 A-string Drop 2, root position (labeled "C7"):
    # From the diagrams, bottom to top: C(1), G(5), Bb(b7), E(3)
    # That's: R, 5, b7, 3

    # Actually, looking at our verified voicings:
    # c7-drop2-a-str-6: C(5/fret3), G(4/fret5), Bb(3/fret3), E(2/fret5)
    # Bottom to top: C(root), G(5), Bb(b7), E(3)
    # So the order is: R, 5, b7, 3

    # And c7-drop2-e-str-6: C(6/fret8), Bb(4/fret8), E(3/fret9), G(2/fret8)
    # Bottom to top: C(root), Bb(b7), E(3), G(5)
    # So the order is: R, b7, 3, 5

    # These are DIFFERENT Drop 2 inversions depending on the string group!
    # E-shape (6-4-3-2, skipping string 5): R, b7, 3, 5
    # A-shape (5-4-3-2): R, 5, b7, 3

    # This is because Drop 2 on non-adjacent strings (E shape skips string 5)
    # produces different interval arrangements than on adjacent strings.

    # Let me just use the KNOWN correct arrangements from our validated data:

    pass  # Will use lookup tables instead


# Known correct Drop 2 voice arrangements per string group
# These are verified from Laukens and our validator.
# Format: list of interval indices [R=0, 3=1, 5=2, 7=3] from lowest string to highest
DROP2_VOICE_ORDER = {
    # E shape (strings 6-4-3-2, skipping 5): R, b7, 3, 5
    "E": [0, 3, 1, 2],
    # A shape (strings 5-4-3-2): R, 5, b7, 3
    "A": [0, 2, 3, 1],
    # D shape (strings 4-3-2-1): R, 5, b7, 3 (same as A shape, one string group up)
    "D": [0, 2, 3, 1],
}

# For shells: R, 3/b3, 7/b7
SHELL_VOICE_ORDER = {
    "E": [0, 2, 1],  # R on 6, 7th on 4, 3rd on 3
    "A": [0, 2, 1],  # R on 5, 7th on 3, 3rd on 2
    "D": [0, 1, 2],  # R on 4, 3rd on 3, 7th on 2
}


def build_voicing(quality_name, quality_def, strings, caged_name, voice_order,
                  category, mute_strings):
    """Build a voicing from quality definition and voice arrangement."""
    intervals = quality_def["intervals"][:len(voice_order)]
    interval_names = quality_def["names"][:len(voice_order)]

    pcs = [(ROOT_PC + i) % 12 for i in intervals]

    # Arrange voices according to the order
    arranged_pcs = [pcs[i] for i in voice_order]
    arranged_intervals = [interval_names[i] for i in voice_order]

    # Find fret positions
    dots = []
    notes = []
    frets_used = []

    for idx, string in enumerate(strings):
        target_pc = arranged_pcs[idx]
        # Search for the note starting from fret 0
        fret = fret_for_note_on_string(string, target_pc, min_fret=0, max_fret=15)
        if fret is None:
            return None  # Can't build this voicing
        frets_used.append(fret)
        notes.append(midi_to_note(TUNING[string] + fret))

    # Determine fret_number (lowest fret used) and relative positions
    min_fret = min(frets_used)
    max_fret = max(frets_used)

    # For root position, ensure the root is close to the standard CAGED position
    # E shape: root at fret 8, A shape: root at fret 3, D shape: root at fret 10
    caged_root_frets = {"E": 8, "A": 3, "D": 10}
    target_root_fret = caged_root_frets[caged_name]

    # Find the root string and adjust all frets to be near the target position
    root_string = strings[voice_order.index(0)] if 0 in voice_order else strings[0]
    root_fret = fret_for_note_on_string(root_string, ROOT_PC, min_fret=0, max_fret=15)

    # If root fret is too low, try an octave up
    if root_fret is not None and root_fret < target_root_fret - 2:
        root_fret += 12

    # Recompute all frets near the target root position
    frets_used = []
    for idx, string in enumerate(strings):
        target_pc = arranged_pcs[idx]
        # Try to find the note near the target root fret
        best_fret = None
        for f in range(max(0, target_root_fret - 4), target_root_fret + 6):
            if (TUNING[string] + f) % 12 == target_pc:
                best_fret = f
                break
        if best_fret is None:
            # Expand search
            best_fret = fret_for_note_on_string(string, target_pc, 0, 20)
        if best_fret is None:
            return None
        frets_used.append(best_fret)

    # Recompute notes with adjusted frets
    notes = [midi_to_note(TUNING[strings[i]] + frets_used[i]) for i in range(len(strings))]

    min_fret = min(frets_used)
    max_fret = max(frets_used)
    fret_number = min_fret
    span = max_fret - min_fret

    # Skip voicings that span more than 4 frets (not playable)
    if span > 4:
        return None

    visible_frets = max(4, span + 1)

    # Build dots (relative to fret_number)
    dots = []
    for idx, string in enumerate(strings):
        rel_fret = frets_used[idx] - fret_number + 1
        dots.append({"string": string, "fret": rel_fret})

    # Build mutes
    all_strings = set(range(1, 7))
    used_strings = set(strings)
    mutes = sorted(all_strings - used_strings)

    # Quality display name
    quality_display = {
        "dom7": "C7", "maj7": "Cmaj7", "min7": "Cm7", "min7b5": "Cm7b5",
        "dim7": "Cdim7", "dom7sharp5": "C7#5", "dom7b9": "C7b9",
    }
    display = quality_display.get(quality_name, "C" + quality_name)

    cat_display = {"drop2": "Drop 2", "shell": "Shell"}
    voicing_id = f"c{quality_name.replace('dom7', '7').replace('maj7', 'maj7').replace('min7', 'm7')}-{category}-{caged_name.lower()}-shape-6"
    # Clean up ID
    voicing_id = voicing_id.replace("dom7sharp5", "7sharp5").replace("dom7b9", "7b9")
    voicing_id = voicing_id.lower().replace(" ", "-")

    return {
        "id": voicing_id,
        "name": f"{display} — {caged_name} shape — {cat_display.get(category, category)}",
        "chord_quality": quality_name,
        "root": "C",
        "category": "caged",
        "context": "CV6",
        "strings": 6,
        "fret_number": fret_number,
        "visible_frets": visible_frets,
        "dots": dots,
        "mutes": mutes,
        "open": [],
        "notes": notes,
        "intervals": arranged_intervals,
        "tags": [f"caged-{caged_name.lower()}", category,
                 f"{caged_name.lower()}-string-root", "needs_verification"],
    }


def generate_all(qualities_filter=None):
    """Generate all CAGED voicings."""
    voicings = []

    for quality_name, quality_def in QUALITIES.items():
        if qualities_filter and quality_name not in qualities_filter:
            continue

        # Skip 5-note chords for shells and standard Drop 2
        is_5note = len(quality_def["intervals"]) > 4

        # Drop 2 voicings
        if not is_5note:
            for bass_str, string_list, caged_name in STRING_GROUPS:
                voice_order = DROP2_VOICE_ORDER[caged_name]
                v = build_voicing(
                    quality_name, quality_def, string_list, caged_name,
                    voice_order, "drop2", []
                )
                if v:
                    voicings.append(v)

        # Shell voicings (3-note: root, 3rd, 7th — skip 5-note and dim7)
        if quality_name not in ("dom7b9", "dom7sharp5", "dim7"):
            shell_def = {
                "intervals": [quality_def["intervals"][i] for i in [0, 1, 3]],
                "names": [quality_def["names"][i] for i in [0, 1, 3]],
            }
            for bass_str, string_list, caged_name in SHELL_GROUPS:
                voice_order = SHELL_VOICE_ORDER[caged_name]
                v = build_voicing(
                    quality_name, shell_def, string_list, caged_name,
                    voice_order, "shell", []
                )
                if v:
                    # Fix shell ID
                    v["id"] = v["id"].replace("-drop2-", "-shell-").replace("drop2", "shell")
                    voicings.append(v)

        # 5-note voicings (dom7b9) — only on E shape (strings 6-4-3-2-1)
        if is_5note:
            v = build_5note_voicing(quality_name, quality_def, "E")
            if v:
                voicings.append(v)

    return voicings


def build_5note_voicing(quality_name, quality_def, caged_name):
    """Build a 5-note voicing (e.g., dom7b9) on E shape strings 6-4-3-2-1."""
    if caged_name != "E":
        return None

    strings = [6, 4, 3, 2, 1]
    intervals = quality_def["intervals"][:5]
    interval_names = quality_def["names"][:5]
    pcs = [(ROOT_PC + i) % 12 for i in intervals]

    # Voice order for E shape 5-note: R, b7, 3, 5, b9
    voice_order = [0, 3, 1, 2, 4]
    arranged_pcs = [pcs[i] for i in voice_order]
    arranged_intervals = [interval_names[i] for i in voice_order]

    target_fret = 8
    frets_used = []
    for idx, string in enumerate(strings):
        target_pc = arranged_pcs[idx]
        best_fret = None
        for f in range(max(0, target_fret - 3), target_fret + 5):
            if (TUNING[string] + f) % 12 == target_pc:
                best_fret = f
                break
        if best_fret is None:
            return None
        frets_used.append(best_fret)

    notes = [midi_to_note(TUNING[strings[i]] + frets_used[i]) for i in range(len(strings))]
    min_fret = min(frets_used)
    max_fret = max(frets_used)
    if max_fret - min_fret > 4:
        return None

    fret_number = min_fret
    dots = [{"string": strings[i], "fret": frets_used[i] - fret_number + 1}
            for i in range(len(strings))]
    mutes = sorted(set(range(1, 7)) - set(strings))

    quality_display = {"dom7b9": "C7b9", "dom7sharp5": "C7#5"}
    display = quality_display.get(quality_name, "C" + quality_name)

    return {
        "id": f"c{quality_name.replace('dom', '')}-e-shape-6",
        "name": f"{display} — E shape",
        "chord_quality": quality_name,
        "root": "C",
        "category": "caged",
        "context": "CV6",
        "strings": 6,
        "fret_number": fret_number,
        "visible_frets": 4,
        "dots": dots,
        "mutes": mutes,
        "open": [],
        "notes": notes,
        "intervals": arranged_intervals,
        "tags": ["caged-e", "altered", "e-string-root", "needs_verification"],
    }


def verify_voicing(v):
    """Quick note verification."""
    errors = []
    for j, dot in enumerate(v["dots"]):
        s = dot["string"]
        f = dot["fret"]
        abs_fret = v["fret_number"] + (f - 1)
        computed = midi_to_note(TUNING[s] + abs_fret)
        declared = v["notes"][j] if j < len(v["notes"]) else "?"
        # Normalize for comparison
        computed_pc = CHROMATIC.index(computed)
        try:
            declared_pc = CHROMATIC.index(declared)
        except ValueError:
            # Try enharmonic
            enharmonic = {
                "Bbb": "A", "C#": "Db", "D#": "Eb", "E#": "F",
                "F#": "Gb", "G#": "Ab", "A#": "Bb", "B#": "C", "Cb": "B",
            }
            declared_norm = enharmonic.get(declared, declared)
            try:
                declared_pc = CHROMATIC.index(declared_norm)
            except ValueError:
                errors.append(f"  {v['id']}: unknown note '{declared}'")
                continue
        if computed_pc != declared_pc:
            errors.append(
                f"  {v['id']}: string {s} fret {f} (abs {abs_fret}) = {computed}, "
                f"declared {declared}"
            )
    return errors


def main():
    parser = argparse.ArgumentParser(description="Generate CAGED voicings")
    parser.add_argument(
        "--output", "-o", type=Path,
        default=Path.home() / "Desktop" / "voicings-caged.json",
        help="Output file path",
    )
    parser.add_argument(
        "--qualities", type=str, default=None,
        help="Comma-separated quality names to generate (default: all)",
    )
    args = parser.parse_args()

    qualities_filter = None
    if args.qualities:
        qualities_filter = set(args.qualities.split(","))

    voicings = generate_all(qualities_filter)

    # Verify all voicings
    all_errors = []
    for v in voicings:
        errors = verify_voicing(v)
        all_errors.extend(errors)

    if all_errors:
        print(f"\n{len(all_errors)} NOTE ERRORS:", file=sys.stderr)
        for e in all_errors:
            print(e, file=sys.stderr)
        print("\nFix errors before using this file!", file=sys.stderr)
    else:
        print("All notes verified.")

    # Write output
    output = {"voicings": voicings}
    with open(args.output, "w") as f:
        json.dump(output, f, indent=2)

    # Summary
    by_shape = {}
    by_quality = {}
    by_category = {}
    for v in voicings:
        shape = [t for t in v["tags"] if t.startswith("caged-")]
        shape = shape[0] if shape else "?"
        by_shape[shape] = by_shape.get(shape, 0) + 1
        by_quality[v["chord_quality"]] = by_quality.get(v["chord_quality"], 0) + 1
        by_category[v["category"]] = by_category.get(v["category"], 0) + 1

    print(f"\nGenerated {len(voicings)} voicings → {args.output}")
    print(f"By shape:    {by_shape}")
    print(f"By quality:  {by_quality}")
    print(f"By category: {by_category}")


if __name__ == "__main__":
    main()
