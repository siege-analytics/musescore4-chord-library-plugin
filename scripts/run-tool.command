#!/bin/bash
# Runner script for Siege Analytics Chord Library tools.
# Reads tool-config.json from the plugin directory, executes the
# Python script, and opens the output file.

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$PLUGIN_DIR/tool-config.json"

if [ ! -f "$CONFIG" ]; then
    echo "Error: tool-config.json not found at $CONFIG"
    echo "Press any key to close..."
    read -n 1
    exit 1
fi

# Parse JSON config (using python since it's required anyway)
SCRIPT=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(d['script'])")
ARGS=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(d.get('args',''))")
OUTPUT=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(d.get('output','$PLUGIN_DIR/tool-output.txt'))")
PDIR=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(d.get('pluginDir','$PLUGIN_DIR'))")

cd "$PDIR"

# Run the tool and capture output
eval python3 "$SCRIPT" $ARGS > "$OUTPUT" 2>&1

# Open the output
open "$OUTPUT"
exit 0
