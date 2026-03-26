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
