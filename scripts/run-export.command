#!/bin/bash
# Runner script for Siege Analytics Chord Library exports.
# Reads export-config.json from the plugin directory and executes.

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$PLUGIN_DIR/export-config.json"

if [ ! -f "$CONFIG" ]; then
    echo "Error: export-config.json not found at $CONFIG"
    echo "Press any key to close..."
    read -n 1
    exit 1
fi

CMD=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(d['command'])")
cd "$PLUGIN_DIR"
eval $CMD
exit 0
