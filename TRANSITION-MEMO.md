# Transition Memo — ChordLibrary v2.0

**Date:** 2026-04-17 (updated)
**Author:** Dheeraj Chand (with Craft Agent)
**Repo:** `/Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin`
**Installed:** `~/Documents/MuseScore4/Plugins/chordlibrary/`
**Branch:** `develop` (7 commits ahead of origin)

---

## What This Is

A MuseScore 4 QML plugin for jazz guitar chord voicing — a library browser, guided walkthrough for voicing entire scores, and a runtime voicing calculator that generates geometrically correct voicings for any guitar tuning. Supports 6- and 7-string guitars with multiple tunings including standard, Van Eps, all-thirds (Ralph Patt), DADGAD, all-fourths, and baritone.

---

## Architecture (Post-Decomposition)

| File | Lines | Purpose |
|------|-------|---------|
| `plugin/ChordLibrary.qml` | ~2,900 | Main plugin: state management, scoring, signal routing |
| `plugin/ui/LibraryPanel.qml` | ~900 | Library tab: filters, voicing list, ComboBoxes |
| `plugin/ui/SettingsPanel.qml` | ~450 | Settings tab: tuning CRUD, calculator constraints |
| `plugin/ui/WalkthroughPanel.qml` | ~450 | Walkthrough overlay: preview, controls, voice leading |
| `plugin/ui/ImportPanel.qml` | ~200 | Import tab: JSON, iReal Pro, tuning import |
| `plugin/model/InlineTools.qml` | ~400 | Score tools: analysis, fingering, export |
| `plugin/model/MelodyEngine.js` | ~310 | Melody/bass scoring, voice leading, note parsing |
| `plugin/model/VoicingCalculator.js` | ~440 | Runtime voicing generation from tuning geometry |
| `plugin/model/FilterEngine.js` | ~100 | Voicing filtering by context, category, quality, scale |
| `plugin/model/IRealParser.js` | ~250 | iReal Pro URL/HTML/plain text chord parsing |
| `plugin/model/ReharmonizationEngine.js` | ~124 | Reharm suggestions (tritone subs, ii-V, etc.) |
| `plugin/model/Transposer.js` | ~126 | Semitone transposition, note spelling |
| `plugin/model/ChordScales.js` | ~200 | Chord-scale mappings (43 qualities) |
| `plugin/model/DataCache.js` | ~100 | Voicing cache read/write |
| `deploy.sh` | ~47 | Copies source files to MuseScore plugin dir |

### Key Design Decisions

1. **No symlinks.** MuseScore's `FileIO` sandbox resolves symlinks and refuses to write outside the plugin directory. Use `deploy.sh` to copy files.

2. **Harmonic geometry, not fret shifting.** Voicings for non-standard tunings are calculated from pitch class sets placed on the actual fretboard — not standard-tuning shapes with fret offsets. This is mathematically correct for any tuning including those with non-standard inter-string intervals (DADGAD, all-fourths, etc.).

3. **12-root generation.** Open strings can't be transposed. The calculator generates voicings for all 12 roots so open strings always produce correct chord tones. `findBestVoicing` matches by root — no transposition needed for calculated voicings.

4. **Standard library for standard tuning.** The 820 hand-curated voicings are still used for standard 6-string tuning. The runtime calculator only activates for non-standard tunings.

5. **Explicit `chordLibrary.` qualification in all child component handlers.** Signal handlers inside `LibraryPanel {}`, `InlineTools {}`, etc. MUST use `chordLibrary.propertyName` — bare `propertyName` resolves to the child component's own property if it declares one with the same name, silently writing to the wrong object. This caused #154 (context/tuning filtering appeared broken). See CLAUDE.md Common Pitfalls.

6. **Imperative `syncIndex()` pattern for ComboBoxes.** Declarative `currentIndex:` bindings are destroyed the first time a user clicks the ComboBox. Use `syncIndex()` functions called from `onModelChanged`, `Component.onCompleted`, and parent `onPropertyChanged` handlers.

7. **Array model for ListView.** `model: array` with `modelData` in delegates, not `model: array.length` with `array[index]`. Integer models only re-render when the count changes, not when the data changes.

---

## Deployment

```bash
./deploy.sh              # Copy source → MuseScore plugin dir
./deploy.sh --watch      # Auto-deploy on file changes (requires fswatch)
```

Then **quit and relaunch MuseScore** (it caches QML).

**Never** put backup copies in `~/Documents/MuseScore4/Plugins/` — MuseScore scans all subdirectories and may load the wrong copy.

---

## What Works (v2.0)

### Voicing Calculator
- Runtime generation from tuning geometry for any tuning
- Configurable constraints: max fret, max stretch, open strings, root-in-bass, min notes, max muted
- "Max per quality" setting: 0 = unlimited (Ted Greene mode), any positive number = capped
- All 12 roots generated (open string correctness)
- Inversions (non-root bass) for all qualities
- Quartal voicings via harmonic pitch class sets
- Constraints persisted in settings.json

### Walkthrough (Voice Score)
- Guided per-chord voicing with ⌘V paste workflow
- Melody field with lock toggle (🔒 = must match, 🔓 = prefer)
- Bass note field with lock toggle
- Re-voice button with category override (dynamic from data)
- Voice leading path visualization (top/bass note contour with arrows)
- Reharm suggestion chips (tritone sub, ii-V, backdoor, dim passing, sus4, min6, Lydian)
- Impossibility warnings inline ("No playable F7 with A in bass. Offering alternative: F in bass.")
- Tuning indicator with scientific pitch notation (e.g., "A3-E3-C3-G2-D2-A1")

### Tuning System
- Custom tuning CRUD (create, edit, delete) in Settings tab
- Tuning persistence in settings.json (customTunings array + tuningOrder)
- Tuning reorder (▲/▼ buttons) with persistent order
- Display names in tuning combo (not slugs)
- Context-filtered tuning list (CM6 only shows 6-string tunings)
- Tuning-specific voicing calculation on tuning change

### Second-Staff Melody Reading
- `melodyStaffIdx` property (-1 = same staff, 0+ = specific staff)
- Selector in Library tab next to Melody toggle

### Scoring System
- Melody on top: +200 (unlocked) / +500 (locked)
- Bass note match: +250 (unlocked) / +500 (locked)
- Context match: +100
- Category match: +50
- Quality match: +20
- Shell preference: +10, Drop 2: +5
- Voice leading proximity: -2 × distance

---

## Known Issues

1. **Mini fretboard preview doesn't transpose.** The canvas draws raw dot positions from the voicing data, not the transposed fret positions. The pasted diagram is correct; only the preview is wrong.

2. **94k voicings in Ted Greene mode.** Uncapped generation for Baritone B produces ~94k voicings. The UI handles it but it's slow to generate. The `maxPerQuality` setting can cap this.

3. **Category classification is heuristic.** Shell = 3 notes, drop2 = 4 notes with stretch ≤ 3, drop3 = 4 notes with stretch > 3, extended = 5+ notes, altered = quality name contains sharp/b9/b13/b5. Not true shape analysis.

4. **2 pre-existing test failures.** Schema validation: voicings.json has extra properties (`also_contexts`, `also_qualities`, `shape_id`) not in the schema. Not caused by v2.0 changes.

5. **Quartal voicings capped at 10 per size** in Pass 3 of `generateAll`. Should respect `maxPerQuality` setting.

6. **`console.log()` invisible from QML plugins.** MuseScore 4 QML plugin `console.log()` does NOT appear in Terminal stdout or MuseScore log files. For debugging, write directly to UI elements (`statusMsg.text`, `Label.text`). Remove diagnostic output before committing.

7. **Van Eps has no cached voicings file.** `tunings/7string-van-eps.json` exists as a tuning definition but no pre-calculated voicing cache. Voicings are generated at runtime on first use (may be slow).

---

## Open Tickets

See CLAUDE.md for the canonical list. Key items as of 2026-04-17:

- **#154** — QML scoping in signal handlers (FIXED: commits `0a6547a`, `ccb8bee`)
- **#149B** — iReal Pro score creation (deferred — Part A file picker is done)
- **#159** — Band-in-a-Box import (new — needs format research, .SGU is proprietary binary; may need text/MusicXML export path)
- **#74** — cmd("paste") broken (wishlist — needs MuseScore C++ change)

---

## Unbuilt Features

### Integration
- **#149B iReal Pro score creation** — Create MuseScore score from parsed iReal Pro data
- **#159 Band-in-a-Box import** — Parse BiaB chord charts into walkthrough. BiaB uses proprietary binary .SGU/.MGU formats; most viable path is parsing BiaB's text export or MusicXML export. MuseScore already imports GuitarPro natively.
- **iGigBook import** — Open MusicXML from iGigBook
- **Soundslice export** — Export to Soundslice tab format

### UX Polish
- **Voicing comparison** — Side-by-side view of 2-3 voicings
- **Audio preview** — Play voicing through `ms-audio`
- **Save arrangement preset** — Serialize walkthrough selections
- **Auto-advance** — Blocked on upstream MuseScore PR #32848

### Bugs/Polish
- Fix mini fretboard preview to show transposed positions
- Quartal voicings should respect `maxPerQuality` setting
- Better category classification (actual shape analysis vs heuristic)

---

## Dheeraj's Preferences

- **Audience is musicians, not programmers.** Error messages, labels, tooltips — all musical terminology.
- **Martin Taylor chord melody approach.** Highest note = melody. Core use case.
- **Per-chord control.** User makes voicing decisions at each position, not just bulk auto.
- **Quartal voicings are universal.** Work over any chord, not siloed behind quality matching.
- **Harmonic geometry, not fret shifting.** Voicings must be mathematically correct for the tuning.
- **Impossibility messages are critical.** When a request can't be fulfilled, explain what, why, and what's offered instead.
- **Ted Greene mode.** Default is every playable voicing. Limiting is optional.
- **Naming:** `{Root}{Quality} — {Shape} — {Category} ({top note} on top)`. Quartals drop the root prefix.
- **Uses A Standard tuning** (A1-D2-G2-C3-E3-A3, MIDI 33-38-43-48-52-57) on baritone guitar.

---

## Test Suite

```bash
cd /path/to/repo
source .venv/bin/activate
python -m pytest tests/ -q    # 107 JS tests via Node.js VM sandbox, 2 pre-existing schema failures
```

Tests cover: ChordScales, FilterEngine, Transposer, DataCache, IRealParser, HygieneEngine, MelodyEngine, ReharmonizationEngine, VoicingCalculator, FingeringEngine. CI runs on every push to main/develop (`.github/workflows/test.yml`).

---

## Recent Git Log (develop branch, as of 2026-04-17)

```
ccb8bee bugfix: Fix homePath TypeError on InlineTools + update CLAUDE.md (#154, #159)
0a6547a bugfix: Fix QML scoping in LibraryPanel signal handlers (#154)
9c75735 cleanup: Remove debug logging from editTuning (#154)
b7a0522 bugfix: Import and create tuning bypass TuningManager for...in bug (#154)
a1b916d feature: Add confirmation dialogs to all CRUD operations
5d3ea8b feature: Add Browse buttons to all file import locations
5abc25c bugfix: Delete tuning + move tuning bypass TuningManager for...in bug (#154)
```
