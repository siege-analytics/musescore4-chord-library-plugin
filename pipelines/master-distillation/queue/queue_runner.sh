#!/usr/bin/env bash
# Autonomous Stage 1 queue runner. Drains the queue without interactive help.
#
# Loops forever:
#   - clears stale per-book locks
#   - reads the manifest, finds books NOT in done/error/locked state
#   - processes them one at a time via process_one.sh
#   - sleeps POLL_INTERVAL between iterations
#
# Restartable: kill -TERM the daemon, restart it, picks up where it left off.
# Resumable: per-book state markers + lock-staleness detection.
#
# Usage:
#   nohup bash ~/jazz-pipeline/queue_runner.sh \
#       >>~/jazz-pipeline/logs/daemon.stdout \
#       2>>~/jazz-pipeline/logs/daemon.stderr &
#   disown

set -uo pipefail
# Note: NO `set -e` at the loop level — one bad book shouldn't kill the daemon.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/lib.sh"

ensure_dirs

log_line "DAEMON" "starting (pid=$$)"
log_line "DAEMON" "MANIFEST=$MANIFEST_FILE"
log_line "DAEMON" "OUTPUT_DIR=$OUTPUT_DIR"
log_line "DAEMON" "STATE_DIR=$STATE_DIR"
log_line "DAEMON" "POLL_INTERVAL=${POLL_INTERVAL}s"

trap 'log_line DAEMON "shutting down on signal"; exit 0' INT TERM

while true; do
    clear_stale_locks

    # Snapshot of eligible books for this iteration
    eligible=$(eligible_books || true)
    if [ -z "$eligible" ]; then
        log_line "DAEMON" "queue drained; sleeping"
        sleep "$POLL_INTERVAL"
        continue
    fi

    while IFS=$'\t' read -r slug needs_ocr pdf_path; do
        [ -z "$slug" ] && continue
        log_line "DAEMON" "dispatching $slug"
        if bash "$SCRIPT_DIR/process_one.sh" "$slug" "$needs_ocr" "$pdf_path"; then
            log_line "DAEMON" "$slug DONE"
        else
            rc=$?
            log_line "DAEMON" "$slug FAILED (exit $rc)"
        fi
    done <<< "$eligible"

    sleep "$POLL_INTERVAL"
done
