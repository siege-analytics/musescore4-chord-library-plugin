#!/usr/bin/env python3
"""Generate grouped palette .mscz files from voicings.json.

Creates one .mscz file per palette group (context + voicing type),
with each voicing as a separate measure containing a whole note,
a fretboard diagram with full dot/marker data, and a chord symbol.

Output structure mirrors the 24-palette design:
  palettes/
    CV6 — Shell.mscz        (all CV6 shell voicings)
    CV6 — Drop 2.mscz       (all CV6 drop 2 voicings)
    CM7 — Shell.mscz         (all CM7 shell voicings)
    ...

Usage:
    python generate_palettes.py                        # all groups, root C
    python generate_palettes.py --root F               # all groups, transposed to F
    python generate_palettes.py --context CV6          # only CV6 groups
    python generate_palettes.py --output ~/Desktop/palettes
"""

import argparse
import base64
import json
import sys
import uuid
import zipfile
from collections import defaultdict
from pathlib import Path

SEMITONE_MAP = {
    "C": 0, "B#": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
    "E": 4, "Fb": 4, "F": 5, "E#": 5, "F#": 6, "Gb": 6, "G": 7,
    "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11,
}

# MuseScore tonal pitch class values for each root
# tpc 14 = C, 13 = F, 15 = G, etc.
TPC_MAP = {
    "C": 14, "G": 15, "D": 16, "A": 17, "E": 18, "B": 19,
    "F#": 20, "Gb": 12, "Db": 13, "F": 13, "Bb": 14 - 1,
    "Eb": 14 - 2, "Ab": 14 - 3,
}

MIDI_C4 = 60

CATEGORY_LABELS = {
    "shell": "Shell",
    "drop2": "Drop 2",
    "drop3": "Drop 3",
    "extended": "Extended",
    "altered": "Altered",
    "quartal": "Quartal",
}

# Chord quality to MuseScore Harmony name mapping
QUALITY_TO_HARMONY = {
    "dom7": "7",
    "maj7": "maj7",
    "min7": "m7",
    "min7b5": "m7b5",
    "maj6": "6",
    "min6": "m6",
    "dim7": "dim7",
    "aug7": "aug7",
    "dom9": "9",
    "maj9": "maj9",
    "min9": "m9",
    "dom13": "13",
    "sus4": "sus4",
    "sus2": "sus2",
    "dom7alt": "7alt",
}

# MuseScore root tpc values (for Harmony element)
HARMONY_ROOT_TPC = {
    "C": 14, "Db": 9, "D": 16, "Eb": 11, "E": 18, "F": 13,
    "F#": 20, "Gb": 12, "G": 15, "Ab": 10, "A": 17, "Bb": 12, "B": 19,
}

NOTE_NAMES_FLAT = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


def make_eid() -> str:
    raw = uuid.uuid4().bytes + uuid.uuid4().bytes[:8]
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def semitone_offset(source_root: str, target_root: str) -> int:
    src = SEMITONE_MAP.get(source_root)
    tgt = SEMITONE_MAP.get(target_root)
    if src is None or tgt is None:
        raise ValueError(f"Unknown root: {source_root} or {target_root}")
    return (tgt - src) % 12


def transpose_root(root: str, offset: int) -> str:
    src = SEMITONE_MAP.get(root, 0)
    return NOTE_NAMES_FLAT[(src + offset) % 12]


def tpc_for_note(offset: int) -> int:
    """Calculate tonal pitch class for a note at given semitone offset from C."""
    note = NOTE_NAMES_FLAT[offset % 12]
    return HARMONY_ROOT_TPC.get(note, 14)


def generate_harmony_xml(voicing: dict, target_root: str) -> str:
    """Generate <Harmony> element for the chord symbol."""
    quality_name = QUALITY_TO_HARMONY.get(voicing["chord_quality"], voicing["chord_quality"])
    root_tpc = HARMONY_ROOT_TPC.get(target_root, 14)

    return f"""            <Harmony>
              <harmonyInfo>
                <name>{quality_name}</name>
                <root>{root_tpc}</root>
                </harmonyInfo>
              <eid>{make_eid()}</eid>
              </Harmony>"""


def generate_fret_diagram_xml(voicing: dict, target_root: str = "C") -> str:
    """Generate <FretDiagram> XML with full dot/marker data and chord symbol."""
    offset = semitone_offset(voicing["root"], target_root)
    transposed_fret = voicing["fret_number"] + offset
    num_strings = voicing.get("strings", 6)
    num_frets = voicing.get("visible_frets", 4)

    string_data: dict[int, dict] = {}

    for dot in voicing.get("dots", []):
        ms_str = num_strings - dot["string"]
        string_data.setdefault(ms_str, {})["dot"] = dot["fret"]

    for mute_str in voicing.get("mutes", []):
        ms_str = num_strings - mute_str
        string_data.setdefault(ms_str, {})["marker"] = "cross"

    for open_str in voicing.get("open", []):
        ms_str = num_strings - open_str
        string_data.setdefault(ms_str, {})["marker"] = "circle"

    fret_offset = transposed_fret - 1

    lines = ["          <FretDiagram>"]
    if fret_offset > 0:
        lines.append(f"            <fretOffset>{fret_offset}</fretOffset>")
    if num_frets != 4:
        lines.append(f"            <frets>{num_frets}</frets>")
    if num_strings != 6:
        lines.append(f"            <strings>{num_strings}</strings>")

    lines.append(f"            <eid>{make_eid()}</eid>")

    # Chord symbol attached to the diagram
    lines.append(generate_harmony_xml(voicing, target_root))

    lines.append("            <fretDiagram>")
    for ms_str in sorted(string_data.keys()):
        data = string_data[ms_str]
        lines.append(f'              <string no="{ms_str}">')
        if "marker" in data:
            lines.append(f"                <marker>{data['marker']}</marker>")
        if "dot" in data:
            lines.append(f'                <dot fret="{data["dot"]}">normal</dot>')
        lines.append("              </string>")

    lines.append("            </fretDiagram>")
    lines.append("          </FretDiagram>")
    return "\n".join(lines)


def generate_measure_xml(voicing: dict, target_root: str, include_timesig: bool = False) -> str:
    """Generate one <Measure> with a whole note + fretboard diagram + chord symbol."""
    offset = semitone_offset(voicing["root"], target_root)
    midi_pitch = MIDI_C4 + offset
    tpc = tpc_for_note(offset)
    fret_xml = generate_fret_diagram_xml(voicing, target_root)

    # Rehearsal mark with voicing name as tooltip/label
    name = voicing["name"]
    if target_root != "C":
        name = name.replace("C", target_root, 1)

    timesig = ""
    if include_timesig:
        timesig = f"""          <TimeSig>
            <eid>{make_eid()}</eid>
            <sigN>4</sigN>
            <sigD>4</sigD>
            </TimeSig>
"""

    return f"""      <Measure>
        <eid>{make_eid()}</eid>
        <voice>
{timesig}{fret_xml}
          <Chord>
            <eid>{make_eid()}</eid>
            <durationType>whole</durationType>
            <Note>
              <eid>{make_eid()}</eid>
              <pitch>{midi_pitch}</pitch>
              <tpc>{tpc}</tpc>
              </Note>
            </Chord>
          </voice>
        </Measure>"""


def generate_palette_mscx(
    title: str,
    voicings: list[dict],
    target_root: str = "C",
    num_strings: int = 6,
) -> str:
    """Generate a complete .mscx score with multiple measures, one per voicing."""

    if num_strings == 7:
        string_data_xml = """          <StringData>
            <frets>24</frets>
            <string>33</string>
            <string>40</string>
            <string>45</string>
            <string>50</string>
            <string>55</string>
            <string>59</string>
            <string>64</string>
            </StringData>"""
    else:
        string_data_xml = """          <StringData>
            <frets>24</frets>
            <string>40</string>
            <string>45</string>
            <string>50</string>
            <string>55</string>
            <string>59</string>
            <string>64</string>
            </StringData>"""

    # Build measures
    measures = []
    for i, v in enumerate(voicings):
        measures.append(generate_measure_xml(v, target_root, include_timesig=(i == 0)))

    measures_xml = "\n".join(measures)

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<museScore version="4.60">
  <programVersion>4.6.5</programVersion>
  <Score>
    <eid>{make_eid()}</eid>
    <Division>480</Division>
    <showInvisible>1</showInvisible>
    <showUnprintable>1</showUnprintable>
    <showFrames>1</showFrames>
    <showMargins>0</showMargins>
    <metaTag name="workTitle">{title}</metaTag>
    <metaTag name="arranger">Generated by Chord Library Plugin</metaTag>
    <Part id="1">
      <Staff>
        <eid>{make_eid()}</eid>
        <StaffType group="pitched">
          <name>stdNormal</name>
          </StaffType>
        </Staff>
      <trackName>Guitar</trackName>
      <Instrument id="electric-guitar">
        <longName>Electric Guitar</longName>
        <shortName>E.Guit.</shortName>
        <trackName>Electric Guitar</trackName>
        <transposeDiatonic>-7</transposeDiatonic>
        <transposeChromatic>-12</transposeChromatic>
{string_data_xml}
        <Channel name="open">
          <program value="27"/>
          </Channel>
        </Instrument>
      </Part>
    <Staff id="1">
      <VBox>
        <height>10</height>
        <eid>{make_eid()}</eid>
        <Text>
          <style>title</style>
          <eid>{make_eid()}</eid>
          <text>{title}</text>
          </Text>
        </VBox>
{measures_xml}
      </Staff>
    </Score>
  </museScore>
"""


def generate_palette_mscz(title: str, voicings: list[dict], target_root: str, num_strings: int, output_path: Path):
    """Generate a .mscz file for a palette group."""
    mscx = generate_palette_mscx(title, voicings, target_root, num_strings)
    score_name = output_path.stem

    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(f"{score_name}.mscx", mscx)
        zf.writestr(
            "META-INF/container.xml",
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            "<container><rootfiles>"
            f'<rootfile full-path="{score_name}.mscx"/>'
            "</rootfiles></container>\n",
        )


def main():
    parser = argparse.ArgumentParser(description="Generate grouped palette .mscz files")
    parser.add_argument("--root", default="C", help="Target root (default: C)")
    parser.add_argument("--context", help="Only generate for this context (CM6, CM7, CV6, CV7)")
    parser.add_argument("--category", help="Only generate for this category (shell, drop2, drop3, ...)")
    parser.add_argument("--output", "-o", default="palettes", help="Output directory")
    parser.add_argument(
        "--data",
        default=str(Path(__file__).parent.parent / "data" / "voicings.json"),
        help="Path to voicings.json",
    )
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)

    # Group voicings by (context, category)
    groups: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for v in data["voicings"]:
        key = (v["context"], v["category"])
        if args.context and v["context"] != args.context:
            continue
        if args.category and v["category"] != args.category:
            continue
        groups[key].append(v)

    if not groups:
        print("No voicings match the given filters.", file=sys.stderr)
        sys.exit(1)

    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Generating palette files in {out_dir}/ (root: {args.root})\n")

    for (context, category), voicings in sorted(groups.items()):
        cat_label = CATEGORY_LABELS.get(category, category)
        title = f"{context} — {cat_label}"

        # Determine string count from the voicings (all in a group should match)
        num_strings = voicings[0].get("strings", 6)

        # Sort by chord quality for consistent ordering
        quality_order = ["dom7", "maj7", "min7", "min7b5", "maj6", "min6", "dim7"]
        voicings.sort(key=lambda v: (
            quality_order.index(v["chord_quality"]) if v["chord_quality"] in quality_order else 99,
            v["id"],
        ))

        filename = f"{title}.mscz"
        out_file = out_dir / filename
        generate_palette_mscz(title, voicings, args.root, num_strings, out_file)
        print(f"  {filename:40s} ({len(voicings)} voicings)")

    print(f"\nGenerated {len(groups)} palette files.")


if __name__ == "__main__":
    main()
