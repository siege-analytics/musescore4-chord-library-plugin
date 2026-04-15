# Siege Analytics Chord Library

A MuseScore Studio 4 plugin that gives jazz guitarists a searchable, filterable chord voicing library with physically-validated fingerings. 820+ voicings across 39 chord qualities, with fretboard diagrams that insert directly into your score.

## Features

- **820+ curated voicings** in the key of C, auto-transposed to any chord symbol
- **Runtime voicing calculator** generates voicings for any tuning on the fly
- **Physically-aware fingering engine** validates every voicing against a biomechanical hand model (Mersenne's Law + CombinoChord distance table)
- **Barre detection** — full, partial/hinge, tip (Ted Greene), and diagonal barres
- **Difficulty scoring** — each voicing rated standard / advanced / expert, shown in walkthrough
- **Fingering display** — fingering notation (e.g. X X 1 2 3 4) shown on every voicing card and in the walkthrough
- **Melody Lock** — lock voicings to the melody note on top; persists through Voice All and bass string switching
- **Chord-scale suggestions** — clickable scale chips in the walkthrough showing transposed scale notes and intervals (Mixolydian, Lydian b7, Bebop Dom, Blues, etc.)
- **Chord analysis** — voicing notes, chord tones vs tensions, and voice leading context shown in the walkthrough tray
- **Bass string navigation** — browse voicings by bass string position (Str 4, 5, 6, 7) with melody-filtered alternatives
- **iReal Pro import** — paste a URL or chord chart, get voicings matched automatically
- **Arrangement presets** — save and load voiced chord progressions
- **Voicing comparison** — side-by-side view of up to 3 voicings
- **Custom contexts** — create new voicing contexts beyond the built-in set (Settings tab)
- **Dark/light theme** — adapts to your MuseScore color scheme
- **6 guitar tunings** — Standard, 7-String Van Eps, 7-String Low B, DADGAD, All Fourths, Baritone (default: Van Eps)

## Install

### Simple (recommended)

1. Download or clone this repository
2. Copy the **`plugin/`** folder to `~/Documents/MuseScore4/Plugins/`
3. Rename it to **`chordlibrary`**
4. Restart MuseScore Studio
5. Enable **Siege Analytics Chord Library** under **Plugins > Manage Plugins**

That's it — the `plugin/` directory is completely self-contained. No scripts, no terminal commands.

### macOS path

```
~/Documents/MuseScore4/Plugins/chordlibrary/
```

### Windows path

```
%USERPROFILE%\Documents\MuseScore4\Plugins\chordlibrary\
```

## Usage

### Inserting voicings

1. Open a score and select a note or rest
2. Open **Plugins > Chord Library**
3. Use the dropdowns to filter by context, quality, voicing type, and tuning
4. Click **Open** on a voicing card
5. The fretboard diagram appears at the cursor, transposed to the chord symbol's key

If no chord symbol is present, the voicing inserts in C.

### Walkthrough mode (Voice All)

Click **Voice All** to step through a chord progression one chord at a time. The plugin finds the best voicing for each chord based on your context, melody/bass preferences, and voice leading. Each step shows:

- **Fretboard diagram** with color-coded interval dots and fret position
- **Difficulty tier** (Standard / Advanced / Expert) with score
- **Fingering notation** (e.g. X X 1 2 3 4)
- **Bass string selector** — browse alternatives grouped by bass string position
- **Clickable scale chips** — tap a scale name to see transposed notes and intervals
- **Chord analysis** — voicing notes, chord tones vs tensions, voice leading from previous chord
- **Melody/bass lock** — lock the top or bass note across all voicings; arrow navigation shows only matching voicings
- **Reharmonization chips** — tritone sub, diminished passing, sus4 alternatives
- **Per-chord override** — type a note in the Mel/Bass field to override just this chord

### Import tab

- **Rebuild Voicings** — regenerate voicings for the current tuning (first time only; cached afterward)
- **Reset All Data** — clear all caches and reload from the bundled library
- **iReal Pro import** — paste an iReal Pro URL or type chords space-separated
- **Arrangement presets** — save/load voiced progressions as JSON files

### Fretboard diagram colors

Dots are color-coded by interval:

| Color | Interval |
|-------|----------|
| Red | Root (1) |
| Blue | 3rd (3, b3) |
| Green | 5th (5, b5, #5) |
| Orange | 7th (7, b7) |
| Purple | 9th (9, b9, #9) |
| Teal | 4th / 11th |
| Gold | 6th / 13th |

### Contexts

| Code | Name | Use case |
|------|------|----------|
| **CV6** | Comping — 6 string | Guitar provides harmony; melody carried by voice or another instrument |
| **CV7** | Comping — 7 string | Same, with Van Eps 7-string for extended bass range |
| **CM6** | Chord Melody — 6 string | Guitar carries both melody and harmony |
| **CM7** | Chord Melody — 7 string | Same, with 7-string for bass independence |

### Voicing types

| Type | Description |
|------|-------------|
| **Shell** | Root + 3rd + 7th. Freddie Green / guide tone chords. |
| **Drop 2** | 4-note close voicing with 2nd voice dropped an octave. Jazz guitar workhorse. |
| **Drop 3** | 4-note close voicing with 3rd voice dropped. Wider spread. |
| **Extended** | 9ths, 11ths, 13ths — the colorful chords. |
| **Altered** | Dominant chords with b9, #9, b5, #5 tensions. |
| **Quartal** | Stacked 4ths. McCoy Tyner / Bill Evans sound. |

### Chord qualities

39 qualities: dom7, maj7, min7, min7b5, dim7, dom7alt, dom7b9, dom7#9, dom9, dom13, dom7#11, dom7b13, maj6, min6, maj9, min9, min-maj7, aug7, sus4, sus2, and more.

## Tunings

Six guitar tunings are included:

| Tuning | Strings | Open pitches |
|--------|---------|-------------|
| **Standard** | 6 | E4-B3-G3-D3-A2-E2 |
| **Van Eps 7-String** | 7 | E4-B3-G3-D3-A2-E2-A1 |
| **7-String Low B** | 7 | E4-B3-G3-D3-A2-E2-B1 |
| **DADGAD** | 6 | D4-A3-G3-D3-A2-D2 |
| **All Fourths** | 6 | F4-C4-G3-D3-A2-E2 |
| **Baritone** | 6 | B3-F#3-D3-A2-E2-B1 |

Non-standard tunings calculate voicings on first use and cache them to disk. Subsequent startups load instantly.

Custom tunings can be created in **Settings > Tuning**.

## Fingering Engine

The plugin includes a physically-aware fingering engine that validates every voicing:

- **CombinoChord hand model** — inter-finger distance constraints in millimeters, fret widths via Mersenne's Law
- **Barre type detection** — full, hinge (partial), tip (Ted Greene), diagonal (Van Eps, fret 10+)
- **Difficulty scoring** — 0-100 score across 5 factors: stretch, finger count, barre complexity, fret position, thumb usage
- **71% exact match** against 3,282 expert-fingered reference voicings (tombatossals/chords-db)

See [docs/fingering-research-report.md](docs/fingering-research-report.md) for the full research report.

## Developer setup

### Prerequisites

- Python 3.10+ with `pip install jsonschema pillow`
- MuseScore Studio 4
- macOS, Windows, or Linux

### Quick start

```bash
git clone https://github.com/siege-analytics/musescore4-chord-library-plugin.git
cd musescore4-chord-library-plugin

python -m venv .venv && source .venv/bin/activate
pip install jsonschema pillow

# Run tests (90 tests)
python -m pytest tests/ -v

# Validate voicings
python scripts/validate.py -v

# Deploy to MuseScore (developer convenience)
bash deploy.sh
```

### Project structure

```
plugin/                          # Self-contained plugin (copy this to install)
  ChordLibrary.qml              # Main plugin — state, routing, UI (~5100 lines)
  config/contexts.json           # Context display labels
  data/voicings.json             # 820+ voicing library (all in key of C)
  data/progressions/             # Built-in chord progressions
  tunings/                       # Guitar tuning configs (6 tunings)
  model/                         # Business logic (JS modules)
    ChordSelector.js             # Chord parsing + voicing selection
    FilterEngine.js              # Voicing filtering and search
    FingeringEngine.js           # Fingering assignment + difficulty scoring
    VoicingCalculator.js         # Runtime voicing generation
    DiagramEngine.js             # Fretboard diagram XML generation
    DataCache.js                 # Settings/cache serialization
    IRealParser.js               # iReal Pro URL/text parser
    HygieneEngine.js             # Library audit (duplicates, enharmonics)
    Transposer.js                # Key transposition
    MelodyEngine.js              # Melody/bass note analysis
    ChordScales.js               # Scale-chord mapping
    ReharmonizationEngine.js     # Reharmonization suggestions
  ui/                            # Visual components (QML)
    WalkthroughPanel.qml         # Guided walkthrough UI
    VoicingCard.qml              # Single voicing card
    VoicingGrid.qml              # Grid layout for cards
    FilterBar.qml                # Filter controls
    SearchBar.qml                # Search field
    PanelView.qml                # Panel container
    ExportPanel.qml              # Export tab (WIP)
docs/
  fingering-research-report.md   # Comprehensive fingering algorithm research
references/
  databases/                     # Reference chord databases for validation
schema/
  voicings.schema.json           # JSON schema for voicing data
scripts/                         # Python tools (validation, export, generation)
tests/
  test_core.py                   # Unit tests (66 tests)
  test_integration.py            # Integration tests (24 tests)
REFERENCES.md                    # Full credits and bibliography
```

### Architecture

The plugin follows a **Django-style separation**:

- **`model/*.js`** = models/managers (pure business logic, no UI)
- **`ui/*.qml`** = templates (visual components)
- **`ChordLibrary.qml`** = views + urls (state management, routing, wiring)

JS modules that don't receive QML callbacks use `.pragma library` for singleton evaluation (faster startup). Modules that receive function callbacks (ChordSelector, FilterEngine, DiagramEngine) stay non-pragma.

See [REFERENCES.md](REFERENCES.md) for full academic references and credits.

## References

- Greene, Ted. *Chord Chemistry*. Alfred Music, 1971.
- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be
- Smith, Nicholas T. "CombinoChord." *IEEE*, 2021.
- See [REFERENCES.md](REFERENCES.md) for complete bibliography.

## Related projects

- [siege-analytics/jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — `.mpal` palette files (predecessor)
- [siege-analytics/jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — chord melody arrangements

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)

Free to use, share, and adapt with attribution to **Dheeraj Chand / Siege Analytics**.
