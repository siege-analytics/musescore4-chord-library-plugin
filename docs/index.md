---
title: How it all fits
---

# MuseScore 4 Chord Library Plugin

> A MuseScore 4 plugin that recommends guitar voicings against the documented vocabularies of 29 master jazz guitarists.

## What problem is this solving?

Jazz guitar has dozens of distinct **chord vocabularies** — the way Joe Pass voices a Cmaj7 looks nothing like the way George Van Eps voices it, which in turn looks nothing like a Jim Hall quartal voicing of the same chord. A working guitarist learns these vocabularies one tradition at a time, often spending years inside each one.

This plugin compresses that journey. It contains:

- **820 curated voicings** drawn from chord-melody and comping traditions
- **29 masters** with documented principles for *how* they voice chords
- **An engine** that ranks the voicings against the master you select — so picking "Joe Pass" surfaces Pass-shaped voicings ahead of generic ones

If you've ever wanted to ask "what would Joe Pass play here?" while writing in MuseScore, this is the answer.

## How the data fits together

```mermaid
flowchart LR
    M[masters.json<br/>29 masters] --> P[principles[]<br/>per-master rules]
    P --> VST[voicingStyleTags<br/>e.g. joe-pass,<br/>chord-melody]
    P --> SYS[systems[]<br/>traversal_rules]
    SYS --> EP[engine_payload.kind<br/>e.g. SubstitutionExpand]
    V[voicings.json<br/>820 voicings] --> CAT[category<br/>e.g. drop2, shell]
    V --> TAG[tags<br/>currently free-form]
    VST -.match.-> TAG
    CAT -.match.-> EP
    M --> ENG((Ranking Engine))
    V --> ENG
    ENG --> OUT[Ranked voicings<br/>shown in MuseScore]
```

When you pick "Joe Pass" in the Library tab:

1. The engine reads the **voicingStyleTags** from Pass's principles (`pass`, `drop-2`, `drop-3`, …)
2. It walks every voicing in `voicings.json` and asks: *do this voicing's tags match Pass's tags?*
3. Matching voicings get a **master boost** added to their base score
4. Voicings rank by total score; Pass-shaped voicings rise to the top

That's the whole idea. Everything else — categories, systems, payload kinds, principles — is the data that makes step 2 possible.

## What's still missing

**Voicings don't carry tags yet.** All 820 voicings have a `category` (drop2/shell/quartal/...) and a free-form `tags` array, but the `voicingStyle` and `playStyle` fields the engine reads are empty across the board. Until those get filled in, picking a master in the Library tab does nothing visible.

The [voicing-tag review project (#395)]({{ site.baseurl }}/how-to-help/) closes that gap. An automated tagger has already guessed which masters each voicing belongs to. Jazz-guitarist friends are reviewing those guesses via a form, voting YES / NO / REFINE. Once enough votes come in, the approved tags land in `voicings.json` and the engine becomes audible.

## Read more

- [Glossary]({{ site.baseurl }}/glossary/) — every term, label, and tag name explained
- [How to help]({{ site.baseurl }}/how-to-help/) — the voicing-tag review form + what we're asking
- [Design philosophy]({{ site.baseurl }}/design-philosophy/) — what the plugin tries to *be* (and not be)
- [Engine payload kinds]({{ site.baseurl }}/payload-kinds/) — the 12 canonical `engine_payload.kind` values + the `_pending:` overflow convention

## The masters

The 29 masters in the corpus today (alphabetical):

`alan-de-mause` · `barry-galbraith` · `benson` · `brent-vaartstra` · `dirk-laukens` · `gene-bertoncini` · `greg-orourke` · `heussenstamm-silbergleit` · `jamey-aebersold` · `jens-larsen` · `jerry-bergonzi` · `jerry-coker` · `jim-hall` · `jimmy-bruno` · `jody-fisher` · `joe-pass` · `johnny-smith` · `lenny-breau` · `martin-taylor` · `matt-warnock` · `mickey-baker` · `nelson-faria` · `pat-martino` · `peter-bernstein` · `randy-felts` · `ted-dunbar` · `ted-greene` · `van-eps` · `wes-montgomery`

Each one has documented principles — short summaries of *how* they voice chords, derived from their published methods (Joe Pass's *Guitar Chords*, Van Eps's *Harmonic Mechanisms*, Greene's *Chord Chemistry*, Laukens's chord dictionary, etc.). See the [Glossary]({{ site.baseurl }}/glossary/) for one-sentence summaries.
