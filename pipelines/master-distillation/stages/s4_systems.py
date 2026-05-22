"""Stage 4 — Statement of outputs.

Reads the chapter files (Stage 2) + chapter and book summaries (Stage 3)
and produces:

  - plugin/data/masters-corpus/<master>/<work>/derived/systems-draft.json
    A candidate `systems[]` (or `works[]/systems[]`) in the masters.json
    shape, including engine_payload.kind values drawn from the 12 names
    traced to predecessor session 260521-aware-nebula's schema-systems-model.md.
    When uncertain about a kind, use `_pending:<kebab>` — the schema
    accepts that and #298 will define the formal kind set.

  - plugin/data/masters-corpus/<master>/<work>/derived/STATEMENT.md
    The human-readable statement weaving the systems together, citing
    chapter summaries and underlying quotes.

This is the judgment-heaviest stage. Run with the largest local model
available (or cloud-Sonnet via the file-dance fallback).
"""

from __future__ import annotations

import json
from pathlib import Path

from lib import provenance
from lib.llm import LLMRequest, request_llm
from lib.paths import BookPaths

ALLOWED_KINDS = [
    "PositionContinuity",
    "VoiceMotion",
    "StringSetTransition",
    "SymmetryMovement",
    "FamilyCoherence",
    "SubstitutionExpand",
    "DensityFloor",
    "DensityCeiling",
    "OmissionAllow",
    "ColorToneRequire",
    "NCTHarmonization",
    "TextureCycle",
]

# Validation schema mirrors a subset of schema/masters.schema.json for
# the systems[] array we generate. We don't validate the full master
# wrapper; that's the human reviewer's job during the Stage B PR.
SYSTEMS_DRAFT_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["master_id", "work_id", "systems"],
    "properties": {
        "master_id": {"type": "string"},
        "work_id": {"type": "string"},
        "systems": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["id", "name"],
                "properties": {
                    "id": {"type": "string", "minLength": 1},
                    "name": {"type": "string", "minLength": 1},
                    "summary": {"type": "string"},
                    "members": {"type": "array"},
                    "traversal_rules": {"type": "array"},
                    "modification_rules": {"type": "array"},
                    "references": {"type": "array"},
                },
                "additionalProperties": True,
            },
        },
    },
    "additionalProperties": True,
}


def run(cfg: dict, book: BookPaths) -> list[str]:
    if not book.book_summary.exists():
        raise FileNotFoundError(
            f"book summary missing at {book.book_summary}; "
            f"Stage 3 must complete first."
        )

    chapter_bounds = json.loads(book.chapter_bounds.read_text())["chapters"]
    chapter_summaries = [
        book.chapter_summary(ch["n"]).read_text() for ch in chapter_bounds
    ]
    chapter_files = [
        book.chapter_file(ch["n"]).read_text() for ch in chapter_bounds
    ]
    book_summary = book.book_summary.read_text()

    model = cfg["stages"]["s4"]["model"]
    source_pdf_name = Path(cfg["source"]["pdf"]).name

    # --- systems-draft.json ---
    systems_payload = _derive_systems(
        cfg, book, book_summary, chapter_summaries, chapter_files, model
    )
    _write_systems_draft(book, systems_payload, model, source_pdf_name)

    # --- STATEMENT.md ---
    statement = _write_statement_prose(
        cfg, book, book_summary, chapter_summaries, systems_payload, model
    )
    _write_statement(book, statement, model, source_pdf_name)

    return [
        _rel_to_repo(book, book.systems_draft),
        _rel_to_repo(book, book.statement),
        f"derived {len(systems_payload['systems'])} system(s); "
        f"see {book.systems_draft.name}",
    ]


# ---------------------------------------------------------------------------

_SYSTEMS_SYSTEM = """You are deriving structured "systems" from the distilled summary of a guitar method book.

A SYSTEM is a graph-with-rules. It has:
  - members[]: the taxonomy (the things this system operates over — chord
    types, position regions, voicing categories, scale forms, etc.)
  - traversal_rules[]: how you MOVE between members (preference for
    common-tone voice motion, pivot-finger shifts, position continuity,
    etc.)
  - modification_rules[]: how you ALTER a member (substitution lattices,
    voicing density changes, omission policies, color-tone requirements,
    etc.)

Each rule carries an `engine_payload` with a `kind` field. The kind is
either ONE of these 12 names (use exactly as spelled):

  PositionContinuity, VoiceMotion, StringSetTransition, SymmetryMovement,
  FamilyCoherence, SubstitutionExpand, DensityFloor, DensityCeiling,
  OmissionAllow, ColorToneRequire, NCTHarmonization, TextureCycle

OR a `_pending:<short-kebab-slug>` placeholder when no name in the list
clearly fits. When in doubt, USE `_pending:`. Do not stretch a name to fit.
The formal definitions of these kinds are pending (#298); your job today
is to pick the best label or honestly admit uncertainty.

Output a JSON object with this shape:

  {
    "master_id": "<from config>",
    "work_id": "<from config>",
    "systems": [
      {
        "id": "<master_id>:<work_id>:<system-slug>",
        "name": "<full system name>",
        "summary": "<one-paragraph prose>",
        "members": [
          { "id": "<slug>", "name": "<full name>", "summary": "<optional>" }
        ],
        "traversal_rules": [
          {
            "id": "<slug>",
            "name": "<full name>",
            "summary": "<one sentence>",
            "engine_payload": { "kind": "<kind-name or _pending:slug>" }
          }
        ],
        "modification_rules": [...]
      }
    ]
  }

Guidance:
- Three-segment system ids. Slug is kebab-case. Example:
  "benson:method-vol-1-chord-construction:harmonized-scale"
- Aim for 1-4 systems per book. A book usually has ONE central system plus
  optionally a few smaller ones.
- A system MUST have non-empty members AND at least one rule (traversal
  or modification) — empty systems are not useful.
- members[], traversal_rules[], modification_rules[] are all optional fields
  per the schema, but a real system has at least members + one rule kind.
- If the book teaches a system you can't structure as members+rules,
  describe it in `summary` and leave members/rules empty rather than
  inventing.
- Do not include `references[]` — that gets added by a later step
  pointing back at chapter files.
"""


def _derive_systems(
    cfg: dict,
    book: BookPaths,
    book_summary: str,
    chapter_summaries: list[str],
    chapter_files: list[str],
    model: str,
) -> dict:
    summaries_bundle = "\n\n---\n\n".join(chapter_summaries)
    chapters_bundle = "\n\n---\n\n".join(chapter_files)

    user_prompt = (
        f"Master id: {cfg['master']['id']}\n"
        f"Work id: {cfg['work']['id']}\n\n"
        f"BOOK-LEVEL DISTILLATION:\n\n{book_summary}\n\n"
        f"CHAPTER SUMMARIES:\n\n{summaries_bundle}\n\n"
        f"COMMITTED CHAPTER FILES (verbatim quotes + rationales):\n\n"
        f"{chapters_bundle}\n"
    )

    req = LLMRequest(
        stage="s4",
        scope="systems",
        model=model,
        system_prompt=_SYSTEMS_SYSTEM,
        user_prompt=user_prompt,
        response_schema=SYSTEMS_DRAFT_SCHEMA,
        notes=(
            f"derive systems[] for {cfg['master']['id']}/"
            f"{cfg['work']['id']}; use _pending: when unsure about kind."
        ),
    )
    request_path = book.llm_call_file("s4", "systems", "request")
    response_path = book.llm_call_file("s4", "systems", "response")
    resp = request_llm(req, request_path, response_path)

    _validate_engine_kinds(resp)
    return resp


def _validate_engine_kinds(payload: dict) -> None:
    """Verify every engine_payload.kind is either in ALLOWED_KINDS or
    matches `_pending:<kebab>`. Schema-level enforcement; raises on miss.
    """
    import re

    pending_pat = re.compile(r"^_pending:[a-z0-9-]+$")
    offenders: list[str] = []
    for system in payload.get("systems", []):
        for rules_key in ("traversal_rules", "modification_rules"):
            for rule in system.get(rules_key, []) or []:
                kind = (rule.get("engine_payload") or {}).get("kind")
                if kind is None:
                    continue
                if kind in ALLOWED_KINDS:
                    continue
                if pending_pat.match(kind):
                    continue
                offenders.append(
                    f"system '{system.get('id')}' rule '{rule.get('id')}': "
                    f"kind '{kind}'"
                )
    if offenders:
        raise ValueError(
            "Stage 4 produced engine_payload.kind values that are neither "
            "in the predecessor's 12 names nor `_pending:<kebab>`: "
            + "; ".join(offenders[:5])
            + (f"; +{len(offenders) - 5} more" if len(offenders) > 5 else "")
        )


# ---------------------------------------------------------------------------

_STATEMENT_SYSTEM = """You are writing the "statement of outputs" — a human-readable narrative that
synthesizes everything the book teaches into a coherent description of the master/work's method.

The user will give you the book-level distillation, the chapter summaries, and
the structured systems-draft JSON you just derived. Write the statement.

Structure:

  # <Work Title> — Statement of Outputs

  ## Overview
  (2-3 paragraphs on what the book is and what it teaches, citing the
  book-level distillation.)

  ## Systems
  For each system in the systems-draft, one ## section. For each:
    - one paragraph describing the system in plain language
    - the system's members listed
    - the traversal rules and modification rules listed with their
      engine_payload kinds shown in code formatting
    - citations back to the relevant chapter summaries that backed each
      claim (e.g. "(Chapter 2 summary; ch02.md quotes)")

  ## Pending Work
  List every `_pending:<kebab>` engine_payload.kind value with what it
  signals. If there are none, omit this section.

  ## Provenance Notes
  Brief: what's drawn from what. Note any chapters that didn't yield a
  system and why.

This is the human-facing artifact. Be precise, cite, and don't invent
content outside the summaries and quote files."""


def _write_statement_prose(
    cfg: dict,
    book: BookPaths,
    book_summary: str,
    chapter_summaries: list[str],
    systems_payload: dict,
    model: str,
) -> str:
    user_prompt = (
        f"BOOK-LEVEL DISTILLATION:\n\n{book_summary}\n\n"
        f"CHAPTER SUMMARIES:\n\n"
        + "\n\n---\n\n".join(chapter_summaries)
        + f"\n\nSYSTEMS-DRAFT JSON:\n\n{json.dumps(systems_payload, indent=2)}\n"
    )

    req = LLMRequest(
        stage="s4",
        scope="statement",
        model=model,
        system_prompt=_STATEMENT_SYSTEM,
        user_prompt=user_prompt,
        response_schema=None,
        notes="human-readable statement of outputs",
    )
    request_path = book.llm_call_file("s4", "statement", "request")
    response_path = book.llm_call_file("s4", "statement", "response")
    resp = request_llm(req, request_path, response_path)
    return resp["text"].strip()


# ---------------------------------------------------------------------------

def _write_systems_draft(
    book: BookPaths,
    payload: dict,
    model: str,
    source_pdf_name: str,
) -> None:
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s4",
        source_pdf=source_pdf_name,
        source_pages=None,
        model=model,
    )
    body = {
        "_provenance": prov.json_block(),
        **payload,
    }
    book.committed_derived_dir.mkdir(parents=True, exist_ok=True)
    book.systems_draft.write_text(json.dumps(body, indent=2) + "\n")


def _write_statement(
    book: BookPaths,
    statement: str,
    model: str,
    source_pdf_name: str,
) -> None:
    prov = provenance.Provenance(
        run_id=book.run_id,
        stage="s4",
        source_pdf=source_pdf_name,
        source_pages=None,
        model=model,
    )
    text_out = prov.yaml_block() + "\n\n" + statement.strip() + "\n"
    book.statement.write_text(text_out)


def _rel_to_repo(book: BookPaths, p: Path) -> str:
    repo_root = book.run_dir.parent.parent.parent
    try:
        return str(p.relative_to(repo_root))
    except ValueError:
        return str(p)
