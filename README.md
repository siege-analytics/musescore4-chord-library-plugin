# MuseScore 4 Chord Library Plugin

A MuseScore Studio 4.6+ plugin that replaces MuseScore's flat palette system with a searchable, filterable chord voicing library for jazz guitar. 153 voicings across 26 chord qualities, with fretboard diagrams that insert directly into your score — dots and all.

## What it does

1. Open the Chord Library panel alongside your score
2. Filter by context (chord melody / comping), quality, voicing type, and tuning
3. Click **Open** on a voicing
4. A fretboard diagram appears at the selected note, transposed to the correct key, with complete dot and marker data

All voicings are stored in the key of C and transposed automatically based on the chord symbol at the cursor position. The library is hosted as JSON on GitHub and can be pointed at your own fork.

## Install

### Mac (recommended)

Download the installer from the [latest release](https://github.com/siege-analytics/musescore4-chord-library-plugin/releases):

1. Download **ChordLibrary-mac.zip** and unzip it
2. Double-click **Install Chord Library.command**
3. Restart MuseScore Studio
4. Enable **Chord Library** under **Plugins**

Also available as a `.pkg` installer.

### Windows

1. Download **ChordLibrary-win.zip** and extract it
2. Double-click **Install Chord Library.bat**
3. Restart MuseScore Studio
4. Enable **Chord Library** under **Plugins**

### Manual install

```bash
mkdir -p ~/Documents/MuseScore4/Plugins/chordlibrary
cp plugin/ChordLibrary.qml ~/Documents/MuseScore4/Plugins/chordlibrary/chordlibrary.qml
cp -r plugin/model plugin/ui ~/Documents/MuseScore4/Plugins/chordlibrary/
```

For diagram insertion with dots (macOS), you also need the clipboard helper:

```bash
# Build the Swift clipboard writer
swiftc -o ~/Documents/MuseScore4/Plugins/chordlibrary/ms-clipboard scripts/ms-clipboard.swift -framework AppKit

# Install the launchd agent that bridges the plugin to the clipboard
cp install/com.siegeanalytics.chord-library-clipboard.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.siegeanalytics.chord-library-clipboard.plist
```

Restart MuseScore Studio and enable **Chord Library** under Plugins.

## Usage

### Inserting voicings

1. Open a score and select a note or rest
2. Open **Plugins > Chord Library**
3. Use the dropdowns to filter by context, type, quality, and tuning
4. Click **Open** on a voicing card
5. The fretboard diagram appears at the cursor with correct dots, transposed to the chord symbol's key

If no chord symbol is present at the cursor, the voicing inserts in its stored key (C).

### Contexts

The library organises voicings along two axes:

| Code | Name | What it means |
|------|------|---------------|
| **CV6** | Comping/Vocal — 6 string | Guitar provides harmony while another instrument carries the melody |
| **CV7** | Comping/Vocal — 7 string | Same, using Van Eps 7-string (low A) for extended bass range |
| **CM6** | Chord Melody — 6 string | Guitar carries both melody and harmony; melody note is on top |
| **CM7** | Chord Melody — 7 string | Same, with 7-string for bass independence |

### Voicing types

| Type | Description |
|------|-------------|
| **Shell** | Root + 3rd + 7th (no 5th). Freddie Green / guide tone chords. |
| **Drop 2** | 4-note close voicing with 2nd voice dropped an octave. The workhorse of jazz guitar. |
| **Drop 3** | 4-note close voicing with 3rd voice dropped. Wider spread, good for chord melody. |
| **Extended** | 9ths, 11ths, 13ths, #11, b13 — the colorful chords. |
| **Altered** | Dominant chords with b9, #9, b5, #5 tensions. |
| **Quartal** | Stacked 4ths. McCoy Tyner / Bill Evans sound. |

### Chord qualities

26 qualities: dom7, maj7, min7, min7b5, dim7, dom7#5, dom7b5, dom7alt, dom7b9, dom9, dom13, dom7#11, dom7b13, maj6, maj69, maj9, maj13, maj7#11, min6, min9, min11, min-maj7, aug7, sus4, sus2, quartal.

### Settings

Click **Settings** in the plugin header:

- **Voicing Source URL** — point to your own fork or local file
- **Diagram Placement** — above (default) or below staff
- **Tuning** — select from built-in tunings or import/create your own
- **Export/Import** — save or load voicing libraries as JSON
- **About** — links to GitHub, documentation, and the CC BY 4.0 license

## Tunings

The plugin supports configurable tunings. Four are included:

| Tuning | Strings | Open pitches |
|--------|---------|-------------|
| **Standard + Van Eps** | 7 | E4-B3-G3-D3-A2-E2-A1 |
| **7-String Low B** | 7 | E4-B3-G3-D3-A2-E2-B1 |
| **DADGAD** | 6 | D4-A3-G3-D3-A2-D2 |
| **All Fourths** | 6 | F4-C4-G3-D3-A2-E2 |

### Selecting a tuning

The tuning dropdown is on the main panel, next to the voicing count. Select your tuning and it persists between sessions.

### Importing a tuning

In Settings > Tuning, enter the path to a tuning JSON file and click Import.

### Creating a custom tuning

In Settings > Tuning:

1. Enter a name (e.g. "Open G")
2. Set the string count
3. Enter pitches from high to low — note names (`E4, B3, G3, D3, A2, E2`) or MIDI numbers (`64, 59, 55, 50, 45, 40`)
4. Click **Create Tuning**

Custom tunings are saved to the plugin's `tunings/` directory and appear in the dropdown immediately.

### Tuning JSON format

```json
{
  "name": "Open G",
  "description": "Open G tuning for slide guitar",
  "strings": {
    "1": 62, "2": 59, "3": 50,
    "4": 43, "5": 47, "6": 38
  },
  "notes": {
    "1": "D4", "2": "B3", "3": "D3",
    "4": "G2", "5": "B2", "6": "D2"
  }
}
```

The `strings` values are MIDI note numbers (Middle C = 60). The `notes` field is for human readability.

## How diagram insertion works

MuseScore 4's plugin API does not expose `setDot()` for fretboard diagrams ([issue #32798](https://github.com/musescore/MuseScore/issues/32798), [PR #32848](https://github.com/musescore/MuseScore/pull/32848)). This plugin works around that limitation:

1. The plugin generates the fretboard diagram as XML in MuseScore's internal clipboard format
2. A `launchd` agent detects the file write and runs a compiled Swift tool (`ms-clipboard`) that puts the XML on the macOS pasteboard
3. The plugin calls `cmd("paste")` to insert the diagram from the pasteboard

This produces complete fretboard diagrams with dots, markers, and fret offsets — identical to what you'd get from MuseScore's built-in palette. No Terminal windows, no extra MuseScore tabs, no Accessibility permissions required.

When PR #32848 is accepted into MuseScore, the plugin will switch to direct `setDot()` calls and this workaround becomes unnecessary.

## Developer setup

### Prerequisites

- Python 3.10+ with `pip install jsonschema`
- Xcode Command Line Tools (for `swiftc` — macOS only)
- MuseScore Studio 4.6+

### Quick start

```bash
git clone https://github.com/siege-analytics/musescore4-chord-library-plugin.git
cd musescore4-chord-library-plugin

python -m venv .venv && source .venv/bin/activate
pip install jsonschema

python scripts/validate.py -v          # validate all 153 voicings
python scripts/build_installer.py      # build Mac + Windows installers
```

### Project structure

```
config/
  contexts.json              # Context display labels (extensible)
  tunings/                   # Tuning configs (standard, 7-string, DADGAD, etc.)
data/
  voicings.json              # The 153-voicing chord library (all in key of C)
docs/
  CONTRIBUTING.md            # How to add voicings and tunings
plugin/
  ChordLibrary.qml           # Main plugin source
  model/
    Transposer.js            # Key-aware transposition and note respelling
    VoicingInserter.qml      # Insertion logic and .mscx snippet generation
  ui/                        # Modular UI components (planned refactor)
schema/
  voicings.schema.json       # JSON schema (strings 4-12, free-text categories)
scripts/
  validate.py                # Schema + consistency + note-computation validator
  generate_mscz.py           # Generate .mscz files with complete diagrams
  generate_caged.py          # CAGED voicing generator (E/A/D shapes x qualities)
  ms-clipboard.swift         # Swift pasteboard writer for macOS
  paste_diagram.py           # AppleScript automation (legacy, replaced by clipboard)
  build_installer.py         # Mac/Windows installer builder
  oolimo_urls.py             # Oolimo verification URL generator
```

### Scripts

```bash
# Validate voicings (schema + consistency + note verification)
python scripts/validate.py -v

# Validate with a specific tuning
python scripts/validate.py -v --tuning config/tunings/dadgad.json

# Generate a .mscz file for a voicing transposed to F
python scripts/generate_mscz.py --voicing c7-drop2-e-shape-6 --root F

# Generate .mscz files for ALL voicings in Bb
python scripts/generate_mscz.py --all --root Bb --output diagrams/

# Generate CAGED voicings
python scripts/generate_caged.py

# Build installers
python scripts/build_installer.py --pkg
```

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details on adding voicings, creating tunings, and the validation workflow.

Short version: all voicings must be in C, verified by the note-computation validator, and cross-referenced with [Oolimo](https://www.oolimo.com/).

## References

- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be
- Taylor, Martin. *Complete Jazz Guitar Method*. Alfred Music
- Greene, Ted. *Chord Chemistry*

## Related projects

- [siege-analytics/jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — `.mpal` palette files (predecessor to this plugin)
- [siege-analytics/jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — chord melody arrangements using this library

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)

Free to use, share, and adapt with attribution to **Dheeraj Chand**.
