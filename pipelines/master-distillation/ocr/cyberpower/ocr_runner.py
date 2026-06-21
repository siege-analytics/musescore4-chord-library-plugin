#!/usr/bin/env python3
"""Cyberpower-side OCR runner.

Invoked by `run.sh <run_id>`. Expects images at
  ~/jazz-ocr/inbox/<run_id>/page-NNNN.png
and writes results to
  ~/jazz-ocr/outbox/<run_id>/
    raw-transcript.txt        form-feed-delimited like pdftotext
    page-confidence.json      per-page conf + which engine produced it

Tesseract is the first pass. Pages with mean confidence below threshold OR
character count below a floor are escalated to qwen2.5vl:7b via Ollama HTTP.
"""

from __future__ import annotations

import base64
import io
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
VISION_MODEL = os.environ.get("OCR_VISION_MODEL", "qwen2.5vl:7b")
CONF_THRESHOLD = float(os.environ.get("OCR_CONF_THRESHOLD", "0.70"))
MIN_CHARS_PER_PAGE = int(os.environ.get("OCR_MIN_CHARS_PER_PAGE", "40"))
# Vision tokenizers tile the image; high-resolution scans (2400×3300+ from
# pdftoppm -r 200) blow out a 12GB VRAM card. Resize the long edge to
# ~1500px before send — plenty for OCR-grade prose recognition.
VISION_MAX_LONG_EDGE = int(os.environ.get("OCR_VISION_MAX_LONG_EDGE", "1500"))

VISION_PROMPT = (
    "Transcribe ALL text on this page exactly as printed. Preserve line "
    "breaks. Do not summarize, paraphrase, translate, or comment. If a "
    "region contains music notation or diagrams, skip it silently. Output "
    "ONLY the transcribed text."
)


def _tesseract_page(image_path: Path) -> tuple[str, float]:
    """Return (text, mean confidence in [0,1])."""
    # `tesseract <image> stdout -c tessedit_create_tsv=0` produces text.
    # To get confidence, run a second pass with `tsv` format and average
    # the per-word conf values (excluding the -1 sentinels).
    text_res = subprocess.run(
        ["tesseract", str(image_path), "stdout", "-l", "eng"],
        capture_output=True,
        text=True,
        check=True,
    )
    tsv_res = subprocess.run(
        ["tesseract", str(image_path), "stdout", "-l", "eng", "tsv"],
        capture_output=True,
        text=True,
        check=True,
    )
    confs: list[float] = []
    for line in tsv_res.stdout.splitlines()[1:]:
        cols = line.split("\t")
        if len(cols) < 11:
            continue
        try:
            c = float(cols[10])
        except ValueError:
            continue
        if c < 0:
            continue
        confs.append(c / 100.0)
    mean_conf = sum(confs) / len(confs) if confs else 0.0
    return text_res.stdout, mean_conf


def _downscaled_b64(image_path: Path) -> str:
    """Return base64 of `image_path` downscaled to fit VISION_MAX_LONG_EDGE.

    Pillow-based resize keeps aspect ratio. Re-encoded as PNG so Ollama
    sees a clean self-describing image. Falls back to the raw bytes if
    Pillow is not installed (the caller will likely OOM, but the
    fallback keeps the runner functional in minimal environments).
    """
    try:
        from PIL import Image  # type: ignore[import-not-found]
    except ImportError:
        return base64.b64encode(image_path.read_bytes()).decode("ascii")
    with Image.open(image_path) as img:
        w, h = img.size
        long_edge = max(w, h)
        if long_edge > VISION_MAX_LONG_EDGE:
            scale = VISION_MAX_LONG_EDGE / long_edge
            new_size = (int(w * scale), int(h * scale))
            img = img.resize(new_size, Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=True)
        return base64.b64encode(buf.getvalue()).decode("ascii")


def _vision_page(image_path: Path) -> str:
    """OCR via Ollama vision model. Returns transcribed text."""
    img_b64 = _downscaled_b64(image_path)
    payload = {
        "model": VISION_MODEL,
        "prompt": VISION_PROMPT,
        "images": [img_b64],
        "stream": False,
        "options": {"temperature": 0.0},
    }
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        body = json.loads(resp.read())
    return body.get("response", "")


def _needs_rescue(text: str, conf: float) -> bool:
    chars = len(re.sub(r"\s+", "", text))
    if chars < MIN_CHARS_PER_PAGE:
        return True
    if conf < CONF_THRESHOLD:
        return True
    return False


def main(run_id: str) -> int:
    inbox = Path.home() / "jazz-ocr" / "inbox" / run_id
    outbox = Path.home() / "jazz-ocr" / "outbox" / run_id
    if not inbox.exists():
        print(f"inbox not found: {inbox}", file=sys.stderr)
        return 2
    outbox.mkdir(parents=True, exist_ok=True)

    images = sorted(inbox.glob("page-*.png"))
    if not images:
        print(f"no page-NNNN.png images in {inbox}", file=sys.stderr)
        return 2

    transcript_parts: list[str] = []
    confidence_records: list[dict] = []

    for image in images:
        m = re.match(r"page-(\d+)\.png$", image.name)
        if not m:
            continue
        page_n = int(m.group(1))
        tess_text, tess_conf = _tesseract_page(image)
        engine = "tesseract"
        text = tess_text
        rescue_text = None
        if _needs_rescue(tess_text, tess_conf):
            try:
                rescue_text = _vision_page(image)
                if rescue_text.strip():
                    text = rescue_text
                    engine = VISION_MODEL
            except Exception as exc:  # noqa: BLE001 — log and keep tesseract output
                print(
                    f"page {page_n}: vision rescue failed ({exc}); "
                    "keeping tesseract output",
                    file=sys.stderr,
                )

        transcript_parts.append(text)
        confidence_records.append({
            "n": page_n,
            "engine": engine,
            "tesseract_confidence": round(tess_conf, 3),
            "chars": len(text),
        })
        print(
            f"page {page_n:>4}: engine={engine} "
            f"tess_conf={tess_conf:.2f} chars={len(text)}",
            flush=True,
        )

    # Form-feed delimited, matching pdftotext output shape.
    raw_transcript = "\f".join(transcript_parts)
    (outbox / "raw-transcript.txt").write_text(raw_transcript)
    (outbox / "page-confidence.json").write_text(
        json.dumps({"pages": confidence_records}, indent=2) + "\n"
    )
    print(
        f"wrote {outbox/'raw-transcript.txt'} ({len(raw_transcript):,} chars)",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: ocr_runner.py <run_id>", file=sys.stderr)
        sys.exit(64)
    sys.exit(main(sys.argv[1]))
