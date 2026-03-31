#!/usr/bin/env python3
"""Render fretboard diagrams as SVG.

Produces clean, print-ready fretboard diagrams matching the plugin's
interval color scheme. Used by generate_chord_sheet.py and
export_diagrams.py.

Usage as a library:
    from fretboard_svg import render_voicing_svg
    svg = render_voicing_svg(voicing, title="Cmaj7", width=120, height=160)

Usage as a CLI:
    python fretboard_svg.py data/voicings.json --id c7-shell-e-shape-6 -o diagram.svg
    python fretboard_svg.py data/voicings.json --all -o diagrams/
"""

import argparse
import json
import math
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO_ROOT = Path(__file__).resolve().parent.parent

# Interval color scheme (matches plugin, light mode for print)
INTERVAL_COLORS = {
    "1":    "#D32F2F",  # root — red
    "3":    "#1976D2",  # major 3rd — blue
    "b3":   "#1976D2",  # minor 3rd — blue
    "5":    "#388E3C",  # 5th — green
    "b5":   "#388E3C",  # b5 — green
    "#5":   "#388E3C",  # #5 — green
    "7":    "#F57C00",  # major 7th — orange
    "b7":   "#F57C00",  # minor 7th — orange
    "bb7":  "#F57C00",  # diminished 7th — orange
    "6":    "#FBC02D",  # 6th — gold
    "13":   "#FBC02D",  # 13th — gold
    "b13":  "#FBC02D",  # b13 — gold
    "9":    "#7B1FA2",  # 9th — purple
    "b9":   "#7B1FA2",  # b9 — purple
    "#9":   "#7B1FA2",  # #9 — purple
    "2":    "#7B1FA2",  # 2nd (= 9th) — purple
    "4":    "#00897B",  # 4th — teal
    "11":   "#00897B",  # 11th — teal
    "#11":  "#00897B",  # #11 — teal
}
DEFAULT_DOT_COLOR = "#555555"
GRID_COLOR = "#888888"
TEXT_COLOR = "#333333"
MUTE_COLOR = "#666666"
BG_COLOR = "#FFFFFF"


def render_voicing_svg(
    voicing: dict,
    title: str | None = None,
    width: int = 120,
    height: int = 160,
    show_notes: bool = False,
    show_fingers: bool = False,
    show_intervals: bool = True,
    bg_color: str | None = BG_COLOR,
) -> str:
    """Render a single voicing as an SVG string."""
    ns = voicing.get("strings", 6)
    nf = voicing.get("visible_frets", 4)
    fret_num = voicing.get("fret_number", 1)
    dots = voicing.get("dots", [])
    mutes = voicing.get("mutes", [])
    opens = voicing.get("open", [])
    intervals = voicing.get("intervals", [])
    notes = voicing.get("notes", [])

    if title is None:
        title = voicing.get("name", "")

    # Layout dimensions
    title_h = 22 if title else 0
    marker_h = 14  # space for mute/open markers above nut
    fret_label_w = 18  # space for fret number on the left
    margin = 8
    bottom_margin = 18 if show_notes else 8

    grid_left = margin + fret_label_w
    grid_top = margin + title_h + marker_h
    grid_w = width - grid_left - margin
    grid_h = height - grid_top - bottom_margin

    string_spacing = grid_w / (ns - 1) if ns > 1 else grid_w
    fret_spacing = grid_h / nf

    dot_r = min(string_spacing, fret_spacing) * 0.32
    dot_r = max(dot_r, 4)
    dot_r = min(dot_r, 8)

    # Build SVG
    svg = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "width": str(width),
        "height": str(height),
        "viewBox": f"0 0 {width} {height}",
    })

    # Background
    if bg_color:
        ET.SubElement(svg, "rect", {
            "width": str(width), "height": str(height),
            "fill": bg_color, "rx": "4",
        })

    # Title
    if title:
        # Truncate if too long
        display_title = title if len(title) <= 20 else title[:18] + "…"
        t = ET.SubElement(svg, "text", {
            "x": str(width / 2), "y": str(margin + 14),
            "text-anchor": "middle",
            "font-family": "Helvetica, Arial, sans-serif",
            "font-size": "11", "font-weight": "bold",
            "fill": TEXT_COLOR,
        })
        t.text = display_title

    # Nut (thick line at top if open position)
    nut_y = grid_top
    if fret_num <= 1:
        ET.SubElement(svg, "line", {
            "x1": str(grid_left), "y1": str(nut_y),
            "x2": str(grid_left + grid_w), "y2": str(nut_y),
            "stroke": TEXT_COLOR, "stroke-width": "3",
            "stroke-linecap": "round",
        })

    # Fret lines
    for f in range(nf + 1):
        fy = grid_top + f * fret_spacing
        lw = "0.8"
        ET.SubElement(svg, "line", {
            "x1": str(grid_left), "y1": str(fy),
            "x2": str(grid_left + grid_w), "y2": str(fy),
            "stroke": GRID_COLOR, "stroke-width": lw,
        })

    # String lines
    for s in range(ns):
        sx = grid_left + s * string_spacing
        ET.SubElement(svg, "line", {
            "x1": str(sx), "y1": str(grid_top),
            "x2": str(sx), "y2": str(grid_top + grid_h),
            "stroke": GRID_COLOR, "stroke-width": "0.8",
        })

    # Fret number label
    if fret_num > 1:
        t = ET.SubElement(svg, "text", {
            "x": str(grid_left - 4),
            "y": str(grid_top + fret_spacing * 0.65),
            "text-anchor": "end",
            "font-family": "Helvetica, Arial, sans-serif",
            "font-size": "9",
            "fill": TEXT_COLOR,
        })
        t.text = str(fret_num)

    # Dots (color-coded by interval)
    for d_idx, dot in enumerate(dots):
        iv = intervals[d_idx] if d_idx < len(intervals) else ""
        color = INTERVAL_COLORS.get(iv, DEFAULT_DOT_COLOR)

        # String position: string 1 = rightmost (high e), string 6 = leftmost (low E)
        dx = grid_left + (ns - dot["string"]) * string_spacing
        dy = grid_top + (dot["fret"] - 0.5) * fret_spacing

        ET.SubElement(svg, "circle", {
            "cx": str(dx), "cy": str(dy), "r": str(dot_r),
            "fill": color,
        })

        # Interval label inside dot (if enabled and dot is big enough)
        if show_intervals and iv and dot_r >= 5:
            label = iv
            font_size = str(max(6, min(8, int(dot_r * 1.2))))
            lt = ET.SubElement(svg, "text", {
                "x": str(dx), "y": str(dy + 3),
                "text-anchor": "middle",
                "font-family": "Helvetica, Arial, sans-serif",
                "font-size": font_size, "font-weight": "bold",
                "fill": "#FFFFFF",
            })
            lt.text = label

    # Mute markers (×) above nut
    for m in mutes:
        mx = grid_left + (ns - m) * string_spacing
        my = grid_top - 3
        t = ET.SubElement(svg, "text", {
            "x": str(mx), "y": str(my),
            "text-anchor": "middle",
            "font-family": "Helvetica, Arial, sans-serif",
            "font-size": "10",
            "fill": MUTE_COLOR,
        })
        t.text = "×"

    # Open markers (○) above nut
    for o in opens:
        ox = grid_left + (ns - o) * string_spacing
        oy = grid_top - 5
        ET.SubElement(svg, "circle", {
            "cx": str(ox), "cy": str(oy), "r": "3.5",
            "fill": "none", "stroke": MUTE_COLOR, "stroke-width": "1.2",
        })

    # Note names below grid
    if show_notes and notes:
        note_idx = 0
        # Notes correspond to dots + opens, lowest string first
        all_sounding = []
        for dot in dots:
            all_sounding.append(dot["string"])
        for o in opens:
            all_sounding.append(o)

        for d_idx, dot in enumerate(dots):
            if d_idx < len(notes):
                nx = grid_left + (ns - dot["string"]) * string_spacing
                ny = grid_top + grid_h + 12
                nt = ET.SubElement(svg, "text", {
                    "x": str(nx), "y": str(ny),
                    "text-anchor": "middle",
                    "font-family": "Helvetica, Arial, sans-serif",
                    "font-size": "7",
                    "fill": TEXT_COLOR,
                })
                nt.text = notes[d_idx]

    # Serialize
    ET.indent(svg, space="  ")
    return ET.tostring(svg, encoding="unicode", xml_declaration=False)


def render_voicing_grid_svg(
    voicings: list[dict],
    title: str = "",
    cols: int = 5,
    cell_w: int = 120,
    cell_h: int = 160,
    padding: int = 10,
    **kwargs,
) -> str:
    """Render multiple voicings as a grid SVG."""
    n = len(voicings)
    rows = math.ceil(n / cols)

    header_h = 40 if title else 10
    total_w = cols * (cell_w + padding) + padding
    total_h = header_h + rows * (cell_h + padding) + padding

    svg = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "width": str(total_w),
        "height": str(total_h),
        "viewBox": f"0 0 {total_w} {total_h}",
    })

    # White background
    ET.SubElement(svg, "rect", {
        "width": str(total_w), "height": str(total_h),
        "fill": BG_COLOR,
    })

    # Title
    if title:
        t = ET.SubElement(svg, "text", {
            "x": str(total_w / 2), "y": "28",
            "text-anchor": "middle",
            "font-family": "Helvetica, Arial, sans-serif",
            "font-size": "18", "font-weight": "bold",
            "fill": TEXT_COLOR,
        })
        t.text = title

    # Render each voicing as a nested SVG
    for i, v in enumerate(voicings):
        row = i // cols
        col = i % cols
        x = padding + col * (cell_w + padding)
        y = header_h + row * (cell_h + padding)

        cell_svg_str = render_voicing_svg(v, width=cell_w, height=cell_h, **kwargs)
        cell_svg = ET.fromstring(cell_svg_str)

        g = ET.SubElement(svg, "g", {"transform": f"translate({x},{y})"})
        for child in cell_svg:
            g.append(child)

    ET.indent(svg, space="  ")
    return ET.tostring(svg, encoding="unicode", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description="Render fretboard diagrams as SVG")
    parser.add_argument("data", type=Path, help="Path to voicings.json")
    parser.add_argument("--id", help="Voicing ID to render")
    parser.add_argument("--all", action="store_true", help="Render all voicings as a grid")
    parser.add_argument("--quality", help="Filter by chord quality")
    parser.add_argument("--context", help="Filter by context (CV6, CM6, etc.)")
    parser.add_argument("--category", help="Filter by category (shell, drop2, etc.)")
    parser.add_argument("--cols", type=int, default=5, help="Columns in grid layout")
    parser.add_argument("--width", type=int, default=120, help="Cell width")
    parser.add_argument("--height", type=int, default=160, help="Cell height")
    parser.add_argument("--notes", action="store_true", help="Show note names below diagram")
    parser.add_argument("--intervals", action="store_true", default=True, help="Show intervals in dots")
    parser.add_argument("--no-intervals", action="store_false", dest="intervals")
    parser.add_argument("--title", help="Grid title")
    parser.add_argument("-o", "--output", type=Path, help="Output file or directory")
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)
    voicings = data.get("voicings", data if isinstance(data, list) else [])

    if args.id:
        matches = [v for v in voicings if v["id"] == args.id]
        if not matches:
            print(f"Voicing '{args.id}' not found", file=sys.stderr)
            sys.exit(1)
        v = matches[0]
        svg = render_voicing_svg(
            v, width=args.width, height=args.height,
            show_notes=args.notes, show_intervals=args.intervals,
        )
        if args.output:
            args.output.write_text(svg)
            print(f"Saved to {args.output}")
        else:
            print(svg)

    elif args.all or args.quality or args.context or args.category:
        filtered = voicings
        if args.quality:
            filtered = [v for v in filtered if v.get("chord_quality") == args.quality]
        if args.context:
            filtered = [v for v in filtered if v.get("context") == args.context]
        if args.category:
            filtered = [v for v in filtered if v.get("category") == args.category]

        if not filtered:
            print("No voicings match the filter", file=sys.stderr)
            sys.exit(1)

        if args.output and args.output.suffix == "":
            # Output is a directory — render individual SVGs
            args.output.mkdir(parents=True, exist_ok=True)
            for v in filtered:
                svg = render_voicing_svg(
                    v, width=args.width, height=args.height,
                    show_notes=args.notes, show_intervals=args.intervals,
                )
                out_file = args.output / f"{v['id']}.svg"
                out_file.write_text(svg)
            print(f"Saved {len(filtered)} diagrams to {args.output}/")
        else:
            # Render as grid
            grid_title = args.title or f"Chord Library ({len(filtered)} voicings)"
            svg = render_voicing_grid_svg(
                filtered, title=grid_title, cols=args.cols,
                cell_w=args.width, cell_h=args.height,
                show_notes=args.notes, show_intervals=args.intervals,
            )
            if args.output:
                args.output.write_text(svg)
                print(f"Saved grid to {args.output}")
            else:
                print(svg)

    else:
        parser.error("Specify --id, --all, or a filter (--quality, --context, --category)")


if __name__ == "__main__":
    main()
