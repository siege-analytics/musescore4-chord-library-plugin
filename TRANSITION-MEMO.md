# Transition Memo — Siege Analytics Chord Library v1.5.0

**Date:** 2026-04-02
**Author:** Craft Agent (Claude Opus 4.6)
**Owner:** Dheeraj Chand, Siege Analytics
**Repo:** `/Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin`
**Branch:** `main` (merged from `ui-reorganization`, 24 commits)
**Plugin deploy:** `~/Documents/MuseScore4/Plugins/chordlibrary/chordlibrary.qml` (manual copy, not symlinked)

---

## What This Is

A MuseScore 4 QML plugin for jazz guitarists. It provides a library of 820 chord voicings (stored in root C, transposed at runtime), a guided "Voice Score" walkthrough for placing fretboard diagrams on lead sheets, and a chord melody arranger with per-chord melody note and category overrides.

The audience is **musicians, not programmers**. UI decisions should be evaluated from a player's perspective.

---

## Architecture

### Plugin Structure
```
plugin/
  ChordLibrary.qml    — Main file (~4,300 lines). All UI, logic, and state.
  ui/
    VoicingCard.qml    — Individual voicing card with canvas fretboard thumbnail
    VoicingGrid.qml    — ListView wrapper for voicing cards
    SearchBar.qml      — Search input with clear button
    FilterBar.qml      — Context/category/quality dropdowns
    PanelView.qml      — Legacy/unused (kept for compatibility)
  model/
    LibraryModel.qml   — Data model
    VoicingInserter.qml — Insertion via setDot() or clipboard
    Transposer.js       — Semitone calculation utilities
data/
  voicings.json        — 820 voicings, all root C, normalized naming
config/
  tunings/             — Per-tuning JSON files (standard, 7-string, ukulele, etc.)
  contexts.json        — Context labels (CM6, CM7, CV6, CV7)
scripts/
  validate.py          — Schema validation
  library_hygiene.py   — Duplicate/redundancy detection
  export_gp5.py        — Guitar Pro 5 export
  export_tablature.py  — ASCII tab export
  import_gtdb.py       — GTDB tuning import
  generate_chord_sheet.py
  generate_fingering_sheet.py
tests/
  test_core.py         — Unit tests (62 pass)
  test_integration.py  — Integration tests (7 fail from missing deps)
.github/workflows/
  validate-voicings.yml — CI: schema validation + hygiene + tests on PR
```

### Key Design Decisions
- **All voicings in root C** — transposed at runtime via Transposer.js. Keeps data small and consistent.
- **Clipboard pipeline** — Plugin writes XML → launchd agent → Swift tool (`ms-clipboard`) → macOS pasteboard → user presses ⌘V. `cmd("paste")` does not work in MuseScore 4's plugin API.
- **ThemePalette** — Centralized dark/light mode via `QtObject { id: theme }` with `isDark` detection from `palette.windowText` brightness (not `palette.window` — unreliable in MuseScore's sandbox).
- **Quartal voicings are universal** — They have `chord_quality: "quartal"` in the data but are included as candidates for ALL chord qualities in `findBestVoicing`, `applyFilters`, and `analyzeCurrentScore`.

### Navigation Model
```
currentTab: 0=Library, 1=ScoreTools, 2=Export, 3=Import, 4=Practice, 5=Settings
showToolResults: bool (overlay for Voice Score walkthrough)
```
TabBar with 6 tabs. Voice Score walkthrough is an overlay panel on top of any tab.

---

## What Was Done in v1.5.0

### UI Reorganization
1. **Dark mode palette** — ThemePalette QtObject, ~100 hardcoded colors replaced across 4 QML files
2. **Tab-based layout** — 6-tab TabBar replacing the old "Settings" mega-scroll
3. **Renamed "Add Fingering Text"** → "Annotate Staff Text" with tooltip and subsection
4. **Voice Score UX polish** — Progress bar, mini fretboard preview, ⌘V hint chip

### Data & Infrastructure
5. **Data model normalization** — Deduplicated voicings, added shape cross-references
6. **chords-db merge** — Expanded voicing library
7. **GTDB tuning import** — `scripts/import_gtdb.py` (fetches/scrapes GTDB, converts to project format)
8. **ASCII tablature export** — `scripts/export_tablature.py` (diagram + compact modes, filtering, transposition)
9. **GitHub Actions CI** — `validate-voicings.yml` (schema validation + hygiene + tests on PR)
10. **Practice tab** — Flash card mode for voicing recognition

### Testing Fixes
11. **Dark mode detection** — Switched to windowText brightness (palette.window unreliable in MS4 sandbox)
12. **Voicing name normalization** — 372 names standardized to `C7 — E shape — Shell (3rd on top)` template
13. **Quartal voicing inclusion** — Now in library browser, Score Analysis, and voicing selection for all chord qualities
14. **Annotations read existing diagrams** — `fingeringFromDiagram()` reads FretDiagram elements; "Skip diagrams" checkbox optional

### Chord Melody Features (Martin Taylor Approach)
15. **Melody-on-top toggle** — Global toggle for auto-detection during Voice All scan
16. **Melody carry-forward** — Last melody note carries through rests (sustained top voice)
17. **Per-chord melody override** — Editable text field in walkthrough, always visible, works without global toggle
18. **Per-chord category selector** — Dropdown (Shell, Drop 2, Drop 3, Extended, Altered, Quartal, Any)
19. **Re-voice button** — Applies melody + category changes per chord, re-selects voicing, regenerates clipboard
20. **voicingTopNoteSemitone()** — Computes pitch class of a voicing's highest voice for melody matching (200-point scoring bonus)

---

## Known Issues & Limitations

### MuseScore 4 API Limitations
- `cmd("paste")` is a no-op — clipboard pipeline + manual ⌘V required
- `FileIO` is restricted — can only write to plugin directory
- No `Dialog` or `Popup` QML types — all UI in the main panel
- `SystemPalette.window` doesn't report background color reliably — use `windowText` brightness
- `setDot()` API for auto-paste pending upstream PR #32848

### Untested at Runtime
- **`fingeringFromDiagram()`** — Uses `diagram.dot(s)` and `diagram.marker(s)`. Written from docs, not yet verified with actual FretDiagram elements. Falls back silently to auto-generated voicings if it fails.
- **Melody extraction via `segment.elementAt(voice)`** — Scans voices 0-3 for notes. May miss notes in complex multi-voice arrangements.
- **Dark mode toggle** — Detection works at plugin load; needs verification that it updates when macOS appearance changes mid-session (may require plugin close/reopen).

### Pre-existing Test Failures
7 tests fail from missing optional dependencies:
```
pip3 install --break-system-packages guitarpro jsonschema
```

---

## Deployment

NOT symlinked. After code changes:
```bash
cp plugin/ChordLibrary.qml ~/Documents/MuseScore4/Plugins/chordlibrary/chordlibrary.qml
cp plugin/ui/*.qml ~/Documents/MuseScore4/Plugins/chordlibrary/ui/
cp data/voicings.json ~/Documents/MuseScore4/Plugins/chordlibrary/voicings-cache.json
```
Then **quit and reopen MuseScore 4** (it caches QML).

---

## Dheeraj's Preferences

- **Audience is musicians, not programmers.** Testing instructions, UI labels, error messages — all musical terminology.
- **Martin Taylor chord melody approach** — Highest note of voicing = melody note. Core use case.
- **Per-chord reharm** — User wants to make voicing decisions at each chord position, not just accept auto-selections.
- **Quartal voicings are not quality-specific** — They work over any chord. Don't silo behind `chord_quality` matching.
- **Naming consistency** — Template: `{Root}{Quality} — {Shape} — {Category} ({top note} on top)`
- **Annotations should match existing diagrams** — If the user placed a diagram, the text annotation should describe that diagram, not a different voicing.

---

## Immediate Next Steps (Testing & Polish)

1. **Symlink deploy** — Replace manual copy with symlink from `~/Documents/MuseScore4/Plugins/chordlibrary/` to the repo's `plugin/` directory.
2. **Test fingeringFromDiagram** — Place a diagram manually, run Annotate Staff Text, verify text matches.
3. **Test dark mode toggle** — Verify appearance changes after macOS theme switch.
4. **Voice leading + melody interaction** — Verify 200-point melody bonus dominates proximity scoring in real arrangements.

---

## Feature Ideas

### Voicing Library Expansion
- **More altered dominants** — 7alt, 7#9, 7b9#11, tritone subs. Jazz standards need these constantly.
- **Diminished passing chords** — Ascending/descending dim7 voicings for chromatic movement (e.g. Cdim7 → C#dim7 passing between I and ii).
- **Slash chords / bass note voicings** — Support for C/E, Dm/F, etc. where the bass note is specified.
- **Cluster voicings** — Close-voiced chords for modern jazz (Kurt Rosenwinkel, Ben Monder style).
- **Chord-scale association** — Tag voicings with compatible scales (e.g. dom7 → mixolydian, lydian dominant, altered).

### Chord Melody Workflow
- **Second-staff melody reading** — Read melody from a separate staff (common in chord melody arrangements where melody and chords are on different staves). This would make melody-on-top work automatically without manual overrides.
- **Reharm suggestions** — At each chord position, suggest alternative chord qualities (e.g. at G-7 → C7, suggest tritone sub Gb7 → C7, or backdoor ii-V Abm7 → Db7 → C).
- **Voice leading path visualization** — Show the top-note path as a line across the score, so you can see if the melody voice is smooth or has jumps.
- **Export chord melody arrangement** — Generate a new staff with the voicings written as actual notes (not just diagrams), playable in MuseScore's mixer.

### Integration Ideas
- **iGigBook import** — iGigBook has a huge library of lead sheets with chord symbols. Importing from iGigBook (probably via MusicXML or their API) would give instant access to thousands of standards for chord melody arrangement. **This could be a separate plugin or a script that converts iGigBook exports into MuseScore format with chord symbols intact.** iGigBook supports MusicXML export on iPad/Mac.
- **iReal Pro import** — iReal Pro chord charts are widely shared in the jazz community. Import iReal Pro format (HTML-based chord charts) and create MuseScore lead sheets with chord symbols.
- **Soundslice integration** — Export voicings as Soundslice-compatible tab for interactive online playback.

### UX Improvements
- **Auto-advance after paste** — Listen for score modification events to auto-advance the walkthrough (blocked on setDot() PR #32848, but worth checking if MS4 has other events).
- **Undo per voicing** — Let the user undo the last pasted diagram without undoing the whole Voice Score session.
- **Voicing comparison** — Side-by-side view of 2-3 voicings for the same chord, so you can hear/see the differences before choosing.
- **Audio preview** — Play the voicing as a strummed chord or arpeggio before pasting (the `ms-audio` binary exists but isn't wired into the walkthrough yet).
- **Fretboard range constraint** — Let the user set a max fret (e.g. "only voicings below fret 7") for playability in a specific position.
- **Save arrangement as preset** — After walking through a full score with reharm choices, save the per-chord voicing selections as a named preset that can be re-applied.
