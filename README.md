# MuseScore 4 Chord Library Plugin

A MuseScore Studio 4.6+ plugin for browsing, filtering, and inserting jazz guitar chord voicings directly into your score. The voicing library is hosted as JSON on GitHub — no manual palette management required.

## The problem this solves

MuseScore's native palette system is flat — no nesting, no sub-palettes. A comprehensive jazz guitar voicing library spanning chord melody vs comping contexts, 6 and 7 string guitar, and multiple voicing types is unmanageable as palettes. Sharing requires manual `.mpal` file distribution, and the library can't be updated remotely.

This plugin replaces that workflow: a dialog UI driven by a JSON library that lives online, updates automatically, and can be forked by anyone.

## Features

- Dialog panel with filters for context, chord quality, and voicing type
- Full text search across voicing names and tags
- Double-click to insert a fretboard diagram at any selected note or rest
- Automatic transposition — voicings stored in C, adjusted to target key based on chord symbols in the score
- Library hosted on GitHub, fetched at runtime
- Point the plugin at your own fork for a custom library

## Current status: v0.3.1

- Plugin loads in MuseScore Studio 4.6.x
- 31 voicings in the base library: shells, Drop 2, Drop 3, altered (dom7b9, dom7#5)
- **Settings panel** with persistent configuration (survives MuseScore restarts)
- **Configurable voicing source URL** — point to your own fork or custom library
- **Diagram placement toggle** — above (default) or below staff
- **Export/Import** — save/load voicing libraries as JSON files with validation and merge
- **Dynamic filter dropdowns** — adapt automatically to imported data (new categories, qualities appear in filters)
- **Responsive context labels** — full names when wide ("Chord Melody 6-str"), abbreviations when narrow ("CM6")
- **CAGED voicing generator** — script generates all CAGED shapes mathematically with note verification
- Note-computation validator catches fret/note mismatches automatically
- Configurable tuning system (standard, Van Eps 7-string, low B 7-string, DADGAD, all-fourths)
- Oolimo URL generator for visual cross-referencing of voicings
- Mac and Windows installers for non-programmers

**Known limitation:** MuseScore 4's plugin API does not expose `setDot()`, `setMarker()`, or `setBarre()` for fretboard diagrams. Inserted grids have correct dimensions and fret offset but no dot markers. Filed [musescore/MuseScore#32798](https://github.com/musescore/MuseScore/issues/32798). The `.mscx` XML snippet with full dot data is logged to the MuseScore console for manual use.

## Install (no programming required)

Download the installer for your platform from the [latest release](https://github.com/siege-analytics/musescore4-chord-library-plugin/releases):

### Mac

1. Download **ChordLibrary-0.3.1-mac.zip**
2. Unzip it (double-click the zip)
3. Double-click **Install Chord Library.command**
4. Restart MuseScore Studio and enable **Chord Library** under Plugins

Also available as **ChordLibrary-0.3.1.pkg** — a standard macOS installer package.

### Windows

1. Download **ChordLibrary-0.3.1-win.zip**
2. Extract it (right-click → Extract All)
3. Double-click **Install Chord Library.bat**
4. Restart MuseScore Studio and enable **Chord Library** under Plugins

### Uninstall

Each download includes an uninstaller: **Uninstall Chord Library.command** (Mac) or **Uninstall Chord Library.bat** (Windows).

The installers automatically back up any existing installation before overwriting.

---

## Developer setup

### Prerequisites

- Python 3.10+ with `pip install jsonschema`
- MuseScore Studio 4.6+ (for plugin use)
- Git

### Quick start

```bash
git clone https://github.com/siege-analytics/musescore4-chord-library-plugin.git
cd musescore4-chord-library-plugin

python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install jsonschema

python scripts/validate.py -v          # validate all voicings
python scripts/oolimo_urls.py          # generate Oolimo cross-reference URLs
python scripts/build_installer.py      # build Mac + Windows installers in dist/
```

### Project structure

```
├── config/tunings/         # Tuning configs (standard, 7-string low B, DADGAD, etc.)
├── data/voicings.json      # The chord voicing library (all shapes in C)
├── docs/CONTRIBUTING.md    # How to add voicings, manage tunings, CRUD operations
├── plugin/                 # QML plugin source for MuseScore
├── schema/                 # JSON schema for voicings
├── scripts/
│   ├── validate.py         # Schema + consistency + note-computation validator
│   ├── oolimo_urls.py      # Oolimo verification URL generator
│   ├── generate_caged.py   # CAGED voicing generator (E/A/D shapes)
│   ├── build_installer.py  # Mac/Windows installer builder
│   ├── generate_from_mscz.py
│   └── generate_mscx_snippet.py
└── README.md
```

### Manual install (without installer)

1. Create `~/Documents/MuseScore4/Plugins/chordlibrary/`
2. Copy `plugin/ChordLibrary.qml` into that folder as `chordlibrary.qml`
3. Copy `plugin/model/` and `plugin/ui/` into the same folder
4. Restart MuseScore Studio
5. Go to **Plugins** and enable **Chord Library**

## Usage

1. Open a score in MuseScore Studio
2. Select a note or rest where you want the diagram
3. Open **Plugins → Chord Library**
4. Filter or search for a voicing
5. Double-click a voicing card to insert

The plugin reads chord symbols at the selected position and transposes automatically. No chord symbol = no transposition (inserts in C).

### Settings

Click **Settings** in the plugin header to access:

- **Voicing Source URL** — Point the plugin at your own fork or a local file for a custom voicing library. Changes persist between sessions.
- **Diagram Placement** — Choose whether fretboard diagrams appear above (default) or below the staff.
- **Export Voicings** — Save the current voicing library to a local JSON file.
- **Import Voicings** — Load voicings from a JSON file. Validates required fields and merges with the current library (duplicates are skipped by ID).

### Score-top chord diagram section

MuseScore can display all unique chord diagrams in a row between the title and the first system. This works with Chord Library diagrams since they use MuseScore's standard `FretDiagram` element.

To enable: **Format → Style → Fretboard Diagrams → "Show chord diagrams at top of first page"**

## The voicing library

All voicings live in `data/voicings.json`. Organised by:

| Axis | Values | Meaning |
|------|--------|---------|
| **Context** | CM6, CM7, CV6, CV7 | Chord Melody vs Comping/Vocal × 6 vs 7 string |
| **Category** | shell, drop2, drop3, extended, altered, quartal, caged | Voicing type |
| **Quality** | maj7, dom7, min7, min7b5, maj6, min6, dim7, ... | Chord quality |

All shapes stored with root C. Fully moveable.

## Scripts

```bash
# Validate voicings (schema + consistency + note verification)
python scripts/validate.py -v

# Validate with a specific tuning
python scripts/validate.py -v --tuning config/tunings/7string-low-b.json

# Generate Oolimo verification URLs for all voicings
python scripts/oolimo_urls.py

# Generate Oolimo checklist as markdown
python scripts/oolimo_urls.py --format markdown

# Generate CAGED voicings (E/A/D shapes × all qualities)
python scripts/generate_caged.py                          # output to Desktop
python scripts/generate_caged.py -o data/voicings-caged.json  # custom output

# Build Mac + Windows installers
python scripts/build_installer.py
python scripts/build_installer.py --pkg  # also build macOS .pkg

# Generate .mscx XML snippet for a voicing transposed to F
python scripts/generate_mscx_snippet.py --voicing c7-shell-137-e-str-7 --root F

# Generate all voicings transposed to Bb
python scripts/generate_mscx_snippet.py --all --root Bb --output snippets/
```

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md). All voicings must be verified against [Oolimo](https://www.oolimo.com/) before entry.

## References

- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be
- Taylor, Martin. *Complete Jazz Guitar Method*. Alfred Music
- Greene, Ted. *Chord Chemistry*

## Related

- [siege-analytics/jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — `.mpal` palette files (predecessor)
- [siege-analytics/jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — chord melody arrangements
- [Learning Jazz From The Masters](https://learningjazzguitar.substack.com) — Dheeraj Chand's Substack

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Free to use, share, and adapt with attribution to Dheeraj Chand.
