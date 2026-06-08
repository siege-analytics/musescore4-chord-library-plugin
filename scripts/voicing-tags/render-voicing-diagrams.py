#!/usr/bin/env python3
"""Render fretboard diagrams (SVG + PNG) for a list of voicings (#395).

Reads:
  - scripts/voicing-tags/pilot-50.csv (default), or any CSV with a
    `voicing_id` column; or --ids <id1,id2,...> directly.
  - plugin/data/voicings.json (the voicing source)

Writes:
  - scripts/voicing-tags/diagrams/<voicing_id>.svg
  - scripts/voicing-tags/diagrams/<voicing_id>.png

Pipeline:
  voicings.json[id] -> scripts/fretboard_svg.py:render_voicing_svg(voicing)
                    -> SVG string -> file
                    -> ImageMagick `convert` -> PNG

Why ImageMagick: cairosvg isn't installed on the pipeline host but
ImageMagick is available system-wide. The cost is one subprocess per
voicing; for 50 it's negligible.

The PNG width is 2x the SVG width so it stays sharp when Tally scales
it down on the form.
"""
import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from fretboard_svg import render_voicing_svg  # noqa: E402


def load_voicings(path):
    return {v["id"]: v for v in json.load(open(path))["voicings"]}


def ids_from_csv(path):
    return [r["voicing_id"] for r in csv.DictReader(open(path))]


def svg_to_png(svg_path, png_path, width):
    """Rasterize SVG -> PNG via ImageMagick. Width controls resolution.

    -density 192 (2x default 96 dpi) keeps text crisp on the rasterized
    output even when Tally rescales it to fit a question width.
    """
    cmd = [
        "convert",
        "-density", "192",
        "-background", "white",
        "-resize", f"{width}x",
        str(svg_path),
        str(png_path),
    ]
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voicings", default=str(REPO_ROOT / "plugin/data/voicings.json"))
    ap.add_argument("--csv", default=str(REPO_ROOT / "scripts/voicing-tags/pilot-50.csv"))
    ap.add_argument("--ids", help="comma-separated voicing_ids (overrides --csv)")
    ap.add_argument("--out", default=str(REPO_ROOT / "scripts/voicing-tags/diagrams"))
    ap.add_argument("--svg-width", type=int, default=240)
    ap.add_argument("--svg-height", type=int, default=300)
    ap.add_argument("--png-width", type=int, default=480,
                    help="raster output width in px (PNG)")
    args = ap.parse_args()

    voicings = load_voicings(args.voicings)
    print(f"Loaded {len(voicings)} voicings from {args.voicings}")

    if args.ids:
        ids = [s.strip() for s in args.ids.split(",") if s.strip()]
    else:
        ids = ids_from_csv(args.csv)
    print(f"Rendering {len(ids)} voicings")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    rendered_svg = 0
    rendered_png = 0
    missing = []
    for vid in ids:
        v = voicings.get(vid)
        if not v:
            missing.append(vid)
            continue
        svg = render_voicing_svg(
            v,
            title="",
            width=args.svg_width,
            height=args.svg_height,
        )
        svg_path = out_dir / f"{vid}.svg"
        svg_path.write_text(svg, encoding="utf-8")
        rendered_svg += 1

        png_path = out_dir / f"{vid}.png"
        try:
            svg_to_png(svg_path, png_path, args.png_width)
            rendered_png += 1
        except subprocess.CalledProcessError as e:
            print(f"  [!] PNG conversion failed for {vid}: {e}")

    print(f"\nSVG: {rendered_svg}/{len(ids)} rendered")
    print(f"PNG: {rendered_png}/{len(ids)} rasterized")
    if missing:
        print(f"\nMISSING voicing_ids ({len(missing)}):")
        for m in missing[:10]:
            print(f"  {m}")

    # Size summary
    svg_total = sum(p.stat().st_size for p in out_dir.glob("*.svg"))
    png_total = sum(p.stat().st_size for p in out_dir.glob("*.png"))
    print(f"\nTotal SVG bytes: {svg_total:,}")
    print(f"Total PNG bytes: {png_total:,}")


if __name__ == "__main__":
    main()
