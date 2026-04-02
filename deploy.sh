#!/bin/bash
# deploy.sh — Copy plugin source files to MuseScore's plugin directory.
# Run after editing QML/JS files, then restart MuseScore.
#
# Usage: ./deploy.sh
#        ./deploy.sh --watch   (auto-deploy on file changes, requires fswatch)

REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Documents/MuseScore4/Plugins/chordlibrary"

# Source files to deploy (QML, JS)
copy_sources() {
    cp "$REPO/plugin/ChordLibrary.qml" "$DEST/ChordLibrary.qml"
    cp "$REPO/plugin/ui/FilterBar.qml" "$DEST/ui/FilterBar.qml"
    cp "$REPO/plugin/ui/PanelView.qml" "$DEST/ui/PanelView.qml"
    cp "$REPO/plugin/ui/SearchBar.qml" "$DEST/ui/SearchBar.qml"
    cp "$REPO/plugin/ui/VoicingCard.qml" "$DEST/ui/VoicingCard.qml"
    cp "$REPO/plugin/ui/VoicingGrid.qml" "$DEST/ui/VoicingGrid.qml"
    cp "$REPO/plugin/ui/WalkthroughPanel.qml" "$DEST/ui/WalkthroughPanel.qml"
    cp "$REPO/plugin/model/LibraryModel.qml" "$DEST/model/LibraryModel.qml"
    cp "$REPO/plugin/model/Transposer.js" "$DEST/model/Transposer.js"
    cp "$REPO/plugin/model/MelodyEngine.js" "$DEST/model/MelodyEngine.js"
    cp "$REPO/plugin/model/VoicingCalculator.js" "$DEST/model/VoicingCalculator.js"
    cp "$REPO/plugin/model/ReharmonizationEngine.js" "$DEST/model/ReharmonizationEngine.js"

    # Data file
    cp "$REPO/data/voicings.json" "$DEST/voicings-cache.json"

    echo "$(date '+%H:%M:%S') Deployed to $DEST"
}

# Ensure destination dirs exist
mkdir -p "$DEST/ui" "$DEST/model"

if [ "$1" = "--watch" ]; then
    if ! command -v fswatch &>/dev/null; then
        echo "fswatch not found. Install with: brew install fswatch"
        exit 1
    fi
    echo "Watching for changes... (Ctrl+C to stop)"
    copy_sources
    fswatch -o "$REPO/plugin/" "$REPO/data/voicings.json" | while read; do
        copy_sources
    done
else
    copy_sources
    echo "Done. Restart MuseScore to pick up changes."
fi
