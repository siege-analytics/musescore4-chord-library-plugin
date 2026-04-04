# musescore4-chord-library-plugin

> **SESSION START**: Always read all markdown files in musescore4-chord-library-plugin repositories at session start:
> ```
> /Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin/CLAUDE.md
> /Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin/*/CLAUDE.md
> /Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin/docs/*.md
> /Users/dheerajchand/Documents/Professional/Siege_Analytics/Code/music/musescore4-chord-library-plugin/ROADMAP.md
> ```

[Add additional project-specific documentation paths here]

## Working Guidelines for AI Assistants

### 1. Slow and Deliberate

Always plan first, never jump to implementation:
- Explore the whole codebase to understand context
- Ask clarifying questions upfront
- Think holistically about how changes fit the system
- One correct solution beats sixty rushed attempts
- Use TodoWrite to track and plan multi-step tasks

### 2. Senior Engineer Mindset

Write as if proving value to a skeptical engineer evaluating whether to keep the service:
- High-quality, maintainable code following existing patterns
- Explicit over implicit (Zen of Python applies to all languages)
- Proper error handling - errors should never pass silently
- Readability counts - code should be obvious to the next person
- Simple is better than complex - resist over-engineering
- When in doubt, refuse to guess - ask instead

### 3. Voice and Tone

Use a conversational yet substantive voice in all output (commits, PRs, comments):
- Direct and clear, avoiding corporate speak and hyperbole
- Honest about trade-offs and limitations
- Grounded in practical details over abstractions
- Dry, understated humor when appropriate (never forced)
- Show thinking without over-explaining

### 4. No AI Attribution

Never include AI assistant attribution in any output:
- No "Generated with Claude Code" or similar
- No "Created with [tool name]" or similar
- No "Co-Authored-By: Claude" in commits
- Remove any such attribution if found in existing code

### 5. Test Before Presenting

Always verify solutions before showing them:
- Run tests and iterate until they pass
- Only present finished, tested solutions
- Creating testing work for the user defeats the purpose

### 6. Admit Defeat

If stuck or unable to solve something:
- Say so clearly and directly
- Never try progressively worse solutions hoping something sticks
- Better to admit limitations than cause damage

## Attribution Policy

**NEVER** include AI assistant attribution in commits, PRs, issues, comments, or any public-facing content. This includes:
- No `Co-Authored-By: Claude` or similar lines in commit messages
- No "Created with [tool name]" phrasing anywhere
- No "Generated with [tool name]" in PR descriptions
- No AI assistant mentions in issue comments or documentation
- This applies to ALL repositories

## Project Overview

A MuseScore 4 plugin that replaces MuseScore's flat palette system with a hierarchical, searchable chord voicing library for jazz guitar. Fetches voicing data from a JSON file hosted on GitHub, provides filtering by context/quality/voicing type, and inserts fretboard diagrams into scores with auto-transposition.

**Tech stack**: QML/JavaScript (MuseScore 4 plugin API), Qt.network for JSON fetch, Python for validation/extraction scripts.

**License**: CC BY 4.0 — free to use/share/adapt with attribution to Dheeraj Chand.

## Architecture

### Two-Axis Voicing Organization

**Texture axis** (melody placement):
- CM = Chord Melody / Fingerstyle (melody on guitar)
- CV = Comping / Vocal (melody in voice)

**String count axis**:
- 6 = standard 6-string
- 7 = 7-string Van Eps tuning (low A below standard low E)

**Palette naming**: `[context][strings] — [voicing type]`
**Voicing types**: Shell · Drop 2 · Drop 3 · Extended · Altered · Quartal
**Total**: 24 palettes (4 contexts × 6 voicing types)

### String Numbering Convention

1 = high e, 2 = B, 3 = G, 4 = D, 5 = A, 6 = low E, 7 = low A (Van Eps)

### Key Principles

- Shell chords = root, 3rd, 7th only. No 5th (deliberately omitted).
- All voicings stored in C — transposable by adjusting fret number.
- Dot fret values are relative to fret_number (row 1 = fret_number, row 2 = fret_number + 1, etc.).

## Quick Reference

### Common Commands

```bash
# Validate voicings.json against schema
python scripts/validate.py

# Extract voicing data from MuseScore files
python scripts/generate_from_mscz.py

# Install plugin (copy to MuseScore plugins dir)
cp -r plugin/ ~/Documents/MuseScore4/Plugins/ChordLibrary/
```

### Key Directories

```
plugin/          # QML plugin source (ChordLibrary.qml + ui/ + model/)
schema/          # JSON schema for voicings
data/            # voicings.json — the chord library data
scripts/         # Python validation and extraction tools
docs/            # Contributing guide and documentation
```

### Configuration

- Plugin fetches `data/voicings.json` from GitHub at runtime
- User can point plugin at a fork for custom library (configurable JSON URL)

## Development Phases

1. **JSON schema + initial data** ← current
2. Plugin scaffold — QML structure, fetch JSON, display list
3. UI — filter bar, search, voicing card grid with fretboard thumbnails
4. Score insertion — read chord symbol, transpose, insert diagram
5. Polish — offline cache, user-defined JSON URL, contributing guide, v1.0

## Critical Open Question

Does MuseScore 4's plugin API expose fretboard diagram dot positions programmatically? The `setDot(string, fret, finger)` method exists in MS3 but needs verification for MS4. **This is a blocker for Phase 4.**

## Common Pitfalls

- Always verify fret calculations against the fret reference table, do not compute from memory
- Do not make up voicing fingerings — use the Laukens PDF as source of truth
- Dheeraj uses Oolimo to verify chord voicings — recommend checking there when in doubt

## Related Projects

- [jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — `.mpal` palette files
- [jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — MuseScore arrangements
- Both repos under the siege-analytics GitHub org "Music" project board

## Session Notes (2026-04-03)

### Mistakes to Avoid
- **QML ComboBox cascades**: Never use `onCurrentTextChanged` or `onCurrentIndexChanged` on ComboBoxes with dynamic models. Use `onActivated` (user clicks only). Model changes trigger binding recalculations that fire these handlers spuriously, causing infinite cascades and UI freezes.
- **QML property mutation**: Arrays and objects modified in place (`.push()`, `obj[key] = val`) don't trigger QML binding updates. Always build a new object/array and assign it.
- **Per-quality voicing cap across roots**: Capping voicings globally across all 12 roots starves uncommon roots (F, Bb, Db). Always use `capPerRoot` to distribute evenly.
- **MuseScore title frame**: The MS4 plugin API cannot add elements to the title frame (VBox). `setMetaTag("subtitle")` sets metadata but doesn't create visible text. `Element.POET` creation fails. System text with offset is unreliable. Best approach: clipboard copy + manual subtitle.
- **`removeElement()` doesn't exist** in MS4 plugin API. Don't try to remove annotations — update them in place instead.

### Useful Patterns
- **Cache calculated voicings** per tuning slug to avoid recalculating on every switch. Store in a property var object, rebuild (don't mutate) to trigger bindings.
- **capPerRoot with diversity**: Three phases — (1) one voicing per top note, (2) one per note count, (3) one per category — then fill remaining slots by score. This ensures melody matching, shape variety, and type diversity.
- **Bass string grouping**: Group voicings by lowest sounding string number. Users think in terms of "bass on string 6" not "voicing #114 of 200".
- **Deploy + restart**: MuseScore caches QML aggressively. Always `./deploy.sh` then quit and relaunch MuseScore. No hot reload.

### MuseScore 4 Plugin API Limitations
- No title frame access (VBox/POET/SUBTITLE creation)
- No `removeElement()` — can only update existing elements
- `Align` enum doesn't exist — can't set text alignment
- `setMetaTag()` sets metadata but doesn't create visual elements
- System text anchors at beat 1 (after clef), not at page margin
- `WorkerScript` (threading) not available — calculations block UI thread

---

*Last updated: 2026-04-03*
