# .mscx FretDiagram XML Format (MuseScore 4)

Reference documentation for the XML structure used to represent fretboard diagrams
in MuseScore 4 `.mscx` score files.

## Structure

```xml
<FretDiagram>
  <fretOffset>8</fretOffset>
  <frets>4</frets>
  <strings>7</strings>
  <fretDiagram>
    <string no="0">
      <marker>cross</marker>
    </string>
    <string no="1">
      <dot fret="1">normal</dot>
    </string>
    <string no="3">
      <dot fret="1">normal</dot>
    </string>
    <string no="4">
      <dot fret="2">normal</dot>
    </string>
    <string no="5">
      <marker>cross</marker>
    </string>
    <string no="6">
      <marker>cross</marker>
    </string>
  </fretDiagram>
</FretDiagram>
```

## Element Reference

### `<FretDiagram>` (outer)
The top-level element. Contains properties and the data block.

### Properties (direct children of `<FretDiagram>`)

| Element | Type | Description |
|---------|------|-------------|
| `<fretOffset>` | int | Starting fret number |
| `<frets>` | int | Number of frets displayed |
| `<strings>` | int | Number of strings (6 or 7) |

### `<fretDiagram>` (inner, lowercase)
Contains all per-string data. This is a child of the outer `<FretDiagram>`.

### `<string no="N">`
Defines data for a specific string. `no` is 0-based:
- `no="0"` = highest pitched string (high e on 6-string)
- `no="5"` = lowest on 6-string (low E)
- `no="6"` = lowest on 7-string (low A, Van Eps)

### `<dot fret="N">type</dot>`
A fingered position. `fret` is 1-based relative to `fretOffset`.
Types: `normal`, `cross`, `square`, `triangle`

### `<marker>type</marker>`
String marker above the nut.
Types: `cross` (muted/X), `circle` (open/O)

### `<barre start="S" end="E">fret</barre>`
A barre across strings. `start` and `end` are 0-based string indices.
Text content is the fret number (1-based relative to fretOffset).

## String Number Conversion

Our voicings.json uses 1-based guitar convention (1 = high e).
MuseScore uses 0-based top-down (0 = highest).

```
ms_string = num_strings - our_string
```

| Our string | Guitar | MS string (6-str) | MS string (7-str) |
|-----------|--------|-------------------|-------------------|
| 1 | high e | 5 | 6 |
| 2 | B | 4 | 5 |
| 3 | G | 3 | 4 |
| 4 | D | 2 | 3 |
| 5 | A | 1 | 2 |
| 6 | low E | 0 | 1 |
| 7 | low A | — | 0 |

## Source
Derived from MuseScore 4 source code:
- `src/engraving/rw/write/twrite.cpp` (XML write)
- `src/engraving/rw/read410/tread.cpp` (XML read)
