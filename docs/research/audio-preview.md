# Audio preview research spike (v2.4)

**Ticket:** #198
**Status:** Concluded — outcome 3 (workaround). Question parked for ≥6 months.
**Date:** 2026-05-21

## Question

Can the plugin play a voicing aloud before insertion, using something
exposed by MuseScore 4's plugin API rather than a sidecar?

## Verdict

**No native API path exists in MuseScore 4.7.** The workaround (a Swift
sidecar talking to AVFoundation) is already in the repo and already wired
into the plugin. This ticket closes with the artifact; no follow-up
implementation ticket warranted.

## What was checked

### MuseScore 4 plugin QML import surface

The `MuseScore { ... }` root component exposes score-manipulation
surfaces only: `curScore`, `Cursor`, `Element`, `Note`, `Chord`, `Score`,
`Segment`, plus the score-walking iterators and the `newElement` /
`startCmd` / `endCmd` mutation cycle.

Greppable evidence — the existing plugin's API usage:

```bash
$ grep -rn "MuseScore\\.\|api\\." plugin/*.qml plugin/model/*.qml | grep -vE "comment|//"
# Returns only: curScore, Element.TYPE, newElement, cmd, etc.
# Nothing in the playback / audio / synth namespace.
```

No `MuseScore.playback`, `MuseScore.audio`, `MuseScore.synth`,
`MuseScore.midiOut`, no `Note.play()`, no `Score.play()` available to
plugins. MuseScore's own playback engine (`mu::playback::*` in the C++
source) is not bridged into the QML plugin surface.

### Upstream issue tracker

A search of musescore/MuseScore Issues for "plugin api audio playback"
returns several long-standing requests, all open, none targeted for any
4.x release as of this writing. Nothing changed in 4.6 → 4.7 plugin API.

### What the plugin DOES use (and why it's not a native path)

`plugin/model/InsertionEngine.qml:251` — `playVoicing()` writes a JSON
payload (`{notes:[...], duration, mode}`) to `play-chord.json`. The
companion Swift binary `scripts/ms-audio.swift` polls the file, runs
the notes through `AVAudioUnitSampler` via `AVAudioEngine`. This is
**file-IPC into a sidecar process**, NOT a MuseScore API call.

The plugin can't invoke the sidecar; the user has to install + run it
themselves. So strictly, this isn't a native solution — it's a workaround
that lives outside MuseScore.

## Why we're not pursuing further

1. **MuseScore-side change unlikely soon.** The upstream issue requesting
   plugin audio API access has been open since v3.x. No movement.
2. **The sidecar workaround is fine for the audience.** Mac users who
   want preview can install the Swift binary. Linux/Windows users could
   get equivalent CLIs but nobody has asked.
3. **Embedded playback would require shipping a synth in the plugin.**
   The plugin runs in MuseScore's QML sandbox; loading and shipping a
   soundfont + audio engine inside that sandbox would be a much larger
   project than the question warrants.

## Outcome 1 fallback (if MuseScore exposes the API later)

If a future MuseScore release adds `Note.play()` or similar, the
implementation would replace `InsertionEngine.playVoicing()` body —
build the same `midiNotes` array, call the API instead of writing the
JSON. That's a 10-line change. The data-prep already exists.

When MuseScore 4.8+ ships, re-check `MuseScore` import surface for new
playback methods and reopen this question if any appear. Keep this doc
as the historical reference for what was checked.

## Reference: the existing sidecar wire

```
plugin code:           InsertionEngine.playVoicing(voicing, mode)
  → writes JSON to:    plugin/play-chord.json
external listener:     scripts/ms-audio.swift  (user-installed)
  → uses:              AVAudioUnitSampler / AVAudioEngine
```

The sidecar is documented in `README.md` and the install instructions in
the project doc tree.

## Falsification

Another developer disagrees with this verdict by finding a plugin API
path the spike missed. The grep evidence above is reproducible; if you
find a `MuseScore.playback.*` or `Note.play()` symbol in the 4.7 docs
that this spike missed, reopen #198 and link the finding.
