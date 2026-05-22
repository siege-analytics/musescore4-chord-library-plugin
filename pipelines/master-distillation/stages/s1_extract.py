"""Stage 1 — Extract.

Input:  source PDF (from per-book config).
Output:
  - runs/<ts>/raw-transcript.txt  (gitignored)
  - runs/<ts>/pages.json          (gitignored)  [page_n → char offset + length]
Zero LLM calls.

Implementation strategy:
  - For native (digital-text) PDFs: use `markitdown` if available
    (built-in tool in this environment), else fall back to `pdftotext`.
  - For scanned-image PDFs (e.g. Van Eps 1939): config sets
    `source.needs_ocr: true`, and Stage 1 runs `pdftoppm | tesseract`.
    For #297's first run (Benson Vol 1) we expect a digital PDF and
    don't implement the OCR branch yet — it raises NotImplementedError
    if needs_ocr is true so we don't ship an untested code path.

Stage gate summary (printed by orchestrator from the returned outputs
list): pages extracted, characters extracted, OCR confidence if any,
any failed pages.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

from lib.paths import BookPaths


def run(cfg: dict, book: BookPaths) -> list[str]:
    src_pdf = Path(cfg["source"]["pdf"]).expanduser()
    if not src_pdf.exists():
        raise FileNotFoundError(f"source PDF not found: {src_pdf}")

    if cfg.get("source", {}).get("needs_ocr"):
        raise NotImplementedError(
            "OCR branch not implemented yet; will land in a follow-up "
            "alongside the first scanned-image book (e.g. Van Eps 1939)."
        )

    outputs: list[str] = []

    # Extract text via pdftotext (broadly available; deterministic
    # per-page output with -layout for column-aware extraction). Falls
    # back to `markitdown` if pdftotext is absent.
    raw_text, pages_index = _extract_per_page(src_pdf)

    book.raw_transcript.write_text(raw_text)
    outputs.append(str(book.raw_transcript.relative_to(book.run_dir.parent.parent.parent)))

    book.pages_json.write_text(json.dumps(pages_index, indent=2) + "\n")
    outputs.append(str(book.pages_json.relative_to(book.run_dir.parent.parent.parent)))

    # Summary line printed via outputs return — orchestrator prints them.
    n_pages = len(pages_index["pages"])
    n_chars = len(raw_text)
    outputs.append(f"extracted: {n_pages} pages, {n_chars:,} characters")

    return outputs


def _extract_per_page(pdf_path: Path) -> tuple[str, dict]:
    """Return (full transcript, pages_index).

    pages_index shape:
      { "pages": [ { "n": 1, "start": 0, "length": 1234, "preview": "..." }, ... ] }
    """
    if shutil.which("pdftotext"):
        return _extract_with_pdftotext(pdf_path)
    if shutil.which("markitdown"):
        return _extract_with_markitdown(pdf_path)
    raise RuntimeError(
        "no PDF extractor found. Install pdftotext (poppler-utils) or "
        "markitdown."
    )


def _extract_with_pdftotext(pdf_path: Path) -> tuple[str, dict]:
    """pdftotext -layout -enc UTF-8 emits a form-feed (\\f) between pages."""
    result = subprocess.run(
        ["pdftotext", "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    raw = result.stdout
    # Split on form-feed; each chunk is one page. pdftotext appends a
    # trailing \f after the last page.
    chunks = raw.split("\f")
    # Drop a final empty trailing chunk if present.
    if chunks and chunks[-1] == "":
        chunks = chunks[:-1]

    pages = []
    offset = 0
    transcript_parts = []
    for i, chunk in enumerate(chunks, start=1):
        preview = _preview(chunk)
        pages.append({
            "n": i,
            "start": offset,
            "length": len(chunk),
            "preview": preview,
        })
        transcript_parts.append(chunk)
        offset += len(chunk)
        # Insert an explicit page-break marker into the transcript so
        # downstream stages can locate page boundaries deterministically.
        # The marker itself is OUTSIDE the per-page char-count above, so
        # quote-fidelity validation still works against original page text.
        transcript_parts.append(f"\n<!-- page {i} end -->\n")
        offset += len(transcript_parts[-1])

    transcript = "".join(transcript_parts)
    return transcript, {"pages": pages}


def _extract_with_markitdown(pdf_path: Path) -> tuple[str, dict]:
    result = subprocess.run(
        ["markitdown", str(pdf_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    raw = result.stdout
    # markitdown doesn't preserve page boundaries cleanly. Fall back to
    # a single "page 1" record covering the whole document. Downstream
    # Stage 2 will work, but Stage 2's per-chapter page citations will
    # be less precise.
    return raw, {
        "pages": [
            {
                "n": 1,
                "start": 0,
                "length": len(raw),
                "preview": _preview(raw),
            }
        ],
        "extraction_note": "markitdown-fallback: page boundaries not preserved",
    }


def _preview(text: str) -> str:
    """First non-empty line, trimmed to 80 chars."""
    for line in text.splitlines():
        stripped = re.sub(r"\s+", " ", line).strip()
        if stripped:
            return stripped[:80]
    return ""
