# MuseScore 4 Chord Library Plugin — Development Document

## Overview

A MuseScore 4 plugin that provides a floating panel UI for browsing, filtering, and inserting jazz guitar chord voicings from a web-hosted JSON library. Intended as a replacement for MuseScore's flat palette system, with support for hierarchical categories, search, and remote updates.

## Problem statement

MuseScore's native palette system is flat — palettes cannot be nested or grouped beyond a single level. For a comprehensive jazz guitar voicing library spanning multiple contexts (chord melody vs comping/vocal), string counts (6 and 7 string), and voicing types (shell, drop 2, drop 3, extended, altered, quartal), this results in an unmanageable number of top-level palettes with no cross-referencing.

Additionally, native palettes cannot be updated remotely — sharing requires manual `.mpal` file distribution. A JSON-driven plugin solves both problems: the library lives online, updates propagate automatically, and the UI can expose any organizational hierarchy.

## Goals

- A MuseScore 4 plugin with a dockable/floating panel UI
- Voicing library hosted as JSON on GitHub, fetched at runtime
- Filter and search by chord quality, context, voicing type, string count
- Click to insert a fretboard diagram at the selected note in the score
- Library updateable without reinstalling the plugin
- Forkable and community-extensible

## Non-goals

- Real-time collaboration
- Audio playback within the plugin
- Support for MuseScore versions prior to 4.x

---

## Architecture

### Components
