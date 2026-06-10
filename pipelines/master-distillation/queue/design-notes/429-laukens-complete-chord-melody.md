# #429 design note — Laukens Complete Chord Melody distillation

## What
Run Laukens *Complete Chord Melody* (Dropbox PDF) through master-distillation s1–s5 to produce extracted `usage_notes[]` for `dirk-laukens.work[id=complete-chord-melody]`. First book of the chord-melody axis; validates whether s5's existing schema produces enough granularity on a chord-melody source to capture "melody on top strings," thumb-on-bass voicings, and inner-voice voice-leading rules.

## Why
Curator (Dheeraj) flagged that current Laukens beginners-guide extraction (just merged, #423) does not contain chord-melody-specific prescriptions because the beginners-guide book doesn't teach chord-melody. Complete Chord Melody is the same author's prescriptive treatment of that idiom; landing it cleanly validates the chord-melody axis end-to-end before fanning out to Bertoncini, Galbraith, Howard Roberts, Johnny Smith.

## What could go wrong
1. **Chord-melody pedagogy doesn't fit `chord_quality`-keyed `usage_notes`.** If Laukens organizes by *arrangement technique* (e.g. "drop-2 with melody on string 1") rather than per chord_quality, the extraction will produce notes tagged by chord_quality but with `function_role` doing all the work. Mitigation: accept this — `function_role` was always the flex field. Reject only if extraction produces <10 notes or notes lose page citations.
2. **PDF OCR quality.** Some Laukens books are scanned with marginal OCR. Mitigation: s1 outputs go through manual spot-check before s2.
3. **Schema-drift between work-entries.** `dirk-laukens` already has one accepted work[]; adding a second triggers any latent assumption that masters have exactly one work. Mitigation: schema is array, but verify masters.json renders correctly with multi-work after injection.

## Rollback
- s1–s4 outputs are write-only into `plugin/data/masters-corpus/dirk-laukens/complete-chord-melody/` — delete directory; no downstream impact.
- s5 outputs are draft files only. masters.json is not touched until injection PR.
- Injection PR can be revert-merged if usage_notes are wrong; the existing `dirk-laukens.usage_notes[]` is empty so revert restores empty state.

## Falsifiable claims (signal file: think-gate.json)
1. Laukens Complete Chord Melody PDF exists at the cited Dropbox path.
2. `pipelines/master-distillation/stages/s5_prescriptive.py` exists and is referenced by `run.py`.
3. `dirk-laukens` is present as a master in `plugin/data/masters.json` with the existing beginners-guide work[] entry.

## Scope boundary
This ticket is ONE book through s1–s5 + curator review + injection PR. No schema changes, no other books, no `s5_lines` design. Those are #428's other children.
