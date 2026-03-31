#!/usr/bin/env python3
"""Generate print-ready PDF chord reference sheets.

Produces Neck Diagrams-style chord sheets: song metadata header,
fretboard diagrams in a grid, color-coded by interval, with chord
names, fret numbers, and mute/open markers.

Usage:
    # From a MuseScore file (extracts chord symbols)
    python generate_chord_sheet.py score.mscz -o chord-sheet.pdf

    # From the voicing library with filters
    python generate_chord_sheet.py --library data/voicings.json --quality dom7 -o dom7-sheet.pdf

    # All shell voicings
    python generate_chord_sheet.py --library data/voicings.json --category shell -o shells.pdf

    # Custom title and layout
    python generate_chord_sheet.py --library data/voicings.json --quality maj7 \
        --title "Major 7 Voicings" --cols 4 -o maj7.pdf

Requires: cairosvg (pip install cairosvg)
"""

import argparse
import io
import json
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from fretboard_svg import render_voicing_svg

# Page dimensions (US Letter in points, 72 pts/inch)
PAGE_W = 612
PAGE_H = 792
MARGIN = 36


def extract_chords_from_mscz(path: Path) -> list[str]:
    """Extract chord symbol text from a .mscz or .mscx file."""
    if path.suffix == ".mscz":
        with zipfile.ZipFile(path) as zf:
            mscx_names = [n for n in zf.namelist() if n.endswith(".mscx")]
            if not mscx_names:
                print(f"No .mscx found inside {path}", file=sys.stderr)
                return []
            content = zf.read(mscx_names[0]).decode("utf-8")
    else:
        content = path.read_text()

    root = ET.fromstring(content)
    chords = []
    # Search for Harmony elements
    for harmony in root.iter("Harmony"):
        # Get the text representation
        name_el = harmony.find("name")
        root_el = harmony.find("root")
        if name_el is not None and name_el.text:
            chords.append(name_el.text)
        elif root_el is not None:
            # Build from root + quality
            root_case = root_el.find("rootCase")
            chord_text = root_case.text if root_case is not None and root_case.text else ""
            chords.append(chord_text)

    # Also try text-based harmony
    for harmony in root.iter():
        if harmony.tag == "Harmony" or (hasattr(harmony, "get") and "Harmony" in harmony.tag):
            text = harmony.get("text", "")
            if text and text not in chords:
                chords.append(text)

    return list(dict.fromkeys(chords))  # deduplicate preserving order


def generate_pdf(
    voicings: list[dict],
    output: Path,
    title: str = "Chord Reference Sheet",
    subtitle: str = "",
    cols: int = 5,
    cell_w: int = 110,
    cell_h: int = 145,
):
    """Generate a multi-page PDF chord sheet."""
    try:
        import cairosvg
    except ImportError:
        print("PDF generation requires cairosvg: pip install cairosvg", file=sys.stderr)
        sys.exit(1)

    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.lib.units import inch
        from reportlab.pdfgen import canvas as rl_canvas
    except ImportError:
        print("PDF generation requires reportlab: pip install reportlab", file=sys.stderr)
        sys.exit(1)

    c = rl_canvas.Canvas(str(output), pagesize=letter)
    page_w, page_h = letter

    padding = 8
    usable_w = page_w - 2 * MARGIN
    usable_h = page_h - 2 * MARGIN

    # Header height
    header_h = 60 if title else 20

    # Calculate grid layout
    actual_cols = min(cols, int(usable_w / (cell_w + padding)))
    grid_w = actual_cols * (cell_w + padding)
    start_x = MARGIN + (usable_w - grid_w) / 2

    items_per_page = actual_cols * int((usable_h - header_h) / (cell_h + padding))

    page_num = 0
    item_idx = 0

    while item_idx < len(voicings):
        page_num += 1

        # Header (first page only, or every page)
        y_cursor = page_h - MARGIN

        if page_num == 1 and title:
            c.setFont("Helvetica-Bold", 18)
            c.drawCentredString(page_w / 2, y_cursor - 18, title)
            y_cursor -= 24
            if subtitle:
                c.setFont("Helvetica", 10)
                c.drawCentredString(page_w / 2, y_cursor - 12, subtitle)
                y_cursor -= 16
            y_cursor -= 20
        else:
            y_cursor -= 20

        # Grid of diagrams
        col = 0
        while item_idx < len(voicings) and y_cursor - cell_h > MARGIN:
            v = voicings[item_idx]

            # Render SVG
            svg_str = render_voicing_svg(
                v, width=cell_w, height=cell_h,
                show_notes=False, show_intervals=True,
            )

            # Convert SVG to PNG in memory
            png_data = cairosvg.svg2png(
                bytestring=svg_str.encode("utf-8"),
                dpi=200,
            )

            # Draw on PDF
            from reportlab.lib.utils import ImageReader
            img = ImageReader(io.BytesIO(png_data))
            x = start_x + col * (cell_w + padding)
            y = y_cursor - cell_h

            c.drawImage(img, x, y, width=cell_w, height=cell_h)

            col += 1
            item_idx += 1

            if col >= actual_cols:
                col = 0
                y_cursor -= (cell_h + padding)

        # Page footer
        c.setFont("Helvetica", 7)
        c.setFillColorRGB(0.5, 0.5, 0.5)
        c.drawCentredString(page_w / 2, MARGIN - 10, f"Page {page_num}")
        c.setFillColorRGB(0, 0, 0)

        if item_idx < len(voicings):
            c.showPage()

    c.save()
    print(f"Saved {page_num}-page PDF with {len(voicings)} diagrams to {output}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate print-ready PDF chord reference sheets"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("score", nargs="?", type=Path, help="MuseScore file (.mscz/.mscx)")
    group.add_argument("--library", type=Path, help="Voicings JSON file")

    parser.add_argument("--quality", help="Filter by chord quality")
    parser.add_argument("--context", help="Filter by context")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--title", help="Sheet title")
    parser.add_argument("--subtitle", help="Sheet subtitle (composer, key, etc.)")
    parser.add_argument("--cols", type=int, default=5, help="Diagrams per row (default: 5)")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output PDF path")
    args = parser.parse_args()

    if args.score:
        # Extract chords from score and match to library
        chords = extract_chords_from_mscz(args.score)
        if not chords:
            print(f"No chord symbols found in {args.score}", file=sys.stderr)
            sys.exit(1)

        print(f"Found {len(chords)} unique chords: {', '.join(chords)}")

        # Load library and find matching voicings
        lib_path = REPO_ROOT / "data" / "voicings.json"
        with open(lib_path) as f:
            library = json.load(f)["voicings"]

        # Simple matching: for each chord, find voicings by quality
        # TODO: proper chord symbol parsing with root transposition
        matched = []
        for v in library:
            if v.get("context") in ("CV6", "CM6"):  # prefer 6-string
                matched.append(v)

        title = args.title or args.score.stem
        generate_pdf(matched[:50], args.output, title=title, subtitle=args.subtitle or "", cols=args.cols)

    elif args.library:
        with open(args.library) as f:
            data = json.load(f)
        voicings = data.get("voicings", [])

        if args.quality:
            voicings = [v for v in voicings if v.get("chord_quality") == args.quality]
        if args.context:
            voicings = [v for v in voicings if v.get("context") == args.context]
        if args.category:
            voicings = [v for v in voicings if v.get("category") == args.category]

        if not voicings:
            print("No voicings match the filter", file=sys.stderr)
            sys.exit(1)

        title = args.title or "Chord Reference Sheet"
        subtitle = args.subtitle or f"{len(voicings)} voicings"

        generate_pdf(voicings, args.output, title=title, subtitle=subtitle, cols=args.cols)


if __name__ == "__main__":
    main()
