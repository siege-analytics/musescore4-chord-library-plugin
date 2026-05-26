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
import time
from pathlib import Path

from lib.paths import BookPaths, rel_to_repo


def run(cfg: dict, book: BookPaths) -> list[str]:
    src_pdf = Path(cfg["source"]["pdf"]).expanduser()
    if not src_pdf.exists():
        raise FileNotFoundError(f"source PDF not found: {src_pdf}")

    outputs: list[str] = []
    ocr_summary: str | None = None

    if cfg.get("source", {}).get("needs_ocr"):
        raw_text, pages_index, ocr_summary = _extract_with_ocr(
            src_pdf, book, cfg.get("ocr", {})
        )
    else:
        # Native digital extraction via pdftotext (preferred — deterministic
        # per-page output with -layout) with markitdown fallback.
        raw_text, pages_index = _extract_per_page(src_pdf)

    book.raw_transcript.write_text(raw_text)
    outputs.append(rel_to_repo(book.raw_transcript))

    book.pages_json.write_text(json.dumps(pages_index, indent=2) + "\n")
    outputs.append(rel_to_repo(book.pages_json))

    # Summary line printed via outputs return — orchestrator prints them.
    n_pages = len(pages_index["pages"])
    n_chars = len(raw_text)
    outputs.append(f"extracted: {n_pages} pages, {n_chars:,} characters")
    if ocr_summary:
        outputs.append(ocr_summary)

    return outputs


def _extract_per_page(pdf_path: Path) -> tuple[str, dict]:
    """Return (full transcript, pages_index).

    pages_index shape:
      { "pages": [ { "n": 1, "start": 0, "length": 1234, "preview": "..." }, ... ] }

    C0-control-char stripping happens INSIDE _index_form_feed_transcript
    so the indexed offsets match the returned transcript exactly — both
    the pdftotext and OCR paths go through the same indexer.
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
    return _index_form_feed_transcript(result.stdout)


def _index_form_feed_transcript(raw: str) -> tuple[str, dict]:
    """Convert a \\f-delimited transcript into (transcript, pages_index).

    Strips C0 control chars (\\x00-\\x08, \\x0b, \\x0e-\\x1f) before
    indexing — some PDFs leak these via stylized bullet glyphs and break
    JSON when faithfully copied into subagent response files. \\t (\\x09),
    \\n (\\x0a), \\r (\\x0d), \\f (\\x0c) are all preserved — the form feed
    is the page-boundary delimiter we split on, so stripping it would
    collapse the entire document into one page. Stripping BEFORE indexing
    keeps the returned offsets aligned with the returned transcript.

    Shared by the pdftotext path and the OCR path; both produce
    form-feed-delimited output by convention. Inserts an explicit
    `<!-- page N end -->` marker between pages so downstream stages can
    locate boundaries deterministically. The marker is OUTSIDE the
    per-page char count, so quote-fidelity validation still works
    against the original page text.
    """
    raw = re.sub(r"[\x00-\x08\x0b\x0e-\x1f]", "", raw)
    chunks = raw.split("\f")
    if chunks and chunks[-1] == "":
        chunks = chunks[:-1]
    pages = []
    offset = 0
    transcript_parts = []
    for i, chunk in enumerate(chunks, start=1):
        pages.append({
            "n": i,
            "start": offset,
            "length": len(chunk),
            "preview": _preview(chunk),
        })
        transcript_parts.append(chunk)
        offset += len(chunk)
        transcript_parts.append(f"\n<!-- page {i} end -->\n")
        offset += len(transcript_parts[-1])
    return "".join(transcript_parts), {"pages": pages}


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


# ---------------------------------------------------------------------------
# OCR path (cyberpower remote runner)
# ---------------------------------------------------------------------------

OCR_DEFAULTS = {
    "host": "cyberpower",
    "user": "dheerajchand",
    "vision_model": "qwen2.5vl:7b",
    "confidence_threshold": 0.70,
    "min_chars_per_page": 40,
    "render_dpi": 200,
}


def _extract_with_ocr(
    pdf_path: Path, book: BookPaths, ocr_cfg: dict
) -> tuple[str, dict, str]:
    """Run the OCR pipeline on a scanned PDF via the cyberpower remote.

    Steps: pdftoppm → rsync to remote inbox → ssh run.sh → rsync outbox
    back → re-use the form-feed indexer to build (transcript, pages_index).
    Returns the same (transcript, pages_index) shape as the pdftotext path,
    plus a one-line OCR summary the orchestrator can display.
    """
    cfg = {**OCR_DEFAULTS, **(ocr_cfg or {})}
    host = cfg["host"]
    user = cfg["user"]
    remote = f"{user}@{host}"

    for binary in ("pdftoppm", "rsync", "ssh"):
        if not shutil.which(binary):
            raise RuntimeError(f"OCR branch requires `{binary}` in PATH")

    image_dir = book.run_dir / "ocr-input"
    output_dir = book.run_dir / "ocr-output"
    image_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. pdftoppm — render each page to PNG. Output filenames are
    # `page-NN.png` (zero-padded to match the page count digits).
    subprocess.run(
        [
            "pdftoppm",
            "-png",
            "-r", str(cfg["render_dpi"]),
            str(pdf_path),
            str(image_dir / "page"),
        ],
        check=True,
    )

    # 2. rsync images → cyberpower inbox.
    remote_inbox = f"~/jazz-ocr/inbox/{book.run_id}/"
    subprocess.run(
        ["ssh", remote, f"mkdir -p {remote_inbox}"],
        check=True,
    )
    subprocess.run(
        [
            "rsync", "-a", "--delete",
            f"{image_dir}/",
            f"{remote}:{remote_inbox}",
        ],
        check=True,
    )

    # 3. ssh-launch the runner under nohup so it's INDEPENDENT of this
    # SSH session. The remote process survives laptop sleep / lid close /
    # SSH disconnect — only the local poll loop (next step) cares about
    # connectivity, and that re-establishes on wake. If the laptop dies
    # entirely mid-run, the remote runner still finishes and the outbox
    # is recoverable via `ocr/reingest.py <run_id>`.
    env_prefix = (
        f"OCR_VISION_MODEL={cfg['vision_model']} "
        f"OCR_CONF_THRESHOLD={cfg['confidence_threshold']} "
        f"OCR_MIN_CHARS_PER_PAGE={cfg['min_chars_per_page']} "
    )
    launch_cmd = (
        f"nohup bash -c '{env_prefix}~/jazz-ocr/bin/run.sh {book.run_id}' "
        f"</dev/null >~/jazz-ocr/{book.run_id}.log 2>&1 & disown; "
        f"sleep 1; pgrep -af 'ocr_runner.*{book.run_id}' >/dev/null"
    )
    subprocess.run(
        ["ssh", remote, launch_cmd],
        check=True,
    )

    # 4. Poll cyberpower until the runner exits and the outbox transcript
    # appears. Robust to laptop sleep (the poll just pauses on sleep and
    # resumes on wake — the remote runner doesn't care).
    remote_outbox = f"~/jazz-ocr/outbox/{book.run_id}"
    poll_interval = 30
    while True:
        probe = subprocess.run(
            ["ssh", remote,
             f"if pgrep -f 'ocr_runner.*{book.run_id}' >/dev/null; then "
             f"echo RUNNING; "
             f"elif [ -f {remote_outbox}/raw-transcript.txt ]; then "
             f"echo DONE; "
             f"else "
             f"echo CRASHED; "
             f"fi"],
            capture_output=True, text=True, check=True,
        )
        status = probe.stdout.strip()
        if status == "DONE":
            break
        if status == "CRASHED":
            raise RuntimeError(
                f"OCR runner exited without producing outbox. "
                f"Check ~/jazz-ocr/{book.run_id}.log on {host}."
            )
        # status == "RUNNING": keep waiting.
        time.sleep(poll_interval)

    # 5. rsync results back.
    subprocess.run(
        [
            "rsync", "-a",
            f"{remote}:{remote_outbox}/",
            f"{output_dir}/",
        ],
        check=True,
    )

    transcript_file = output_dir / "raw-transcript.txt"
    confidence_file = output_dir / "page-confidence.json"
    if not transcript_file.exists():
        raise RuntimeError(
            f"OCR transcript missing after remote run: {transcript_file}"
        )

    raw = transcript_file.read_text()
    # C0-control-char stripping is now centralized inside
    # _index_form_feed_transcript so the OCR path and pdftotext path
    # both get the same offset-aligned guarantee.
    transcript, pages_index = _index_form_feed_transcript(raw)

    summary = "ocr: tesseract-only"
    if confidence_file.exists():
        conf_data = json.loads(confidence_file.read_text())
        records = conf_data.get("pages", [])
        rescued = [r for r in records if r.get("engine") != "tesseract"]
        if rescued:
            summary = (
                f"ocr: {len(records)} pages, "
                f"{len(rescued)} rescued via {cfg['vision_model']}"
            )
        else:
            summary = f"ocr: {len(records)} pages, all tesseract"

    return transcript, pages_index, summary
