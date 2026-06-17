---
run_id: 2026-06-12T09-48-05-ligon-connecting-chords
stage: s4
source_pdf: Ligon, Bert - Connecting Chords with Linear Harmony.pdf
model: claude-sonnet
extracted_at: 2026-06-15T20:36:24+00:00
schema_version: 0.1
---

# Connecting Chords with Linear Harmony — Statement of Outputs

## Overview

*Connecting Chords with Linear Harmony* by Bert Ligon is a method book for jazz improvisers built around a single organizing conviction: the improviser's primary obligation is *harmonic specificity* — the ability to make chords audible through melodic choices, independent of what the rhythm section provides. The book identifies three stances toward harmony (specificity, generalization, and avoidance) and argues that even deliberate vagueness, in expert hands, is an informed choice made by someone who knows precisely what they are omitting. The methodology is consistently descriptive rather than prescriptive: principles are extracted from transcriptions of outstanding jazz artists, not invented in the abstract.

The theoretical foundation is *linear harmony* — the treatment of chords not as vertical stacks but as horizontal lines unfolding in time, with melodic choices made in relation to the bass line rather than root-position voicings. Within this framework, the third and the seventh of each chord are the load-bearing tones. The third supplies harmonic specificity; the seventh is a restless pointer that resolves downward to the next chord's third, driving melodic momentum across the ii–V–I progression.

## Systems

### Linear Harmony Outline System

The central system of this book is a graph whose members are the three melodic outlines plus their fragment variants and the guide-tone pair that underlies all of them. The outlines are not interchangeable shapes but distinct motion-types: stepwise descent, ascending arpeggio, and descending arpeggio, each operating over the same ii–V–I progression. Movement is governed by voice-leading traversal rules that prioritize the seventh-to-third resolution chain. Modification rules govern how any outline member may be embellished, reduced, or superimposed without losing harmonic clarity. The system generalizes to any root-motion-by-fifths progression — including minor ii–V, modal contexts, and turnarounds.

#### Members
- **Outline No. 1 — Stepwise Descent**: Begins on the third of the ii chord, descends stepwise through V7, resolves to the third of I.
- **Outline No. 2 — Ascending Arpeggio**: Arpeggiation of ii (1–3–5–7); seventh resolves to third of V7 on V7 itself (punch line rule).
- **Outline No. 3 — Descending Arpeggio**: Descends ii (5–3–1), adds seventh below as pointer; special affinity for C.E.S.H. and compound melody.
- **Outline Fragment**: Partial version with omissions; coherence maintained when target tones are placed and resolved.
- **Guide-Tone Pair**: Third supplies specificity; seventh is the restless pointer.

#### Traversal Rules
- **Seventh-to-Third Resolution** (`VoiceMotion`): Seventh of each chord resolves down to third of next.
- **Third-Before-Seventh Placement** (`VoiceMotion`): Third appears earlier than seventh in any line.
- **Root Omission for Counterpoint** (`VoiceMotion`): Root omitted because bass covers it.
- **Punch Line Rule** (`VoiceMotion`): Target note withheld until V7 chord arrives.
- **Target-Tone Rhythmic Placement on Strong Beats** (`VoiceMotion`): Thirds and sevenths on metrically significant beats.
- **Multi-Outline Sequential Combination** (`_pending:outline-sequence-chain`): Outlines combined sequentially.
- **Universal Root-Motion-by-Fifths Applicability** (`_pending:progression-generalization`): Any outline over any descending-fifths progression.

#### Modification Rules
- **C.E.S.H.** (`NCTHarmonization`): Descending chromatic line superimposed over static ii–V (D–C♯–C–B in C major).
- **Parallel Minor Borrowing on Dominant** (`SubstitutionExpand`): Flat-9, sharp-9, flat-13 borrowed from parallel minor.
- **Octave Displacement** (`NCTHarmonization`): Step replaced by compound equivalent (3rd-to-9th leap).
- **Chromatic Directional Tendency Rule** (`NCTHarmonization`): Flats descend, sharps ascend.
- **Diatonic UNT / Chromatic LNT Convention** (`NCTHarmonization`): UNTs diatonic, LNTs chromatic.
- **Outline Fragmentation** (`OmissionAllow`): Non-target chord tones may be omitted.
- **Encircling Target-Tone Surrounding** (`NCTHarmonization`): Target approached from above and below.
- **Compound Melody via Register Split** (`_pending:compound-melody`): Single line implies two voices via 3rd-to-flat-9 leap.
- **Bebop Outline Superimposition over Modal Harmony** (`SubstitutionExpand`): Outlines layered over modal harmony via leading-tone approach.

## Pending Work

Three engine kinds are pending formalization: `_pending:outline-sequence-chain`, `_pending:progression-generalization`, and `_pending:compound-melody`. Each signals a concept operative in the book but lacking formal engine representation.
