# MuseScore 4 Chord Library Plugin

A MuseScore 4 plugin that adds a floating panel for browsing, filtering, and inserting jazz guitar chord voicings directly into your score. The voicing library is hosted as JSON on GitHub — no manual palette management required.

## The problem this solves

MuseScore's native palette system is flat. There is no way to nest or group palettes beyond a single level, which makes a comprehensive jazz guitar voicing library — spanning chord melody vs comping contexts, 6 and 7 string guitar, and multiple voicing types — essentially unmanageable. Sharing palettes requires manual `.mpal` file distribution, and the library can't be updated remotely.

This plugin replaces that workflow with a panel UI driven by a JSON library that lives online, updates automatically, and can be forked and extended by anyone.

## Features

- Floating panel with filter by context, chord quality, voicing type, and string count
- Full text search across voicing names and tags
- Click to insert a fretboard diagram at the selected note
- Automatic transposition — voicings are stored in C and adjusted to the target key on insert
- Library hosted on GitHub, fetched at runtime — always up to date
- Point the plugin at your own fork for a custom library

## Status

Early development. See [DEVELOPMENT.md](DEVELOPMENT.md) for the full architecture, JSON schema, and build phases.

Current phase: **Phase 1 — JSON schema and initial data entry**

## The voicing library

All voicings live in `data/voicings.json`. They are organised by:

- **Context**: chord melody (CM) or comping/vocal (CV)
- **String count**: 6 or 7 string (7-string uses Van Eps tuning — low A)
- **Voicing type**: shell, drop 2, drop 3, extended, altered, quartal

All shapes are stored with root C and are fully moveable — the plugin handles transposition to any key on insert.

## Contributing

Contributions to the voicing library are welcome. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for how to add voicings, validate the JSON, and submit a pull request.

If you find errors in voicing data, please open an issue.

## Related repositories

- [siege-analytics/jazz-guitar-palette](https://github.com/siege-analytics/jazz-guitar-palette) — the MuseScore `.mpal` palette files this plugin is designed to replace
- [siege-analytics/jazz-guitar-arrangements](https://github.com/siege-analytics/jazz-guitar-arrangements) — chord melody arrangements using this library

## Background

This plugin grew out of work on jazz guitar chord melody arrangements documented on [Learning Jazz From The Masters](https://learningjazzguitar.substack.com), using Martin Taylor's *Complete Jazz Guitar Method* and Dirk Laukens' *Jazz Guitar Chord Dictionary* as primary references.

## Requirements

- MuseScore Studio 4.x
- Internet connection for library fetch (offline fallback planned for Phase 5)

## License

Licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

You are free to use, share, and adapt this material for any purpose, provided you credit **Dheeraj Chand** and link to this repository.
