# Siege Analytics Chord Library — Development Document

## Overview

A MuseScore 4 plugin that provides a floating panel UI for browsing, filtering, and inserting jazz guitar chord voicings from a web-hosted JSON library. Intended as a replacement for MuseScore's flat palette system, with support for hierarchical categories, search, and remote updates.

## Problem statement

MuseScore's native palette system is flat — palettes cannot be nested or grouped beyond a single level. For a comprehensive jazz guitar voicing library spanning multiple contexts (chord melody vs comping/vocal), string counts (6 and 7 string), and voicing types (shell, drop 2, drop 3, extended, altered, quartal), this results in an unmanageable number of top-level palettes with no cross-referencing.

Additionally, native palettes cannot be updated remotely — sharing requires manual `.mpal` file distribution. A JSON-driven plugin solves both problems: the library lives online, updates propagate automatically, and the UI can expose any organizational hierarchy.

## Goals

- A MuseScore 4 plugin with a dockable/floating panel UI
- Voicing library hosted as JSON on GitHub, fetched at runtime
- Filter and search by chord quality, context, voicing type, string count
- Click to insert a fretboard diagram at the selected note in the score
- Library updateable without reinstalling the plugin
- Forkable and community-extensible

## Non-goals

- Real-time collaboration
- Audio playback within the plugin
- Support for MuseScore versions prior to 4.x

---
## Architecture

### Components (as of v2.2)

```
musescore4-chord-library-plugin/
├── plugin/                         Self-contained installable unit
│   ├── ChordLibrary.qml            State + routing + signal wiring (~3.3k lines)
│   ├── config/
│   │   ├── modes.json              Mode axis configs (#161)
│   │   ├── styles.json             Style + composition entries (#162)
│   │   └── scales.json             Scale library (#142)
│   ├── data/
│   │   └── voicings.json           820 curated voicings (key of C)
│   ├── tunings/                    Built-in tuning definitions
│   ├── model/                      Pure JS modules (no UI)
│   │   ├── ChordSelector.js        Chord parsing + voicing selection
│   │   ├── VoicingCalculator.js    Runtime voicing generation per tuning
│   │   ├── FingeringEngine.js      Fingering assignment + difficulty
│   │   ├── DiagramEngine.js        Fretboard diagram XML generation
│   │   ├── DataCache.js            Settings/cache serialization
│   │   ├── IRealParser.js          iReal Pro URL/text parsing
│   │   ├── HygieneEngine.js        Library audit
│   │   ├── Transposer.js           Key transposition
│   │   ├── MelodyEngine.js         Melody/bass note analysis
│   │   ├── ChordScales.js          Scale-chord mapping
│   │   ├── ReharmonizationEngine.js  Reharm suggestions
│   │   ├── StyleComposer.js        Style composition resolver (#162)
│   │   ├── FilterEngine.js         Voicing filter logic
│   │   └── BackupManager.js        Backup/restore archive shape (#172, #179)
│   ├── model/ (QML)                Stateful helpers
│   │   ├── BatchEngine.qml         Walkthrough state machine
│   │   ├── TuningManager.qml       Tuning CRUD
│   │   ├── InlineTools.qml         Score-tool actions
│   │   ├── InsertionEngine.qml     Single-chord insertion
│   │   └── VoicingInserter.qml     Diagram insertion glue
│   └── ui/                         QML panels (properties-in / signals-out)
│       ├── LibraryPanel.qml        Tab 0 — search, filter, voicings
│       ├── ScoreToolsPanel.qml     Tab 1 — analysis, calc constraints
│       ├── ExportPanel.qml         Tab 2 — exports
│       ├── ImportPanel.qml         Tab 3 — imports
│       ├── PracticePanel.qml       Tab 4 — practice mode (flash cards)
│       ├── SettingsPanel.qml       Tab 5 — General | Tuning | Scales | Profiles
│       └── WalkthroughPanel.qml    Walkthrough overlay
├── schema/voicings.schema.json     Validation schema
├── scripts/                        Python tools (validation, migration, import)
├── tests/                          198 tests (Python + JS via Node.js sandbox)
├── deploy.sh                       macOS/Linux deploy
├── deploy.ps1                      Windows PowerShell deploy
├── CLAUDE.md                       AI-assistant guidance
├── README.md                       User-facing docs
├── DEVELOPMENT.md                  This file
└── REFERENCES.md                   Citations + bibliography
```

### Data flow (current)

The library is bundled with the plugin (single source of truth in `plugin/data/voicings.json`). Optional features layer on top:

```
plugin/data/voicings.json (bundled)
    ↓
ChordLibrary.qml.loadFromCache()
    ↓
ChordSelector.findBestVoicing() / findAllVoicings()
    ↓
LibraryPanel grid  OR  WalkthroughPanel step
    ↓
User triggers Voice-Here / Voice-All
    ↓
BatchEngine + DiagramEngine generate XML
    ↓
ms-clipboard.py writes diagram to macOS pasteboard
    ↓
cmd("paste") inserts at the score cursor
```

For non-standard tunings, `VoicingCalculator.generateAll(tuningMidi, constraints)` produces voicings at runtime; the result is cached at `~/Documents/MuseScore4/Plugins/chordlibrary/tunings/<slug>-voicings.json`.

For backup/restore (#172) and URL imports (#67), `BackupManager` handles archive serialization, version-checking (#179), and merge.

---

## JSON schema

Each voicing in the library is a JSON object with the following structure:
```json
{
  "id": "c7-shell-137-e-str-7",
  "name": "C7 — Shell 137 — E str",
  "chord_quality": "dom7",
  "root": "C",
  "category": "shell",
  "context": "CM7",
  "strings": 7,
  "fret_number": 8,
  "visible_frets": 4,
  "dots": [
    {"string": 6, "fret": 1},
    {"string": 4, "fret": 1},
    {"string": 3, "fret": 2}
  ],
  "mutes": [7, 5, 2, 1],
  "open": [],
  "notes": ["C", "Bb", "E"],
  "intervals": ["1", "b7", "3"],
  "tags": ["shell", "guide-tone", "e-string-root"]
}
```

### Field reference

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier, kebab-case |
| `name` | string | Human-readable label shown in UI |
| `chord_quality` | string | `maj7`, `dom7`, `min7`, `min7b5`, `dim7`, `maj6`, `dom9`, `dom7b9`, etc. |
| `root` | string | Reference root note, always `C` for moveable shapes |
| `category` | string | `shell`, `drop2`, `drop3`, `extended`, `altered`, `quartal` |
| `context` | string | `CM6`, `CM7`, `CV6`, `CV7` |
| `strings` | integer | 6 or 7 |
| `fret_number` | integer | First visible fret in diagram |
| `visible_frets` | integer | Number of frets shown (default 4) |
| `dots` | array | `{string, fret}` pairs — string 1 = high e, string 6/7 = low E/A |
| `mutes` | array | String numbers to mark as muted (X) |
| `open` | array | String numbers to mark as open (O) |
| `notes` | array | Actual note names at reference position |
| `intervals` | array | Chord intervals (1, 3, b7, etc.) |
| `tags` | array | Freeform tags for search |

### Mode axis (v2.1+)

The `context` field on voicings was retired in #174 / #184. Playing role is now expressed as a per-voicing `suitableModes` array referring to entries in `plugin/config/modes.json`.

| Mode | Meaning |
|---|---|
| `chord-melody` | Melody note on top; top-note match scored heavily |
| `comping` | Accompaniment; mid-range shells/drop 2s preferred |
| `solo-guitar` | Bass + chord + melody on one instrument; wider range |
| `duo` | Comping behind voice/another instrument; narrow mid-upper range |

Tuning carries the string-count dimension that legacy CM6/CM7/CV6/CV7 codes packed into one string.

---

## Plugin UI

### Panel layout (Library tab, v2.2)

```
┌─────────────────────────────────────────┐
│ Library | Score Tools | Export | …      │  (top-level tab bar)
├─────────────────────────────────────────┤
│ Search voicings…                        │
│ Quality: All | maj7 | dom7 | min7 | …   │
│ Type:    All | Shell | Drop2 | Drop3 …  │
│ Scale:   All | Mixolydian | Dorian | …  │
│ Tuning:  Standard 6-String              │
│ Mode:    Chord Melody                   │
│ Style:   Default                        │
├─────────────────────────────────────────┤
│ ┌──────┐ ┌──────┐ ┌──────┐               │
│ │  C7  │ │ Cm7  │ │ Cmaj7│  Voicing cards│
│ │ ♫♫♫  │ │ ♫♫♫  │ │ ♫♫♫  │  fretboard +  │
│ │Shell │ │Shell │ │Drop2 │  metadata     │
│ └──────┘ └──────┘ └──────┘               │
└─────────────────────────────────────────┘
```

### Interaction model

- Selecting a note in the score enables the insert action
- Single click on a voicing card previews it (highlights the card)
- Double click inserts it at the selected note
- The plugin transposes automatically — if the selected note's chord symbol is F7 and you click a C7 voicing, the fret number adjusts by +5 semitones

### Transposition logic

All voicings are stored with root C. On insert:

1. Read the chord symbol attached to the selected note
2. Parse the root note from the chord symbol
3. Calculate semitone offset from C to target root
4. Add offset to `fret_number`
5. Insert diagram with adjusted fret number, same dot pattern

---

## MuseScore 4 plugin API — key methods
```javascript
// Access current score
var score = curScore

// Get selected element
var element = score.selection.elements[0]

// Add fretboard diagram to a note
var diagram = newElement(Element.FRETBOARD_DIAGRAM)
diagram.fretOffset = fretNumber - 1  // 0-indexed
// set dot positions via diagram.setDot(string, fret, finger)
// set mutes via diagram.setDot(string, 0, -1)

// Insert into score
var cursor = score.newCursor()
cursor.rewindToSelection()
cursor.add(diagram)
```

Note: the exact API for fretboard diagram manipulation needs verification against the MuseScore 4 plugin API docs — the above is based on MuseScore 3 patterns and may need updating.

---

## Development phases

### Phase 1 — JSON schema and data (complete, v1.0)
- [x] JSON schema with extensible strings (4-12), free-text category/quality
- [x] Note-computation validator with per-voicing tuning support
- [x] Voicing data published bundled with the plugin (no longer fetched at runtime)

### Phase 2 — Plugin scaffold (complete, v1.0)
- [x] QML plugin loads in MuseScore Studio 4.x (verified through 4.6; 4.7 expected to work)
- [x] Local voicing cache persists between sessions

### Phase 3 — UI (complete, v1.0 → v2.0)
- [x] Filter dropdowns: quality, type, scale, tuning, mode, style
- [x] Search bar with name, quality, and tag matching
- [x] Fretboard thumbnail canvas on voicing cards with interval color coding
- [x] Phase A decomposition: extracted Library/Settings/Walkthrough/Score Tools/Import/Practice panels

### Phase 4 — Score insertion (complete, v1.0)
- [x] Key-aware transposition with correct enharmonic spelling
- [x] Insert fretboard diagram via macOS-pasteboard + cmd("paste") workflow
- [x] Diagram placement above/below staff (configurable)

### Phase 5 — Polish + tuning system (complete, v1.0 → v2.0)
- [x] Configurable tuning system with import and create
- [x] User-defined JSON URL (deprecated in v2.2 in favor of bundled data + community-packs URL import)
- [x] Export/import voicings as JSON
- [x] v1.0.0 release

### Phase 6 — Mode + style + sections (complete, v2.1 → v2.2)
- [x] `context` field retired (#160, #174); replaced by `suitableModes` array
- [x] Four-mode axis: chord-melody, comping, solo-guitar, duo (#161)
- [x] Style composition engine: blend multiple styles with user-selectable rules (#162)
- [x] Section-based mode: per-section overrides in walkthrough (#167)
- [x] Backup + restore with archive-version migration (#172, #179)
- [x] URL import from community-packs repo (#67 Phase 1)
- [x] Windows compliance: homePath + deploy.ps1 + CI matrix (#176)
- [x] Built-in tuning rename + edit-in-place + reset-to-factory
- [x] Megarelease code-review pass + 8 follow-up tickets (#178-#185)

---

## Resolved questions

- **Does MuseScore 4's plugin API expose setDot()?** No. Workaround: write diagram XML to macOS pasteboard via a Swift CLI tool (`ms-clipboard`), then call `cmd("paste")` from the plugin. Filed [PR #32848](https://github.com/musescore/MuseScore/pull/32848) to add `setDot()` upstream.
- **QML network fetch pattern?** Standard `XMLHttpRequest` works in MuseScore's QML engine.
- **Multiple JSON sources?** Supported via import/merge. The plugin merges imported voicings into the local cache, skipping duplicates by ID.
- **Fretboard thumbnail rendering?** Canvas renderer is inline in the main plugin delegate. Each voicing card shows a mini fretboard diagram with dots color-coded by interval (root=red, 3rd=blue, 5th=green, 7th=orange, 9th=purple, 4th/11th=teal, 6th/13th=gold). Adapts to dark/light mode.

---

## References

- [MuseScore 4 Plugin API](https://musescore.org/en/handbook/4/plugins)
- [MuseScore Plugin development forum](https://musescore.org/en/forum/7)
- [Qt QML Network documentation](https://doc.qt.io/qt-6/qtnetwork-index.html)
- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be.
- Taylor, Martin. *Complete Jazz Guitar Method*. Alfred Music.

---

## License

Licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

You are free to use, share, and adapt this material for any purpose, provided you credit **Dheeraj Chand** and link to this repository.