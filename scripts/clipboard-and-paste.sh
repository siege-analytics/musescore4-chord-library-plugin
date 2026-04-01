#!/bin/bash
# Write to clipboard then auto-paste via Cmd+V
PLUGIN_DIR="$(dirname "$0")"

# Step 1: Write XML to macOS pasteboard
"$PLUGIN_DIR/ms-clipboard" "$1" 2>/tmp/chord-library-clipboard.log

# Step 2: Brief pause for clipboard to settle
sleep 0.3

# Step 3: Send Cmd+V to MuseScore via osascript
osascript -e '
tell application "System Events"
    tell process "mscore"
        keystroke "v" using command down
    end tell
end tell
' 2>>/tmp/chord-library-clipboard.log

echo "Clipboard written and Cmd+V sent" >> /tmp/chord-library-clipboard.log
