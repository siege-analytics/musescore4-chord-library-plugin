# Contributing to the Jazz Guitar Chord Library

This document covers two things: how to use the voicing library from the plugin, and how to add voicings to the library.

---

## Using the library

The plugin provides a floating panel inside MuseScore Studio 4. When it is open:

1. Use the filter bar to narrow by **context** (CM6, CM7, CV6, CV7), **chord quality**, **voicing type**, or **string count**
2. Use the search box to find voicings by name or tag
3. Select a note in your score that has a chord symbol attached
4. Double-click a voicing card to insert a fretboard diagram at that note

The plugin reads the chord symbol on the selected note, calculates the semitone distance from C to the target root, and adds that offset to the `fret_number` before inserting. The dot pattern stays the same — only the starting fret changes. All voicings in the library are stored with root C precisely so this works uniformly.

### Contexts

| Code | Meaning |
|------|---------|
| CM6 | Chord Melody, 6-string standard |
| CM7 | Chord Melody, 7-string Van Eps (low A below low E) |
| CV6 | Comping/Vocal, 6-string standard |
| CV7 | Comping/Vocal, 7-string Van Eps |

**Chord Melody** voicings are for fingerstyle playing where the melody is on the guitar. The top note of the chord is constrained to be the melody note — use these when you are arranging a melody for solo guitar.

**Comping/Vocal** voicings are for playing behind a singer or soloist. The melody is in the voice or another instrument, so the guitar is free to voice the harmony however it wants — use these for rhythm guitar work or when comping.

### Voicing types

| Type | Notes sounded | String sets |
|------|--------------|-------------|
| Shell | Root, 3rd, 7th (no 5th) | 3 strings |
| Drop 2 | 4-note voicing, 2nd voice dropped one octave | 4 strings |
| Drop 3 | 4-note voicing, 3rd voice dropped one octave | 4 strings (skip 1) |
| Extended | 9th, 11th, or 13th extensions | 4–6 strings |
| Altered | b9, #9, b5, #5 alterations | 4–6 strings |
| Quartal | Stacked 4ths | 3–6 strings |

Shell chords omit the 5th deliberately. The 5th is harmonically expendable and its absence makes the voicing lighter. A C7 shell contains only C, Bb, and E — root, b7, and 3rd.

---

## How the fret data works

### String numbering

String 1 is the high e string. String 6 is the low E string. String 7 is the low A string (Van Eps 7-string only).

```
String:  7    6    5    4    3    2    1
Tuning:  A    E    A    D    G    B    e
```

### Fret numbers

`fret_number` is the starting fret of the diagram — the first row of fret boxes shown. `dot.fret` is the row within the diagram, where 1 = the first visible row (at `fret_number`), 2 = `fret_number + 1`, and so on.

A C7 shell voicing with `fret_number: 8` and a dot at `{string: 6, fret: 1}` means the root C is at fret 8 on the low E string. That is correct — C is at fret 8 on string 6.

### Fret reference table

Use this to find the correct fret for any root note on any string. All voicings are entered with root C, so work from the C row.

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

Use Dirk Laukens' *Jazz Guitar Chord Dictionary* (jazzguitar.be) or another authoritative source. Note the fingering as fret numbers per string, not finger numbers.

### Step 2: Verify with Oolimo

Before entering anything, verify the voicing at [oolimo.com](https://www.oolimo.com/). Enter the frets, confirm the notes and intervals match what the source says. If Oolimo disagrees with the source, investigate before proceeding.

### Step 3: Determine the C-position

All voicings are stored with root C. Use the fret reference table to find where C falls on the root string for your voicing. That is your `fret_number`.

Calculate each dot as: `dot.fret = actual_fret - fret_number + 1`

If any dot comes out as 0 or negative, your `fret_number` is wrong — recheck.

### Step 4: Write the JSON object

Add your voicing to `data/voicings.json` inside the `"voicings"` array. Every string must appear in exactly one of `dots`, `mutes`, or `open`.

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

This is C7 Shell: root C on string 6 fret 8, Bb on string 4 fret 8, E on string 3 fret 9. Strings 7, 5, 2, and 1 are muted. The `fret` values 1 and 2 are relative to `fret_number` 8 — so dot fret 1 is actual fret 8, dot fret 2 is actual fret 9.

### Step 5: Validate

```bash
python scripts/validate.py -v
```

Fix any errors before submitting. The validator checks all required fields, enum values, string/fret range constraints, and that no string is in more than one of `dots`/`mutes`/`open`.

### Step 6: Submit a pull request

Open a PR with:
- The voicing(s) added
- The source (book title and page, or URL)
- Confirmation that you checked with Oolimo

---

## Field reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique identifier, kebab-case, no spaces. See ID format below. |
| `name` | string | yes | Human-readable label shown in the plugin UI. |
| `chord_quality` | string | yes | One of the quality values listed below. |
| `root` | string | yes | Always `"C"` — voicings are stored at root C and transposed on insert. |
| `category` | string | yes | `shell`, `drop2`, `drop3`, `extended`, `altered`, or `quartal`. |
| `context` | string | yes | `CM6`, `CM7`, `CV6`, or `CV7`. |
| `strings` | integer | yes | `6` or `7`. Use `7` for Van Eps tuning. |
| `fret_number` | integer | yes | Starting fret of the diagram — where C sits on the root string. |
| `visible_frets` | integer | yes | Number of fret rows shown in the diagram. Typically `4`. |
| `dots` | array | yes | Fingered positions. Each is `{"string": N, "fret": M}` where fret is relative to `fret_number`. |
| `mutes` | array | yes | String numbers that are muted (X marker). Empty array if none. |
| `open` | array | yes | String numbers that are played open (O marker). Empty array if none. |
| `notes` | array | yes | Note names at the reference C position, low to high by string. |
| `intervals` | array | yes | Interval labels in the same order as `notes`. |
| `tags` | array | yes | Freeform tags used for search. At minimum include the category and root string. |

### Chord quality values

`maj7`, `dom7`, `min7`, `min7b5`, `maj6`, `min6`, `dim7`, `aug7`, `dom7alt`, `dom7sharp5`, `dom7flat5`, `min-maj7`, `dom9`, `maj9`, `min9`, `dom13`, `sus4`, `sus2`

### ID format

```
{root}{quality}-{category}-{intervals}-{root-string}-{string-count}
```

Examples:
- `c7-shell-137-e-str-7` — C dominant 7, shell voicing, intervals 1-3-7, root on E string, 7-string
- `cmaj7-drop2-1357-a-str-6` — Cmaj7, drop 2, root on A string, 6-string
- `cm7b5-shell-1b5b7-e-str-7` — Cm7b5, shell, root on E string, 7-string

Keep it lowercase. Use `b` for flat (`b7`, `b3`), `bb` for double flat (`bb7`). Use the string letter, not the string number, in the ID.

---

## CAGED position to voicing type reference

| CAGED shape | Root string | Voicing type | String set |
|-------------|-------------|--------------|------------|
| E shape | 6th string | Drop 3 | 6-4-3-2 |
| A shape | 5th string | Drop 2 | 5-4-3-2 |
| A shape | 5th string | Drop 3 | 5-4-3-1 |
| D shape | 4th string | Drop 2 | 4-3-2-1 |
| D shape | 4th string | Shell | 4-3-2 |

---

## Source references

Primary sources used for voicing data:

- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be. — shell and drop voicings
- Taylor, Martin. *Complete Jazz Guitar Method*. Alfred Music. — chord melody methodology
- Greene, Ted. *Chord Chemistry*. — extended and altered voicings

If you are adding voicings from a different source, include the title, author, and page number in your PR.

---

## Code style

- Python: PEP 8
- QML: Qt conventions, 4-space indent
- JSON: 2-space indent, no trailing commas
