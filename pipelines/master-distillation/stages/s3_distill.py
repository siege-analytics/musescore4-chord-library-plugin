"""Stage 3 — Hierarchical distillation.

Two LLM scope groups:

  - `chapter:chNN`: per chapter, write a one-paragraph distillation of
    what the chapter teaches, drawing from the committed chapter file's
    curated quotes.
  - `book`: aggregate the chapter summaries into a coherent book-level
    distillation. Sonnet-class model (or the largest local available)
    because this is the synthesis stage where breadth matters.

Outputs (committed):
  - plugin/data/masters-corpus/<master>/<work>/summaries/chNN-summary.md
  - plugin/data/masters-corpus/<master>/<work>/<work>-book-summary.md
"""

from __future__ import annotations

import json
from pathlib import Path

from lib import provenance
from lib.llm import LLMRequest, request_llm
from lib.paths import BookPaths


def run(cfg: dict, book: BookPaths) -> list[str]:
    if not book.chapter_bounds.exists():
        raise FileNotFoundError(
            f"chapter-bounds.json missing at {book.chapter_bounds}; "
            f"Stage 2 must complete first."
        )

    chapters = json.loads(book.chapter_bounds.read_text())["chapters"]
    per_chapter_model = cfg["stages"]["s3"]["per_chapter_model"]
    book_model = cfg["stages"]["s3"]["book_level_model"]
    source_pdf_name = Path(cfg["source"]["pdf"]).name

    outputs: list[str] = []

    # --- 1. Per-chapter summaries ---
    chapter_summaries: list[tuple[dict, str]] = []
    for ch in chapters:
        ch_n = ch["n"]
        summary_path = book.chapter_summary(ch_n)
        chapter_md = book.chapter_file(ch_n).read_text()
        body = _strip_frontmatter(chapter_md)
        summary_text = _summarize_chapter(
            book, ch, body, per_chapter_model
        )
        _write_chapter_summary(
            book, ch, summary_text, per_chapter_model, source_pdf_name
        )
        chapter_summaries.append((ch, summary_text))
        outputs.append(_rel_to_repo(book, summary_path))

    # --- 2. Book-level summary ---
    book_summary_text = _summarize_book(book, chapter_summaries, book_model)
    _write_book_summary(
        book, book_summary_text, book_model, source_pdf_name
    )
    outputs.append(_rel_to_repo(book, book.book_summary))

    return outputs


# ---------------------------------------------------------------------------

_CHAPTER_SYSTEM = """You are distilling one chapter of a guitar method book into a short summary.

The user will give you a chapter file with topic-organized verbatim quotes
plus the human-rationale notes for each. Write a one-paragraph summary (4-7
sentences) that captures:

  - what this chapter teaches (the techniques, concepts, rules, examples)
  - the master's characteristic moves visible in this chapter (if any)
  - the load-bearing terminology this chapter introduces

Reference the topic labels from the chapter file when useful. Do not invent
information not present in the chapter. If the chapter is biographical or
introductory rather than instructional, say so explicitly.

Output just the paragraph — no preamble, no JSON, no markdown formatting.
"""


def _summarize_chapter(
    book: BookPaths, ch: dict, chapter_md_body: str, model: str
) -> str:
    req = LLMRequest(
        stage="s3",
        scope=f"chapter-ch{ch['n']:02d}",
        model=model,
        system_prompt=_CHAPTER_SYSTEM,
        user_prompt=(
            f"Chapter {ch['n']}: {ch['title']}\n\n"
            f"<<<CHAPTER FILE\n{chapter_md_body}\nCHAPTER FILE>>>"
        ),
        response_schema=None,  # free-form prose
        notes=f"per-chapter distillation for ch{ch['n']:02d}",
    )
    request_path = book.llm_call_file("s3", f"chapter-ch{ch['n']:02d}", "request")
    response_path = book.llm_call_file("s3", f"chapter-ch{ch['n']:02d}", "response")
    resp = request_llm(req, request_path, response_path)
    return resp["text"].strip()


# ---------------------------------------------------------------------------

_BOOK_SYSTEM = """You are distilling the entire book into a coherent statement of what it teaches.

The user will give you the list of chapter-level summaries. Write a multi-paragraph
distillation (typically 4-8 paragraphs) that captures:

  - the book's overall arc and pedagogical structure
  - the master's characteristic systems, terminology, and moves
  - the rules and prescriptions the book establishes
  - any explicit method or methodology the book teaches

Cite chapters by number when useful (e.g. "Chapter 3 introduces..."). Do not
invent material outside the summaries. The output is the input to Stage 4
which derives structured systems[] from it, so be precise about what the
book actually says, not what guitar pedagogy generically might say.

Output the prose — no preamble, no JSON. Use markdown headings if helpful.
"""


def _summarize_book(
    book: BookPaths,
    chapter_summaries: list[tuple[dict, str]],
    model: str,
) -> str:
    bundled = "\n\n".join(
        f"## Chapter {ch['n']}: {ch['title']}\n\n{summary}"
        for ch, summary in chapter_summaries
    )
    req = LLMRequest(
        stage="s3",
        scope="book",
        model=model,
        system_prompt=_BOOK_SYSTEM,
        user_prompt=(
            f"All chapter summaries follow.\n\n"
            f"<<<CHAPTER SUMMARIES\n{bundled}\nCHAPTER SUMMARIES>>>"
        ),
        response_schema=None,
        notes="book-level distillation aggregating chapter summaries.",
    )
    request_path = book.llm_call_file("s3", "book", "request")
    response_path = book.llm_call_file("s3", "book", "response")
    resp = request_llm(req, request_path, response_path)
    return resp["text"].strip()


# ---------------------------------------------------------------------------

def _write_chapter_summary(
    book: BookPaths,
    ch: dict,
    summary: str,
    model: str,
    source_pdf_name: str,
) -> None:
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s3",
        source_pdf=source_pdf_name,
        source_pages=f"{ch['start_page']}-{ch['end_page']}",
        model=model,
    )
    text_out = (
        prov.yaml_block()
        + "\n\n"
        + f"# Chapter {ch['n']} — {ch['title']}\n\n"
        + f"_Distillation; backed by `chapters/ch{ch['n']:02d}.md`._\n\n"
        + summary.strip()
        + "\n"
    )
    book.committed_summaries_dir.mkdir(parents=True, exist_ok=True)
    book.chapter_summary(ch["n"]).write_text(text_out)


def _write_book_summary(
    book: BookPaths,
    summary: str,
    model: str,
    source_pdf_name: str,
) -> None:
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s3",
        source_pdf=source_pdf_name,
        source_pages=None,  # book-wide
        model=model,
    )
    text_out = (
        prov.yaml_block()
        + "\n\n"
        + f"# Book-level distillation — {book.work_id}\n\n"
        + "_Aggregated from per-chapter summaries under `summaries/`._\n\n"
        + summary.strip()
        + "\n"
    )
    book.book_summary.write_text(text_out)


# ---------------------------------------------------------------------------

def _strip_frontmatter(md: str) -> str:
    """Drop the YAML frontmatter (between leading --- pair) from a
    markdown file so the LLM doesn't see run_id / model / etc."""
    if not md.startswith("---"):
        return md
    parts = md.split("---", 2)
    if len(parts) < 3:
        return md
    return parts[2].lstrip("\n")


def _rel_to_repo(book: BookPaths, p: Path) -> str:
    """Best-effort path relative to repo root for orchestrator output."""
    repo_root = book.run_dir.parent.parent.parent
    try:
        return str(p.relative_to(repo_root))
    except ValueError:
        return str(p)
