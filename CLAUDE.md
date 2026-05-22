# musescore4-chord-library-plugin

> **SESSION START**: Read this file, `REFERENCES.md`, and `docs/design-philosophy.md` before making any changes.
>
> Note: as of 2026-05-22 (session 260521-aware-nebula) the project's identity has evolved from "chord voicing management" to a **jazz arrangement system**. The framing in this file is partially historical; `docs/design-philosophy.md` is the operative scope and design contract. When the two conflict, the design-philosophy doc wins. See also `.agents/skills/jazz-system/SKILL.md`.

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

- Run `python3 -m pytest tests/test_js_modules.py tests/test_core.py -v` and iterate until all pass (currently 198 tests). The full `tests/` suite includes macOS-pasteboard integration tests that are environmental and skipped on CI.
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

- `ChordSelector.findBestVoicing()` ranks candidates by quality (+20),
  category (shell +10, drop2 +5), melody/bass match (with mode-driven multipliers),
  proximity, and register preference. The legacy `+100 for context match` rubric was
  retired in #174 — Mode + Tuning now carry that responsibility.
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
  ChordLibrary.qml         # State management, routing, wiring (~2365 lines)
  config/contexts.json      # Context labels
  config/scales.json        # Scale definitions, chord-scale mappings (#142)
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
python3 -m pytest tests/ -v              # Run all 197 tests (90 Python + 107 JS module)
python3 scripts/validate.py -v           # Validate voicing data
bash deploy.sh                           # Deploy to local MuseScore (dev only)
bash deploy.sh --watch                   # Auto-deploy on file changes
```

### JS Module Testing (#145)

`.pragma library` modules are pure JS — tested directly via Node.js from pytest.
`tests/js_runner.js` strips QML directives and evaluates modules in a VM sandbox.
Tests cover: ChordScales, FilterEngine, Transposer, DataCache, IRealParser,
HygieneEngine, MelodyEngine, ReharmonizationEngine, VoicingCalculator, FingeringEngine.

CI runs on every push to main/develop and on all PRs (`.github/workflows/test.yml`).

## Open Issues (as of 2026-04-16)

- **#75** — Epic: decompose ChordLibrary.qml (Phases A, B, C complete; 5174→2365 lines)
- **#142** — Scale management (implemented: scales.json, ChordScales.js CRUD, 43 chord-scale mappings)
- **#144** — Tab content redistribution (implemented: Import/Create Tuning → Import, Save/Audit → Library)
- **#145** — Test modernization (Tier 1 complete: 107 JS tests, CI workflow)
- **#146** — Style profiles (implemented: profiles.json, 4 built-in profiles, ChordSelector weights, profile selector)
- **#147** — Scale UX polish (implemented: delete confirmation, duplicate, validation feedback)
- **#148** — Tuning list view (implemented) + context-tuning auto-switch (implemented)
- **#149** — iReal Pro file import (Part A: file picker — implemented; Part B: score creation — deferred)
- **#150** — Walkthrough layout collision (fixed)
- **#151** — Clickable scale chips on voicing cards (implemented)
- **#154** — QML scoping: signal handlers in LibraryPanel/InlineTools wrote to child properties instead of chordLibrary (fixed: explicit `chordLibrary.` qualification)
- **#159** — Band-in-a-Box import (parse .SGU/.MG? chord charts into walkthrough — needs format research)
- **#149B** — iReal Pro score creation (deferred from #149 Part A)
- **#74** — cmd("paste") broken (wishlist — needs MuseScore C++ change, PR #32848 rejected)

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
- **Child QML scope**: `newElement()` only exists on the root MuseScore plugin object. Child Items in `model/` or `ui/` must receive `pluginRef: chordLibrary` and call `pluginRef.newElement()`. Do NOT add `import MuseScore 3.0` to child files — it breaks plugin loading. `Element.*` constants resolve through QML's parent scope chain. See VoicingInserter.qml for the pattern.
- **Signal handler scoping trap**: Inside `ChildComponent { onSignal: { propName = val } }`, `propName` resolves to the child's property if it declares one, NOT the parent's. Always qualify: `chordLibrary.propName = val`. This caused #154 — context/tuning switching silently wrote to LibraryPanel copies instead of ChordLibrary's canonical state.
- **Duplicate function names**: QML does not allow two functions with the same name in a component — even if they have different parameter counts. The plugin will fail to load with "Duplicate method name" in the log. Always check `grep -n "function " plugin/ChordLibrary.qml | sed 's/(.*//; s/.*function //' | sort | uniq -d` before committing.

## Masters schema (#220 / #276 Stage A)

`plugin/data/masters.json` is governed by `schema/masters.schema.json`. The schema declares a **dual-shape window**: each master may carry the legacy `principles[]` array, the new `systems[]` array (systems-with-three-layers per `docs/design-philosophy.md`), or both. At least one is required. Per-master migrations land in #277-#285; Stage C will drop `principles`.

**System IDs** are `<master>:<slug>` (e.g. `van-eps:harmonized-scale`). A leading `_placeholder:` prefix marks an intentionally-empty system whose interior is pending design (relaxes the non-empty-members rule).

**Engine payload `kind`** is either one of 12 named kinds traced to predecessor session 260521-aware-nebula's `plans/schema-systems-model.md` (lines 121-134) — `PositionContinuity`, `VoiceMotion`, `StringSetTransition`, `SymmetryMovement`, `FamilyCoherence`, `SubstitutionExpand`, `DensityFloor`, `DensityCeiling`, `OmissionAllow`, `ColorToneRequire`, `NCTHarmonization`, `TextureCycle` — or a `_pending:<kebab-slug>` placeholder for kinds awaiting definition. A formal glossary defining each kind's semantics is pending; until then these names are nominal labels, not behavioral contracts. (PR #290 originally shipped a 12-name enum where 9 names were invented without design source; #295 rolled them back to the predecessor-designed set.)

**Validate** with:

```
python scripts/validate.py --target masters
```

**MastersStore.js** accessors for systems (alongside the existing principle accessors): `allSystems(store)`, `findSystem(store, masterId, systemId)`, `preferencesFor(store, masterId)`, `findPreferenceById(store, prefId)`, plus `counts(store)` now reports `systems`.

---

*Last updated: 2026-05-22*
