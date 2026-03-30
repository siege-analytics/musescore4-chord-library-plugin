#!/usr/bin/env python3
"""Export the voicing library as Guitar Pro 5 (.gp5) files.

Generates all 153 voicings in all 12 keys. Each voicing becomes a beat
with a chord diagram attached. Output can be a single file with all
voicings or one file per chord quality.

Usage:
    python export_gp5.py                          # single file, all voicings
    python export_gp5.py --by-quality -o exports/  # one file per quality
    python export_gp5.py --root F                  # single key only
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import guitarpro as gp
except ImportError:
    print("Missing dependency: pip install pyguitarpro", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"

ROOTS = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

SEMITONE_MAP = {
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
    "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
    "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11,
}

# Map chord_quality to GP ChordType enum values
QUALITY_TO_GP_TYPE = {
    "maj7": gp.models.ChordType.majorSeventh,
    "dom7": gp.models.ChordType.seventh,
    "min7": gp.models.ChordType.minorSeventh,
    "min7b5": gp.models.ChordType.diminished,
    "dim7": gp.models.ChordType.diminished,
    "maj6": gp.models.ChordType.sixth,
    "min6": gp.models.ChordType.minorSixth,
    "aug7": gp.models.ChordType.augmented,
    "sus4": gp.models.ChordType.suspendedFourth,
    "sus2": gp.models.ChordType.suspendedSecond,
    "min-maj7": gp.models.ChordType.minorMajor,
}

# Map root name to GP PitchClass
PITCH_CLASS = {
    "C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5,
    "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11,
}

NOTE_NAMES_FLAT = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
NOTE_NAMES_SHARP = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Standard tuning MIDI values (high to low for GP: string 0 = highest)
STANDARD_TUNING_GP = [64, 59, 55, 50, 45, 40]  # E4 B3 G3 D3 A2 E2
SEVEN_STRING_TUNING_GP = [64, 59, 55, 50, 45, 40, 33]  # + A1


def semitone_offset(source: str, target: str) -> int:
    return (SEMITONE_MAP[target] - SEMITONE_MAP[source]) % 12


def transpose_name(name: str, target_root: str) -> str:
    """Replace leading C in voicing name with target root."""
    if target_root == "C":
        return name
    # Replace C at the start, before quality suffix
    import re
    return re.sub(r"^C(?=[^a-z]|maj|min|dim|aug|sus|m[^a-z]|$)", target_root, name)


def voicing_to_gp_chord(voicing: dict, target_root: str) -> gp.models.Chord:
    """Convert a voicing dict to a PyGuitarPro Chord object."""
    num_strings = voicing.get("strings", 6)
    offset = semitone_offset("C", target_root)
    transposed_fret = voicing["fret_number"] + offset

    chord = gp.models.Chord(num_strings)
    chord.name = transpose_name(voicing["name"].split(" — ")[0], target_root)
    chord.firstFret = transposed_fret
    chord.sharp = target_root not in {"F", "Bb", "Eb", "Ab", "Db", "Gb"}
    chord.newFormat = True
    chord.show = True

    # Set root pitch class
    pc = PITCH_CLASS.get(target_root, 0)
    try:
        chord.root = gp.models.PitchClass(pc)
    except (ValueError, AttributeError):
        pass

    # Set chord type
    quality = voicing.get("chord_quality", "")
    if quality in QUALITY_TO_GP_TYPE:
        chord.type = QUALITY_TO_GP_TYPE[quality]

    # Build strings array: fret per string, -1 = not played
    # GP uses 0-based indexing, 0 = highest string
    strings = [-1] * num_strings

    for dot in voicing.get("dots", []):
        # Our format: string 1 = high e, string 6 = low E
        # GP format: index 0 = high e, index 5 = low E
        gp_idx = dot["string"] - 1
        absolute_fret = voicing["fret_number"] + (dot["fret"] - 1) + offset
        strings[gp_idx] = absolute_fret

    for open_str in voicing.get("open", []):
        gp_idx = open_str - 1
        strings[gp_idx] = 0

    # Muted strings stay as -1 (default)

    chord.strings = strings
    return chord


def create_gp5_song(
    voicings: list[dict],
    target_root: str,
    title: str = "Chord Library",
) -> gp.Song:
    """Create a GP5 song with one beat per voicing, each with a chord diagram."""
    song = gp.Song()
    song.title = f"{title} — {target_root}"
    song.artist = "Chord Library Plugin"

    # Set up guitar track
    track = song.tracks[0]
    track.name = "Guitar"
    track.isPercussionTrack = False

    # Set tuning based on max string count
    max_strings = max((v.get("strings", 6) for v in voicings), default=6)
    if max_strings == 7:
        track.strings = [gp.GuitarString(i + 1, v) for i, v in enumerate(SEVEN_STRING_TUNING_GP)]
    else:
        track.strings = [gp.GuitarString(i + 1, v) for i, v in enumerate(STANDARD_TUNING_GP)]

    # Use the first measure as a template for time signature etc.
    template_header = song.measureHeaders[0]
    template_measure = track.measures[0]

    # Put the first voicing in the existing first measure
    if voicings:
        voice = template_measure.voices[0]
        beat = gp.models.Beat(voice)
        beat.duration = gp.models.Duration(value=1)  # whole note
        chord = voicing_to_gp_chord(voicings[0], target_root)
        beat.effect.chord = chord
        note = gp.models.Note(beat)
        note.value = 0
        note.string = 1
        beat.notes.append(note)
        voice.beats.append(beat)

    # Add remaining voicings as new measures
    for i, voicing in enumerate(voicings[1:], start=1):
        header = gp.models.MeasureHeader()
        header.number = i + 1
        header.start = template_header.start + (template_header.length * i)
        header.timeSignature = template_header.timeSignature
        song.measureHeaders.append(header)

        measure = gp.models.Measure(track, header)
        track.measures.append(measure)

        voice = measure.voices[0]
        beat = gp.models.Beat(voice)
        beat.duration = gp.models.Duration(value=1)

        chord = voicing_to_gp_chord(voicing, target_root)
        beat.effect.chord = chord

        note = gp.models.Note(beat)
        note.value = 0
        note.string = 1
        beat.notes.append(note)
        voice.beats.append(beat)

    return song


def main():
    parser = argparse.ArgumentParser(
        description="Export voicing library as Guitar Pro 5 (.gp5) files"
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
        "-o", "--output", type=Path, default=Path("exports/gp5"),
        help="Output directory",
    )
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)
    voicings = data["voicings"]

    roots = [args.root] if args.root else ROOTS
    args.output.mkdir(parents=True, exist_ok=True)

    if args.by_quality:
        # Group by quality
        by_quality: dict[str, list] = {}
        for v in voicings:
            q = v["chord_quality"]
            by_quality.setdefault(q, []).append(v)

        total = 0
        for quality, vlist in sorted(by_quality.items()):
            for root in roots:
                song = create_gp5_song(vlist, root, title=f"{quality} voicings")
                out_file = args.output / f"{quality}_{root}.gp5"
                gp.write(song, str(out_file))
                total += 1
        print(f"Generated {total} GP5 files in {args.output}/")
    else:
        for root in roots:
            song = create_gp5_song(voicings, root)
            out_file = args.output / f"chord-library_{root}.gp5"
            gp.write(song, str(out_file))
            print(f"  {out_file} ({len(voicings)} voicings)")
        print(f"\nGenerated {len(roots)} GP5 files in {args.output}/")


if __name__ == "__main__":
    main()
