# #440 design note — Ted Greene Walking Bass & Chords 1982-1986

## What
Distill Greene *Walking Bass & Chords 1982-1986* through s1-s5. Adds the 4th work to existing master `ted-greene` (already has chord-chemistry, modern-chord-progressions, single-note-soloing).

## Why
Greene's walking-bass-with-chords approach is a different axis than his Chord Chemistry compendium (which is voicing-catalog). The 1982-1986 compendium captures his lesson-handout pedagogy for the walking-bass + comping idiom. Complements Goodrick (voice-leading) and the chord-melody books (#429/#438/#439) by covering the bass-line-driven comping axis specifically.

## What could go wrong
1. **Compendium of handouts → loose structure.** No traditional chapter structure; the TOC may be a catalogue of handout titles. s2 chapter extraction may struggle.
2. **Heavy notation, sparse prose.** Greene's handouts are mostly fretboard diagrams + chord stacks with terse prose. Expect many small chapters with sparse quotes[].
3. **OCR queue position.** Behind #436/#438/#439.

## Rollback
Same as other distillation tickets.

## Falsifiable claims (registered when executing)
1. Greene WBC PDF exists on cyberpower at the configured path.
2. `s5_prescriptive.py` has the granular-levels prompt.
3. `ted-greene` master exists in masters.json (no new master needed).

## Scope boundary
One book through s1-s5 + Stage B PR. Greene's *Trail Guide to Chord Chemistry* is a separate child.
