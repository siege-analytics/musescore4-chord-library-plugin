# Stage-B for #429 + queue-drain protocol for #428

## What
1. Accept #429's s5 outputs (36 chord-melody usage_notes, schema-valid) and inject both Laukens works' usage_notes into `dirk-laukens.usage_notes[]` in `plugin/data/masters.json` — one PR carrying both `beginners-guide` (23 notes) and `complete-chord-melody` (36 notes), 59 total, replacing the 4 `inferred-from-principles` placeholders that landed in #416.
2. Lock in the queue-drain protocol for the remaining #428 child books: each book = own ticket, own branch, own design note, worker-subagent for s2-s4, main-agent inline for s5 + injection PR.

## Why
- #429 hit DoD (23+ notes per the beginners-guide bar; in fact 36 > 23). Curator skim of PRESCRIPTIVE.md showed chord-melody coverage that beginners-guide could not produce (shell-voicing-floor, sub-family-discrimination, sparse-chord-placement, tritone-substitution-with-guide-tone-validity, lick-swap-trigger, ii/V-interchangeability, back-cycling). The two works are complementary — same master, different idiom — and should land together to avoid intermediate masters.json state where Laukens has one work but not the other.
- User's standing guidance (2026-06-10 13:04): "the more granular the rules, the better: we want many levels of granularity for each rule or item." The 36 notes already include multiple granularity levels per chord_quality (family-assignment + voicing-floor + omission-priority + substitution-rule + rhythmic-placement + chromatic-approach). Subsequent books should match or exceed.

## Granularity guidance — update Worker.md
The chapter-loop subagent's s5 prompt should explicitly request multiple-granularity-levels-per-chord. Concretely: for each chord_quality the book addresses, the worker should aim for entries covering at minimum:
1. Harmonic-family classification (where does this chord live in the master's taxonomy?)
2. Voicing floor / shell (irreducible minimum voicing)
3. Omission priorities (which notes can be dropped, in what order)
4. Color-tone policy (which extensions/alterations the master mandates, allows, forbids)
5. Substitution rules (any chord can stand in if X; tritone, relative, back-cycle, etc.)
6. Rhythmic placement (beat 1 vs upbeat vs walking-bass alternation)
7. Voice-leading (where this chord connects to its neighbors)
8. Idiom-specific application (solo vs trio vs chord-melody-specific)

Not every book will cover all 8 levels for every chord_quality — sparsity is honest. But the worker should TRY for each, and the curator-review can prune.

## What could go wrong
1. **Injection order shuffles principles[] cross-references.** The 36 notes cite `source_principle_ids` like `dirk-laukens:complete-chord-melody:chord-melody-harmonization` that don't yet exist in masters.json. Either inject the principles[] entries at the same time, or accept that the references are forward-pointers awaiting Stage B principle definitions. Mitigation: validate masters.json against schema BEFORE pushing; if cross-refs are required, generate the principles[] entries from systems-draft.json.
2. **Beginners-guide notes' source_principle_ids may not match chord-melody's.** The two works' principle taxonomies were synthesized independently. Mitigation: keep them as work-scoped (each note's `source_work_id` identifies which work the principle_ids belong to).
3. **Worker subagent context limits.** Each new book run consumes a fresh subagent's context (~80-90k tokens for a 300-page book). At 16 books, that's substantial token spend. Mitigation: spawn subagents per-book, not per-batch.

## Rollback
Injection PR revert restores empty `dirk-laukens.usage_notes[]`. Worker outputs in `plugin/data/masters-corpus/<master>/<work>/derived/` are read-only artifacts; no impact on plugin runtime.

## Falsifiable claims (signal file)
1. The reviewed PRESCRIPTIVE.md is at `plugin/data/masters-corpus/dirk-laukens/complete-chord-melody/derived/PRESCRIPTIVE.md`.
2. The 36 usage_notes file is at `plugin/data/masters-corpus/dirk-laukens/complete-chord-melody/derived/prescriptive-lessons-draft.json` and is schema-valid against `$defs/usage_note`.
3. `dirk-laukens` master entry exists in `plugin/data/masters.json` and has zero or only-placeholder usage_notes[] currently.

## Scope boundary
This note covers #429's Stage B (injection PR) and the queue-drain protocol going forward. Each subsequent book (Goodrick Vol 1, Roberts CM, etc.) gets its own ticket + design note + branch. The Worker.md edit (granularity guidance) lands as a separate small PR with its own ticket.
