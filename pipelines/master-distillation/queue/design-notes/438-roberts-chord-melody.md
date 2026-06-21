# #438 design note — Howard Roberts Chord Melody distillation

## What
Run Roberts *Chord Melody* through master-distillation s1-s5 to produce extracted `usage_notes[]` for new master `howard-roberts.work[id=chord-melody]`. Second chord-melody-axis book (after #429 Laukens CCM). Will fan out the master entry + the work entry via Stage B injection PR.

## Why
Per #428 umbrella + standing order. Roberts brings a different chord-melody voice: studio-session pragmatism rather than method-school comprehensive curriculum. His chord-melody approach is terser and more performance-focused, so the per-chord_quality usage_notes should complement Laukens' rather than duplicate. The granular-levels prompt (#434) is in effect for this book — expect per-chord_quality entries across family / floor / omission / color / sub / rhythm / voice-leading / idiom levels where the book addresses them.

## What could go wrong
1. **Short book, dense notation, sparse prose.** Roberts books are typically <100 pages, mostly chord diagrams + arrangements with brief prose introductions. Worker may return many empty quotes[] chapters — honest output. systems[] derivation from limited prose is the real risk.
2. **OCR pre-condition.** The OCR slot on cyberpower is currently occupied by #436 (Goodrick Vol 1). s1 cannot start until Goodrick OCR finishes (~5h ETA at 19:13 CDT). The orchestrator will queue.
3. **howard-roberts master entry is new.** Same as #436 — Stage B injection PR adds both master and work in one shot.

## Rollback
- s1-s4 outputs in `plugin/data/masters-corpus/howard-roberts/chord-melody/`. Delete directory; no plugin-runtime impact.
- Stage B PR revert removes howard-roberts from masters.json.

## Falsifiable claims (will register when actively executing s1)
1. Roberts Chord Melody PDF exists on cyberpower at the configured path.
2. `s5_prescriptive.py` exists with the granular-levels prompt (#434 merged).
3. `howard-roberts` is NOT yet in masters.json (Stage B will add it).

## Scope boundary
One book through s1-s5 + Stage B PR. NOT Roberts' other book (Jazz Guitar Technique in 20 Weeks); that's a future #428 child. No schema changes.
