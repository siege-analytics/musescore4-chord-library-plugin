"""Tests for the master-distillation pipeline (#297).

Covers load-bearing helpers in `pipelines/master-distillation/`:
  - lib/text.py: page slicing, quote verification, page lookup
  - lib/state.py: state machine transitions, next-runnable logic
  - lib/paths.py: rel_to_repo, BookPaths properties
  - lib/llm.py: PendingLLMOutput shape, schema validation on response load
  - stages/s4_systems.py: _validate_engine_kinds + schema sync

Doesn't test stage `run()` end-to-end — those are LLM-driven and tested
by the actual Benson Vol 1 run committed under
plugin/data/masters-corpus/benson/.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
PIPELINE_DIR = REPO_ROOT / "pipelines" / "master-distillation"
sys.path.insert(0, str(PIPELINE_DIR))

from lib import paths, state, text  # noqa: E402
from lib.llm import LLMRequest, PendingLLMOutput, request_llm  # noqa: E402
from lib.paths import BookPaths, rel_to_repo  # noqa: E402
from stages import s4_systems  # noqa: E402


# === lib/text.py ===

PAGES_FIXTURE = "Page-1 content.\n<!-- page 1 end -->\nPage-2 content.\n<!-- page 2 end -->\nPage-3 content.\n<!-- page 3 end -->\n"


def test_text_between_pages_first_page():
    out = text.text_between_pages(PAGES_FIXTURE, 1, 1)
    assert "Page-1 content" in out
    assert "Page-2 content" not in out


def test_text_between_pages_last_page():
    out = text.text_between_pages(PAGES_FIXTURE, 3, 3)
    assert "Page-3 content" in out
    assert "Page-2 content" not in out


def test_text_between_pages_span():
    out = text.text_between_pages(PAGES_FIXTURE, 1, 3)
    assert "Page-1" in out and "Page-2" in out and "Page-3" in out


def test_text_between_pages_end_beyond_transcript():
    # end_page=99 well past last marker → returns through end-of-string
    out = text.text_between_pages(PAGES_FIXTURE, 2, 99)
    assert "Page-2" in out and "Page-3" in out


def test_text_between_pages_missing_start_marker_raises():
    # No marker for page 7 (only 3 pages exist)
    with pytest.raises(ValueError, match="no page-end marker"):
        text.text_between_pages(PAGES_FIXTURE, 8, 9)


def test_strip_page_marks():
    cleaned = text.strip_page_marks(PAGES_FIXTURE)
    assert "<!-- page" not in cleaned
    assert "Page-1 content" in cleaned


def test_verify_quote_whitespace_normalized():
    """Quote with extra whitespace should still match the source."""
    transcript = "  The   guitar fretboard   is a matrix.  "
    quote = "The guitar fretboard is a matrix."
    assert text.verify_quote_in_transcript(quote, transcript)


def test_verify_quote_paraphrased_rejected():
    """Paraphrased quote must NOT verify even with whitespace normalization."""
    transcript = "The guitar fretboard is a matrix."
    paraphrase = "The fretboard of the guitar is a matrix."  # word order changed
    assert not text.verify_quote_in_transcript(paraphrase, transcript)


def test_verify_quote_pdftotext_artifact_NOT_normalized():
    """Documents the known footgun: pdftotext extraction artifacts (e.g. '7irst'
    for 'first') are NOT normalized by the validator. The chapter-file
    frontmatter callout exists to warn maintainers."""
    transcript = "He focused on the 7irst chord."
    quote_with_artifact = "He focused on the 7irst chord."
    quote_corrected = "He focused on the first chord."
    assert text.verify_quote_in_transcript(quote_with_artifact, transcript)
    # The "corrected" version doesn't match. This is the footgun documented
    # in the chapter-file frontmatter.
    assert not text.verify_quote_in_transcript(quote_corrected, transcript)


def test_find_page_of_quote_single_page():
    pages = [
        {"n": 1, "start": 0, "length": 20, "preview": "Page-1"},
        {"n": 2, "start": 20, "length": 20, "preview": "Page-2"},
        {"n": 3, "start": 40, "length": 20, "preview": "Page-3"},
    ]
    assert text.find_page_of_quote("Page-2 content", PAGES_FIXTURE, pages) == 2


def test_find_page_of_quote_missing_returns_none():
    pages = [{"n": 1, "start": 0, "length": 20, "preview": "Page-1"}]
    assert text.find_page_of_quote("nonexistent text", PAGES_FIXTURE, pages) is None


def test_total_pages():
    pages = [{"n": 1}, {"n": 2}, {"n": 3}]
    assert text.total_pages(pages) == 3
    assert text.total_pages([]) == 0


# === lib/state.py ===


def test_state_initial_runnable_is_s1():
    run = state.RunState.new("test-run", "config.toml")
    assert run.next_runnable_stage() == "s1"


def test_state_pending_blocked_by_earlier_unaccepted():
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "awaiting-review"
    # s2 is pending but s1 isn't accepted → no runnable stage
    assert run.next_runnable_stage() is None


def test_state_pending_unblocked_after_advance():
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "awaiting-review"
    run.advance("s1")
    assert run.next_runnable_stage() == "s2"


def test_state_running_resumable():
    """Crash mid-stage leaves status='running'; resume should pick back up."""
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "accepted"
    run.stages["s2"].status = "running"
    assert run.next_runnable_stage() == "s2"


def test_state_awaiting_llm_resumable():
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "accepted"
    run.stages["s2"].status = "awaiting-llm"
    assert run.next_runnable_stage() == "s2"


def test_state_awaiting_review_blocks():
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "accepted"
    run.stages["s2"].status = "awaiting-review"
    assert run.next_runnable_stage() is None


def test_state_error_blocks():
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "accepted"
    run.stages["s2"].status = "error"
    assert run.next_runnable_stage() is None


def test_state_all_accepted_returns_none():
    run = state.RunState.new("test-run", "config.toml")
    for s in state.STAGE_ORDER:
        run.stages[s].status = "accepted"
    assert run.next_runnable_stage() is None


def test_state_redo_resets_downstream():
    run = state.RunState.new("test-run", "config.toml")
    for s in state.STAGE_ORDER:
        run.stages[s].status = "accepted"
    run.redo("s2")
    assert run.stages["s1"].status == "accepted"  # earlier preserved
    assert run.stages["s2"].status == "pending"
    assert run.stages["s3"].status == "pending"  # downstream reset
    assert run.stages["s4"].status == "pending"


def test_state_save_load_roundtrip(tmp_path):
    run = state.RunState.new("test-run", "config.toml")
    run.stages["s1"].status = "accepted"
    run.stages["s2"].outputs = ["a.txt", "b.txt"]
    path = tmp_path / "state.json"
    run.save(path)
    reloaded = state.RunState.load(path)
    assert reloaded.run_id == "test-run"
    assert reloaded.stages["s1"].status == "accepted"
    assert reloaded.stages["s2"].outputs == ["a.txt", "b.txt"]


# === lib/paths.py ===


def test_rel_to_repo_inside_repo():
    p = REPO_ROOT / "plugin" / "data" / "voicings.json"
    out = rel_to_repo(p)
    assert out == "plugin/data/voicings.json"


def test_rel_to_repo_outside_repo(tmp_path):
    """A path outside the repo falls back to absolute."""
    p = tmp_path / "elsewhere.txt"
    out = rel_to_repo(p)
    assert out == str(p)


def test_book_paths_canonical_layout():
    book = BookPaths(master_id="test", work_id="vol-1", run_id="2026-01-01-test")
    assert book.run_dir.name == "2026-01-01-test"
    assert book.committed_chapters_dir.name == "chapters"
    assert book.chapter_file(3).name == "ch03.md"
    assert book.committed_summaries_dir.name == "summaries"
    assert book.book_summary.name == "vol-1-book-summary.md"
    assert book.systems_draft.name == "systems-draft.json"
    assert book.statement.name == "STATEMENT.md"


# === lib/llm.py ===


def test_request_llm_writes_request_and_raises_when_no_response(tmp_path):
    req = LLMRequest(
        stage="s2", scope="probe", model="test",
        system_prompt="sys", user_prompt="usr",
        response_schema={"type": "object", "required": ["x"], "properties": {"x": {"type": "string"}}},
    )
    request_path = tmp_path / "req.json"
    response_path = tmp_path / "resp.json"
    with pytest.raises(PendingLLMOutput):
        request_llm(req, request_path, response_path)
    assert request_path.exists()
    data = json.loads(request_path.read_text())
    assert data["scope"] == "probe"
    assert data["user_prompt"] == "usr"


def test_request_llm_loads_response(tmp_path):
    req = LLMRequest(
        stage="s2", scope="probe", model="test",
        system_prompt="sys", user_prompt="usr",
        response_schema={"type": "object", "required": ["x"], "properties": {"x": {"type": "string"}}},
    )
    request_path = tmp_path / "req.json"
    response_path = tmp_path / "resp.json"
    response_path.write_text(json.dumps({"x": "hello"}))
    out = request_llm(req, request_path, response_path)
    assert out == {"x": "hello"}


def test_request_llm_rejects_schema_violation(tmp_path):
    req = LLMRequest(
        stage="s2", scope="probe", model="test",
        system_prompt="sys", user_prompt="usr",
        response_schema={"type": "object", "required": ["x"], "properties": {"x": {"type": "string"}}},
    )
    request_path = tmp_path / "req.json"
    response_path = tmp_path / "resp.json"
    response_path.write_text(json.dumps({"y": "wrong field"}))
    with pytest.raises(ValueError, match="schema validation"):
        request_llm(req, request_path, response_path)


def test_request_llm_rejects_invalid_json(tmp_path):
    req = LLMRequest(
        stage="s2", scope="probe", model="test",
        system_prompt="sys", user_prompt="usr",
        response_schema=None,
    )
    request_path = tmp_path / "req.json"
    response_path = tmp_path / "resp.json"
    response_path.write_text("{not valid json")
    with pytest.raises(ValueError, match="not valid JSON"):
        request_llm(req, request_path, response_path)


# === stages/s4_systems.py ===


def _systems_payload(rules_key: str, kind: str) -> dict:
    """Build a minimal systems-draft payload with one rule of the given kind
    in the named bucket. References array required by schema."""
    return {
        "master_id": "test",
        "work_id": "vol-1",
        "systems": [{
            "id": "test:vol-1:foo",
            "name": "Foo",
            "members": [{"id": "x", "name": "X"}],
            rules_key: [{
                "id": "r1",
                "name": "Rule 1",
                "engine_payload": {"kind": kind},
                "references": [{"chapter_n": 1, "topic": "x"}],
            }],
        }],
    }


def test_validate_engine_kinds_accepts_named():
    payload = _systems_payload("traversal_rules", "VoiceMotion")
    s4_systems._validate_engine_kinds(payload)  # no raise


def test_validate_engine_kinds_accepts_pending():
    payload = _systems_payload("modification_rules", "_pending:something-new")
    s4_systems._validate_engine_kinds(payload)


def test_validate_engine_kinds_rejects_invented_name():
    payload = _systems_payload("traversal_rules", "InventedKind")
    with pytest.raises(ValueError, match="InventedKind"):
        s4_systems._validate_engine_kinds(payload)


def test_validate_engine_kinds_rejects_pending_not_kebab():
    payload = _systems_payload("traversal_rules", "_pending:NotKebab")
    with pytest.raises(ValueError, match="NotKebab"):
        s4_systems._validate_engine_kinds(payload)


def test_validate_engine_kinds_walks_preferences():
    """Preferences[] entries must be validated too. The pre-fix version
    skipped this bucket — invented kinds could slip through via preferences."""
    payload = _systems_payload("preferences", "InventedKind")
    with pytest.raises(ValueError, match="InventedKind"):
        s4_systems._validate_engine_kinds(payload)


def test_allowed_kinds_count_is_12():
    """The 12-name enum should not drift without explicit update."""
    assert len(s4_systems.ALLOWED_KINDS) == 12


def test_allowed_kinds_matches_masters_schema():
    """ALLOWED_KINDS in s4 must match the enum in schema/masters.schema.json."""
    schema = json.loads((REPO_ROOT / "schema" / "masters.schema.json").read_text())
    schema_enum = schema["$defs"]["engine_payload"]["properties"]["kind"]["anyOf"][0]["enum"]
    assert set(s4_systems.ALLOWED_KINDS) == set(schema_enum)


def test_systems_draft_schema_requires_references_per_rule():
    """The pipeline's Stage 4 schema must require references[] on every rule
    to defend against stretch failures (Benson DensityCeiling-for-no-b9, etc.)."""
    rule_schema = s4_systems._RULE_SCHEMA
    assert "references" in rule_schema["required"]
    assert rule_schema["properties"]["references"]["minItems"] == 1


# ---------------------------------------------------------------------------
# Stage 1 — form-feed indexer + OCR config (#315)
# ---------------------------------------------------------------------------

from stages import s1_extract  # noqa: E402


def test_form_feed_indexer_basic_shape():
    """Three form-feed-delimited pages → 3 page records + per-page-end markers."""
    raw = "page one\fpage two\fpage three\f"
    transcript, idx = s1_extract._index_form_feed_transcript(raw)
    assert len(idx["pages"]) == 3
    assert idx["pages"][0]["n"] == 1
    assert idx["pages"][0]["preview"] == "page one"
    assert idx["pages"][2]["preview"] == "page three"
    # Page-end markers separate pages in the transcript so Stage 2 can locate
    # boundaries deterministically.
    assert "<!-- page 1 end -->" in transcript
    assert "<!-- page 3 end -->" in transcript


def test_form_feed_indexer_drops_trailing_empty_chunk():
    """pdftotext appends a final \\f; the trailing empty chunk must not become
    a phantom page."""
    raw = "only page\f"
    _, idx = s1_extract._index_form_feed_transcript(raw)
    assert len(idx["pages"]) == 1


def test_form_feed_indexer_page_start_offsets_are_monotonic():
    """Each page's `start` must be >= the previous page's start + length."""
    raw = "alpha\fbeta\fgamma\f"
    _, idx = s1_extract._index_form_feed_transcript(raw)
    starts = [p["start"] for p in idx["pages"]]
    assert starts == sorted(starts)
    for prev, curr in zip(idx["pages"], idx["pages"][1:]):
        assert curr["start"] >= prev["start"] + prev["length"]


def test_form_feed_indexer_strips_c0_control_chars_with_aligned_offsets():
    """C0 control chars must be stripped BEFORE indexing so the returned
    transcript offsets line up with the returned transcript. Regression
    test: an earlier rebase shape had the strip AFTER indexing, which
    misaligned per-page offset lookups by the count of stripped chars."""
    raw = "alpha\x01beta\fgamma\x02delta\f"
    transcript, idx = s1_extract._index_form_feed_transcript(raw)
    assert "\x01" not in transcript
    assert "\x02" not in transcript
    p1 = idx["pages"][0]
    p2 = idx["pages"][1]
    assert transcript[p1["start"]:p1["start"] + p1["length"]] == "alphabeta"
    assert transcript[p2["start"]:p2["start"] + p2["length"]] == "gammadelta"


def test_ocr_defaults_cover_required_keys():
    """OCR_DEFAULTS must define every key _extract_with_ocr reads from cfg,
    so a config without an [ocr] block still runs."""
    required = {
        "host", "user", "vision_model",
        "confidence_threshold", "min_chars_per_page", "render_dpi",
    }
    assert required <= set(s1_extract.OCR_DEFAULTS.keys())


# ---------------------------------------------------------------------------
# SourceLocator (#331 remote-source refactor)
# ---------------------------------------------------------------------------


def test_source_locator_local_only():
    """When `host` is omitted, the locator stays local and resolves the path."""
    s = s1_extract.SourceLocator({"pdf": "~/test.pdf"})
    assert not s.is_remote
    assert s.local_path == Path("~/test.pdf").expanduser()


def test_source_locator_remote():
    """When `host` is set, the locator is remote and keeps the path string
    unmodified (so the remote shell can expand `~`)."""
    s = s1_extract.SourceLocator({
        "host": "cyberpower",
        "user": "dheerajchand",
        "pdf": "~/jazz_docs/foo.pdf",
    })
    assert s.is_remote
    assert s.remote_user_host == "dheerajchand@cyberpower"
    assert s.remote_path == "~/jazz_docs/foo.pdf"


def test_source_locator_remote_user_defaults_to_current():
    """If `user` is omitted, fall back to the local username (current process)."""
    import getpass
    s = s1_extract.SourceLocator({"host": "cyberpower", "pdf": "/abs/path.pdf"})
    assert s.user == getpass.getuser()


def test_remote_quoted_path_expands_tilde():
    """`~/` MUST become `$HOME/` so the remote bash expands it correctly.
    Regression: an earlier shape used shlex.quote() which wrapped the whole
    path including ~ in single quotes, preventing expansion."""
    s = s1_extract.SourceLocator({
        "host": "h", "user": "u", "pdf": "~/foo/bar.pdf",
    })
    quoted = s.remote_quoted_path
    assert quoted.startswith('"$HOME/')
    assert "~" not in quoted


def test_remote_quoted_path_handles_spaces_and_apostrophes():
    """Real jazz-book filenames have spaces, commas, parens, apostrophes.
    Double-quote wrapping protects them all without breaking $HOME expansion."""
    s = s1_extract.SourceLocator({
        "host": "h", "user": "u",
        "pdf": "~/Music/Baker, Mickey - Mickey Baker's Jazz Guitar.pdf",
    })
    quoted = s.remote_quoted_path
    assert quoted.startswith('"$HOME/Music/')
    assert quoted.endswith('.pdf"')
    # apostrophe survives inside double quotes
    assert "Baker's" in quoted
