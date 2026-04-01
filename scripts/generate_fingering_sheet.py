#!/usr/bin/env python3
"""Generate a branded PDF fingering reference sheet for a score.

Shows each chord in the score with its fretboard diagram and recommended
fingering. Designed to be printed and placed on a music stand alongside
the score.

Usage:
    python generate_fingering_sheet.py --chords score-chords.json -o fingerings.pdf
    python generate_fingering_sheet.py --chords score-chords.json --title "Au Privave" --context CV6
"""

import argparse
import io
import json
import sys
from datetime import date
from pathlib import Path

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
from suggest_fingerings import suggest_fingering, format_fingering, FINGER_NAMES
from analyze_score import parse_chord_symbol

BRAND_GREEN = HexColor("#6B8E23")
BRAND_DARK = HexColor("#212121")
BRAND_GRAY = HexColor("#757575")
BRAND_LIGHT = HexColor("#E0E0E0")

QUALITY_MAP = {
    "7": "dom7", "maj7": "maj7", "M7": "maj7",
    "m7": "min7", "-7": "min7",
    "m7b5": "min7b5", "-7b5": "min7b5",
    "dim7": "dim7", "o7": "dim7",
    "6": "maj6", "m6": "min6",
    "9": "dom9", "maj9": "maj9", "m9": "min9",
    "13": "dom13", "7b9": "dom7b9", "7#9": "dom7sharp9",
    "7#11": "dom7sharp11", "7b13": "dom7b13",
    "sus4": "sus4", "sus2": "sus2",
    "": "maj7",
}


def match_voicing(chord_text, voicings, context="CV6", category=None):
    """Match a chord symbol to the best library voicing."""
    parsed = parse_chord_symbol(chord_text)
    if not parsed:
        return None
    root, quality, _ = parsed
    candidates = [v for v in voicings
                  if v["chord_quality"] == quality
                  and (v["context"] == context or context == "all")]
    if category:
        filtered = [v for v in candidates if v["category"] == category]
        if filtered:
            candidates = filtered
    return candidates[0] if candidates else None


def svg_to_pdf_drawing(svg_string):
    try:
        from svglib.svglib import svg2rlg
        svg_io = io.BytesIO(svg_string.encode("utf-8"))
        return svg2rlg(svg_io)
    except ImportError:
        return None


def draw_header(c, page_width, margin, title, subtitle):
    page_height = letter[1]
    header_top = page_height - margin * 0.5

    logo_height = 22
    logo_y = header_top - logo_height - 2
    logo_width = logo_height * 5.9
    if LOGO_PATH.exists():
        try:
            logo = ImageReader(str(LOGO_PATH))
            iw, ih = logo.getSize()
            logo_width = logo_height * (iw / ih)
            c.drawImage(logo, margin, logo_y, width=logo_width, height=logo_height,
                        preserveAspectRatio=True, mask="auto")
        except Exception:
            c.setFont("Helvetica-Bold", 10)
            c.setFillColor(BRAND_DARK)
            c.drawString(margin, logo_y + 6, "SIEGE ANALYTICS")
            logo_width = 100

    c.linkURL("https://www.siegeanalytics.com",
              (margin, logo_y, margin + logo_width, logo_y + logo_height))

    link_text = "Made by Siege Analytics Chord Library for MuseScore"
    c.setFont("Helvetica", 8)
    c.setFillColor(BRAND_GREEN)
    text_width = c.stringWidth(link_text, "Helvetica", 8)
    text_x = page_width - margin - text_width
    text_y = logo_y + 6
    c.drawString(text_x, text_y, link_text)
    c.linkURL(GITHUB_URL, (text_x, text_y - 2, page_width - margin, text_y + 10))

    accent_y = logo_y - 6
    c.setStrokeColor(BRAND_GREEN)
    c.setLineWidth(2)
    c.line(margin, accent_y, page_width - margin, accent_y)
    c.setLineWidth(1)

    title_y = accent_y - 26
    c.setFont("Helvetica-Bold", 20)
    c.setFillColor(BRAND_DARK)
    c.drawCentredString(page_width / 2, title_y, title)

    content_y = title_y - 6
    if subtitle:
        content_y -= 16
        c.setFont("Helvetica", 11)
        c.setFillColor(BRAND_GRAY)
        c.drawCentredString(page_width / 2, title_y - 18, subtitle)

    content_y -= 10
    c.setStrokeColor(BRAND_LIGHT)
    c.setLineWidth(0.5)
    c.line(margin, content_y, page_width - margin, content_y)

    return content_y - 15


def draw_footer(c, page_width, margin, page_num, total_pages):
    footer_y = margin * 0.4

    c.setStrokeColor(BRAND_GREEN)
    c.setLineWidth(1)
    c.line(margin, footer_y + 14, page_width - margin, footer_y + 14)

    c.setFont("Helvetica", 7)

    link_text = "github.com/siege-analytics/musescore4-chord-library-plugin"
    c.setFillColor(BRAND_GREEN)
    c.drawString(margin, footer_y, link_text)
    link_width = c.stringWidth(link_text, "Helvetica", 7)
    c.linkURL(GITHUB_URL, (margin, footer_y - 2, margin + link_width, footer_y + 8))

    c.setFillColor(BRAND_GRAY)
    c.drawRightString(page_width - margin, footer_y, f"Page {page_num}/{total_pages}")


def generate_fingering_sheet(output_path, entries, title, subtitle=""):
    """Generate a branded PDF fingering sheet.

    entries: list of (chord_text, voicing, fingering, fingering_str)
    """
    from reportlab.graphics import renderPDF

    page_width, page_height = letter
    margin = 0.75 * inch
    usable_width = page_width - 2 * margin
    columns = 4
    col_width = usable_width / columns
    diagram_width = 130
    row_height = diagram_width * 1.6  # taller to fit fingering text
    footer_space = margin * 0.8

    # Estimate pages
    content_start = page_height - margin * 0.5 - 22 - 6 - 26 - 6 - 10 - 15
    if subtitle:
        content_start -= 16
    rows_first = int((content_start - footer_space) / row_height)
    diagrams_first = rows_first * columns
    rows_cont = int((page_height - margin - 20 - footer_space) / row_height)
    diagrams_cont = rows_cont * columns

    total = len(entries)
    if total <= diagrams_first:
        total_pages = 1
    else:
        total_pages = 1 + max(1, -(-( total - diagrams_first) // max(1, diagrams_cont)))

    c = canvas.Canvas(str(output_path), pagesize=letter)
    c.setTitle(title)
    c.setAuthor("Dheeraj Chand / Siege Analytics")
    c.setSubject("Fingering Reference Sheet")

    page_num = 1
    row_y = draw_header(c, page_width, margin, title, subtitle)
    col = 0

    for chord_text, voicing, fingering, fing_str in entries:
        if row_y - row_height < footer_space:
            draw_footer(c, page_width, margin, page_num, total_pages)
            c.showPage()
            page_num += 1
            row_y = page_height - margin - 20
            col = 0

        x = margin + col * col_width

        # Extract root from chord text for transposition
        target_root = None
        for r in sorted(["C", "Db", "D", "Eb", "E", "F", "F#", "Gb", "G", "Ab", "A", "Bb", "B",
                          "C#", "D#", "G#", "A#"], key=len, reverse=True):
            if chord_text.startswith(r):
                target_root = r
                break

        # Draw fretboard diagram (transposed to actual key)
        dwg = render_fretboard_svg(
            voicing, width=int(diagram_width * 0.8),
            show_labels=True, show_title=True, show_intervals=True,
            target_root=target_root, display_name=chord_text,
        )
        svg_string = dwg.tostring()
        drawing = svg_to_pdf_drawing(svg_string)

        if drawing:
            scale = min(col_width / drawing.width, (row_height * 0.7) / drawing.height) * 0.9
            drawing.width *= scale
            drawing.height *= scale
            drawing.scale(scale, scale)
            renderPDF.draw(drawing, c,
                           x + (col_width - drawing.width) / 2,
                           row_y - drawing.height)

            # Fingering text below diagram
            fing_y = row_y - drawing.height - 12
        else:
            fing_y = row_y - 100

        # Chord name (transposed)
        c.setFont("Helvetica-Bold", 10)
        c.setFillColor(BRAND_DARK)
        c.drawCentredString(x + col_width / 2, fing_y, chord_text)

        # Fingering string
        c.setFont("Courier", 9)
        c.setFillColor(BRAND_GREEN)
        c.drawCentredString(x + col_width / 2, fing_y - 12, fing_str)

        # Finger legend (small)
        if fingering:
            legend_parts = []
            for fg in fingering:
                legend_parts.append(f"s{fg['string']}={FINGER_NAMES[fg['finger']]}")
            c.setFont("Helvetica", 6)
            c.setFillColor(BRAND_GRAY)
            c.drawCentredString(x + col_width / 2, fing_y - 22, "  ".join(legend_parts))

        col += 1
        if col >= columns:
            col = 0
            row_y -= row_height

    draw_footer(c, page_width, margin, page_num, total_pages)
    c.save()
    print(f"Saved fingering sheet: {output_path} ({total_pages} pages)")


def main():
    parser = argparse.ArgumentParser(
        description="Generate a branded PDF fingering reference sheet"
    )
    parser.add_argument("--chords", type=Path, required=True,
                        help="JSON file of extracted chords (from plugin)")
    parser.add_argument("--title", default="Fingering Reference")
    parser.add_argument("--context", default="CV6")
    parser.add_argument("--category")
    parser.add_argument("-o", "--output", type=Path, default=Path("fingering-sheet.pdf"))
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "data" / "voicings.json")
    args = parser.parse_args()

    with open(args.data) as f:
        voicings = json.load(f)["voicings"]

    with open(args.chords) as f:
        chord_data = json.load(f)

    title = args.title
    composer = chord_data.get("composer", "")
    subtitle = f"Fingering Reference — {args.context}"
    if composer:
        subtitle = f"{composer} — Fingering Reference — {args.context}"

    entries = []
    seen = set()
    for c in chord_data.get("chords", []):
        text = c.get("text", "")
        if text in seen:
            continue
        seen.add(text)

        v = match_voicing(text, voicings, args.context, args.category)
        if v:
            fg = suggest_fingering(v)
            fing_str = format_fingering(v, fg) if fg else ""
            entries.append((text, v, fg, fing_str))
        else:
            print(f"Warning: no voicing for '{text}'", file=sys.stderr)

    if not entries:
        print("No chords matched", file=sys.stderr)
        sys.exit(1)

    generate_fingering_sheet(args.output, entries, title, subtitle)


if __name__ == "__main__":
    main()
