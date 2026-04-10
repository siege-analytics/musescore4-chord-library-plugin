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
- **`plugin/ChordLibrary.qml`** = state management, routing, wiring (~5100 lines)

Decomposition into tab-level QML components is ongoing (#75, #79).

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

### Key design decisions

- `onActivated` not `onCurrentIndexChanged` for ComboBoxes (prevents cascade on model rebuild)
- All voicings stored in key of C — transposed at runtime
- Voicing cache per tuning, persisted to disk (`tunings/<slug>-voicings.json`)
- All contexts always shown in dropdown — even if current tuning has zero voicings
- Thumb (T/finger 0) offered as alternative, not default
- Individual finger assignments preferred over mini-barres (standard pedagogy)

## Key Directories

```
plugin/                    # Self-contained installable plugin
  ChordLibrary.qml         # Main plugin source
  config/contexts.json      # Context labels
  data/voicings.json        # 820+ voicing library (key of C)
  tunings/                  # 6 guitar tuning configs
  model/                    # 12 JS business logic modules
  ui/                       # 7 QML visual components
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

- **#75** — Epic: decompose ChordLibrary.qml
- **#79** — Phase 4: extract tab UIs into QML components
- **#92** — Fingering validation with partial barre support (phases 1-5 done)
- **#93** — Fret-distance finger assignment (implemented, 71% validation)

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

---

*Last updated: 2026-04-10*
