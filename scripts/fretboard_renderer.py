#!/usr/bin/env python3
"""Render fretboard diagrams as SVG or PNG.

Produces clean, print-ready chord diagrams matching the plugin's interval
color scheme. Used by generate_chord_sheet.py for PDF chord reference sheets
and by export_diagrams.py for standalone image export.

Usage:
    # Render a single voicing from the library
    python fretboard_renderer.py --voicing c7-shell-e-shape-6 -o c7-shell.svg

    # Render all voicings matching a filter
    python fretboard_renderer.py --quality dom7 --context CV6 -o diagrams/

    # Render with custom size and no labels
    python fretboard_renderer.py --voicing c7-shell-e-shape-6 --width 200 --no-labels
"""

import argparse
import json
import math
import sys
from pathlib import Path

import svgwrite

REPO_ROOT = Path(__file__).resolve().parent.parent

# Interval color scheme (matches plugin's Canvas renderer)
INTERVAL_COLORS = {
    "1":    "#D32F2F",   # red — root
    "b3":   "#1565C0",   # blue — minor 3rd
    "3":    "#1565C0",   # blue — major 3rd
    "b5":   "#2E7D32",   # green — flat 5th
    "5":    "#2E7D32",   # green — 5th
    "#5":   "#2E7D32",   # green — sharp 5th
    "b7":   "#E65100",   # orange — minor 7th
    "7":    "#E65100",   # orange — major 7th
    "bb7":  "#E65100",   # orange — diminished 7th
    "b9":   "#7B1FA2",   # purple — flat 9th
    "9":    "#7B1FA2",   # purple — 9th
    "#9":   "#7B1FA2",   # purple — sharp 9th
    "4":    "#00838F",   # teal — 4th
    "#11":  "#00838F",   # teal — sharp 11th
    "6":    "#F9A825",   # gold — 6th
    "b13":  "#F9A825",   # gold — flat 13th
}
DEFAULT_DOT_COLOR = "#424242"  # grey fallback


def interval_color(interval: str) -> str:
    """Get the color for an interval label."""
    return INTERVAL_COLORS.get(interval, DEFAULT_DOT_COLOR)


CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
SEMITONE_MAP = {n: i for i, n in enumerate(CHROMATIC)}
SEMITONE_MAP.update({"C#": 1, "D#": 3, "F#": 6, "G#": 8, "A#": 10})


def _semitone_offset(src: str, tgt: str) -> int:
    """Calculate semitone offset from src to tgt root."""
    return (SEMITONE_MAP.get(tgt, 0) - SEMITONE_MAP.get(src, 0)) % 12


def render_fretboard_svg(
    voicing: dict,
    width: int = 160,
    show_labels: bool = True,
    show_title: bool = True,
    show_intervals: bool = True,
    show_notes: bool = False,
    target_root: str | None = None,
    display_name: str | None = None,
) -> svgwrite.Drawing:
    """Render a single fretboard diagram as an SVG Drawing.

    Args:
        voicing: voicing dict from voicings.json
        width: diagram width in pixels
        show_labels: show fret number label
        show_title: show chord name above diagram
        show_intervals: show interval labels inside dots
        show_notes: show note names inside dots (overrides intervals)
        target_root: if set, transpose fret_number for display
        display_name: if set, use this as the chord name instead of voicing name

    Returns:
        svgwrite.Drawing object (call .tostring() or .saveas())
    """
    num_strings = voicing.get("strings", 6)
    fret_number = voicing.get("fret_number", 1)
    visible_frets = voicing.get("visible_frets", 4)
    dots = voicing.get("dots", [])
    mutes = voicing.get("mutes", [])
    opens = voicing.get("open", [])
    intervals = voicing.get("intervals", [])
    notes = voicing.get("notes", [])
    name = display_name or voicing.get("name", "")

    # Transpose fret_number if target_root is specified
    if target_root and target_root != voicing.get("root", "C"):
        offset = _semitone_offset(voicing.get("root", "C"), target_root)
        fret_number = fret_number + offset

    # Layout constants (proportional to width)
    string_spacing = width / (num_strings + 1)
    fret_spacing = string_spacing * 1.3
    margin_top = 50 if show_title else 25
    margin_left = string_spacing * 1.5
    margin_bottom = 15
    nut_height = 4

    # Total dimensions
    grid_width = string_spacing * (num_strings - 1)
    grid_height = fret_spacing * visible_frets
    total_width = grid_width + margin_left + string_spacing
    total_height = margin_top + nut_height + grid_height + margin_bottom + 20

    dwg = svgwrite.Drawing(size=(f"{total_width}px", f"{total_height}px"))
    dwg.viewbox(0, 0, total_width, total_height)

    # Background
    dwg.add(dwg.rect(insert=(0, 0), size=(total_width, total_height),
                      fill="white", opacity=0))

    # Title (chord name)
    if show_title and name:
        # Use first part of name (before " — ")
        display_name = name.split(" — ")[0] if " — " in name else name
        dwg.add(dwg.text(
            display_name,
            insert=(total_width / 2, margin_top - 15),
            text_anchor="middle",
            font_size="14px",
            font_family="Arial, Helvetica, sans-serif",
            font_weight="bold",
            fill="#212121",
        ))

    # Nut (thick line at top if fret 1, or fret number label)
    nut_y = margin_top
    if fret_number <= 1:
        dwg.add(dwg.rect(
            insert=(margin_left, nut_y),
            size=(grid_width, nut_height),
            fill="#212121",
        ))
    else:
        # Thin line + fret number
        dwg.add(dwg.line(
            start=(margin_left, nut_y + nut_height / 2),
            end=(margin_left + grid_width, nut_y + nut_height / 2),
            stroke="#212121", stroke_width=1.5,
        ))
        if show_labels:
            dwg.add(dwg.text(
                str(fret_number),
                insert=(margin_left - 8, nut_y + fret_spacing * 0.6 + nut_height),
                text_anchor="end",
                font_size="11px",
                font_family="Arial, Helvetica, sans-serif",
                fill="#616161",
            ))

    grid_top = nut_y + nut_height

    # Fret lines (horizontal)
    for f in range(visible_frets + 1):
        y = grid_top + f * fret_spacing
        dwg.add(dwg.line(
            start=(margin_left, y),
            end=(margin_left + grid_width, y),
            stroke="#BDBDBD" if f > 0 else "#212121",
            stroke_width=1 if f > 0 else 1.5,
        ))

    # String lines (vertical)
    for s in range(num_strings):
        x = margin_left + s * string_spacing
        dwg.add(dwg.line(
            start=(x, grid_top),
            end=(x, grid_top + grid_height),
            stroke="#757575",
            stroke_width=1,
        ))

    # Muted strings (X above nut)
    for mute_str in mutes:
        # String numbering: 1=highest, so string 1 is rightmost
        s_idx = num_strings - mute_str
        x = margin_left + s_idx * string_spacing
        y = nut_y - 6
        size = 5
        dwg.add(dwg.line(
            start=(x - size, y - size), end=(x + size, y + size),
            stroke="#757575", stroke_width=1.5,
        ))
        dwg.add(dwg.line(
            start=(x + size, y - size), end=(x - size, y + size),
            stroke="#757575", stroke_width=1.5,
        ))

    # Open strings (O above nut)
    for open_str in opens:
        s_idx = num_strings - open_str
        x = margin_left + s_idx * string_spacing
        y = nut_y - 6
        dwg.add(dwg.circle(
            center=(x, y), r=5,
            stroke="#757575", stroke_width=1.5, fill="none",
        ))

    # Dots (filled circles on fretboard)
    dot_radius = string_spacing * 0.35
    for i, dot in enumerate(dots):
        s_idx = num_strings - dot["string"]
        x = margin_left + s_idx * string_spacing
        # Dot fret is relative to fret_number: fret 1 = first visible fret
        y = grid_top + (dot["fret"] - 0.5) * fret_spacing

        # Color by interval
        color = DEFAULT_DOT_COLOR
        if i < len(intervals):
            color = interval_color(intervals[i])

        dwg.add(dwg.circle(
            center=(x, y), r=dot_radius,
            fill=color, stroke="white", stroke_width=1,
        ))

        # Label inside dot
        if show_notes and i < len(notes):
            label = notes[i]
        elif show_intervals and i < len(intervals):
            label = intervals[i]
        else:
            label = None

        if label:
            font_size = max(7, min(10, dot_radius * 1.2))
            dwg.add(dwg.text(
                label,
                insert=(x, y + font_size * 0.35),
                text_anchor="middle",
                font_size=f"{font_size}px",
                font_family="Arial, Helvetica, sans-serif",
                font_weight="bold",
                fill="white",
            ))

    # Voicing type / category label below
    category = voicing.get("category", "")
    if show_title and category:
        cat_label = category.replace("drop2", "Drop 2").replace("drop3", "Drop 3").title()
        dwg.add(dwg.text(
            cat_label,
            insert=(total_width / 2, grid_top + grid_height + 15),
            text_anchor="middle",
            font_size="10px",
            font_family="Arial, Helvetica, sans-serif",
            fill="#757575",
        ))

    return dwg


def render_to_svg_string(voicing: dict, **kwargs) -> str:
    """Render a voicing to an SVG string."""
    dwg = render_fretboard_svg(voicing, **kwargs)
    return dwg.tostring()


def render_to_file(voicing: dict, path: Path, **kwargs) -> None:
    """Render a voicing to an SVG file."""
    dwg = render_fretboard_svg(voicing, **kwargs)
    dwg.saveas(str(path), pretty=True)


def main():
    parser = argparse.ArgumentParser(
        description="Render fretboard diagrams as SVG"
    )
    parser.add_argument("--voicing", help="Voicing ID to render")
    parser.add_argument("--quality", help="Filter by chord quality")
    parser.add_argument("--context", help="Filter by context")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--width", type=int, default=160, help="Diagram width (px)")
    parser.add_argument("--no-labels", action="store_true", help="Hide fret labels")
    parser.add_argument("--no-title", action="store_true", help="Hide chord name")
    parser.add_argument("--show-notes", action="store_true", help="Show note names instead of intervals")
    parser.add_argument("-o", "--output", type=Path, default=Path("."), help="Output file or directory")
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "plugin" / "data" / "voicings.json")
    args = parser.parse_args()

    with open(args.data) as f:
        all_voicings = json.load(f)["voicings"]

    # Filter
    voicings = all_voicings
    if args.voicing:
        voicings = [v for v in voicings if v["id"] == args.voicing]
        if not voicings:
            print(f"Voicing '{args.voicing}' not found", file=sys.stderr)
            sys.exit(1)
    else:
        if args.quality:
            voicings = [v for v in voicings if v["chord_quality"] == args.quality]
        if args.context:
            voicings = [v for v in voicings if v["context"] == args.context]
        if args.category:
            voicings = [v for v in voicings if v["category"] == args.category]

    if not voicings:
        print("No voicings match the filter", file=sys.stderr)
        sys.exit(1)

    render_kwargs = {
        "width": args.width,
        "show_labels": not args.no_labels,
        "show_title": not args.no_title,
        "show_notes": args.show_notes,
    }

    if len(voicings) == 1 and args.output.suffix in (".svg", ""):
        out = args.output if args.output.suffix == ".svg" else args.output / f"{voicings[0]['id']}.svg"
        out.parent.mkdir(parents=True, exist_ok=True)
        render_to_file(voicings[0], out, **render_kwargs)
        print(f"Saved {out}")
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for v in voicings:
            out = args.output / f"{v['id']}.svg"
            render_to_file(v, out, **render_kwargs)
        print(f"Saved {len(voicings)} diagrams to {args.output}/")


if __name__ == "__main__":
    main()
