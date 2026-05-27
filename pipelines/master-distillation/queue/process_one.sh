#!/usr/bin/env bash
# Process ONE book end-to-end through Stage 1.
#
# usage: process_one.sh <slug> <needs_ocr:0|1> <pdf-path>
#   pdf-path may begin with `~/` (expanded via $HOME).
#
# Writes:
#   $OUTPUT_DIR/<slug>/raw-transcript.txt
#   $OUTPUT_DIR/<slug>/pages.json (for digital path only — OCR path emits
#       the transcript only; pages.json is built by the laptop-side
#       reingest.py which has the canonical indexer.)
#   $STATE_DIR/<slug>.done or .error
#   $LOG_DIR/<slug>.stdout, $LOG_DIR/<slug>.stderr

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/lib.sh"

if [ $# -ne 3 ]; then
    echo "usage: $0 <slug> <needs_ocr:0|1> <pdf-path>" >&2
    exit 64
fi

SLUG="$1"
NEEDS_OCR="$2"
PDF_PATH_RAW="$3"

# Expand `~` against $HOME for the local cyberpower context
PDF_PATH="${PDF_PATH_RAW/#\~/$HOME}"

ensure_dirs
mkdir -p "$OUTPUT_DIR/$SLUG"

STDOUT_LOG="$LOG_DIR/$SLUG.stdout"
STDERR_LOG="$LOG_DIR/$SLUG.stderr"

acquire_lock "$SLUG"
trap 'release_lock "$SLUG"' EXIT

log_line "$SLUG" "starting (needs_ocr=$NEEDS_OCR, pdf=$PDF_PATH)" \
    | tee -a "$STDOUT_LOG"

if [ ! -f "$PDF_PATH" ]; then
    log_line "$SLUG" "ERROR: PDF not found at $PDF_PATH" \
        | tee -a "$STDERR_LOG" >&2
    mark_error "$SLUG" "PDF not found at $PDF_PATH"
    exit 2
fi

if [ "$NEEDS_OCR" = "1" ] || [ "$NEEDS_OCR" = "true" ]; then
    # OCR path: invoke the existing OCR runner.
    # OCR_RUN_SH = ~/jazz-ocr/bin/run.sh (from #316/#318).
    # We seed the inbox + invoke; the runner writes outbox.
    if [ ! -f "$OCR_RUN_SH" ]; then
        log_line "$SLUG" "ERROR: OCR runner missing at $OCR_RUN_SH" \
            | tee -a "$STDERR_LOG" >&2
        mark_error "$SLUG" "OCR runner not deployed"
        exit 2
    fi

    OCR_RUN_ID="$SLUG"   # use slug as the run_id so paths are stable
    OCR_INBOX="$HOME/jazz-ocr/inbox/$OCR_RUN_ID"
    OCR_OUTBOX="$HOME/jazz-ocr/outbox/$OCR_RUN_ID"
    mkdir -p "$OCR_INBOX"

    if ! ls "$OCR_INBOX"/page-*.png >/dev/null 2>&1; then
        log_line "$SLUG" "running pdftoppm into $OCR_INBOX" \
            | tee -a "$STDOUT_LOG"
        pdftoppm -png -r "$OCR_RENDER_DPI" "$PDF_PATH" "$OCR_INBOX/page" \
            >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
    else
        log_line "$SLUG" "skipping pdftoppm (inbox already populated)" \
            | tee -a "$STDOUT_LOG"
    fi

    log_line "$SLUG" "running OCR runner" | tee -a "$STDOUT_LOG"
    OCR_VISION_MODEL="$OCR_VISION_MODEL" \
    OCR_CONF_THRESHOLD="$OCR_CONF_THRESHOLD" \
    OCR_MIN_CHARS_PER_PAGE="$OCR_MIN_CHARS_PER_PAGE" \
    OLLAMA_URL="$OLLAMA_URL" \
        bash "$OCR_RUN_SH" "$OCR_RUN_ID" \
            >>"$STDOUT_LOG" 2>>"$STDERR_LOG"

    if [ -f "$OCR_OUTBOX/raw-transcript.txt" ]; then
        cp "$OCR_OUTBOX/raw-transcript.txt" "$OUTPUT_DIR/$SLUG/raw-transcript.txt"
        cp "$OCR_OUTBOX/page-confidence.json" "$OUTPUT_DIR/$SLUG/page-confidence.json" 2>/dev/null || true
        chars=$(wc -c < "$OUTPUT_DIR/$SLUG/raw-transcript.txt")
        log_line "$SLUG" "OCR DONE: $chars chars" | tee -a "$STDOUT_LOG"
        mark_done "$SLUG"
    else
        log_line "$SLUG" "ERROR: OCR finished but no transcript at $OCR_OUTBOX/raw-transcript.txt" \
            | tee -a "$STDERR_LOG" >&2
        mark_error "$SLUG" "OCR outbox missing transcript"
        exit 3
    fi
else
    # Digital path: pdftotext -layout -enc UTF-8 with form-feed delimited output.
    log_line "$SLUG" "running pdftotext" | tee -a "$STDOUT_LOG"
    if pdftotext -layout -enc UTF-8 "$PDF_PATH" "$OUTPUT_DIR/$SLUG/raw-transcript.txt" \
            2>>"$STDERR_LOG"; then
        chars=$(wc -c < "$OUTPUT_DIR/$SLUG/raw-transcript.txt")
        log_line "$SLUG" "DIGITAL DONE: $chars chars" | tee -a "$STDOUT_LOG"
        mark_done "$SLUG"
    else
        log_line "$SLUG" "ERROR: pdftotext failed" \
            | tee -a "$STDERR_LOG" >&2
        mark_error "$SLUG" "pdftotext returned nonzero"
        exit 4
    fi
fi
