#!/usr/bin/env python3
"""Paste a fretboard diagram into the active MuseScore score.

Generates a temp .mscz file with the complete diagram (dots, markers),
then uses macOS AppleScript to automate:
  1. Open the temp file in MuseScore (new tab)
  2. Select All → Copy (gets the diagram with dots onto clipboard)
  3. Close the temp tab without saving
  4. Switch back to the user's score tab
  5. Paste at the cursor position

Usage:
    python paste_diagram.py --voicing c7-drop2-e-shape-6 --root F
    python paste_diagram.py --request /tmp/chord-library-request.json
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# Add parent dir so we can import generate_mscz
sys.path.insert(0, str(Path(__file__).parent))
from generate_mscz import generate_mscz, semitone_offset

MUSESCORE_BUNDLE = "org.musescore.MuseScore"


def _get_musescore_process_name() -> str:
    """Detect the MuseScore process name from System Events."""
    try:
        result = subprocess.run(
            ["osascript", "-e",
             'tell application "System Events" to get name of first process '
             f'whose bundle identifier is "{MUSESCORE_BUNDLE}"'],
            capture_output=True, text=True, timeout=5,
        )
        name = result.stdout.strip()
        if name:
            return name
    except Exception:
        pass
    return "MuseScore 4"  # fallback


def paste_via_applescript(mscz_path: Path, score_title: str) -> bool:
    """Use AppleScript to open temp file, copy diagram, close, and paste."""
    mscz_posix = str(mscz_path.resolve())
    process_name = _get_musescore_process_name()
    print(f"MuseScore process: {process_name}")

    # AppleScript that automates the entire flow
    script = f'''
        -- Open the temp diagram file in MuseScore
        tell application id "{MUSESCORE_BUNDLE}"
            activate
            open POSIX file "{mscz_posix}"
        end tell

        -- Wait for the file to load
        delay 1.5

        -- Select all and copy (gets the fretboard diagram with dots)
        tell application "System Events"
            tell process "{process_name}"
                keystroke "a" using command down
                delay 0.3
                keystroke "c" using command down
                delay 0.3
                -- Close the temp tab without saving
                keystroke "w" using command down
                delay 0.5
            end tell
        end tell

        -- Handle "Save changes?" dialog if it appears
        delay 0.5
        tell application "System Events"
            tell process "{process_name}"
                try
                    if exists sheet 1 of window 1 then
                        -- Look for Discard / Don't Save button
                        try
                            click button "Discard" of sheet 1 of window 1
                        on error
                            try
                                click button "Don't Save" of sheet 1 of window 1
                            on error
                                key code 2 using command down
                            end try
                        end try
                        delay 0.3
                    end if
                end try
            end tell
        end tell

        -- Now paste into the user's score at the cursor position
        delay 0.3
        tell application "System Events"
            tell process "{process_name}"
                keystroke "v" using command down
            end tell
        end tell
    '''

    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            print(f"AppleScript error: {result.stderr}", file=sys.stderr)
            return False
        return True
    except subprocess.TimeoutExpired:
        print("AppleScript timed out", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Paste a fretboard diagram into the active MuseScore score"
    )
    parser.add_argument("--voicing", help="Voicing ID from voicings.json")
    parser.add_argument("--root", default="C", help="Target root note")
    parser.add_argument(
        "--request", help="Path to JSON request file (from plugin)"
    )
    parser.add_argument(
        "--data",
        default=str(Path(__file__).parent.parent / "data" / "voicings.json"),
        help="Path to voicings.json",
    )
    args = parser.parse_args()

    # Load request from file if provided
    if args.request:
        with open(args.request) as f:
            req = json.load(f)
        voicing_id = req["voicing_id"]
        target_root = req.get("root", "C")
        score_title = req.get("score_title", "")
    elif args.voicing:
        voicing_id = args.voicing
        target_root = args.root
        score_title = ""
    else:
        parser.print_help()
        sys.exit(1)

    # Load voicing data
    with open(args.data) as f:
        data = json.load(f)
    voicings = {v["id"]: v for v in data["voicings"]}

    if voicing_id not in voicings:
        print(f"Error: voicing '{voicing_id}' not found.", file=sys.stderr)
        sys.exit(1)

    voicing = voicings[voicing_id]

    # Generate temp .mscz
    with tempfile.NamedTemporaryFile(
        suffix=".mscz", prefix="chord-library-", delete=False
    ) as tmp:
        tmp_path = Path(tmp.name)

    generate_mscz(voicing, target_root, tmp_path)
    print(f"Generated: {tmp_path}")

    # Automate copy-paste
    success = paste_via_applescript(tmp_path, score_title)

    # Clean up temp file after a delay (let MuseScore finish reading it)
    time.sleep(2)
    try:
        tmp_path.unlink()
    except OSError:
        pass

    if success:
        offset = semitone_offset(voicing["root"], target_root)
        name = voicing["name"]
        if target_root != "C":
            name = name.replace("C", target_root, 1)
        print(f"Pasted: {name}")
    else:
        print("Paste failed — check Accessibility permissions", file=sys.stderr)
        print(
            "System Preferences > Privacy & Security > Accessibility",
            file=sys.stderr,
        )
        print(
            "Grant access to Terminal (or whatever runs this script)",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
