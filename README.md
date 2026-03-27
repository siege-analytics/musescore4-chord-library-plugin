# MuseScore 4 Chord Library Plugin

A MuseScore Studio 4.6+ plugin for browsing, filtering, and inserting jazz guitar chord voicings directly into your score. The voicing library is hosted as JSON on GitHub — no manual palette management required.

## The problem this solves

MuseScore's native palette system is flat — no nesting, no sub-palettes. A comprehensive jazz guitar voicing library spanning chord melody vs comping contexts, 6 and 7 string guitar, and multiple voicing types is unmanageable as palettes. Sharing requires manual `.mpal` file distribution, and the library can't be updated remotely.

This plugin replaces that workflow: a dialog UI driven by a JSON library that lives online, updates automatically, and can be forked by anyone.

## Features

- Dialog panel with filters for context, chord quality, and voicing type
- Full text search across voicing names and tags
- Double-click to insert a fretboard diagram at any selected note or rest
- Automatic transposition — voicings stored in C, adjusted to target key based on chord symbols in the score
- Library hosted on GitHub, fetched at runtime
- Point the plugin at your own fork for a custom library

## Current status: v0.3.0

- Plugin loads in MuseScore Studio 4.6.x
- 27 voicings: shells (E/A string, 6/7 string), Drop 2 (E/A string), Drop 3 (E string)
- Inserts fretboard diagram grids at the correct position with correct fret offset
- Chord symbol auto-transposition reads HARMONY annotations from the score

**Known limitation:** MuseScore 4's plugin API does not expose `setDot()`, `setMarker()`, or `setBarre()` for fretboard diagrams. Inserted grids have correct dimensions and fret offset but no dot markers. Filed [musescore/MuseScore#32798](https://github.com/musescore/MuseScore/issues/32798). The `.mscx` XML snippet with full dot data is logged to the MuseScore console for manual use.

## Installation

1. Clone or download this repository
2. Create `~/Documents/MuseScore4/Plugins/chordlibrary/`
3. Copy `plugin/ChordLibrary.qml` into that folder as `chordlibrary.qml`
4. Copy `plugin/model/` and `plugin/ui/` into the same folder
5. Restart MuseScore Studio
6. Go to **Plugins** and enable **Chord Library**

## Usage

1. Open a score in MuseScore Studio
2. Select a note or rest where you want the diagram
3. Open **Plugins → Chord Library**
4. Filter or search for a voicing
5. Double-click a voicing card to insert

The plugin reads chord symbols at the selected position and transposes automatically. No chord symbol = no transposition (inserts in C).

## The voicing library

All voicings live in `data/voicings.json`. Organised by:

| Axis | Values | Meaning |
|------|--------|---------|
| **Context** | CM6, CM7, CV6, CV7 | Chord Melody vs Comping/Vocal × 6 vs 7 string |
| **Category** | shell, drop2, drop3, extended, altered, quartal | Voicing type |
| **Quality** | maj7, dom7, min7, min7b5, maj6, min6, dim7, ... | Chord quality |

All shapes stored with root C. Fully moveable.

## Scripts

```bash
# Validate voicings against schema
python scripts/validate.py -v

# Generate .mscx XML snippet for a voicing transposed to F
python scripts/generate_mscx_snippet.py --voicing c7-shell-137-e-str-7 --root F

# Generate all voicings transposed to Bb
python scripts/generate_mscx_snippet.py --all --root Bb --output snippets/
```

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md). All voicings must be verified against [Oolimo](https://www.oolimo.com/) before entry.

## References

- Laukens, Dirk. *Jazz Guitar Chord Dictionary*. jazzguitar.be
- Taylor, Martin. *Complete Jazz Guitar Method*. Alfred Music
- Greene, Ted. *Chord Chemistry*

## Related

- [siege-analytics/jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — `.mpal` palette files (predecessor)
- [siege-analytics/jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — chord melody arrangements
- [Learning Jazz From The Masters](https://learningjazzguitar.substack.com) — Dheeraj Chand's Substack

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Free to use, share, and adapt with attribution to Dheeraj Chand.
