#!/bin/bash
# deploy.sh — Copy the plugin folder to MuseScore's plugin directory.
# The plugin/ directory is self-contained — no assembly required.
#
# Usage: ./deploy.sh
#        ./deploy.sh --watch   (auto-deploy on file changes, requires fswatch)

REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Documents/MuseScore4/Plugins/chordlibrary"

deploy() {
    mkdir -p "$DEST"
    # Copy everything, preserving user-created files (settings, caches)
    rsync -a --exclude='settings.json' --exclude='*-voicings.json' \
        "$REPO/plugin/" "$DEST/"
    echo "$(date '+%H:%M:%S') Deployed to $DEST"
}

if [ "$1" = "--watch" ]; then
    if ! command -v fswatch &>/dev/null; then
        echo "fswatch not found. Install with: brew install fswatch"
        exit 1
    fi
    echo "Watching for changes... (Ctrl+C to stop)"
    deploy
    fswatch -o "$REPO/plugin/" | while read; do
        deploy
    done
else
    deploy
    echo "Done. Restart MuseScore to pick up changes."
fi
