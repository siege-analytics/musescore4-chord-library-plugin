# #436 design note — Goodrick Almanac of Guitar Voice Leading, Vol 1

## What
Run Goodrick *Almanac of Guitar Voice Leading, Vol 1* through master-distillation s1-s5 to produce extracted `usage_notes[]` for new master `mick-goodrick.work[id=almanac-vol-1]`. First book of the **voice-leading axis** through the new s5 granular-levels prompt (#434 / PR #435).

## Why
Per #428 umbrella + 2026-06-10 user standing order ("go through the rest of the books like this"). Goodrick is canonical voice-leading pedagogy and one of four volumes in the series; landing Vol 1 cleanly establishes the master entry + the extraction pattern for Vols 2-4 (which will get their own tickets but reuse the master entry).

The new s5 prompt (#434) asks for multiple granularity levels per chord_quality. Goodrick's content is heavily organized AROUND voice-leading moves (common-tone, contrary motion, leap minimization, voice-by-voice substitution lattices), so the per-chord_quality entries should naturally fan out across the family / floor / omission / color / sub / rhythm / voice-leading / idiom levels.

## What could go wrong
1. **Notation-heavy book, prose-light extraction.** Goodrick books are largely written exercises with brief prose introductions. The chapter-loop worker may return many `{"quotes": []}` chapters. Mitigation: that's honest output; the systems[] taxonomy still gets derived from the prose that does exist.
2. **mick-goodrick master entry is new.** The Stage B injection PR must add the master entry, not just a work entry. Mitigation: validate masters.json against schema before pushing the Stage B PR; ensure the master entry has all required fields (id, name, traditions, instrument, biography sentinel, principles[], works[], usage_notes[], status).
3. **Worker subagent may emit a `_pending:<4-segment>` system id** like the existing barry-galbraith bug from #432. Mitigation: same as #432 — flag and fix in the systems-draft before injection; track via #432.
4. **Granularity bar from #434 not yet in effect at s5.** PR #435 might not have merged when I run s5. Mitigation: gate s5 on #435 merge; if not merged, surface and pause.

## Rollback
- s1-s4 outputs are corpus artifacts in `plugin/data/masters-corpus/mick-goodrick/almanac-vol-1/`. Delete directory; no plugin-runtime impact.
- s5 draft files are read-only until Stage B PR. Revert Stage B PR restores masters.json without mick-goodrick.

## Falsifiable claims (signal file)
1. Goodrick Vol 1 PDF exists in Dropbox at the cited path.
2. `s5_prescriptive.py` is wired (function `run` defined).
3. `mick-goodrick` does NOT yet exist as a master in masters.json (Stage B will add it).

## Scope boundary
One book through s1-s5 + Stage B injection PR adding mick-goodrick master + almanac-vol-1 work. NOT Vols 2/3/4; those get their own #428 children. No schema changes, no other masters.
