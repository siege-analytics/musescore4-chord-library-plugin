# Siege Analytics Chord Library

A MuseScore Studio 4 plugin that gives jazz guitarists a searchable, mode-aware chord-voicing library with physically-validated fingerings. 820+ curated voicings for standard tuning, runtime voicing calculator for any tuning, and a scoring engine that adapts to what you're playing.

> **Current release: v2.2.0** — see [CHANGELOG-style notes](#whats-new-in-v22) at the bottom.

---

## What this plugin gives you

Three orthogonal axes of configuration shape every voicing the plugin recommends:

| Axis | What it says | Where you set it |
|---|---|---|
| **Tuning** | What instrument you're holding | Settings → Tuning |
| **Mode** | What the guitar is doing in the arrangement | Library tab → Mode dropdown |
| **Style** | Genre vocabulary | Library tab → Style dropdown |

Each is independently selectable, and they stack: "Baritone A + Solo Guitar + Bossa Nova" is a real combination that scores differently from "Van Eps 7 + Comping + Bebop."

### Modes

- **Chord Melody** — melody on top, top-note match scored heavily, mid-upper register preferred
- **Comping** — accompaniment behind a melody instrument, mid-range shells / drop 2s preferred, no melody constraint
- **Solo Guitar** — bass + chord + melody on one instrument, wider range, drop 3 / extended preferred
- **Duo** — comping behind a voice or another instrument, narrow mid-upper range, clear top line

### Styles

- **Default** — no overrides, base scoring
- **Bebop** — drop 2s, altered dominants, ii-V-I substitutions
- **Manouche** — Django-style triads/shells, harmonic minor over minor chords, dim passing
- **Bossa Nova** — Lydian over major, smooth voice leading, 9th chords
- **Compositions** — blend two or more styles with custom weights and rule selectors (see below)

### Sections

For arrangements where different parts call for different modes (intro as Solo Guitar, head as Chord Melody, solos as Comping, out-chorus back to Chord Melody), the walkthrough has a **Sections editor**. Click "▸ Sections" → "Split here" at any chord to define a section boundary; pick the mode for that section from a dropdown.

---

## Install

### Easy path

1. Download or clone this repository (or grab the latest tagged release)
2. Copy the **`plugin/`** folder to your MuseScore plugins directory
3. Rename the copy to **`chordlibrary`**
4. Restart MuseScore Studio
5. Enable **Siege Analytics Chord Library** under **Plugins → Manage Plugins**

The `plugin/` directory is self-contained. No scripts required for end users.

### Plugin paths

| OS | Path |
|---|---|
| macOS | `~/Documents/MuseScore4/Plugins/chordlibrary/` |
| Windows | `%USERPROFILE%\Documents\MuseScore4\Plugins\chordlibrary\` |
| Linux | `~/Documents/MuseScore4/Plugins/chordlibrary/` |

> **Heads up:** if you've installed before and Finder/Explorer renamed during a copy, look for stray `chordlibrary 2/` or `ChordLibrary 2.qml` files in the plugins directory and delete them. MuseScore loads every QML file it sees, so duplicates cause unpredictable behaviour.

---

## Day-to-day use

### Single voicing — the **Library** tab

1. Pick a tuning (default: Standard 6-String). Pick a Mode and Style.
2. Filter or search for the chord quality you want.
3. Click **Open** on a voicing card.
4. The diagram inserts at your cursor position, transposed to the chord symbol's key.

If no chord symbol is present at the cursor, the voicing inserts in C.

### Whole progression — the **Walkthrough**

Click **Voice All** on the Library tab. The plugin steps through every chord symbol in your score, picking the best voicing for each chord based on:

- The active Mode + Style + Tuning
- Melody on top (if you toggle Melody Lock)
- Bass note (root by default; type to override)
- Voice-leading proximity to the previous voicing
- Section overrides (if you've defined any)

For each chord you can:
- **⌘V** to paste the diagram
- **Re-voice** to pull an alternative
- **Lock** the melody or bass note across all subsequent chords
- **Click a scale chip** to see its notes/intervals against the current chord
- **Click a reharm chip** (tritone sub, ii-V, backdoor, dim passing, sus4, min6, Lydian) to substitute on the fly
- **Override the mode for this section** via the Sections editor

### **Score Tools** tab

Voicing calculator constraints. The settings here govern what voicings the calculator generates for the active tuning:

- **Max fret** (default 12) — don't generate above this fret
- **Max stretch** (default 4) — biggest finger span in frets
- **Min notes** (default 3) — fewest sounding notes
- **Max muted** (default 3) — most muted strings
- **Allow open** / **Root in bass** — toggles
- **Max per quality** — how many voicings to keep per chord quality. **0 means unlimited (Ted Greene mode)**; positive numbers cap. The label says it.

> **Performance note:** flipping `Max per quality` to 0 on a non-standard tuning will compute every playable voicing — that can be 90,000+ for baritone. Set it to 240 or so if you want generous coverage without a stall.

### **Settings** tab

Sub-tabs for everything that persists:

- **General** — diagram placement, **Backup / Restore**, **Import from URL**
- **Tuning** — built-in and custom tunings, edit-in-place, factory reset for built-ins, custom CRUD with persistent ordering
- **Scales** — scale library (built-in + custom), interval definitions, chord-scale mappings
- **Profiles** — style profiles + **+ New Composition…** for blending
- **Contexts** — historical, mostly empty now (mode replaced this in v2.1)

### Backup, restore, and sharing

**Settings → General → Backup/Restore:**

- **Export Backup…** — writes a single timestamped JSON file to your desktop containing your custom tunings, custom styles, custom scales, settings, and saved compositions. Built-in data isn't included (keeps the file small and avoids version drift).
- **Restore from File…** — pick an exported backup; merges it into your current state by id. Conflicts overwrite.
- **Import from URL** — paste any raw `.json` URL. The plugin sniffs the file shape:
  - A tuning JSON (has `strings` + `notes` + `name`) → imports as a tuning preset
  - A backup-archive JSON → restores the whole pack

The `siege-analytics/chordlibrary-community-packs` repository is the canonical source for shareable presets:

```
https://raw.githubusercontent.com/siege-analytics/community-packs/main/tunings/<name>.json
```

Drop a raw URL into the import field and the tuning appears in your picker.

---

## Tunings

Six built-in tunings ship with the plugin:

| Tuning | Strings | Open pitches |
|---|---|---|
| **Standard 6-String** | 6 | E4-B3-G3-D3-A2-E2 |
| **Van Eps 7-String (Low A)** | 7 | E4-B3-G3-D3-A2-E2-A1 |
| **Low B 7-String** | 7 | E4-B3-G3-D3-A2-E2-B1 |
| **DADGAD 6-String** | 6 | D4-A3-G3-D3-A2-D2 |
| **All Fourths 6-String** | 6 | F4-C4-G3-D3-A2-E2 |
| **Baritone Guitar 6-String (B Standard)** | 6 | B3-F#3-D3-A2-E2-B1 |

### Custom tunings

- Create one in **Settings → Tuning** by entering pitches as note names (`E4, B3, G3, D3, A2, E2`) or MIDI values
- Edit / rename / reorder / delete custom tunings freely
- **Built-in tunings:** edit-in-place is allowed (rename `Standard 6-String` → `My Tuning` works without creating a duplicate); delete is not (use the **Reset** button to restore factory defaults)
- Tunings persist across MuseScore restarts in `settings.json`

### Voicing calculation

For non-standard tunings the plugin generates voicings by **harmonic geometry** — placing each chord's pitch-class set against the actual fretboard — so DADGAD, all-thirds, all-fourths, baritone, and arbitrary user-defined tunings produce musically correct voicings rather than "standard shapes shifted by frets."

The 820 hand-curated voicings still apply when you're on Standard 6-String. The calculator runs for everything else, caching results to disk so subsequent loads are instant.

---

## Voicing types

| Type | Description |
|---|---|
| **Shell** | Root + 3rd + 7th. Freddie Green / guide-tone chords. |
| **Drop 2** | 4-note close voicing with the 2nd voice dropped an octave. Jazz guitar workhorse. |
| **Drop 3** | 4-note close voicing with the 3rd voice dropped. Wider spread. |
| **Extended** | 9ths, 11ths, 13ths — colour chords. |
| **Altered** | Dominants with b9, #9, b5, #5 tensions. |
| **Quartal** | Stacked 4ths. McCoy Tyner / Bill Evans / Lenny Breau territory. |

### Fretboard diagram colours

Dots are colour-coded by chord interval:

| Colour | Interval |
|---|---|
| Red | Root (1) |
| Blue | 3rd (3, b3) |
| Green | 5th (5, b5, #5) |
| Orange | 7th (7, b7) |
| Purple | 9th (9, b9, #9) |
| Teal | 4th / 11th |
| Gold | 6th / 13th |

---

## What's new in v2.2

- **Three-axis configuration** — Tuning + Mode + Style replace v2.0's `context` field. Mode (`chord-melody` / `comping` / `solo-guitar` / `duo`) drives playing-role scoring; Style drives genre vocabulary.
- **Style composition** — blend multiple styles with weight sliders and user-selectable blend rules (numeric: weighted-sum / max / average; scale: union-priority / intersect / first-only; resolution: re-resolve / freeze).
- **Section-based mode** — different modes for different parts of the same score, defined in the walkthrough's Sections editor.
- **Backup / restore** — export everything to a single JSON file; import via file picker or URL.
- **Community packs** — `siege-analytics/chordlibrary-community-packs` is the canonical source for shareable tuning / style / scale / voicing files. Plugin pulls them via raw URLs.
- **Windows support** — `homePath()` handles Windows correctly; `deploy.ps1` mirrors `deploy.sh`. CI matrix covers ubuntu/macos/windows.
- **Built-in tuning naming** — every built-in tuning advertises its string count in the display name now that tuning is the carrier of that information.
- **Editable SpinBoxes** — every numeric field (Max fret / Stretch / Per-quality / etc.) accepts typed input; you don't have to click arrow buttons 240 times.
- **Tuning reorder regression fix** — multiple ▲/▼ clicks work after any CRUD action.
- **Mini fretboard preview transpose fix** — what you see is what gets pasted, including barred opens when off the nut.

For the full ticket-by-ticket history, see [closed issues](https://github.com/siege-analytics/musescore4-chord-library-plugin/issues?q=is%3Aclosed) on GitHub.

---

## Developer setup

### Prerequisites

- **Python 3.10+** with `pip install jsonschema pytest`
- **Node.js 20+** (used by the JS-module test harness)
- **MuseScore Studio 4**
- macOS, Windows, or Linux

### Quick start

```bash
git clone https://github.com/siege-analytics/musescore4-chord-library-plugin.git
cd musescore4-chord-library-plugin

python -m venv .venv && source .venv/bin/activate
pip install jsonschema pytest

# Run all unit tests (198 cases — Python + JS via Node.js)
python -m pytest tests/test_js_modules.py tests/test_core.py -v

# Validate voicing data against the schema
python scripts/validate.py -v

# Deploy to MuseScore (developer convenience — copies plugin/ into the plugins dir)
bash deploy.sh                 # macOS / Linux
pwsh -File .\deploy.ps1        # Windows PowerShell 5+
```

After deploying, **quit MuseScore fully and relaunch** — QML is cached at load time on every platform.

`deploy.sh` and `deploy.ps1` also support a `--watch` / `-Watch` mode that re-deploys on file changes.

### Project structure

```
plugin/                            # Self-contained plugin (this is what end users install)
  ChordLibrary.qml                 # Main plugin: state, routing, signal wiring (~3.6k lines)
  config/
    contexts.json                  # Legacy context labels (mostly unused now)
    modes.json                     # Mode definitions (chord-melody / comping / solo-guitar / duo)
    styles.json                    # Style + composition definitions
    scales.json                    # Scale library
  data/
    voicings.json                  # 820 curated voicings (Standard tuning, key of C)
    progressions/                  # Built-in chord progressions
  tunings/                         # 6 built-in tuning definitions + any user-created ones
  model/                           # Pure JS modules (no UI)
    ChordSelector.js               # Chord parsing + voicing selection
    FilterEngine.js                # Voicing filtering and search
    FingeringEngine.js             # Fingering assignment + difficulty scoring
    VoicingCalculator.js           # Runtime voicing generation
    DiagramEngine.js               # Fretboard diagram XML generation
    DataCache.js                   # Settings/cache serialization
    IRealParser.js                 # iReal Pro URL/text parser
    HygieneEngine.js               # Library audit (duplicates, enharmonics)
    Transposer.js                  # Key transposition
    MelodyEngine.js                # Melody/bass note analysis
    ChordScales.js                 # Scale-chord mapping
    ReharmonizationEngine.js       # Reharmonization suggestions
    StyleComposer.js               # Style composition resolver (#162)
    BackupManager.js               # Backup/restore archive serialization (#172)
  ui/                              # QML visual components
    LibraryPanel.qml               # Library tab
    SettingsPanel.qml              # Settings tab + sub-tabs
    WalkthroughPanel.qml           # Walkthrough panel + sections editor
    ScoreToolsPanel.qml            # Voicing-calculator controls
    ImportPanel.qml                # Import tab
schema/voicings.schema.json        # JSON schema for voicing data
scripts/                           # Python tools (validation, migration, import, export)
  validate.py                      # Schema + note-position validation
  migrate_context_to_modes.py      # v2.0 → v2.1 data migration (idempotent)
  retire_context_field.py          # v2.1 → v2.2 cleanup (idempotent)
  import_chords_db.py              # Pull voicings from tombatossals/chords-db
  ...
tests/
  test_core.py                     # Voicing data invariants
  test_js_modules.py               # JS module unit tests via Node.js sandbox
  test_integration.py              # macOS-specific environmental tests (skipped on CI)
.github/workflows/test.yml         # CI matrix: ubuntu / macos / windows
deploy.sh                          # bash deploy
deploy.ps1                         # PowerShell deploy
```

### Architecture

**Django-style separation:**
- `model/*.js` = business logic (pure, no UI)
- `ui/*.qml` = visual components
- `ChordLibrary.qml` = state + routing (the "view" + "URLs" layer)

**Properties-in / signals-out:** UI panels never mutate parent state directly — they emit signals, ChordLibrary handles the mutation. Panels also never import JS modules — parent passes function callbacks as properties (e.g. `difficultyFn`, `modeIdResolverFn`).

**`.pragma library` rules:** modules that don't receive QML callbacks are `.pragma library` (singleton evaluation, faster startup). Modules that receive function callbacks (ChordSelector, FilterEngine, DiagramEngine) stay non-pragma.

See [REFERENCES.md](REFERENCES.md) for academic credits and source bibliography.

---

## Fingering Engine

The plugin includes a physically-aware fingering engine that validates every voicing:

- **CombinoChord hand model** — inter-finger distance constraints in millimeters, fret widths via Mersenne's Law
- **Barre type detection** — full, hinge (partial), tip (Ted Greene), diagonal (Van Eps, fret 10+)
- **Difficulty scoring** — 0–100 score across 5 factors: stretch, finger count, barre complexity, fret position, thumb usage
- **71% exact match** against 3,282 expert-fingered reference voicings (tombatossals/chords-db)

See [docs/fingering-research-report.md](docs/fingering-research-report.md) for the research detail.

---

## References

- Greene, Ted. *Chord Chemistry*. Alfred Music, 1971.
- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be
- Smith, Nicholas T. "CombinoChord." *IEEE*, 2021.
- See [REFERENCES.md](REFERENCES.md) for the complete bibliography.

## Related projects

- [siege-analytics/chordlibrary-community-packs](https://github.com/siege-analytics/chordlibrary-community-packs) — community-contributed tunings, styles, scales, and voicings
- [siege-analytics/jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — `.mpal` palette files (predecessor)
- [siege-analytics/jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — chord melody arrangements

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)

Free to use, share, and adapt with attribution to **Dheeraj Chand / Siege Analytics**.
