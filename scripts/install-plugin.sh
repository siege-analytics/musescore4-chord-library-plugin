#!/bin/bash
# Install the Chord Library plugin for MuseScore 4 testing.
# Creates a symlink from the MS4 plugins directory to this repo's plugin folder.
#
# Usage: ./scripts/install-plugin.sh
#        ./scripts/install-plugin.sh --uninstall

PLUGIN_DIR="$HOME/Documents/MuseScore4/Plugins"
PLUGIN_NAME="ChordLibrary"
REPO_PLUGIN_DIR="$(cd "$(dirname "$0")/../plugin" && pwd)"

if [ "$1" = "--uninstall" ]; then
    if [ -L "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
        rm "$PLUGIN_DIR/$PLUGIN_NAME"
        echo "Uninstalled: removed symlink $PLUGIN_DIR/$PLUGIN_NAME"
    else
        echo "Not installed (no symlink found at $PLUGIN_DIR/$PLUGIN_NAME)"
    fi
    exit 0
fi

# Ensure plugin directory exists
mkdir -p "$PLUGIN_DIR"

# Remove existing symlink/directory if present
if [ -L "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
    rm "$PLUGIN_DIR/$PLUGIN_NAME"
    echo "Removed existing symlink"
elif [ -d "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
    echo "Warning: $PLUGIN_DIR/$PLUGIN_NAME exists as a directory, not a symlink."
    echo "Remove it manually if you want to replace it."
    exit 1
fi

ln -s "$REPO_PLUGIN_DIR" "$PLUGIN_DIR/$PLUGIN_NAME"
echo "Installed: $PLUGIN_DIR/$PLUGIN_NAME -> $REPO_PLUGIN_DIR"
echo ""
echo "Next steps:"
echo "  1. Open MuseScore 4"
echo "  2. Go to Home > Plugins"
echo "  3. Find 'Chord Library' and enable it"
echo "  4. Access via Plugins menu or dock panel"
