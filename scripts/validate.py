#!/usr/bin/env python3
"""Validate voicings.json against the JSON schema and verify note accuracy.

Usage:
    python scripts/validate.py
    python scripts/validate.py --data path/to/voicings.json
    python scripts/validate.py --verbose
    python scripts/validate.py --tuning tunings/7string-low-b.json
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import jsonschema
    from jsonschema import Draft202012Validator
except ImportError:
    print("Missing dependency: pip install jsonschema", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SCHEMA = REPO_ROOT / "schema" / "voicings.schema.json"
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"
DEFAULT_TUNING = REPO_ROOT / "config" / "tunings" / "7string-van-eps.json"

# Chromatic note names (using sharps and flats consistently)
CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Enharmonic equivalents for matching declared notes
ENHARMONIC = {
    "C#": "Db", "Db": "Db",
    "D#": "Eb", "Eb": "Eb",
    "E#": "F", "Fb": "E",
    "F#": "Gb", "Gb": "Gb",
    "G#": "Ab", "Ab": "Ab",
    "A#": "Bb", "Bb": "Bb",
    "B#": "C", "Cb": "B",
    "Bbb": "A",
}

# Interval-to-semitone mapping (from root)
INTERVAL_SEMITONES = {
    "1": 0,
    "b2": 1, "b9": 1,
    "2": 2, "9": 2,
    "#2": 3, "#9": 3,
    "b3": 3,
    "3": 4,
    "4": 5, "11": 5,
    "#4": 6, "#11": 6, "b5": 6,
    "5": 7,
    "#5": 8, "b6": 8, "b13": 8,
    "6": 9, "13": 9, "bb7": 9,
    "b7": 10,
    "7": 11,
}


def _load_tuning(tuning_path: Path) -> dict[int, int]:
    """Load a tuning config file. Returns {string_number: midi_note_of_open_string}.

    Tuning files map string numbers to open-string MIDI note numbers.
    Standard tuning: {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40}
    """
    if tuning_path.exists():
        with open(tuning_path) as f:
            config = json.load(f)
        return {int(k): v for k, v in config["strings"].items()}

    # Fallback: standard 6-string + 7th string low A (Van Eps default)
    return _default_tuning()


def _default_tuning() -> dict[int, int]:
    """Standard tuning with Van Eps 7th string (low A).

    MIDI notes for open strings:
      1 (high e) = E4 = 64
      2 (B)      = B3 = 59
      3 (G)      = G3 = 55
      4 (D)      = D3 = 50
      5 (A)      = A2 = 45
      6 (low E)  = E2 = 40
      7 (low A)  = A1 = 33  (Van Eps tuning)
    """
    return {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40, 7: 33}


def _midi_to_note(midi: int) -> str:
    """Convert MIDI note number to note name (no octave)."""
    return CHROMATIC[midi % 12]


def _note_to_pitch_class(name: str) -> int:
    """Convert a note name to pitch class (0-11). Handles enharmonics."""
    name = name.strip()
    canonical = ENHARMONIC.get(name, name)
    try:
        return CHROMATIC.index(canonical)
    except ValueError:
        return -1


def _resolve_tuning(
    voicing: dict,
    default_tuning: dict[int, int],
    tuning_cache: dict[str, dict[int, int]],
) -> dict[int, int]:
    """Resolve the tuning for a voicing: use its 'tuning' field if present,
    otherwise fall back to the default tuning."""
    tuning_name = voicing.get("tuning")
    if not tuning_name or tuning_name == "standard":
        return default_tuning

    if tuning_name in tuning_cache:
        return tuning_cache[tuning_name]

    # Try to load from config/tunings/<name>.json
    tuning_path = REPO_ROOT / "config" / "tunings" / f"{tuning_name}.json"
    if tuning_path.exists():
        loaded = _load_tuning(tuning_path)
        tuning_cache[tuning_name] = loaded
        return loaded

    # Fall back to default
    return default_tuning


def _verify_notes(data: dict, tuning: dict[int, int]) -> list[str]:
    """Verify that declared notes/intervals match actual fret positions.

    For each voicing, computes the actual note at each dot position using:
        actual_note = tuning[string] + fret_number + (fret - 1)

    Then compares against the declared notes and intervals arrays.
    If a voicing has a 'tuning' field, loads that tuning config instead.
    """
    errors = []
    tuning_cache: dict[str, dict[int, int]] = {}

    for i, v in enumerate(data.get("voicings", [])):
        vid = v.get("id", f"<index {i}>")
        fret_number = v.get("fret_number", 0)
        root = v.get("root", "C")
        root_pc = _note_to_pitch_class(root)
        dots = v.get("dots", [])
        declared_notes = v.get("notes", [])
        declared_intervals = v.get("intervals", [])
        voicing_tuning = _resolve_tuning(v, tuning, tuning_cache)

        if len(dots) != len(declared_notes):
            # Already caught by consistency check, skip note verification
            continue

        for j, dot in enumerate(dots):
            string_num = dot["string"]
            fret = dot["fret"]

            if string_num not in voicing_tuning:
                errors.append(
                    f"{vid}: string {string_num} not in tuning config"
                )
                continue

            # Compute actual note at this position
            absolute_fret = fret_number + (fret - 1)
            midi = voicing_tuning[string_num] + absolute_fret
            computed_note = _midi_to_note(midi)
            computed_pc = _note_to_pitch_class(computed_note)

            # Compare against declared note
            if j < len(declared_notes):
                declared_pc = _note_to_pitch_class(declared_notes[j])
                if declared_pc != computed_pc:
                    errors.append(
                        f"{vid}: dot {j+1} (string {string_num}, fret {fret}) "
                        f"= {computed_note} (abs fret {absolute_fret}), "
                        f"but declared as {declared_notes[j]}"
                    )

            # Verify interval if available
            if j < len(declared_intervals):
                interval = declared_intervals[j]
                if interval in INTERVAL_SEMITONES:
                    expected_semitones = INTERVAL_SEMITONES[interval]
                    actual_semitones = (computed_pc - root_pc) % 12
                    if actual_semitones != expected_semitones:
                        expected_note = _midi_to_note(
                            root_pc + expected_semitones + 60
                        )
                        errors.append(
                            f"{vid}: dot {j+1} interval '{interval}' "
                            f"should be {expected_note} "
                            f"({expected_semitones} semitones from {root}), "
                            f"but position gives {computed_note} "
                            f"({actual_semitones} semitones)"
                        )

    return errors


def validate(schema_path: Path, data_path: Path, verbose: bool = False) -> bool:
    with open(schema_path) as f:
        schema = json.load(f)
    with open(data_path) as f:
        data = json.load(f)

    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))

    if not errors:
        count = len(data.get("voicings", []))
        print(f"Valid. {count} voicing(s) passed schema validation.")
        if verbose:
            _print_summary(data)
        return True

    print(f"INVALID. {len(errors)} error(s) found:\n", file=sys.stderr)
    for i, error in enumerate(errors, 1):
        path = " > ".join(str(p) for p in error.absolute_path) or "(root)"
        print(f"  {i}. [{path}] {error.message}", file=sys.stderr)
    return False


def _check_consistency(data: dict) -> list[str]:
    """Run additional consistency checks beyond schema validation."""
    warnings = []
    seen_ids = set()

    for i, v in enumerate(data.get("voicings", [])):
        vid = v.get("id", f"<index {i}>")

        # Duplicate ID check
        if vid in seen_ids:
            warnings.append(f"Duplicate id: {vid}")
        seen_ids.add(vid)

        # Mutes + dots + open should cover all strings
        strings = v.get("strings", 6)
        all_strings = set(range(1, strings + 1))
        dotted = {d["string"] for d in v.get("dots", [])}
        muted = set(v.get("mutes", []))
        opened = set(v.get("open", []))
        accounted = dotted | muted | opened
        unaccounted = all_strings - accounted
        if unaccounted:
            warnings.append(
                f"{vid}: strings {sorted(unaccounted)} not in dots/mutes/open"
            )

        # Dot/mute/open overlap check
        overlap = dotted & muted
        if overlap:
            warnings.append(
                f"{vid}: strings {sorted(overlap)} in both dots and mutes"
            )
        overlap = dotted & opened
        if overlap:
            warnings.append(
                f"{vid}: strings {sorted(overlap)} in both dots and open"
            )

        # Notes and intervals length match
        if len(v.get("notes", [])) != len(v.get("intervals", [])):
            warnings.append(
                f"{vid}: notes ({len(v['notes'])}) and intervals "
                f"({len(v['intervals'])}) count mismatch"
            )

        # Notes count should match dots count
        if len(v.get("notes", [])) != len(v.get("dots", [])):
            warnings.append(
                f"{vid}: notes ({len(v['notes'])}) and dots "
                f"({len(v['dots'])}) count mismatch"
            )

        # --- Chord quality ↔ interval consistency ---
        quality = v.get("chord_quality", "")
        interval_set = set(v.get("intervals", []))

        # Define required intervals for each quality family
        quality_rules: dict[str, tuple[set[str], set[str]]] = {
            # quality: (must_have, must_not_have)
            "dom7":       ({"3", "b7"}, {"7", "b3"}),
            "maj7":       ({"3", "7"}, {"b7", "b3"}),
            "min7":       ({"b3", "b7"}, {"3", "7"}),
            "min7b5":     ({"b3", "b5", "b7"}, {"3", "5", "7"}),
            "dim7":       ({"b3", "b5", "bb7"}, {"3", "5", "7", "b7"}),
            "maj6":       ({"3", "6"}, {"b3"}),
            "min6":       ({"b3", "6"}, {"3"}),
            "dom7b9":     ({"3", "b7"}, {"7", "b3"}),
            "dom7sharp5": ({"3", "#5", "b7"}, {"5", "7"}),
            "dom7flat5":  ({"3", "b5", "b7"}, {"5", "7"}),
            "dom7alt":    ({"3", "b7"}, {"7"}),
            "dom9":       ({"3", "b7"}, {"7", "b3"}),
            "maj9":       ({"3", "7"}, {"b7", "b3"}),
            "min9":       ({"b3", "b7"}, {"3", "7"}),
            "dom13":      ({"3", "b7"}, {"7", "b3"}),
            "min-maj7":   ({"b3", "7"}, {"3", "b7"}),
            "aug7":       ({"3", "#5"}, {"5", "b3"}),
            "sus4":       ({"4"}, {"3", "b3"}),
            "sus2":       ({"9"}, {"3", "b3"}),
        }

        if quality in quality_rules:
            must_have, must_not = quality_rules[quality]

            # Expand interval_set with equivalences (2=9, 4=11, 6=13)
            expanded = set(interval_set)
            equiv = {"2": "9", "9": "2", "4": "11", "11": "4", "6": "13", "13": "6"}
            for iv in interval_set:
                if iv in equiv:
                    expanded.add(equiv[iv])

            # Shell voicings have only 3 notes — relax must_have rules
            category = v.get("category", "")
            is_shell = category == "shell" or len(v.get("dots", [])) <= 3

            missing = must_have - expanded
            bad = must_not & expanded

            # For shells, only warn about must_not violations (wrong tones),
            # not missing tones (shells deliberately omit notes)
            if missing and not is_shell:
                warnings.append(
                    f"{vid}: quality '{quality}' expects intervals "
                    f"{sorted(missing)} but they're missing"
                )
            if bad:
                warnings.append(
                    f"{vid}: quality '{quality}' should NOT have "
                    f"intervals {sorted(bad)}"
                )

        # --- Playability check: max fret stretch ---
        fret_positions = [d["fret"] for d in v.get("dots", [])]
        if len(fret_positions) >= 2:
            stretch = max(fret_positions) - min(fret_positions)
            if stretch > 4:
                warnings.append(
                    f"{vid}: fret stretch of {stretch} may be unplayable "
                    f"(max recommended: 4)"
                )

    return warnings


def _print_summary(data: dict) -> None:
    voicings = data.get("voicings", [])
    contexts = {}
    categories = {}
    qualities = {}

    for v in voicings:
        ctx = v.get("context", "?")
        contexts[ctx] = contexts.get(ctx, 0) + 1
        cat = v.get("category", "?")
        categories[cat] = categories.get(cat, 0) + 1
        qual = v.get("chord_quality", "?")
        qualities[qual] = qualities.get(qual, 0) + 1

    print(f"\n--- Summary ---")
    print(f"Total voicings: {len(voicings)}")
    print(f"By context:  {contexts}")
    print(f"By category: {categories}")
    print(f"By quality:  {qualities}")


def main():
    parser = argparse.ArgumentParser(description="Validate voicings.json")
    parser.add_argument(
        "--schema", type=Path, default=DEFAULT_SCHEMA, help="Path to JSON schema"
    )
    parser.add_argument(
        "--data", type=Path, default=DEFAULT_DATA, help="Path to voicings.json"
    )
    parser.add_argument(
        "--tuning", type=Path, default=DEFAULT_TUNING,
        help="Path to tuning config JSON (default: config/tunings/standard.json)"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Show summary")
    args = parser.parse_args()

    if not args.schema.exists():
        print(f"Schema not found: {args.schema}", file=sys.stderr)
        sys.exit(1)
    if not args.data.exists():
        print(f"Data not found: {args.data}", file=sys.stderr)
        sys.exit(1)

    valid = validate(args.schema, args.data, args.verbose)

    # Load tuning and run all checks
    tuning = _load_tuning(args.tuning)
    with open(args.data) as f:
        data = json.load(f)

    # Consistency checks
    warnings = _check_consistency(data)
    if warnings:
        print(f"\n{len(warnings)} consistency warning(s):", file=sys.stderr)
        for w in warnings:
            print(f"  - {w}", file=sys.stderr)

    # Note-computation verification
    note_errors = _verify_notes(data, tuning)
    if note_errors:
        print(
            f"\n{len(note_errors)} note verification ERROR(s):",
            file=sys.stderr,
        )
        for e in note_errors:
            print(f"  ✗ {e}", file=sys.stderr)
        valid = False
    else:
        print("Note verification: all positions match declared notes.")

    sys.exit(0 if valid else 1)


if __name__ == "__main__":
    main()
