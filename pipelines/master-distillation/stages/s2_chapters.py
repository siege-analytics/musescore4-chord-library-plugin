"""Stage 2 — Chapter detection + curated verbatim quote extraction.

Two LLM scopes:

  - `toc`: given the front matter (first ~20 pages), produce a list of
    chapter-shaped sections with page ranges.
  - `extract:chNN`: per chapter, extract verbatim quotes for every
    passage that teaches a technique, defines a concept, gives a rule,
    or shows a load-bearing example.

Outputs:
  - runs/<id>/chapter-bounds.json       (committed, audit trail)
  - plugin/data/masters-corpus/<master>/<work>/chapters/chNN.md (committed)

Quote-fidelity: every extracted quote must appear in the raw
transcript verbatim (whitespace-normalized substring). The validator
rejects hallucinated quotes and the stage retries with a tightening
hint up to N times; persistent failures error-out the stage.
"""

from __future__ import annotations

import json
from pathlib import Path

from lib import provenance, text
from lib.llm import LLMRequest, request_llm
from lib.paths import BookPaths, rel_to_repo

TOC_RESPONSE_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["chapters"],
    "properties": {
        "chapters": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "required": ["n", "title", "start_page", "end_page"],
                "properties": {
                    "n": {"type": "integer", "minimum": 1},
                    "title": {"type": "string", "minLength": 1},
                    "start_page": {"type": "integer", "minimum": 1},
                    "end_page": {"type": "integer", "minimum": 1},
                    "notes": {"type": "string"},
                },
                "additionalProperties": True,
            },
        }
    },
    "additionalProperties": True,
}

EXTRACT_RESPONSE_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["quotes"],
    "properties": {
        "quotes": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["topic", "verbatim_quote", "why_load_bearing"],
                "properties": {
                    "topic": {"type": "string", "minLength": 1},
                    "verbatim_quote": {"type": "string", "minLength": 1},
                    "why_load_bearing": {"type": "string", "minLength": 1},
                    "page": {"type": "integer", "minimum": 1},
                },
                "additionalProperties": True,
            },
        }
    },
    "additionalProperties": True,
}


def run(cfg: dict, book: BookPaths) -> list[str]:
    transcript = text.load_transcript(book.raw_transcript)
    pages = text.load_pages(book.pages_json)
    n_pages = text.total_pages(pages)
    model = cfg["stages"]["s2"]["model"]

    # --- 1. Detect chapters from front matter ---
    chapters = _detect_chapters(cfg, book, transcript, pages, n_pages, model)
    book.chapter_bounds.write_text(
        json.dumps({"chapters": chapters}, indent=2) + "\n"
    )

    outputs: list[str] = [
        f"detected {len(chapters)} chapter(s)",
        rel_to_repo(book.chapter_bounds),
    ]

    # --- 2a. Pre-write ALL per-chapter request files so the agent/human
    # can fan out responses in parallel. We only skip chapters whose
    # committed chapter MD file already exists.
    pending_chapters: list[dict] = []
    for ch in chapters:
        ch_md_path = book.chapter_file(ch["n"])
        if ch_md_path.exists():
            outputs.append(rel_to_repo(ch_md_path))
            continue
        _write_extract_request(book, transcript, ch, model)
        pending_chapters.append(ch)

    # --- 2b. Consume responses in order. If any response is missing,
    # PendingLLMOutput surfaces — but the other request files already on
    # disk remain available for parallel filling.
    for ch in pending_chapters:
        quotes = _consume_extract_response(cfg, book, transcript, ch, model)
        _write_chapter_file(book, ch, quotes, model)
        outputs.append(rel_to_repo(book.chapter_file(ch["n"])))

    return outputs


# ---------------------------------------------------------------------------
# TOC detection
# ---------------------------------------------------------------------------

_TOC_SYSTEM = """You are extracting the structural outline of a guitar method book from its front matter.

The user will give you the verbatim text of the first ~20 pages of a book.
Identify the chapters or major sections of the book (whichever the book uses
— some method books use "Lesson", "Chapter", "Part", "Section", "Unit").

Output a JSON object with this shape:

  { "chapters": [
      { "n": 1, "title": "...", "start_page": <int>, "end_page": <int> },
      ...
  ] }

Rules:
- `n` is the 1-indexed chapter number you assign (independent of the book's
  own numbering — book may start at 0 or use Roman numerals).
- `title` is the chapter's title as it appears in the book.
- `start_page` is the first page of the chapter; `end_page` is the last.
- If the front matter doesn't list page numbers, infer from the chapter
  headings you see — start_page is where the chapter HEADING appears, and
  end_page is one less than the next chapter's start_page (or the book's
  last page for the final chapter).
- Skip the table of contents itself, the title page, the copyright page,
  the author bio — they are not "chapters" in this sense.
- If the book is short and not subdivided, output a single chapter covering
  the entire content."""


def _detect_chapters(
    cfg: dict,
    book: BookPaths,
    transcript: str,
    pages: list[dict],
    n_pages: int,
    model: str,
) -> list[dict]:
    fm_pages = min(20, n_pages)
    front = text.front_matter(transcript, n_pages=fm_pages)
    # Strip page markers from the prompt so the model doesn't quote them.
    front_clean = text.strip_page_marks(front)

    req = LLMRequest(
        stage="s2",
        scope="toc",
        model=model,
        system_prompt=_TOC_SYSTEM,
        user_prompt=(
            f"Total pages in the book: {n_pages}.\n"
            f"First {fm_pages} pages follow. Identify chapters.\n\n"
            f"<<<TEXT\n{front_clean}\nTEXT>>>"
        ),
        response_schema=TOC_RESPONSE_SCHEMA,
        notes=f"book has {n_pages} pages; using first {fm_pages} as front matter.",
    )
    request_path = book.llm_call_file("s2", "toc", "request")
    response_path = book.llm_call_file("s2", "toc", "response")
    resp = request_llm(req, request_path, response_path)
    return resp["chapters"]


# ---------------------------------------------------------------------------
# Per-chapter extraction
# ---------------------------------------------------------------------------

_EXTRACT_SYSTEM = """You are extracting load-bearing passages from one chapter of a guitar method book.

The user will give you the verbatim text of one chapter. Extract every passage
that does any of the following:

- teaches a technique (how to play, fingering, hand position, picking pattern)
- defines a concept (a chord type, a scale, a position system, a terminology)
- gives a rule (when to do X, what to avoid, what to prefer)
- shows a load-bearing example (an exercise that illustrates a method's
  characteristic move)

Output a JSON object with this shape:

  { "quotes": [
      { "topic": "<short topic label>",
        "verbatim_quote": "<exact substring of the input>",
        "why_load_bearing": "<one sentence on why this passage matters>",
        "page": <int, optional>
      },
      ...
  ] }

CRITICAL RULES:
1. `verbatim_quote` MUST be an EXACT substring of the input text. Do not
   paraphrase. Do not add words. Do not fix typos. Copy character-for-character.
2. If you can't find a substantial passage in the input that fits a topic,
   skip the topic — don't fabricate.
3. Skip prose that is purely biographical, motivational, or transitional.
   Keep prose that teaches.
4. Aim for 3-15 quotes per chapter. A chapter with only one load-bearing
   passage gets one quote; a dense chapter gets many.
5. `topic` is a short label (2-6 words). Use the book's own terminology
   when possible.
6. `why_load_bearing` is one sentence in YOUR voice explaining the
   significance — not a paraphrase of the quote."""


def _chapter_user_prompt(transcript: str, ch: dict) -> str:
    """The prompt body sent for one chapter — shared between
    _write_extract_request and the validator's chapter_text source."""
    chapter_text = text.text_between_pages(
        transcript, ch["start_page"], ch["end_page"]
    )
    chapter_text_clean = text.strip_page_marks(chapter_text)
    return (
        f"Chapter {ch['n']}: {ch['title']}\n"
        f"Pages {ch['start_page']}-{ch['end_page']} of the book.\n\n"
        f"<<<CHAPTER TEXT\n{chapter_text_clean}\nCHAPTER TEXT>>>"
    )


def _write_extract_request(
    book: BookPaths,
    transcript: str,
    ch: dict,
    model: str,
) -> None:
    """Write the request file for one chapter's extraction. Idempotent —
    safe to re-run. Does not consume a response."""
    scope = f"extract-ch{ch['n']:02d}"
    req = LLMRequest(
        stage="s2",
        scope=scope,
        model=model,
        system_prompt=_EXTRACT_SYSTEM,
        user_prompt=_chapter_user_prompt(transcript, ch),
        response_schema=EXTRACT_RESPONSE_SCHEMA,
        notes=f"chapter {ch['n']} extraction",
    )
    request_path = book.llm_call_file("s2", scope, "request")
    # Use request_llm without expecting a response — we just want the
    # request file written. If the response is already on disk, that's
    # fine; we'll consume it in phase 2b.
    request_path.parent.mkdir(parents=True, exist_ok=True)
    request_path.write_text(json.dumps(req.to_dict(), indent=2) + "\n")


# NOTE on retries (behaviour change from the initial scaffold):
# The original implementation embedded a MAX_EXTRACT_RETRIES=2 loop that
# auto-regenerated the request prompt with a tightening hint on
# fidelity failure. The pre-write-all-requests refactor (#297 second
# commit) dropped that loop. Today, on fidelity failure, the stage
# raises and the maintainer/agent edits the response file directly
# (or re-fills it) and re-runs `resume`. The orchestrator's
# awaiting-llm message names this explicitly.


def _consume_extract_response(
    cfg: dict,
    book: BookPaths,
    transcript: str,
    ch: dict,
    model: str,
) -> list[dict]:
    """Read the response file for one chapter, validate quote fidelity,
    return the validated quotes. Raises PendingLLMOutput if missing.

    Validates each quote against the chapter text (tighter check than
    full transcript — catches a model echoing content from outside the
    chapter scope)."""
    scope = f"extract-ch{ch['n']:02d}"
    req = LLMRequest(
        stage="s2",
        scope=scope,
        model=model,
        system_prompt=_EXTRACT_SYSTEM,
        user_prompt=_chapter_user_prompt(transcript, ch),
        response_schema=EXTRACT_RESPONSE_SCHEMA,
        notes=f"chapter {ch['n']} extraction",
    )
    request_path = book.llm_call_file("s2", scope, "request")
    response_path = book.llm_call_file("s2", scope, "response")
    resp = request_llm(req, request_path, response_path)
    quotes = resp["quotes"]

    # Quote-fidelity gate.
    chapter_text = text.text_between_pages(
        transcript, ch["start_page"], ch["end_page"]
    )
    bad = [q for q in quotes if not text.verify_quote_in_transcript(
        q["verbatim_quote"], chapter_text
    )]
    if bad:
        examples = "; ".join(
            f'"{q["verbatim_quote"][:80]}..."' for q in bad[:2]
        )
        raise RuntimeError(
            f"chapter {ch['n']} extraction failed quote-fidelity: "
            f"{len(bad)} of {len(quotes)} quote(s) were NOT exact "
            f"substrings of the chapter. Examples: {examples}. "
            f"Edit the response file at {response_path} and re-resume."
        )

    # Back-fill missing page numbers from a transcript-wide search.
    pages = text.load_pages(book.pages_json)
    for q in quotes:
        if "page" not in q:
            page = text.find_page_of_quote(
                q["verbatim_quote"], transcript, pages
            )
            if page is not None:
                q["page"] = page
    return quotes


# ---------------------------------------------------------------------------
# Writing committed chapter files
# ---------------------------------------------------------------------------


def _write_chapter_file(
    book: BookPaths,
    ch: dict,
    quotes: list[dict],
    model: str,
) -> None:
    """Emit chNN.md with the provenance frontmatter + one section per
    topic. Quotes are wrapped in markdown blockquotes; rationales follow
    as plain prose."""
    ch_n = ch["n"]
    source_pages = f"{ch['start_page']}-{ch['end_page']}"
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s2",
        source_pdf=Path(_source_pdf(book)).name,
        source_pages=source_pages,
        model=model,
    )

    lines: list[str] = [
        prov.yaml_block(),
        "",
        f"# Chapter {ch_n} — {ch['title']}",
        "",
        f"_Pages {source_pages}._",
        "",
        "> **Verbatim-quote constraint.** The quotes below are exact substrings "
        "of the raw transcript produced by `pdftotext`. The transcript may "
        "contain extraction artifacts where the book's typeface confuses the "
        "tool — e.g. `7irst` or `<irst` for `first`, `speci7ic` for `specific`. "
        "**Do NOT manually fix these in this file**: the quote-fidelity "
        "validator compares against the raw transcript, so a 'fixed' quote "
        "will fail verification and break Stage 2 idempotency. If a future "
        "pipeline iteration adds artifact-normalization, it must normalize "
        "the transcript and these files together.",
        "",
    ]
    if not quotes:
        lines.append(
            "_No load-bearing passages identified in this chapter._\n"
        )

    by_topic: dict[str, list[dict]] = {}
    for q in quotes:
        by_topic.setdefault(q["topic"], []).append(q)

    for topic, items in by_topic.items():
        lines.append(f"## {topic}")
        lines.append("")
        for q in items:
            page = q.get("page")
            page_suffix = f" (p. {page})" if page else ""
            quote_text = q["verbatim_quote"].strip()
            for line in quote_text.splitlines():
                lines.append(f"> {line}".rstrip())
            lines.append("")
            lines.append(f"**Significance{page_suffix}.** {q['why_load_bearing'].strip()}")
            lines.append("")

    book.committed_chapters_dir.mkdir(parents=True, exist_ok=True)
    book.chapter_file(ch_n).write_text("\n".join(lines).rstrip() + "\n")


def _source_pdf(book: BookPaths) -> str:
    """Best-effort recovery of the source PDF path from stage-state.

    Avoids a second config read; the state file path leads to the
    config which leads to the PDF. We only need the basename for
    provenance, so a fallback to the work_id is acceptable.

    Catches only the specific failure modes the lookup chain can produce
    (missing file, malformed TOML, missing config-key). A broader
    `except Exception` would hide real bugs in the call site.
    """
    import tomllib

    try:
        state = json.loads(book.state_file.read_text())
        cfg = tomllib.loads(Path(state["config"]).read_text())
        return cfg["source"]["pdf"]
    except (FileNotFoundError, json.JSONDecodeError, tomllib.TOMLDecodeError, KeyError):
        return book.work_id  # fallback; better than nothing
