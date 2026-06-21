#!/usr/bin/env bash
# Cyberpower-side entrypoint. Invoked from the laptop as
#   ssh cyberpower bash ~/jazz-ocr/bin/run.sh <run_id>
#
# Reads images from ~/jazz-ocr/inbox/<run_id>/page-NNNN.png and writes
# transcript + confidence to ~/jazz-ocr/outbox/<run_id>/.
#
# Environment overrides for tuning:
#   OCR_VISION_MODEL       default: qwen2.5vl:7b
#   OCR_CONF_THRESHOLD     default: 0.70
#   OCR_MIN_CHARS_PER_PAGE default: 40
#   OLLAMA_URL             default: http://localhost:11434

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: run.sh <run_id>" >&2
    exit 64
fi

RUN_ID="$1"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/ocr_runner.py"

if [[ ! -f "$RUNNER" ]]; then
    echo "ocr_runner.py missing at $RUNNER" >&2
    exit 2
fi

# Sanity checks (fail loud before we burn time).
command -v tesseract >/dev/null 2>&1 || { echo "tesseract not in PATH" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "curl not in PATH" >&2; exit 2; }

# Confirm Ollama reachable (rescue tier optional but warn if not).
if ! curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" >/dev/null; then
    echo "warning: Ollama not reachable at ${OLLAMA_URL:-http://localhost:11434}; tesseract-only mode" >&2
fi

exec python3 "$RUNNER" "$RUN_ID"
