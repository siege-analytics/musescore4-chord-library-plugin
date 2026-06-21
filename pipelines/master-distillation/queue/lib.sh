# Shared helper functions for the queue runner.
# Source this AFTER config.sh.

ensure_dirs() {
    mkdir -p "$OUTPUT_DIR" "$STATE_DIR" "$LOG_DIR"
}

# Per-book state predicates.
is_done()  { [ -f "$STATE_DIR/$1.done" ]; }
is_error() { [ -f "$STATE_DIR/$1.error" ]; }
is_locked() { [ -f "$STATE_DIR/$1.lock" ]; }

# Stale lock = lock file exists but no live process matches.
# We track the PID inside the lock file and check kill -0.
clear_stale_locks() {
    for lock in "$STATE_DIR"/*.lock; do
        [ -f "$lock" ] || continue
        local pid
        pid=$(cat "$lock" 2>/dev/null || echo 0)
        if [ "$pid" = "0" ] || ! kill -0 "$pid" 2>/dev/null; then
            local slug
            slug=$(basename "$lock" .lock)
            echo "$(date -Iseconds) clearing stale lock for $slug (pid=$pid)" >&2
            rm -f "$lock"
        fi
    done
}

acquire_lock() {
    local slug="$1"
    echo "$$" > "$STATE_DIR/$slug.lock"
}

release_lock() {
    local slug="$1"
    rm -f "$STATE_DIR/$slug.lock"
}

mark_done() {
    local slug="$1"
    date -Iseconds > "$STATE_DIR/$slug.done"
}

mark_error() {
    local slug="$1"
    local reason="$2"
    {
        date -Iseconds
        echo "REASON: $reason"
    } > "$STATE_DIR/$slug.error"
}

# Read the manifest file: tab-separated slug<TAB>needs_ocr<TAB>pdf_path
# Returns lines for books that are NOT done, error, or locked.
eligible_books() {
    [ -f "$MANIFEST_FILE" ] || { echo "manifest missing: $MANIFEST_FILE" >&2; return 1; }
    while IFS=$'\t' read -r slug needs_ocr pdf_path; do
        [ -z "$slug" ] && continue
        case "$slug" in '#'*) continue;; esac
        is_done "$slug"  && continue
        is_error "$slug" && continue
        is_locked "$slug" && continue
        printf '%s\t%s\t%s\n' "$slug" "$needs_ocr" "$pdf_path"
    done < "$MANIFEST_FILE"
}

log_line() {
    echo "$(date -Iseconds) [$1] $2"
}
