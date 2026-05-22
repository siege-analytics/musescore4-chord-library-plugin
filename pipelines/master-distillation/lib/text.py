"""Text-manipulation utilities for the pipeline.

Functions for slicing the page-marked transcript, picking the front
matter for TOC detection, and verifying that quoted strings are exact
substrings of the raw transcript (the quote-fidelity check).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

PAGE_MARK_RE = re.compile(r"<!--\s*page\s+(\d+)\s+end\s*-->")


def load_transcript(raw_transcript_path: Path) -> str:
    """Read the raw transcript verbatim. Includes the page-end markers
    that Stage 1 inserted."""
    return raw_transcript_path.read_text()


def load_pages(pages_json_path: Path) -> list[dict]:
    """Return the list of {n, start, length, preview} records."""
    data = json.loads(pages_json_path.read_text())
    return data["pages"]


def text_between_pages(
    transcript: str, start_page: int, end_page: int
) -> str:
    """Return the substring of `transcript` covering pages [start_page,
    end_page] inclusive, based on the `<!-- page N end -->` markers
    inserted by Stage 1. If end_page is past the last marker, returns
    through end-of-string.
    """
    # Find the position immediately AFTER the marker for page (start_page-1),
    # i.e. the start of page start_page. Pages are 1-indexed.
    start = 0
    if start_page > 1:
        m = re.search(
            rf"<!--\s*page\s+{start_page - 1}\s+end\s*-->",
            transcript,
        )
        if not m:
            raise ValueError(f"no page-end marker for page {start_page - 1}")
        start = m.end()

    # Find the END marker for end_page.
    m = re.search(
        rf"<!--\s*page\s+{end_page}\s+end\s*-->",
        transcript,
    )
    end = m.end() if m else len(transcript)

    return transcript[start:end]


def strip_page_marks(text: str) -> str:
    """Remove `<!-- page N end -->` markers from `text`. Used when
    sending text to the LLM so the markers don't appear in quotes."""
    return PAGE_MARK_RE.sub("", text)


def verify_quote_in_transcript(quote: str, transcript: str) -> bool:
    """Return True if `quote` appears verbatim in `transcript` after
    page-mark removal AND whitespace normalization.

    The LLM may produce a quote with single-space whitespace where the
    transcript has multiple spaces (PDF -layout extraction often has
    column-padding). We normalize both to single-spaced lines before
    comparing. This is slightly looser than pure substring match but
    still detects hallucination — a fabricated sentence will not appear
    even under whitespace normalization.
    """
    norm_quote = _normalize_whitespace(quote)
    norm_transcript = _normalize_whitespace(strip_page_marks(transcript))
    return norm_quote in norm_transcript


def find_page_of_quote(quote: str, transcript: str, pages: list[dict]) -> int | None:
    """Return the page number containing `quote`, or None.

    Uses the same whitespace-normalized substring search as
    verify_quote_in_transcript, against each page's slice.
    """
    norm_quote = _normalize_whitespace(quote)
    # Build whitespace-normalized per-page text once.
    for p in pages:
        page_text = text_between_pages(transcript, p["n"], p["n"])
        if _normalize_whitespace(strip_page_marks(page_text)).__contains__(norm_quote):
            return p["n"]
    return None


_WS_RE = re.compile(r"\s+")


def _normalize_whitespace(s: str) -> str:
    return _WS_RE.sub(" ", s).strip()


def total_pages(pages: list[dict]) -> int:
    return max(p["n"] for p in pages) if pages else 0


def front_matter(transcript: str, n_pages: int = 20) -> str:
    """Return the text of the first `n_pages` pages — typically
    contains the TOC. Used as the input for TOC detection."""
    return text_between_pages(transcript, 1, n_pages)
