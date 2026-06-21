# #442 design note — Goodrick Almanac Vol 2 distillation

## What
Distill Goodrick *Almanac Vol 2* through s1-s5. Second mick-goodrick work after #436 Vol 1.

## Why
Goodrick's Almanac is a 4-volume series. Vol 1 establishes the voice-leading taxonomy; Vols 2-4 extend it. Landing Vol 2 next gives cross-volume reference for the same master's systems[]; if Vol 1 derived 3 systems, Vol 2 should align with that taxonomy.

## What could go wrong
1. **Cross-volume system-id alignment.** If Vol 1 used (say) `mick-goodrick:almanac-vol-1:close-voicing-voice-leading`, Vol 2's similar system should reference the Vol 1 id or use a parallel `:almanac-vol-2:` shape. The worker subagent operates per-volume; manual reconciliation may be needed at Stage B.
2. **Notation-heavy.** Same concern as Vol 1.
3. **OCR queue position.** 5th in line.

## Falsifiable claims (when executing)
1. Vol 2 PDF exists on cyberpower.
2. `mick-goodrick` master exists in masters.json (added by #436 Stage B).
3. `s5_prescriptive.py` has the granular-levels prompt.

## Scope boundary
One book through s1-s5 + Stage B PR.
