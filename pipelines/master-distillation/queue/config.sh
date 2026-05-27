# Queue runner configuration. Override any of these via env before invoking
# queue_runner.sh, or edit this file in your deployed copy.
# This file is sourced by lib.sh; keep it pure variable definitions.

# Where the source PDF library lives (cyberpower-relative)
: "${LIBRARY_ROOT:=$HOME/jazz_docs}"

# Where Stage 1 outputs go (raw-transcript.txt + pages.json + ocr-output/)
: "${OUTPUT_DIR:=$HOME/jazz-pipeline/outputs}"

# Per-book state markers (.lock / .done / .error)
: "${STATE_DIR:=$HOME/jazz-pipeline/state}"

# Per-book + daemon logs
: "${LOG_DIR:=$HOME/jazz-pipeline/logs}"

# The flat manifest file (generated from repo configs/*.toml by manifest_from_configs.py)
: "${MANIFEST_FILE:=$HOME/jazz-pipeline/manifest.tsv}"

# OCR runner location (from #316/#318)
: "${OCR_RUN_SH:=$HOME/jazz-ocr/bin/run.sh}"

# Ollama endpoint (the OCR runner reads this; surfaced here for completeness)
: "${OLLAMA_URL:=http://localhost:11434}"

# Polling interval for daemon main loop, seconds
: "${POLL_INTERVAL:=15}"

# OCR vision model (passed through to OCR runner)
: "${OCR_VISION_MODEL:=qwen2.5vl:7b}"
: "${OCR_CONF_THRESHOLD:=0.70}"
: "${OCR_MIN_CHARS_PER_PAGE:=40}"
: "${OCR_RENDER_DPI:=200}"
