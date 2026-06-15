---
run_id: 2026-06-12T09-45-18-goodrick-almanac-vol-2
stage: s4
source_pdf: Goodrick, Mick - Almanac of Guitar Voice Leading, Vol 2.pdf
model: claude-sonnet
extracted_at: 2026-06-15T20:41:41+00:00
schema_version: 0.1
---

# Almanac of Guitar Voice Leading, Vol. 2 — Statement of Outputs

## Overview

Mick Goodrick's *Almanac of Guitar Voice Leading, Volume 2* is the concluding half of a two-volume exhaustive method whose central ambition is completeness: identifying, notating, and systematically practicing every 3-part and 4-part chord voicing within three diatonic scales (C Major, C Melodic Minor, C Harmonic Minor). Volume II pivots from Volume I tertial triads to quartal and cluster structures built on 4ths and 2nds, producing greater harmonic ambiguity and functional range. Chords are deliberately left unnamed throughout (Chapter 3).

The organizing concept is the M-Lode (Mother Lode), defined in Chapter 4: the totality of voicings across both volumes voice-led through six diatonic cycles in each scale. Chapter 16 quantifies the scope (20+ different 3-part chords, 30+ 4-part chords, 1,000+ total voicings) and states the foundational principle: all of the M-Lode is based on voice-leading.

The bulk of the book (Chapters 19–27) is systematic notation — every family through every cycle in every scale (3 families × 3 scales = 9 chapters). Each entry uses the paired Intervallic/Functional Voice-Leading grid (the master signature analytical tool). Chapters 3–18 establish the voicing toolkit and practice methods.

## Systems

### System 1: The M-Lode — Complete Voice-Led Chord Family System

The M-Lode is the master system: every 3-part and 4-part voicing within C Major, C Melodic Minor, and C Harmonic Minor, traversed through six diatonic cycles by voice-leading.

**Members:** Triads, 7th Chords, TBN I, TBN II (Vol I); 3-Part 4ths, 4-Part 4ths, Spread Clusters (Vol II); 3-Part Spread Clusters, 7th-no-5th, 7th-no-3rd (3-part supplements).

**Traversal Rules:**
- Diatonic Stepwise Voice Motion Through Six Cycles — `VoiceMotion` (Chapter 16, 19, 22)
- Common-Tone Preservation Across Chord Positions — `VoiceMotion` (Chapters 19, 23, 26)
- Arpeggio Direction Alternation Across Successive Chords — `TextureCycle` (Chapters 6, 15)
- Drop-D Pedal String Traversal in D Dorian — `StringSetTransition` (Chapter 5)
- Cycles 2 and 7 Dual Voice-Leading Exception — `VoiceMotion` (Chapter 16)

**Modification Rules:**
- Octave Insertion Between Any Two Voices — `SubstitutionExpand` (Chapters 8, 9, 10)
- Single-Voice Omission to Derive 3-Part Subsets — `OmissionAllow` (Chapters 7, 15)
- Passing-Tone Fill on Third-Motion Intervals — `NCTHarmonization` (Chapter 13)
- Drop Voicing Type Selection — `SubstitutionExpand` (Chapters 10, 19)
- Quartal Voicing Interval Exclusion — `FamilyCoherence` (Chapter 5)
- Density Floor: 4-Way Close as Minimum Starting Point — `DensityFloor` (Chapters 15, 16)

### System 2: Exhaustive Voice-Combination Practice System

Governs how the practitioner works with the M-Lode raw voicing material through practice. Systematically traverses every 2-voice and 3-voice subset of every 4-part chord. Joe 2 Plus 2 Thing treats 4-part chord as two alternating 2-note call-and-response pairs. Five deployment modes (melodies/arpeggios/counterpoint/3-part/4-part) define complete taxonomy.

**Members:** Full 4-Voice Chord Position; 2-Voice Combination (6 per chord); 3-Voice Combination (4 per chord); Joe 2 Plus 2 Grouping.

**Traversal Rules:**
- Exhaustive Combinatorial Traversal of Voice Subsets — `_pending:combinatorial-exhaustion` (Chapter 7)
- Joe 2 Plus 2 Call-and-Response Alternation — `TextureCycle` (Chapters 12, 13)
- Five-Mode Application Cycle — `TextureCycle` (Chapter 6)

**Modification Rules:**
- 24-Sequence Arpeggio Permutation Rule — `_pending:permutation-exhaustion` (Chapter 15)
- C Harmonic Minor Scale Preference — `ColorToneRequire` (Chapter 15)

## Pending Work

- `_pending:combinatorial-exhaustion` — Engine encoding for exhaustive 2-voice/3-voice subset traversal (Chapter 7 source).
- `_pending:permutation-exhaustion` — Engine encoding for 24-permutation arpeggio generation (Chapter 15 source).

## Provenance Notes

Sources: book-level distillation (s3), per-chapter summaries (ch01–ch27), systems-draft. Chapters 1, 2, 14, 17, 18 yielded no extractable load-bearing instructional content. Notation chapters 19–27 instantiate System 1 rules exhaustively across nine family/scale combinations.
