# musescore4-chord-library-plugin

> **SESSION START**: Read this file and `REFERENCES.md` before making any changes.

## Working Guidelines for AI Assistants

### 1. Slow and Deliberate

Always plan first, never jump to implementation:
- Explore the codebase to understand context
- Ask clarifying questions upfront
- One correct solution beats sixty rushed attempts
- Use TodoWrite to track multi-step tasks

### 2. Senior Engineer Mindset

- High-quality, maintainable code following existing patterns
- Explicit over implicit
- Proper error handling — errors should never pass silently
- Simple is better than complex — resist over-engineering

### 3. Test Before Presenting

- Run `python3 -m pytest tests/ -v` and iterate until all pass (currently 90 tests)
- Only present finished, tested solutions
- **Don't push untested code** — review and fix first, push after

### 4. Attribution

- All work must be ticketed on GitHub first (use the `create-ticket` skill)
- Always credit researchers and open-source projects in tickets and code (see REFERENCES.md)
- Commit co-authorship: `Co-Authored-By: Craft Agent <agents-noreply@craft.do>`

## Project Overview

A MuseScore Studio 4 plugin for jazz guitar chord voicing management. 820+ curated voicings, runtime calculator for alternate tunings, physically-aware fingering engine with barre detection and difficulty scoring.

**Owner**: Dheeraj Chand (Siege Analytics). Jazz guitarist, 7-string player. Will spot impossible fingerings.
**License**: CC BY 4.0
**Tech stack**: QML/JavaScript (MuseScore 4 plugin API), Python (scripts/tests)

## Architecture

### Django-style separation

- **`plugin/model/*.js`** = business logic (pure functions, no UI)
- **`plugin/ui/*.qml`** = visual components
- **`plugin/ChordLibrary.qml`** = state management, routing, wiring (~3626 lines)

Phase A decomposition complete (6 tab panels extracted). Phase B (logic modules) is next.

### Self-contained plugin

`plugin/` is the complete installable unit. Users copy it to their MuseScore Plugins directory. No scripts, no terminal. `deploy.sh` is developer-only (rsync).

### `.pragma library` rules

- **Safe** (no QML callbacks): HygieneEngine, FingeringEngine, DataCache, IRealParser, VoicingCalculator, Transposer, MelodyEngine, ChordScales, ReharmonizationEngine
- **NOT safe** (receive function callbacks): ChordSelector, FilterEngine, DiagramEngine
- **Cross-importing between `.pragma library` modules is NOT supported** in QML — use inline functions

### Physical hand model

- **Mersenne's Law**: `fretWidth(n) = 36mm / 2^((n-1)/12)`
- **CombinoChord distance table** (Smith 2021, IEEE): inter-finger mm constraints
- **Barre types**: full, hinge, tip (Ted Greene), diagonal (Van Eps, fret 10+)
- **Difficulty scoring**: 0-100 across stretch, finger count, barre complexity, position, thumb
- **71% exact match** against tombatossals/chords-db (3,282 voicings)

### Decomposition pattern (ADR-001)

**Properties-in / signals-out with state groups.** Each tab panel is a self-contained QML
component that receives typed state groups (QtObject properties) and emits signals for all
actions. ChordLibrary.qml remains the router — it handles signal wiring, state mutation,
and JS module dispatch.

- Panels NEVER mutate parent state directly — always emit a signal
- Panels NEVER import JS model modules — parent passes callback functions as properties
  (e.g. `computeNotesForTuningFn`, `suggestFingeringFn`, `difficultyFn`)
- Timers that defer UI rendering (e.g. ImportPanel's initTimer) stay in the panel
  (UI concern), but their `onTriggered` emits a signal — parent does the heavy work
- `statusMsg` is a global status bar label in ChordLibrary.qml, not inside any panel
  (96 references across the codebase — migration to property deferred to Phase C, #104)

### Voicing ranking

- `ChordSelector.findBestVoicing()` ranks candidates by context (+100), quality (+20),
  category (shell +10, drop2 +5), melody/bass match, proximity, and register preference
- **Difficulty penalty** (#105): expert -30, advanced -10, standard 0. Uses
  `FingeringEngine.computeDifficulty()` passed as a callback to avoid cross-module import
- Mute penalty: -5 per muted string. Same-shape-as-previous penalty: -15

### Key design decisions

- `onActivated` not `onCurrentIndexChanged` for ComboBoxes (prevents cascade on model rebuild)
- All voicings stored in key of C — transposed at runtime
- Voicing cache per tuning, persisted to disk (`tunings/<slug>-voicings.json`)
- All contexts always shown in dropdown — even if current tuning has zero voicings
- Thumb (T/finger 0) offered as alternative, not default
- Individual finger assignments preferred over mini-barres (standard pedagogy)
- Difficulty tier displayed in walkthrough: green (standard), yellow (advanced), red (expert)

## Key Directories

```
plugin/                    # Self-contained installable plugin
  ChordLibrary.qml         # State management, routing, wiring (~2266 lines)
  config/contexts.json      # Context labels
  data/voicings.json        # 820+ voicing library (key of C)
  tunings/                  # 6 guitar tuning configs
  model/                    # 12 JS business logic modules
  ui/                       # 12 QML visual components
    ExportPanel.qml          # Tab 2: Export (114 lines)
    ImportPanel.qml          # Tab 3: Import, rebuild, iReal, presets (319 lines)
    PracticePanel.qml        # Tab 4: Flash cards (274 lines)
    ScoreToolsPanel.qml      # Tab 1: Analysis, constraints, annotations (235 lines)
    SettingsPanel.qml        # Tab 5: Tuning, save to library, audit (560 lines)
    LibraryPanel.qml         # Tab 0: Search, filters, voicing list, comparison (544 lines)
    WalkthroughPanel.qml     # Voice Score overlay (640 lines)
    VoicingCard.qml, VoicingGrid.qml, FilterBar.qml, SearchBar.qml, PanelView.qml
docs/
  fingering-research-report.md   # Comprehensive research
references/databases/            # Validation datasets (MIT/CC BY 4.0)
schema/voicings.schema.json      # Data validation schema
scripts/                         # Python tools
tests/                           # 90 tests (pytest)
REFERENCES.md                    # Full credits and bibliography
```

## Common Commands

```bash
python3 -m pytest tests/ -v              # Run all 90 tests
python3 scripts/validate.py -v           # Validate voicing data
bash deploy.sh                           # Deploy to local MuseScore (dev only)
bash deploy.sh --watch                   # Auto-deploy on file changes
```

## Open Issues (as of 2026-04-10)

- **#75** — Epic: decompose ChordLibrary.qml (Phases A, B, C complete; 5174→2273 lines)
- **#74** — cmd("paste") broken in batch insert (core bug, needs MuseScore API fix)

## MuseScore 4 Plugin API Limitations

- QML caching requires quit-and-relaunch for every code change
- No `setDot()` API — uses clipboard workaround for diagram insertion
- No `removeElement()` — update elements in place
- No `WorkerScript` — calculations block UI thread (use Timer deferral for progress messages)
- No title frame access (VBox/POET/SUBTITLE creation)
- Arrays/objects modified in place don't trigger QML bindings — always reassign

## Common Pitfalls

- **ComboBox cascades**: `onCurrentIndexChanged` fires on model rebuilds → use `onActivated`
- **QML property mutation**: `.push()` doesn't trigger bindings → build new array/object and assign
- **`.pragma library` callbacks**: modules with `.pragma library` can't receive QML closure callbacks — pass direct function references + data separately
- **Fret calculations**: dot.fret is relative to fret_number (row 1 = fret_number). Absolute fret = fret_number + dot.fret - 1.
- **String numbering**: 1 = high e, 6 = low E, 7 = low A (Van Eps)
- **Child QML scope**: `newElement()` only exists on the root MuseScore plugin object. Child Items in `model/` or `ui/` must receive `pluginRef: chordLibrary` and call `pluginRef.newElement()`. Also add `import MuseScore 3.0` to any QML file that uses `Element.*` constants. See VoicingInserter.qml for the pattern.

---

*Last updated: 2026-04-10*
