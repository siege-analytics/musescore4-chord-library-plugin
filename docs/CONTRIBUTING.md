# Contributing to the Jazz Guitar Chord Library

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

### Step 5: Validate

```bash
python scripts/validate.py -v
```

Fix any errors before submitting. The validator checks required fields, enum values, string/fret ranges, and consistency between dots/notes counts.

### Step 6: Submit a pull request

Include the source (book + page number) and confirmation that you checked with Oolimo.

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

`maj7`, `dom7`, `min7`, `min7b5`, `maj6`, `min6`, `dim7`, `aug7`, `dom7alt`, `dom7sharp5`, `dom7flat5`, `min-maj7`, `dom9`, `maj9`, `min9`, `dom13`, `sus4`, `sus2`

### ID format

```
{root}{quality}-{category}-{intervals}-{root-string}-{string-count}
```

Examples:
- `c7-shell-137-e-str-7` — C7, shell, intervals 1-3-7, E string root, 7-string
- `cmaj7-drop2-e-str-6` — Cmaj7, drop 2, E string root, 6-string
- `cm7b5-shell-1b5b7-e-str-7` — Cm7b5, shell, E string root, 7-string

Lowercase. Use `b` for flat, `bb` for double flat. Use the string letter in the ID, not the number.

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
