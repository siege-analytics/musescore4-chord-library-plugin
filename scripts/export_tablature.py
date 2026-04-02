#!/usr/bin/env python3
"""Export the voicing library as ASCII guitar tablature.

Generates human-readable tablature for voicings in the chord library.
Supports filtering by quality, context, and category, transposition to
any root, and output in plain text or Markdown format.

Usage:
    python export_tablature.py                           # all voicings, plain text
    python export_tablature.py --quality dom7            # only dom7 voicings
    python export_tablature.py --root G --format markdown -o voicings.md
    python export_tablature.py --context CV6 --category shell
    python export_tablature.py --tuning 7string-low-b    # 7-string tuning
    python export_tablature.py --compact                 # single-line format
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATA = REPO_ROOT / "data" / "voicings.json"
TUNINGS_DIR = REPO_ROOT / "config" / "tunings"

ROOTS = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

SEMITONE_MAP = {
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
    "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
    "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11,
}

NOTE_NAMES_FLAT = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


# ---------------------------------------------------------------------------
# Tuning helpers
# ---------------------------------------------------------------------------

def load_tuning(tuning_name: str) -> dict:
    """Load a tuning configuration from config/tunings/."""
    path = TUNINGS_DIR / f"{tuning_name}.json"
    if not path.exists():
        print(f"Error: tuning file not found: {path}", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        return json.load(f)


def string_labels(tuning: dict) -> list[str]:
    """Return display labels for each string, ordered from string 1 (highest) to N.

    Strips the octave number from the note name (e.g. "E4" -> "e", "E2" -> "E").
    The highest string is shown lowercase by convention.
    """
    notes = tuning["notes"]
    num_strings = len(notes)
    labels = []
    for i in range(1, num_strings + 1):
        note_with_octave = notes[str(i)]
        # Strip trailing digit(s) for the octave
        note = re.sub(r"\d+$", "", note_with_octave)
        # Convention: highest string label is lowercase
        if i == 1:
            labels.append(note.lower())
        else:
            labels.append(note)
    return labels


# ---------------------------------------------------------------------------
# Transposition
# ---------------------------------------------------------------------------

def semitone_offset(source: str, target: str) -> int:
    return (SEMITONE_MAP[target] - SEMITONE_MAP[source]) % 12


def transpose_name(name: str, target_root: str) -> str:
    """Replace leading C in voicing name with target root."""
    if target_root == "C":
        return name
    return re.sub(r"^C(?=[^a-z]|maj|min|dim|aug|sus|m[^a-z]|$)", target_root, name)


# ---------------------------------------------------------------------------
# Voicing -> fret array
# ---------------------------------------------------------------------------

def voicing_to_fret_array(voicing: dict, offset: int = 0) -> list:
    """Convert a voicing dict to a per-string fret array.

    Returns a list indexed by string number (1-based), where:
      - int >= 0 means that fret is played (0 = open)
      - None means the string is muted / not played

    The array has length num_strings + 1 so index 1..num_strings are valid.
    """
    num_strings = voicing.get("strings", 6)
    frets = [None] * (num_strings + 1)  # index 0 unused

    for dot in voicing.get("dots", []):
        s = dot["string"]
        if 1 <= s <= num_strings:
            absolute_fret = voicing["fret_number"] + (dot["fret"] - 1) + offset
            frets[s] = absolute_fret

    for open_str in voicing.get("open", []):
        if 1 <= open_str <= num_strings:
            frets[open_str] = 0

    return frets


# ---------------------------------------------------------------------------
# ASCII tablature rendering
# ---------------------------------------------------------------------------

def render_diagram(voicing: dict, labels: list[str], offset: int = 0,
                   target_root: str = "C") -> str:
    """Render a multi-line ASCII tab diagram for one voicing.

    Example output:
        Cmaj7 — E shape — Shell
        e|---|---|---|---|
        B|---|---|---|-9-|
        G|---|---|---|-9-|
        D|---|---|---|---|
        A|---|---|---|---|
        E|---|---|---|-8-|
    """
    num_strings = voicing.get("strings", 6)
    frets = voicing_to_fret_array(voicing, offset)
    visible = voicing.get("visible_frets", 4)
    start_fret = voicing["fret_number"] + offset

    # Title line
    chord_name = transpose_name(voicing["name"].split(" — ")[0], target_root)
    parts = voicing["name"].split(" — ")
    subtitle_parts = parts[1:] if len(parts) > 1 else []
    title = " — ".join([chord_name] + subtitle_parts)

    # Determine label width for alignment
    label_width = max(len(lbl) for lbl in labels[:num_strings])

    lines = [title]
    for i in range(1, num_strings + 1):
        lbl = labels[i - 1] if i <= len(labels) else str(i)
        padded_label = lbl.rjust(label_width)

        cells = []
        fret_val = frets[i]
        for f_offset in range(visible):
            fret_pos = start_fret + f_offset
            if fret_val is not None and fret_val == fret_pos:
                fret_str = str(fret_val)
                cell = f"-{fret_str}-" if len(fret_str) == 1 else f"-{fret_str}"
            else:
                cell = "---"
            cells.append(cell)

        # Build the string line
        if fret_val is None:
            # Muted string — show X at start then dashes
            line = padded_label + "|" + "-X-" + "|---" * (visible - 1) + "|"
        elif fret_val == 0:
            # Open string — show 0 at start then dashes
            line = padded_label + "|" + "-0-" + "|---" * (visible - 1) + "|"
        else:
            segments = []
            for f_offset in range(visible):
                fret_pos = start_fret + f_offset
                if fret_val == fret_pos:
                    fret_str = str(fret_val)
                    if len(fret_str) == 1:
                        segments.append(f"-{fret_str}-")
                    else:
                        segments.append(f"-{fret_str}")
                else:
                    segments.append("---")
            line = padded_label + "|" + "|".join(segments) + "|"

        lines.append(line)

    return "\n".join(lines)


def render_compact(voicing: dict, offset: int = 0,
                   target_root: str = "C") -> str:
    """Render a single-line compact tab representation.

    Example: Cmaj7 — E shape — Shell: x-x-8-x-9-9 (fret 8)
    """
    num_strings = voicing.get("strings", 6)
    frets = voicing_to_fret_array(voicing, offset)
    start_fret = voicing["fret_number"] + offset

    chord_name = transpose_name(voicing["name"].split(" — ")[0], target_root)
    parts = voicing["name"].split(" — ")
    subtitle_parts = parts[1:] if len(parts) > 1 else []
    title = " — ".join([chord_name] + subtitle_parts)

    # Build fret string from low to high (string N..1)
    fret_strs = []
    for i in range(num_strings, 0, -1):
        val = frets[i]
        if val is None:
            fret_strs.append("x")
        else:
            fret_strs.append(str(val))

    tab_str = "-".join(fret_strs)
    return f"{title}: {tab_str} (fret {start_fret})"


# ---------------------------------------------------------------------------
# Grouping and filtering
# ---------------------------------------------------------------------------

def filter_voicings(voicings: list[dict], *,
                    quality: str | None = None,
                    context: str | None = None,
                    category: str | None = None) -> list[dict]:
    """Filter voicings by optional criteria."""
    result = voicings
    if quality:
        result = [v for v in result if v.get("chord_quality") == quality]
    if context:
        result = [v for v in result
                  if v.get("context") == context
                  or context in v.get("also_contexts", [])]
    if category:
        result = [v for v in result if v.get("category") == category]
    return result


def group_voicings(voicings: list[dict],
                   group_by: str) -> dict[str, list[dict]]:
    """Group voicings by a field name (quality, context, category)."""
    field_map = {
        "quality": "chord_quality",
        "context": "context",
        "category": "category",
    }
    field = field_map.get(group_by, group_by)
    groups: dict[str, list[dict]] = {}
    for v in voicings:
        key = v.get(field, "unknown")
        groups.setdefault(key, []).append(v)
    return groups


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def format_text(voicings: list[dict], labels: list[str], *,
                compact: bool = False,
                group_by: str | None = None,
                offset: int = 0,
                target_root: str = "C") -> str:
    """Format voicings as plain text."""
    sections = []

    if group_by:
        groups = group_voicings(voicings, group_by)
        for group_name, group_voicings_list in sorted(groups.items()):
            section_lines = [f"=== {group_name} ===", ""]
            for v in group_voicings_list:
                if compact:
                    section_lines.append(render_compact(v, offset, target_root))
                else:
                    section_lines.append(render_diagram(v, labels, offset, target_root))
                    section_lines.append("")
            sections.append("\n".join(section_lines))
    else:
        for v in voicings:
            if compact:
                sections.append(render_compact(v, offset, target_root))
            else:
                sections.append(render_diagram(v, labels, offset, target_root))

    separator = "\n" if compact else "\n\n"
    return separator.join(sections) + "\n"


def format_markdown(voicings: list[dict], labels: list[str], *,
                    compact: bool = False,
                    group_by: str | None = None,
                    offset: int = 0,
                    target_root: str = "C") -> str:
    """Format voicings as Markdown."""
    sections = [f"# Guitar Tablature — Root: {target_root}", ""]

    if group_by:
        groups = group_voicings(voicings, group_by)
        for group_name, group_voicings_list in sorted(groups.items()):
            sections.append(f"## {group_name}")
            sections.append("")
            for v in group_voicings_list:
                if compact:
                    sections.append(f"- `{render_compact(v, offset, target_root)}`")
                else:
                    sections.append(f"### {transpose_name(v['name'].split(' — ')[0], target_root)}")
                    sections.append("")
                    sections.append("```")
                    sections.append(render_diagram(v, labels, offset, target_root))
                    sections.append("```")
                    sections.append("")
    else:
        for v in voicings:
            if compact:
                sections.append(f"- `{render_compact(v, offset, target_root)}`")
            else:
                sections.append(f"### {transpose_name(v['name'].split(' — ')[0], target_root)}")
                sections.append("")
                sections.append("```")
                sections.append(render_diagram(v, labels, offset, target_root))
                sections.append("```")
                sections.append("")

    return "\n".join(sections) + "\n"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Export voicing library as ASCII guitar tablature.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument("--data", type=Path, default=DEFAULT_DATA,
                   help="Path to voicings.json (default: %(default)s)")
    p.add_argument("--tuning", default="standard",
                   help="Tuning name from config/tunings/ (default: standard)")
    p.add_argument("--root", default="C", choices=ROOTS,
                   help="Transpose all voicings to this root (default: C)")
    p.add_argument("--quality",
                   help="Filter by chord quality (e.g. dom7, maj7, min7)")
    p.add_argument("--context",
                   help="Filter by context (e.g. CV6, CM7)")
    p.add_argument("--category",
                   help="Filter by category (e.g. shell, drop2, altered)")
    p.add_argument("--group-by", choices=["quality", "context", "category"],
                   help="Group output by a field")
    p.add_argument("--compact", action="store_true",
                   help="Use single-line compact format instead of diagrams")
    p.add_argument("--format", dest="fmt", choices=["text", "markdown"],
                   default="text",
                   help="Output format (default: text)")
    p.add_argument("-o", "--output", type=Path,
                   help="Output file path (default: stdout)")
    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    # Load voicings
    if not args.data.exists():
        print(f"Error: voicings file not found: {args.data}", file=sys.stderr)
        sys.exit(1)
    with open(args.data) as f:
        data = json.load(f)
    voicings = data.get("voicings", [])

    # Load tuning
    tuning = load_tuning(args.tuning)
    labels = string_labels(tuning)

    # Filter
    voicings = filter_voicings(
        voicings,
        quality=args.quality,
        context=args.context,
        category=args.category,
    )

    if not voicings:
        print("No voicings match the given filters.", file=sys.stderr)
        sys.exit(0)

    # Compute transposition offset
    offset = semitone_offset("C", args.root)

    # Render
    if args.fmt == "markdown":
        output = format_markdown(
            voicings, labels,
            compact=args.compact,
            group_by=args.group_by,
            offset=offset,
            target_root=args.root,
        )
    else:
        output = format_text(
            voicings, labels,
            compact=args.compact,
            group_by=args.group_by,
            offset=offset,
            target_root=args.root,
        )

    # Write
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
        print(f"Wrote {len(voicings)} voicing(s) to {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
