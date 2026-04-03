# Transition Memo — ChordLibrary v2.0

**Date:** 2026-04-02
**Author:** Dheeraj Chand (with Craft Agent)
**Repo:** `/Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin`
**Installed:** `~/Documents/MuseScore4/Plugins/chordlibrary/`

---

## What This Is

A MuseScore 4 QML plugin for jazz guitar chord voicing — a library browser, guided walkthrough for voicing entire scores, and now a runtime voicing calculator that generates geometrically correct voicings for any guitar tuning.

---

## Architecture (Post-Decomposition)

| File | Lines | Purpose |
|------|-------|---------|
| `plugin/ChordLibrary.qml` | ~4,900 | Main plugin: UI, state, scoring, batch walkthrough |
| `plugin/model/MelodyEngine.js` | ~310 | Melody/bass scoring, voice leading, note parsing |
| `plugin/model/VoicingCalculator.js` | ~440 | Runtime voicing generation from tuning geometry |
| `plugin/model/ReharmonizationEngine.js` | ~124 | Reharm suggestions (tritone subs, ii-V, etc.) |
| `plugin/model/Transposer.js` | ~126 | Semitone transposition, note spelling, name transposition |
| `plugin/ui/WalkthroughPanel.qml` | ~450 | Walkthrough overlay: preview, controls, voice leading |
| `deploy.sh` | ~47 | Copies source files to MuseScore plugin dir |

### Key Design Decisions

1. **No symlinks.** MuseScore's `FileIO` sandbox resolves symlinks and refuses to write outside the plugin directory. Use `deploy.sh` to copy files.

2. **Harmonic geometry, not fret shifting.** Voicings for non-standard tunings are calculated from pitch class sets placed on the actual fretboard — not standard-tuning shapes with fret offsets. This is mathematically correct for any tuning including those with non-standard inter-string intervals (DADGAD, all-fourths, etc.).

3. **12-root generation.** Open strings can't be transposed. The calculator generates voicings for all 12 roots so open strings always produce correct chord tones. `findBestVoicing` matches by root — no transposition needed for calculated voicings.

4. **Standard library for standard tuning.** The 820 hand-curated voicings are still used for standard 6-string tuning. The runtime calculator only activates for non-standard tunings.

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

---

## Unbuilt Features

### Phase 1 Remaining
- **1.5 Second voice export** — Write voicings as actual notes on a second staff/voice (not just diagrams). Uses MuseScore's `newElement(Element.NOTE)` API.

### Phase 2 — Voicing Library
- **2.3 Slash chord parsing** — Parse "C/E" chord symbols and auto-set bass to E
- **2.5 Chord-scale tags** — Tag voicings with compatible scales

### Phase 3 — Integration
- **3.1 iReal Pro import** — Parse iReal Pro URLs into chord charts
- **3.2 iGigBook import** — Open MusicXML from iGigBook
- **3.3 Soundslice export** — Export to Soundslice tab format

### Phase 4 — UX Polish
- **4.2 Voicing comparison** — Side-by-side view of 2-3 voicings
- **4.3 Audio preview** — Play voicing through `ms-audio`
- **4.4 Save arrangement preset** — Serialize walkthrough selections
- **4.5 Auto-advance** — Blocked on upstream MuseScore PR #32848

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
python -m pytest tests/ -q    # 67 pass, 2 pre-existing failures
```

---

## Git Log (Today's Commits)

```
be2fb1e feat: configurable max voicings per quality (0 = Ted Greene mode)
b946351 feat: uncap voicing generation — digital Ted Greene mode
5c5c932 fix: cap calculated voicings to ~36 per quality (was 45k uncapped)
1f100f4 fix: open strings producing wrong notes after transposition
6460ba1 feat: melody/bass priority lock toggles
c3cc575 fix: tuning combo shows display names instead of slugs
af16a94 feat: tuning UX improvements — pitches display, reorder, explicit names
f630521 fix: clearer impossibility messages — explain what's offered and why
adbadb1 fix: notify user when bass/melody request can't be fulfilled
448d636 fix: bass note scoring too weak, increase inversion cap
d782c05 fix: impossibility warnings shown inline, not in hidden status bar
def91e5 fix: melody/bass scoring used wrong interval index, add tuning indicator
9784be6 feat: Phase 1 chord melody features — voice leading, reharm, bass, melody staff
0d75204 fix: voicing calculator — harmonic geometry, capped inversions, dynamic types
028da55 wip: runtime voicing calculator, bass note UI, tuning-specific generation
4fe7857 refactor: decompose ChordLibrary.qml, add tuning-aware voicing pipeline
```
