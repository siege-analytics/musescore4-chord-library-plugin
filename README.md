# Siege Analytics Chord Library

A MuseScore Studio 4.6+ plugin that replaces MuseScore's flat palette system with a searchable, filterable chord voicing library for jazz guitar. 787 voicings across 39 chord qualities, with fretboard diagrams that insert directly into your score — dots and all.

## What it does

1. Open the Siege Analytics Chord Library panel alongside your score
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
4. Enable **Siege Analytics Chord Library** under **Plugins**

Also available as a `.pkg` installer.

### Windows

1. Download **ChordLibrary-win.zip** and extract it
2. Double-click **Install Chord Library.bat**
3. Restart MuseScore Studio
4. Enable **Siege Analytics Chord Library** under **Plugins**

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

### Fretboard diagram colors

Each voicing card shows a mini fretboard diagram with dots color-coded by interval:

| Color | Interval |
|-------|----------|
| Red | Root (1) |
| Blue | 3rd (3, b3) |
| Green | 5th (5, b5, #5) |
| Orange | 7th (7, b7, bb7) |
| Purple | 9th (9, b9, #9) |
| Teal | 4th / 11th (#11) |
| Gold | 6th / 13th (b13) |

A compact legend is shown between the filter controls and the voicing list. Colors adapt to dark/light mode.

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

39 qualities: dom7, maj7, min7, min7b5, dim7, dom7#5, dom7b5, dom7alt, dom7b9, dom7#9, dom9, dom13, dom7#11, dom7b13, maj6, maj69, maj9, maj13, maj7#11, maj7#5, min6, min9, min11, min-maj7, min-maj9, aug7, augMaj7, sus4, sus2, 9sus4, 13sus4, 7b9sus4, 13b9, 13#9, 7b5(b9), 7b5(#9), 7#5(b9), 7#5(#9), quartal.

### Settings

Click **Settings** in the plugin header:

- **Voicing Source URL** — point to your own fork or local file
- **Diagram Placement** — above (default) or below staff
- **Tuning** — select from built-in tunings or import/create your own
- **Export/Import** — save or load voicing libraries as JSON
- **About** — links to GitHub, documentation, and the CC BY 4.0 license

## Tunings

The plugin supports configurable tunings. Twelve are included:

| Tuning | Strings | Open pitches |
|--------|---------|-------------|
| **Standard** | 6 | E4-B3-G3-D3-A2-E2 |
| **Van Eps 7-String** | 7 | E4-B3-G3-D3-A2-E2-A1 |
| **7-String Low B** | 7 | E4-B3-G3-D3-A2-E2-B1 |
| **DADGAD** | 6 | D4-A3-G3-D3-A2-D2 |
| **All Fourths** | 6 | F4-C4-G3-D3-A2-E2 |
| **Baritone** | 6 | B3-F#3-D3-A2-E2-B1 |
| **Ukulele** | 4 | A4-E4-C4-G4 |
| **Ukulele (Low G)** | 4 | A4-E4-C4-G3 |
| **Mandolin** | 4 | E5-A4-D4-G3 |
| **Banjo (Open G)** | 5 | D4-B3-G3-D3-G4 |
| **Bass 4-String** | 4 | G2-D2-A1-E1 |
| **Bass 5-String** | 5 | G2-D2-A1-E1-B0 |

Pre-generated voicing libraries for alternate tunings are available in `data/tuning-libraries/`. Import them via Settings > Import Voicings.

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

MuseScore 4's plugin API does not yet expose `setDot()` for fretboard diagrams ([issue #32798](https://github.com/musescore/MuseScore/issues/32798), [PR #32848](https://github.com/musescore/MuseScore/pull/32848)). The plugin detects at runtime whether `setDot()` is available:

**If `setDot()` is available** (future MuseScore versions): diagrams insert instantly via the direct API. No clipboard, no timer delay.

**If `setDot()` is not available** (current MuseScore 4.6): the plugin uses a clipboard workaround:

1. The plugin generates the fretboard diagram as XML in MuseScore's internal clipboard format (`application/musescore/symbol`)
2. A `launchd` agent (macOS) or `ms-clipboard.py` (cross-platform) writes the XML to the system clipboard
3. The plugin calls `cmd("paste")` to insert the diagram from the clipboard

This produces complete fretboard diagrams with dots, markers, and fret offsets — identical to what you'd get from MuseScore's built-in palette. No Terminal windows, no extra MuseScore tabs, no Accessibility permissions required.

The cross-platform clipboard tool (`scripts/ms-clipboard.py`) supports macOS, Windows, and Linux. On Windows, it uses the Win32 API to register MuseScore's clipboard format directly.

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

python scripts/validate.py -v          # validate all 787 voicings
python scripts/build_installer.py      # build Mac + Windows installers
```

### Project structure

```
config/
  contexts.json              # Context display labels (extensible)
  tunings/                   # 12 tuning configs (standard, 7-string, DADGAD, etc.)
data/
  voicings.json              # The 787-voicing chord library (all in key of C)
  tuning-libraries/          # Pre-generated voicing libraries for alternate tunings
docs/
  CONTRIBUTING.md            # How to add voicings and tunings
plugin/
  ChordLibrary.qml           # Main plugin source
  model/
    Transposer.js            # Key-aware transposition and note respelling
    VoicingInserter.qml      # Insertion logic (setDot API or clipboard fallback)
  ui/                        # Modular UI components
schema/
  voicings.schema.json       # JSON schema (strings 4-12, free-text categories)
scripts/
  validate.py                # Schema + consistency + note-computation validator
  chord_calculator.py        # Generate voicings for any tuning (39 qualities)
  generate_tuning_library.py # Batch-generate importable libraries for alternate tunings
  export_gp5.py              # Guitar Pro 5 export
  export_musicxml.py         # MusicXML export
  library_hygiene.py         # Duplicate/enharmonic/naming audit
  ms-clipboard.swift         # Swift pasteboard writer for macOS
  ms-clipboard.py            # Cross-platform clipboard writer (macOS/Windows/Linux)
  sniff_clipboard_win.py     # Windows clipboard format discovery tool
  build_installer.py         # Mac/Windows installer builder
tests/
  test_core.py               # 49 unit tests
  test_integration.py        # Integration tests (clipboard, exports, transposition)
```

### Scripts

```bash
# Validate voicings (schema + consistency + note verification)
python scripts/validate.py -v

# Validate with a specific tuning
python scripts/validate.py -v --tuning config/tunings/dadgad.json

# Generate voicings for an alternate tuning
python scripts/chord_calculator.py --tuning config/tunings/dadgad.json --root C --export

# Generate a full importable library for an alternate tuning
python scripts/generate_tuning_library.py --tuning config/tunings/dadgad.json

# Generate libraries for ALL alternate tunings at once
python scripts/generate_tuning_library.py --all-tunings

# Export to Guitar Pro 5
python scripts/export_gp5.py --root C -o exports/

# Export to MusicXML
python scripts/export_musicxml.py --root C -o exports/

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
