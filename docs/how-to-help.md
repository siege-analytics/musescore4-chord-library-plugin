---
title: How to help
---

# How to help — the voicing-tag review

The plugin's master-style recommender works only after each voicing is **tagged** with the masters whose tradition it belongs to. We've got 820 voicings and they're currently untagged. Friends voting on tag proposals is the bridge.

## The form

[**Open the review form**](https://tally.so/r/2EoZNg)

Each page shows you:

1. **A fretboard diagram** of one voicing — so you see the chord, not a database id
2. **The agent's guess** at which masters and play-styles fit this voicing, plus a one-line reasoning chain
3. **Inline definitions** of every tag the agent proposed (drawn from the master's principle in `masters.json`)
4. **Three radio buttons**: YES, NO, REFINE
5. **A textarea** for your override reason if you disagree
6. **A field** for tags you would add

## What we're asking

For each row you choose to review:

- **YES** — these tags fit; move on.
- **NO** — these tags don't belong; tell us briefly why.
- **REFINE** — some are right, some are wrong, or some are missing. Add what's missing in `additions` and explain what's wrong in `override_reason`.

**You don't have to review all 820.** Skip rows you're unsure about, skip categories you don't play, skip voicings of chords you don't use. Quality of judgment beats coverage every time.

## What's in it for you

Three things:

1. **Your taste shapes the engine.** Once your votes land in `voicings.json`, picking your favorite master in the Library tab actually does something — and that "something" reflects what *you* think Joe Pass would play, not just what an automated tagger guessed.
2. **You get a structured tour of a chord-vocabulary corpus you probably already love.** Going row-by-row through 50 voicings means thinking explicitly about *why* a particular Cmaj9 belongs to Greene's V-System and not Pass's drop-2 catalog.
3. **You help a friend.** This plugin exists in large part because [Dheeraj](https://github.com/dheerajchand) is rebuilding his chord-melody chops after a stroke and wants a recommender that thinks the way his heroes thought. Your judgment goes into that.

## Background reading

If you want the full vocabulary before you start:

- [Glossary]({{ site.baseurl }}/glossary/) — every label, tag, category, and master one-liner
- [How it all fits]({{ site.baseurl }}/) — the data flow from masters.json to engine output

If a row stumps you, **skip it**. Sparse and honest beats complete and uncertain.

## Questions

The form has a `notes` field on every row — use it. The project owner reads them and writes back. Or open a [GitHub Discussion](https://github.com/siege-analytics/musescore4-chord-library-plugin/discussions) if your question is bigger than a single row.

Thanks for helping.
