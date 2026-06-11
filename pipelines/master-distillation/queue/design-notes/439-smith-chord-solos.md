# #439 design note — Johnny Smith Chord Solos distillation

## What
Distill Smith *Chord Solos* through s1-s5. New master `johnny-smith.work[id=chord-solos]`. Third chord-melody-axis book (#429 Laukens CCM, #438 Roberts CM, this).

## Why
Smith's contribution to the chord-melody axis is distinct: very close voicings on adjacent strings, no doubling, quiet ballad-oriented (rather than Pass's big-band swing or Laukens's curriculum-pedagogy framing). His "Moonlight in Vermont" arrangement is the canonical reference. Even if the book is short and prose-light, the close-voicing density-floor + adjacent-string-voicing rules should emerge.

## What could go wrong
1. **Older book, possibly poor OCR.** Smith's 1956 book may have stylized typography that the OCR struggles with. The vision model may need to rescue many pages.
2. **Notation-heavy.** Like Roberts CM and Bertoncini, this is largely arrangements with brief prose. Empty quotes[] chapters likely.
3. **OCR queue position.** Behind #436 and #438 on cyberpower.

## Rollback
Same as other distillation tickets: corpus dir deletion + Stage B PR revert.

## Falsifiable claims (registered when actively executing)
1. Smith Chord Solos PDF exists on cyberpower at the configured path.
2. `s5_prescriptive.py` has the granular-levels prompt.
3. `johnny-smith` is NOT yet in masters.json.

## Scope boundary
One book through s1-s5 + Stage B PR. Smith's *Aids to Technique* is a separate child ticket.
