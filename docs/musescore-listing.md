# musescore.org Plugin Listing — Submission Copy

**Title:** Siege Analytics Chord Library

**API Compatibility:** 4.x

**Categories:** Composing tools, Chord notation

**Description (paste this into the listing):**

---

A searchable, filterable chord voicing library for jazz guitar. 169 voicings across 27 chord qualities — shells, drop 2, drop 3, extended, altered, and quartal — with fretboard diagrams that insert directly into your score with complete dot and marker data.

**What it does:**

- Browse voicings by context (chord melody / comping), quality, voicing type, and tuning
- Click a voicing to insert a fretboard diagram at the selected note, transposed to the correct key
- Color-coded fretboard thumbnails on every voicing card (root=red, 3rd=blue, 5th=green, 7th=orange)
- Key-aware transposition with correct enharmonic spelling
- Batch insert: auto-place diagrams for all chord symbols in a selection
- Voice leading: sort voicings by proximity to the previous chord for smooth arranging

**Tuning support:**

- 5 built-in tunings: Standard 6-string, Van Eps 7-string (low A), 7-string low B, DADGAD, All Fourths
- Multi-instrument presets: ukulele, mandolin, banjo, bass guitar
- Create custom tunings from within the plugin (note names or MIDI numbers)
- Notes on voicing cards recalculate when you switch tunings

**Library management:**

- Import/export voicing libraries as JSON
- Save custom voicings to the library with auto-reprojection to C
- Library hygiene checker detects duplicates, enharmonic equivalents, and naming issues
- Export to Guitar Pro 5 and MusicXML (all 12 keys)

**How diagram insertion works:**

MuseScore 4's plugin API does not expose setDot() for fretboard diagrams. This plugin works around that limitation using a compiled Swift tool that writes diagram data to the macOS clipboard in MuseScore's internal format. The plugin then calls cmd("paste") to insert the complete diagram with dots. No Terminal windows, no extra tabs, no permissions required.

Speculative Windows support is included via a Python clipboard writer (untested — testers welcome).

**Requirements:**

- MuseScore Studio 4.6+
- macOS (for full diagram insertion with dots)
- Xcode Command Line Tools (for building the clipboard helper during install)
- Python 3.10+ (optional, for exporters and chord calculator)

**Links:**

- GitHub: https://github.com/siege-analytics/musescore4-chord-library-plugin
- Documentation: https://github.com/siege-analytics/musescore4-chord-library-plugin/wiki
- Issues: https://github.com/siege-analytics/musescore4-chord-library-plugin/issues
- License: CC BY 4.0

**Author:** Dheeraj Chand / Siege Analytics

---

**Screenshots to include (you take these):**

1. Main panel showing voicing list with color-coded fretboard thumbnails and filter dropdowns
2. A fretboard diagram inserted into a score (Au Privave) showing dots
3. Settings panel showing tuning selector and Library Health section
