#!/usr/bin/env python3
"""Generate print-ready PDF chord reference sheets.

Produces Neck Diagrams-style chord sheets: a header with song metadata,
followed by a grid of fretboard diagrams for each chord used. Reads chord
symbols from a MuseScore file (.mscx/.mscz) or takes a list of voicing IDs.

Usage:
    # From a MuseScore file (extracts chord symbols, matches to library voicings)
    python generate_chord_sheet.py arrangement.mscz -o chord-sheet.pdf

    # From a list of voicing IDs
    python generate_chord_sheet.py --voicings c7-shell-e-shape-6,cmaj7-drop2-a-shape-6

    # All voicings matching a filter
    python generate_chord_sheet.py --quality dom7 --context CV6 -o dom7-comping.pdf

    # Custom title and metadata
    python generate_chord_sheet.py arrangement.mscz --title "Autumn Leaves" --key Gm
"""

import argparse
import io
import json
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from fretboard_renderer import render_fretboard_svg


def extract_chords_from_mscx(mscx_path):
    """Extract song metadata and chord symbols from a MuseScore file."""
    if mscx_path.suffix == ".mscz":
        with zipfile.ZipFile(mscx_path) as zf:
            mscx_names = [n for n in zf.namelist() if n.endswith(".mscx")]
            if not mscx_names:
                raise ValueError(f"No .mscx file found inside {mscx_path}")
            xml_data = zf.read(mscx_names[0])
            root = ET.fromstring(xml_data)
    else:
        tree = ET.parse(str(mscx_path))
        root = tree.getroot()

    title = ""
    composer = ""
    for meta in root.iter("metaTag"):
        name = meta.get("name", "")
        if name == "workTitle":
            title = meta.text or ""
        elif name == "composer":
            composer = meta.text or ""

    chords = []
    seen = set()
    for harmony in root.iter("Harmony"):
        chord_text = None
        root_elem = harmony.find("root")
        name_elem = harmony.find("name")

        if root_elem is not None:
            root_val = int(root_elem.text or "0")
            chromatic = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
            chord_root = chromatic[root_val % 12]
            suffix = ""
            if name_elem is not None:
                suffix = name_elem.text or ""
            chord_text = chord_root + suffix
        else:
            text = harmony.text or harmony.get("text", "")
            if text:
                chord_text = text

        if chord_text and chord_text not in seen:
            chords.append(chord_text)
            seen.add(chord_text)

    return {"title": title, "composer": composer, "chords": chords}


def match_chord_to_voicings(chord_text, voicings, context="CV6"):
    """Find voicings that match a chord symbol."""
    chromatic = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    root = None
    for r in sorted(chromatic, key=len, reverse=True):
        if chord_text.startswith(r):
            root = r
            break
    if not root:
        return []

    suffix = chord_text[len(root):]
    quality_map = {
        "7": "dom7", "maj7": "maj7", "M7": "maj7",
        "m7": "min7", "-7": "min7", "min7": "min7",
        "m7b5": "min7b5", "-7b5": "min7b5",
        "dim7": "dim7", "o7": "dim7",
        "6": "maj6", "m6": "min6",
        "9": "dom9", "maj9": "maj9", "m9": "min9",
        "13": "dom13", "7b9": "dom7b9", "7#9": "dom7sharp9",
        "7#11": "dom7sharp11", "7b13": "dom7b13",
        "sus4": "sus4", "sus2": "sus2", "": "dom7",
    }

    quality = quality_map.get(suffix)
    if not quality:
        for k, v in sorted(quality_map.items(), key=lambda x: -len(x[0])):
            if k and suffix.startswith(k):
                quality = v
                break
    if not quality:
        return []

    return [v for v in voicings
            if v["chord_quality"] == quality
            and (v["context"] == context or context == "all")][:3]


def svg_to_pdf_drawing(svg_string):
    """Convert an SVG string to a ReportLab drawing."""
    try:
        from svglib.svglib import svg2rlg
        svg_io = io.BytesIO(svg_string.encode("utf-8"))
        return svg2rlg(svg_io)
    except ImportError:
        return None


def generate_chord_sheet_pdf(
    output_path,
    voicings_to_render,
    title="Chord Reference Sheet",
    subtitle="",
    columns=5,
    diagram_width=140,
):
    """Generate a PDF chord sheet with a grid of fretboard diagrams."""
    from reportlab.graphics import renderPDF

    page_width, page_height = letter
    margin = 0.75 * inch
    usable_width = page_width - 2 * margin
    col_width = usable_width / columns
    row_height = diagram_width * 1.4

    c = canvas.Canvas(str(output_path), pagesize=letter)
    c.setTitle(title)

    # Header
    y = page_height - margin
    c.setFont("Helvetica-Bold", 18)
    c.drawCentredString(page_width / 2, y, title)
    y -= 22

    if subtitle:
        c.setFont("Helvetica", 11)
        c.drawCentredString(page_width / 2, y, subtitle)
        y -= 16

    y -= 8
    c.setStrokeColorRGB(0.7, 0.7, 0.7)
    c.line(margin, y, page_width - margin, y)
    y -= 20

    col = 0
    row_y = y

    for voicing in voicings_to_render:
        if row_y - row_height < margin:
            c.showPage()
            row_y = page_height - margin - 20
            col = 0

        x = margin + col * col_width

        dwg = render_fretboard_svg(
            voicing,
            width=int(diagram_width * 0.85),
            show_labels=True,
            show_title=True,
            show_intervals=True,
        )

        svg_string = dwg.tostring()
        drawing = svg_to_pdf_drawing(svg_string)

        if drawing:
            scale = min(col_width / drawing.width, row_height / drawing.height) * 0.9
            drawing.width *= scale
            drawing.height *= scale
            drawing.scale(scale, scale)
            renderPDF.draw(drawing, c, x + (col_width - drawing.width) / 2, row_y - drawing.height)

        col += 1
        if col >= columns:
            col = 0
            row_y -= row_height

    c.setFont("Helvetica", 8)
    c.setFillColorRGB(0.5, 0.5, 0.5)
    c.drawCentredString(page_width / 2, margin / 2,
                        "Generated by Siege Analytics Chord Library")
    c.save()
    print(f"Saved chord sheet: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate PDF chord reference sheets"
    )
    parser.add_argument("score", nargs="?", type=Path,
                        help="MuseScore file (.mscx/.mscz) to analyze")
    parser.add_argument("--voicings", help="Comma-separated voicing IDs")
    parser.add_argument("--quality", help="Filter by chord quality")
    parser.add_argument("--context", default="CV6", help="Context filter")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--title", help="Override sheet title")
    parser.add_argument("--key", help="Key for subtitle")
    parser.add_argument("--columns", type=int, default=5)
    parser.add_argument("-o", "--output", type=Path, default=Path("chord-sheet.pdf"))
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "data" / "voicings.json")
    args = parser.parse_args()

    with open(args.data) as f:
        all_voicings = json.load(f)["voicings"]

    voicings_to_render = []
    title = args.title or "Chord Reference Sheet"
    subtitle = ""

    if args.score:
        info = extract_chords_from_mscx(args.score)
        title = args.title or info["title"] or args.score.stem
        parts = []
        if info["composer"]:
            parts.append(info["composer"])
        if args.key:
            parts.append(f"Key: {args.key}")
        subtitle = " — ".join(parts)

        for chord_text in info["chords"]:
            matches = match_chord_to_voicings(chord_text, all_voicings, args.context)
            if matches:
                voicings_to_render.append(matches[0])
            else:
                print(f"Warning: no voicing for '{chord_text}'", file=sys.stderr)
    elif args.voicings:
        for vid in args.voicings.split(","):
            vid = vid.strip()
            matches = [v for v in all_voicings if v["id"] == vid]
            if matches:
                voicings_to_render.append(matches[0])
            else:
                print(f"Warning: '{vid}' not found", file=sys.stderr)
    else:
        voicings_to_render = all_voicings
        if args.quality:
            voicings_to_render = [v for v in voicings_to_render if v["chord_quality"] == args.quality]
        if args.context and args.context != "all":
            voicings_to_render = [v for v in voicings_to_render if v["context"] == args.context]
        if args.category:
            voicings_to_render = [v for v in voicings_to_render if v["category"] == args.category]
        title = args.title or f"Chord Library — {args.quality or 'All'} ({args.context})"

    if not voicings_to_render:
        print("No voicings to render", file=sys.stderr)
        sys.exit(1)

    generate_chord_sheet_pdf(
        args.output, voicings_to_render,
        title=title, subtitle=subtitle, columns=args.columns,
    )


if __name__ == "__main__":
    main()
