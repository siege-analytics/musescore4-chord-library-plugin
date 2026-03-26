# MuseScore 4 Chord Library Plugin — Development Document

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

### Components

musescore4-chord-library-plugin/
├── plugin/
│   ├── ChordLibrary.qml
│   ├── ui/
│   │   ├── PanelView.qml
│   │   ├── FilterBar.qml
│   │   ├── VoicingGrid.qml
│   │   ├── VoicingCard.qml
│   │   └── SearchBar.qml
│   ├── model/
│   │   ├── LibraryModel.qml
│   │   └── VoicingInserter.qml
│   └── assets/
│       └── icons/
├── schema/
│   └── voicings.schema.json
├── data/
│   └── voicings.json
├── scripts/
│   ├── validate.py
│   └── generate_from_mscz.py
├── docs/
│   └── CONTRIBUTING.md
├── DEVELOPMENT.md
└── README.md

### Data flow
GitHub (voicings.json)
↓  HTTP fetch (Qt.network)
LibraryModel.qml
↓  parsed + filtered
VoicingGrid.qml
↓  user clicks voicing
VoicingInserter.qml
↓  MuseScore plugin API
Selected note in score ← fretboard diagram inserted

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

### Context codes

| Code | Meaning |
|---|---|
| `CM6` | Chord Melody, 6-string |
| `CM7` | Chord Melody, 7-string (Van Eps tuning: low A) |
| `CV6` | Comping/Vocal, 6-string |
| `CV7` | Comping/Vocal, 7-string |

---

## Plugin UI

### Panel layout
┌─────────────────────────────┐
│ Search voicings...          │
├─────────────────────────────┤
│ Context: CM6 CM7 CV6 CV7    │
│ Quality: maj7 dom7 min7 ... │
│ Type:  Shell Drop2 Drop3 .. │
│ Strings: 6  7               │
├─────────────────────────────┤
│ ┌────┐ ┌────┐ ┌────┐        │
│ │    │ │    │ │    │        │
│ │ C7 │ │Cm7 │ │Cma7│        │
│ └────┘ └────┘ └────┘        │
│ Shell  Shell  Shell         │
└─────────────────────────────┘

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

### Phase 1 — JSON schema and data
- [ ] Finalise JSON schema
- [ ] Write schema validator (Python)
- [ ] Enter initial voicings: CM7 Shell set (7 shapes)
- [ ] Publish `voicings.json` to GitHub

### Phase 2 — Plugin scaffold
- [ ] Basic QML plugin structure
- [ ] Panel window opens from Plugins menu
- [ ] Fetch and parse `voicings.json` from GitHub
- [ ] Display raw list of voicing names

### Phase 3 — UI
- [ ] Filter bar (context, quality, type, strings)
- [ ] Search bar
- [ ] Voicing card grid with fretboard thumbnail rendering
- [ ] Selected state on card

### Phase 4 — Score insertion
- [ ] Read selected note and chord symbol
- [ ] Transpose voicing to target key
- [ ] Insert fretboard diagram at selected note
- [ ] Error handling (no note selected, no chord symbol, out of range)

### Phase 5 — Polish
- [ ] Offline fallback (cache last fetched JSON locally)
- [ ] User-defined JSON URL (point to a fork)
- [ ] Contributing guide
- [ ] Release v1.0

---

## Open questions

- Does MuseScore 4's plugin API expose enough of the fretboard diagram object to set individual dot positions programmatically? Needs verification.
- What is the correct QML network fetch pattern for MuseScore 4 specifically?
- Should the plugin support multiple JSON sources (e.g. a community library alongside the official one)?
- Fretboard thumbnail rendering in QML — draw from dot data directly, or use MuseScore's rendering engine?

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