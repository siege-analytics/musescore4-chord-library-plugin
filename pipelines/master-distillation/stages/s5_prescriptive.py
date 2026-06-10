"""Stage 5 — Prescriptive lessons.

Reads the chapter files (Stage 2), chapter summaries (Stage 3), book
summary (Stage 3), and systems-draft.json (Stage 4) and produces:

  - plugin/data/masters-corpus/<master>/<work>/derived/prescriptive-lessons-draft.json
    A candidate `usage_notes[]` array in the shape required by
    schema/masters.schema.json $defs/usage_note (#415, PR #416). Each
    entry is keyed by `chord_quality` and carries a prescriptive
    narrative — the specific lesson the master teaches for that chord
    quality, NOT the master's general organizing principles (those go
    in s4's systems-draft).

  - plugin/data/masters-corpus/<master>/<work>/derived/PRESCRIPTIVE.md
    Human-readable review surface for the extracted lessons before
    injection into masters.json.

Why a separate stage from s4: s4 extracts the master's organizing
ABSTRACTIONS (principles + systems with traversal/modification rules).
s5 extracts the master's CONCRETE PRESCRIPTIONS per chord-quality —
'for m7b5, voice it on string set 5-2 with the b5 on top, substituting
altered V via the tritone, because ...' This is the level of granularity
project-owner feedback explicitly asked for: real prescriptive lessons,
not principle-level summaries (see plugin#419 design note).

The draft is NOT auto-injected into masters.json. A separate review +
injection step (after human eyeballing PRESCRIPTIVE.md) places the
content into the master's `usage_notes[]` block. This keeps the
schema's `provenance: 'extracted'` flag honest — the human ran the
extraction, reviewed it, and approved injection.

Run with the largest local model available (judgment-heavy stage, same
profile as s4).
"""

from __future__ import annotations

import json
from pathlib import Path

from lib import provenance
from lib.llm import LLMRequest, request_llm
from lib.paths import BookPaths, rel_to_repo


def run(cfg: dict, book: BookPaths) -> list[str]:
    if not book.book_summary.exists():
        raise FileNotFoundError(
            f"book summary missing at {book.book_summary}; "
            f"Stage 3 must complete first."
        )
    if not book.systems_draft.exists():
        raise FileNotFoundError(
            f"systems draft missing at {book.systems_draft}; "
            f"Stage 4 must complete first."
        )

    chapter_bounds = json.loads(book.chapter_bounds.read_text())["chapters"]
    chapter_summaries = [
        book.chapter_summary(ch["n"]).read_text() for ch in chapter_bounds
    ]
    chapter_files = [
        book.chapter_file(ch["n"]).read_text() for ch in chapter_bounds
    ]
    book_summary = book.book_summary.read_text()
    systems_draft = json.loads(book.systems_draft.read_text())

    model = cfg["stages"]["s5"]["model"]
    source_pdf_name = Path(cfg["source"]["pdf"]).name

    # --- prescriptive-lessons-draft.json ---
    usage_notes_payload = _derive_usage_notes(
        cfg, book, book_summary, chapter_summaries, chapter_files,
        systems_draft, model,
    )
    _write_usage_notes_draft(book, usage_notes_payload, model, source_pdf_name)

    # --- PRESCRIPTIVE.md (human-review surface) ---
    prescriptive_md = _write_prescriptive_prose(
        cfg, book, book_summary, usage_notes_payload, model,
    )
    _write_prescriptive(book, prescriptive_md, model, source_pdf_name)

    return [
        rel_to_repo(book.prescriptive_lessons_draft),
        rel_to_repo(book.prescriptive_md),
        f"extracted {len(usage_notes_payload['usage_notes'])} prescriptive "
        f"lesson(s) across "
        f"{len({n['chord_quality'] for n in usage_notes_payload['usage_notes']})} "
        f"distinct chord_quality value(s); see "
        f"{book.prescriptive_lessons_draft.name}",
    ]


# ---------------------------------------------------------------------------

_USAGE_NOTES_SYSTEM = """You are extracting per-chord-quality PRESCRIPTIVE LESSONS from a guitar method book.

A PRESCRIPTIVE LESSON is what the master tells the student to DO with a specific chord quality — the voicing recommendation, the substitution rule, the voice-leading move, the rationale. It is NOT the master's general organizing principles (those are upstream in the systems[] taxonomy). It is the concrete, actionable, per-chord application of those principles.

Examples of GOOD prescriptive lessons:
  - "For m7b5, Laukens prescribes substituting altered V on the tritone — the m7b5 root becomes the b5 of the altered V — voiced on string set 6-3 with the b5 on top. Page 47, chapter 3."
  - "For dom7 in bebop comping, Pass teaches the R-3-7 shell dressed with #9 or b9 on top, anticipated on the upbeat of 4 of the prior bar. Page 23, chapter 2."

Examples of BAD (too abstract — these belong in the s4 principles/systems):
  - "Laukens organizes his vocabulary by function." (principle, not lesson)
  - "Pass treats dom7 as the most-substituted chord." (organizing claim, not actionable prescription)

You will be given:
  - The book-level summary (s3 output)
  - All chapter summaries (s3 output)
  - All chapter files (s2 output, with quoted source passages)
  - The systems-draft JSON (s4 output) so you know the master's organizing framework

Output a JSON object with this shape:

  {
    "master_id": "<from config>",
    "work_id": "<from config>",
    "usage_notes": [
      {
        "chord_quality": "<value from voicings.json voicings[].chord_quality vocabulary; e.g. maj7, min7, min7b5, dom7, dom7b9, dom7alt, min-maj7, dim7, aug7, sus4, sus2, etc.>",
        "function_role": "<free text — the master's named function for this chord, e.g. 'predominant-in-minor-ii-V-i', 'tonic-substitute', 'passing-diminished'>",
        "narrative": "<1-3 sentences. Prescriptive. Cite the page or chapter where this is taught. Use direct quotes from the chapter files when possible.>",
        "source_principle_ids": ["<refs to principles[].id from the master's existing principles[] when the lesson grounds in one>"],
        "source_work_id": "<from config>",
        "references": [
          { "source": "<book id>", "citation": "<chapter X p.Y>" }
        ],
        "provenance": "extracted"
      }
    ]
  }

RULES:
  1. Only include `chord_quality` values explicitly discussed in the book. If the book never addresses sus4 chords, do not invent a lesson for sus4.
  2. Every narrative MUST cite a chapter and page (or chapter number if pagination isn't preserved). If you cannot cite, omit the lesson.
  3. Multiple lessons per chord_quality are allowed (e.g., the master may treat dom7 differently in chapter 3 vs chapter 7). Each gets its own entry.
  4. `provenance: 'extracted'` is REQUIRED on every entry. Do not emit entries you'd need to mark 'inferred-from-principles' — those belong to the placeholder pass, not this extraction.
  5. If the master draws a diagram for a voicing, mention it in the narrative ("see diagram p.47").
  6. function_role values: free text in kebab-case. Don't strain to match an existing taxonomy.

Return ONLY the JSON object. No prose wrapper, no markdown code fence.
"""


def _derive_usage_notes(
    cfg: dict,
    book: BookPaths,
    book_summary: str,
    chapter_summaries: list[str],
    chapter_files: list[str],
    systems_draft: dict,
    model: str,
) -> dict:
    """Single-shot LLM call producing the usage_notes payload.

    For long books the prompt may exceed the model's context. If that
    becomes an issue, split per-chapter and merge — but start with the
    single-shot for honesty (the model sees the whole book at once and
    can balance lessons across chapters).
    """
    user_prompt = (
        f"BOOK-LEVEL SUMMARY:\n\n{book_summary}\n\n"
        f"CHAPTER SUMMARIES (s3):\n\n"
        + "\n\n---\n\n".join(chapter_summaries)
        + f"\n\nCHAPTER FILES (s2, with quoted passages):\n\n"
        + "\n\n---\n\n".join(chapter_files)
        + f"\n\nSYSTEMS-DRAFT JSON (s4):\n\n{json.dumps(systems_draft, indent=2)}\n\n"
        f"master_id (from config): {cfg['master']['id']}\n"
        f"work_id (from config): {cfg['work']['id']}\n"
    )

    req = LLMRequest(
        stage="s5",
        scope="usage-notes",
        model=model,
        system_prompt=_USAGE_NOTES_SYSTEM,
        user_prompt=user_prompt,
        response_schema=None,
        notes="per-chord-quality prescriptive lessons",
    )
    request_path = book.llm_call_file("s5", "usage-notes", "request")
    response_path = book.llm_call_file("s5", "usage-notes", "response")
    resp = request_llm(req, request_path, response_path)
    text = resp["text"].strip()
    # Tolerate accidental code-fencing
    if text.startswith("```"):
        text = text.strip("`")
        # may now start with "json\n"
        if text.startswith("json"):
            text = text[4:].lstrip()
    payload = json.loads(text)

    # Normalize: ensure master_id and work_id match config (LLM sometimes
    # echoes from elsewhere in the prompt).
    payload["master_id"] = cfg["master"]["id"]
    payload["work_id"] = cfg["work"]["id"]

    # Ensure every entry carries provenance: 'extracted'. If the model
    # omitted it, fill it in (safer than failing).
    for note in payload.get("usage_notes", []):
        note.setdefault("provenance", "extracted")
        note.setdefault("source_work_id", cfg["work"]["id"])

    return payload


# ---------------------------------------------------------------------------

_PRESCRIPTIVE_SYSTEM = """You are producing a human-readable review surface (PRESCRIPTIVE.md) for the extracted prescriptive lessons.

The reviewer (a curator who knows the source book) will skim this file to confirm or refute each lesson before injection into masters.json. Group lessons by chord_quality. For each group, write 2-3 sentences synthesizing the master's teaching, followed by the per-lesson narratives as bullets. Keep prose tight; the reviewer wants signal density, not eloquence.

Format:

# Prescriptive lessons — <master_id> × <work_id>

## maj7
2-3 sentence synthesis of how this master treats maj7 across the book.

- [ch.X p.Y] First lesson narrative.
- [ch.A p.B] Second lesson narrative.

## min7
...

Return ONLY the markdown. No JSON, no preamble.
"""


def _write_prescriptive_prose(
    cfg: dict,
    book: BookPaths,
    book_summary: str,
    usage_notes_payload: dict,
    model: str,
) -> str:
    user_prompt = (
        f"BOOK SUMMARY:\n\n{book_summary}\n\n"
        f"USAGE NOTES JSON (just extracted):\n\n"
        f"{json.dumps(usage_notes_payload, indent=2)}\n"
    )

    req = LLMRequest(
        stage="s5",
        scope="prescriptive-md",
        model=model,
        system_prompt=_PRESCRIPTIVE_SYSTEM,
        user_prompt=user_prompt,
        response_schema=None,
        notes="human-readable review surface for extracted prescriptive lessons",
    )
    request_path = book.llm_call_file("s5", "prescriptive-md", "request")
    response_path = book.llm_call_file("s5", "prescriptive-md", "response")
    resp = request_llm(req, request_path, response_path)
    return resp["text"].strip()


# ---------------------------------------------------------------------------

def _write_usage_notes_draft(
    book: BookPaths,
    payload: dict,
    model: str,
    source_pdf_name: str,
) -> None:
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s5",
        source_pdf=source_pdf_name,
        source_pages=None,
        model=model,
    )
    body = {
        "_provenance": prov.json_block(),
        **payload,
    }
    book.committed_derived_dir.mkdir(parents=True, exist_ok=True)
    book.prescriptive_lessons_draft.write_text(json.dumps(body, indent=2) + "\n")


def _write_prescriptive(
    book: BookPaths,
    prescriptive_md: str,
    model: str,
    source_pdf_name: str,
) -> None:
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s5",
        source_pdf=source_pdf_name,
        source_pages=None,
        model=model,
    )
    text_out = prov.yaml_block() + "\n\n" + prescriptive_md.strip() + "\n"
    book.prescriptive_md.write_text(text_out)
