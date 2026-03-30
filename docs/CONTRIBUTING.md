# Contributing to the Siege Analytics Chord Library

This document covers how to use the voicing library from the plugin and how to add voicings to it.

---

## Using the library

The plugin provides a dialog panel inside MuseScore Studio 4.6+. When it is open:

1. Use the filter bar to narrow by **context** (CM6, CM7, CV6, CV7), **chord quality**, or **voicing type**
2. Use the search box to find voicings by name or tag
3. Select a note or rest in your score
4. Double-click a voicing card to insert a fretboard diagram at that position

The plugin reads the chord symbol on the selected note, calculates the semitone distance from C to the target root, and adjusts the fret number. The dot pattern stays the same — only the starting fret changes. All voicings are stored with root C precisely so this works uniformly.

### Contexts

| Code | Texture | Strings | Meaning |
|------|---------|---------|---------|
| CM6 | Chord Melody | 6 | Melody on guitar — hard constraint on melody note placement |
| CM7 | Chord Melody | 7 | Same, with low A string (Van Eps tuning) for bass notes |
| CV6 | Comping/Vocal | 6 | Melody in voice — guitar freed for harmony/rhythm |
| CV7 | Comping/Vocal | 7 | Same, with low A string |

### Voicing types

| Type | Notes sounded | String sets |
|------|--------------|-------------|
| Shell | Root, 3rd, 7th (no 5th) | 3 strings |
| Drop 2 | 4-note voicing, 2nd voice dropped one octave | 4 strings (5-4-3-2 or 4-3-2-1) |
| Drop 3 | 4-note voicing, 3rd voice dropped one octave | 4 strings (6-4-3-2 or 5-4-3-1) |
| Extended | 9th, 11th, or 13th extensions | 4-6 strings |
| Altered | b9, #9, b5, #5 alterations | 4-6 strings |
| Quartal | Stacked 4ths | 3-6 strings |

Shell chords omit the 5th deliberately. The 5th is harmonically expendable and its absence makes the voicing lighter.

---

## How the fret data works

### String numbering

String 1 = high e, String 6 = low E, String 7 = low A (Van Eps 7-string only).

```
String:  7    6    5    4    3    2    1
Tuning:  A    E    A    D    G    B    e
```

### Fret numbers

`fret_number` is the starting fret of the diagram. `dot.fret` is the row within the diagram: 1 = first visible row (at `fret_number`), 2 = `fret_number + 1`, etc.

Example: C7 Shell with `fret_number: 8` and dot at `{string: 6, fret: 1}` means root C at fret 8 on the low E string. Dot at `{string: 3, fret: 2}` means E at fret 9 on the G string.

### Fret reference table

| Note | A str (7) | E str (6) | A str (5) | D str (4) | G str (3) | B str (2) | e str (1) |
|------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| C    | 3         | 8         | 3         | 10        | 5         | 1         | 8         |
| Db   | 4         | 9         | 4         | 11        | 6         | 2         | 9         |
| D    | 5         | 10        | 5         | 12        | 7         | 3         | 10        |
| Eb   | 6         | 11        | 6         | 1         | 8         | 4         | 11        |
| E    | 7         | 12        | 7         | 2         | 9         | 5         | 12        |
| F    | 8         | 1         | 8         | 3         | 10        | 6         | 1         |
| F#   | 9         | 2         | 9         | 4         | 11        | 7         | 2         |
| G    | 10        | 3         | 10        | 5         | 12        | 8         | 3         |
| Ab   | 11        | 4         | 11        | 6         | 1         | 9         | 4         |
| A    | 12        | 5         | 12        | 7         | 2         | 10        | 5         |
| Bb   | 1         | 6         | 1         | 8         | 3         | 11        | 6         |
| B    | 2         | 7         | 2         | 9         | 4         | 12        | 7         |

String 7 (low A) and string 5 (A) share the same fret numbers — same pitch class, two octaves apart.

---

## Adding a voicing

### Step 1: Find the fingering

Use one of the primary reference sources:
- **Dirk Laukens**, *Jazz Guitar Chord Dictionary* (jazzguitar.be) — primary voicing source
- **Martin Taylor**, *Complete Jazz Guitar Method* (Alfred Music) — chord melody methodology
- **Ted Greene**, *Chord Chemistry* — extended/altered voicings

### Step 2: Verify with Oolimo

Before entering anything, verify at [oolimo.com](https://www.oolimo.com/). Enter the frets, confirm the notes and intervals match the source. If Oolimo disagrees, investigate before proceeding.

### Step 3: Convert to C position

All voicings are stored with root C. Use the fret reference table to find where C falls on the root string. That is your `fret_number`.

Calculate each dot as: `dot.fret = actual_fret - fret_number + 1`

If any dot comes out as 0 or negative, your `fret_number` is wrong.

### Step 4: Write the JSON object

Add your voicing to `data/voicings.json`. Every string must appear in exactly one of `dots`, `mutes`, or `open`.

```json
{
  "id": "c7-shell-e-shape-6",
  "name": "C7 — E shape — Shell",
  "chord_quality": "dom7",
  "root": "C",
  "category": "shell",
  "context": "CV6",
  "strings": 6,
  "fret_number": 8,
  "visible_frets": 4,
  "dots": [
    {"string": 6, "fret": 1},
    {"string": 4, "fret": 1},
    {"string": 3, "fret": 2}
  ],
  "mutes": [5, 2, 1],
  "open": [],
  "notes": ["C", "Bb", "E"],
  "intervals": ["1", "b7", "3"],
  "tags": ["shell", "guide-tone", "e-string-root"]
}
```

### Step 5: Validate

```bash
python scripts/validate.py -v
```

The validator runs three levels of checks:

1. **Schema validation** — required fields, enum values, string/fret ranges
2. **Consistency checks** — every string accounted for in dots/mutes/open, no overlaps, notes/dots count match
3. **Note-computation verification** — computes the actual note at each fret position using tuning-aware MIDI math and compares against declared `notes` and `intervals` arrays

If the validator reports a note mismatch, your fret positions or declared notes are wrong. Fix before proceeding.

To validate with a non-standard tuning:

```bash
python scripts/validate.py -v --tuning config/tunings/7string-low-b.json
```

### Step 6: Cross-reference with Oolimo

Generate verification URLs for visual spot-checking:

```bash
python scripts/oolimo_urls.py
python scripts/oolimo_urls.py --format markdown   # for a checklist
```

This outputs direct links to Oolimo chord pages for every quality in the library. Open the link, find your voicing shape among the displayed diagrams, and confirm it matches.

### Step 7: Submit a pull request

Include the source (book + page number) and confirmation that you checked with Oolimo.

---

## Managing tunings

Tuning configurations live in `config/tunings/` as JSON files. The validator uses these to compute correct notes at fret positions.

### Tuning file format

```json
{
  "name": "Standard + Van Eps 7th (Low A)",
  "description": "Standard 6-string with optional 7th string tuned to low A.",
  "strings": {
    "1": 64,
    "2": 59,
    "3": 55,
    "4": 50,
    "5": 45,
    "6": 40,
    "7": 33
  },
  "notes": {
    "1": "E4",
    "2": "B3",
    "3": "G3",
    "4": "D3",
    "5": "A2",
    "6": "E2",
    "7": "A1"
  },
  "reference": "MIDI note numbers. Middle C (C4) = 60. A440 (A4) = 69."
}
```

The `strings` object maps string number to the MIDI note number of the open string. The `notes` object is for human readability — only `strings` is used by the validator.

### MIDI note reference

| Note | MIDI | Note | MIDI | Note | MIDI |
|------|------|------|------|------|------|
| A1   | 33   | E2   | 40   | B2   | 47   |
| B1   | 35   | F2   | 41   | C3   | 48   |
| C2   | 36   | G2   | 43   | D3   | 50   |
| D2   | 38   | A2   | 45   | G3   | 55   |
| Eb2  | 39   | Bb2  | 46   | B3   | 59   |

### Adding a tuning

1. Create a new JSON file in `config/tunings/` (e.g., `open-g.json`)
2. Set the `strings` object with MIDI note numbers for each open string
3. Add a human-readable `notes` object
4. Test it: `python scripts/validate.py -v --tuning config/tunings/open-g.json`

### Editing a tuning

Edit the `strings` values in the JSON file. To change the 7th string from low A (33) to low B (35), update `"7": 35` and the corresponding note to `"B1"`.

### Shipped tunings

| File | Description |
|------|-------------|
| `standard.json` | Standard 6-string + Van Eps 7th (low A). **Default.** |
| `7string-low-b.json` | Standard 7-string with low B |
| `dadgad.json` | DADGAD alternate tuning |
| `all-fourths.json` | All-fourths tuning (E A D G C F) |

---

## Managing voicings (CRUD)

### Create

Follow the "Adding a voicing" steps above. Key rules:
- Root is always `C`
- Every string must appear in exactly one of `dots`, `mutes`, or `open`
- Run `validate.py` — it will catch note/interval errors automatically

### Read

```bash
# List all voicings with their Oolimo verification status
python scripts/oolimo_urls.py

# Show summary by quality/context/category
python scripts/validate.py -v
```

### Update

Edit the voicing entry in `data/voicings.json` directly. After any change:

```bash
python scripts/validate.py -v
```

The note-computation validator will catch any fret/note mismatches introduced by the edit.

### Delete

Remove the voicing object from `data/voicings.json`. Run `validate.py` to confirm the file is still valid JSON.

---

## Field reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique identifier, kebab-case. See ID format below. |
| `name` | string | yes | Human-readable label shown in the plugin UI. |
| `chord_quality` | string | yes | One of the quality enum values. |
| `root` | string | yes | Always `"C"`. |
| `category` | string | yes | `shell`, `drop2`, `drop3`, `extended`, `altered`, or `quartal`. |
| `context` | string | yes | `CM6`, `CM7`, `CV6`, or `CV7`. |
| `strings` | integer | yes | `6` or `7`. |
| `fret_number` | integer | yes | Starting fret of the diagram. |
| `visible_frets` | integer | yes | Number of fret rows shown. Typically `4`. |
| `dots` | array | yes | Fingered positions: `{"string": N, "fret": M}` where fret is relative. |
| `mutes` | array | yes | Muted string numbers. Empty array if none. |
| `open` | array | yes | Open string numbers. Empty array if none. |
| `notes` | array | yes | Note names at the C position. |
| `intervals` | array | yes | Interval labels in the same order as `notes`. |
| `tags` | array | yes | Freeform tags for search. |

### Chord quality values

`maj7`, `dom7`, `min7`, `min7b5`, `maj6`, `maj69`, `min6`, `dim7`, `aug7`, `dom7alt`, `dom7sharp5`, `dom7flat5`, `dom7b9`, `dom7sharp11`, `dom7b13`, `min-maj7`, `dom9`, `maj9`, `maj13`, `maj7sharp11`, `min9`, `min11`, `dom13`, `sus4`, `sus2`, `quartal`

Free-text field — imports can introduce new qualities. The plugin's filter dropdowns adapt automatically.

### Name format

All voicings follow the pattern: `[Chord] — [CAGED shape] — [Type]`

Examples:
- `C7 — E shape — Shell`
- `Cmaj7 — A shape — Drop 2`
- `Cm7 — Drop 2 — b7 on top` (CM6 chord melody voicings include melody note)

### ID format

```
{quality}-{category}-{shape}-{string-count}
```

Examples:
- `c7-shell-e-shape-6` — C7, shell, E shape, 6-string
- `cmaj7-drop2-a-shape-6` — Cmaj7, drop 2, A shape, 6-string
- `cm7b5-drop3-a-shape-6` — Cm7b5, drop 3, A shape, 6-string
- `c7-cm6-drop2-b7top-6` — C7, chord melody drop 2, b7 on top, 6-string

Lowercase. Use `b` for flat, `s` for sharp in IDs (e.g., `c7s5` for C7#5).

## CAGED position → voicing type map

| CAGED shape | Root string | Voicing type | String set |
|---|---|---|---|
| E shape | 6th string | Drop 3 | 6-4-3-2 |
| A shape | 5th string | Drop 2 | 5-4-3-2 |
| A shape | 5th string | Drop 3 | 5-4-3-1 |
| D shape | 4th string | Drop 2 | 4-3-2-1 |
| D shape | 4th string | Shell | 4-3-2 |

## Source references

- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be
- Taylor, Martin. *Complete Jazz Guitar Method*. Alfred Music
- Greene, Ted. *Chord Chemistry*

Include title, author, and page number in your PR for any new source.

## Code style

- Python: PEP 8
- QML: Qt conventions, 4-space indent
- JSON: 2-space indent, no trailing commas
