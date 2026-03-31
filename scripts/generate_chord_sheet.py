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

from datetime import date

from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "assets"
LOGO_PATH = ASSETS_DIR / "siege-logo-black.png"
GITHUB_URL = "https://github.com/siege-analytics/musescore4-chord-library-plugin"

sys.path.insert(0, str(REPO_ROOT / "scripts"))

from fretboard_renderer import render_fretboard_svg

# Siege Analytics brand colors (from website)
BRAND_GREEN = HexColor("#6B8E23")      # olive green accent
BRAND_DARK = HexColor("#212121")       # near-black text
BRAND_GRAY = HexColor("#757575")       # secondary text
BRAND_LIGHT = HexColor("#E0E0E0")      # divider lines


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


def _draw_header(c, page_width, margin, title, subtitle):
    """Draw the branded header on the current page."""
    y = page_height = letter[1]
    header_top = y - margin * 0.5

    # Logo (left side) — links to siegeanalytics.com
    logo_height = 22
    logo_y = header_top - logo_height - 2
    logo_width = logo_height * 5.9  # fallback aspect ratio
    if LOGO_PATH.exists():
        try:
            logo = ImageReader(str(LOGO_PATH))
            iw, ih = logo.getSize()
            logo_width = logo_height * (iw / ih)
            c.drawImage(
                logo, margin, logo_y,
                width=logo_width, height=logo_height,
                preserveAspectRatio=True, mask="auto",
            )
        except Exception:
            c.setFont("Helvetica-Bold", 10)
            c.setFillColor(BRAND_DARK)
            c.drawString(margin, logo_y + 6, "SIEGE ANALYTICS")
            logo_width = 100

    # Make logo clickable → siegeanalytics.com
    c.linkURL("https://www.siegeanalytics.com",
              (margin, logo_y, margin + logo_width, logo_y + logo_height))

    # "Made by Siege Analytics Chord Library for MuseScore" (right side)
    # Links to GitHub repo
    link_text = "Made by Siege Analytics Chord Library for MuseScore"
    c.setFont("Helvetica", 8)
    c.setFillColor(BRAND_GREEN)
    text_width = c.stringWidth(link_text, "Helvetica", 8)
    text_x = page_width - margin - text_width
    text_y = logo_y + 6
    c.drawString(text_x, text_y, link_text)
    c.linkURL(GITHUB_URL,
              (text_x, text_y - 2, page_width - margin, text_y + 10))

    # Green accent line under header
    accent_y = logo_y - 6
    c.setStrokeColor(BRAND_GREEN)
    c.setLineWidth(2)
    c.line(margin, accent_y, page_width - margin, accent_y)
    c.setLineWidth(1)

    # Title
    title_y = accent_y - 26
    c.setFont("Helvetica-Bold", 20)
    c.setFillColor(BRAND_DARK)
    c.drawCentredString(page_width / 2, title_y, title)

    # Subtitle
    content_y = title_y - 6
    if subtitle:
        content_y -= 16
        c.setFont("Helvetica", 11)
        c.setFillColor(BRAND_GRAY)
        c.drawCentredString(page_width / 2, title_y - 18, subtitle)

    # Thin divider
    content_y -= 10
    c.setStrokeColor(BRAND_LIGHT)
    c.setLineWidth(0.5)
    c.line(margin, content_y, page_width - margin, content_y)

    return content_y - 15  # return Y position for content start


def _draw_footer(c, page_width, margin, page_num, total_pages, generated_date):
    """Draw the branded footer on the current page."""
    footer_y = margin * 0.4

    # Green accent line above footer
    c.setStrokeColor(BRAND_GREEN)
    c.setLineWidth(1)
    c.line(margin, footer_y + 14, page_width - margin, footer_y + 14)

    c.setFont("Helvetica", 7)

    # Left: GitHub link (clickable)
    link_text = "github.com/siege-analytics/musescore4-chord-library-plugin"
    c.setFillColor(BRAND_GREEN)
    c.drawString(margin, footer_y, link_text)
    link_width = c.stringWidth(link_text, "Helvetica", 7)
    c.linkURL(GITHUB_URL, (margin, footer_y - 2, margin + link_width, footer_y + 8))

    # Right: page number
    c.setFillColor(BRAND_GRAY)
    c.drawRightString(page_width - margin, footer_y,
                      f"Page {page_num}/{total_pages}")


def generate_chord_sheet_pdf(
    output_path,
    voicings_to_render,
    title="Chord Reference Sheet",
    subtitle="",
    columns=5,
    diagram_width=140,
):
    """Generate a branded PDF chord sheet with Siege Analytics header/footer."""
    from reportlab.graphics import renderPDF

    page_width, page_height = letter
    margin = 0.75 * inch
    usable_width = page_width - 2 * margin
    col_width = usable_width / columns
    row_height = diagram_width * 1.4
    footer_space = margin * 0.8
    generated_date = date.today().strftime("%B %d, %Y")

    # First pass: calculate total pages
    # (we need this for "Page X/Y" in the footer)
    content_start_y = page_height - margin * 0.5 - 22 - 6 - 26 - 6 - 10 - 15
    if subtitle:
        content_start_y -= 16

    diagrams_per_first_page = 0
    test_y = content_start_y
    while test_y - row_height > footer_space:
        diagrams_per_first_page += columns
        test_y -= row_height

    # Continuation pages have more room (no big title)
    cont_start_y = page_height - margin - 20
    diagrams_per_cont_page = 0
    test_y = cont_start_y
    while test_y - row_height > footer_space:
        diagrams_per_cont_page += columns
        test_y -= row_height

    total_voicings = len(voicings_to_render)
    if total_voicings <= diagrams_per_first_page:
        total_pages = 1
    else:
        remaining = total_voicings - diagrams_per_first_page
        total_pages = 1 + max(1, -(-remaining // diagrams_per_cont_page))  # ceil division

    # Second pass: render
    c = canvas.Canvas(str(output_path), pagesize=letter)
    c.setTitle(title)
    c.setAuthor("Dheeraj Chand / Siege Analytics")
    c.setSubject("Chord Reference Sheet")

    page_num = 1
    row_y = _draw_header(c, page_width, margin, title, subtitle)
    col = 0

    for i, voicing in enumerate(voicings_to_render):
        if row_y - row_height < footer_space:
            # Draw footer on current page, start new page
            _draw_footer(c, page_width, margin, page_num, total_pages, generated_date)
            c.showPage()
            page_num += 1
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

    # Draw footer on final page
    _draw_footer(c, page_width, margin, page_num, total_pages, generated_date)
    c.save()
    print(f"Saved chord sheet: {output_path} ({total_pages} pages)")


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
