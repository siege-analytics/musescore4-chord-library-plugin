#!/usr/bin/env python3
"""Export fretboard diagrams as SVG or PNG files.

Usage:
    # Single voicing
    python export_diagrams.py data/voicings.json --id c7-shell-e-shape-7 -o diagram.svg

    # All shell voicings for CV6 as individual SVGs
    python export_diagrams.py data/voicings.json --context CV6 --category shell -o exports/

    # Grid of all dom7 voicings as PNG
    python export_diagrams.py data/voicings.json --quality dom7 --png -o dom7-grid.png

    # All voicings matching a filter as individual PNGs
    python export_diagrams.py data/voicings.json --quality maj7 --context CV6 --png --dpi 300 -o exports/

PNG output requires cairosvg: pip install cairosvg
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from fretboard_svg import render_voicing_grid_svg, render_voicing_svg


def svg_to_png(svg_str: str, output_path: Path, dpi: int = 150):
    """Convert SVG string to PNG file."""
    try:
        import cairosvg
    except ImportError:
        print("PNG export requires cairosvg: pip install cairosvg", file=sys.stderr)
        sys.exit(1)
    cairosvg.svg2png(bytestring=svg_str.encode("utf-8"), write_to=str(output_path), dpi=dpi)


def main():
    parser = argparse.ArgumentParser(description="Export fretboard diagrams as SVG or PNG")
    parser.add_argument("data", type=Path, help="Path to voicings.json")
    parser.add_argument("--id", help="Single voicing ID")
    parser.add_argument("--quality", help="Filter by chord quality")
    parser.add_argument("--context", help="Filter by context")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--png", action="store_true", help="Export as PNG instead of SVG")
    parser.add_argument("--dpi", type=int, default=150, help="PNG resolution (default: 150)")
    parser.add_argument("--width", type=int, default=140, help="Diagram width in px")
    parser.add_argument("--height", type=int, default=180, help="Diagram height in px")
    parser.add_argument("--cols", type=int, default=5, help="Grid columns")
    parser.add_argument("--notes", action="store_true", help="Show note names")
    parser.add_argument("--no-intervals", action="store_true", help="Hide interval labels")
    parser.add_argument("--transparent", action="store_true", help="Transparent background")
    parser.add_argument("--title", help="Grid title")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output file or directory")
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)
    voicings = data.get("voicings", [])

    ext = ".png" if args.png else ".svg"
    bg = None if args.transparent else "#FFFFFF"
    show_intervals = not args.no_intervals

    if args.id:
        matches = [v for v in voicings if v["id"] == args.id]
        if not matches:
            print(f"Voicing '{args.id}' not found", file=sys.stderr)
            sys.exit(1)
        svg = render_voicing_svg(
            matches[0], width=args.width, height=args.height,
            show_notes=args.notes, show_intervals=show_intervals, bg_color=bg,
        )
        if args.png:
            svg_to_png(svg, args.output, args.dpi)
        else:
            args.output.write_text(svg)
        print(f"Saved to {args.output}")
        return

    # Apply filters
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

    # If output has no extension, treat as directory → individual files
    if args.output.suffix == "":
        args.output.mkdir(parents=True, exist_ok=True)
        for v in filtered:
            svg = render_voicing_svg(
                v, width=args.width, height=args.height,
                show_notes=args.notes, show_intervals=show_intervals, bg_color=bg,
            )
            out = args.output / f"{v['id']}{ext}"
            if args.png:
                svg_to_png(svg, out, args.dpi)
            else:
                out.write_text(svg)
        print(f"Exported {len(filtered)} diagrams to {args.output}/")
    else:
        # Render as grid
        grid_title = args.title or f"Chord Library ({len(filtered)} voicings)"
        svg = render_voicing_grid_svg(
            filtered, title=grid_title, cols=args.cols,
            cell_w=args.width, cell_h=args.height,
            show_notes=args.notes, show_intervals=show_intervals, bg_color=bg,
        )
        if args.png:
            svg_to_png(svg, args.output, args.dpi)
        else:
            args.output.write_text(svg)
        print(f"Saved to {args.output}")


if __name__ == "__main__":
    main()
