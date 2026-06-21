---
run_id: 2026-05-28T15-05-20-coker-patterns-for-jazz
stage: s4
source_pdf: Coker, Jerry - Patterns for Jazz (1970).pdf
model: claude-sonnet
extracted_at: 2026-05-31T03:48:47+00:00
schema_version: 0.1
---

# Patterns for Jazz — Statement of Outputs

## Overview

*Patterns for Jazz* (Jerry Coker, 1970) is a comprehensive, sequentially structured improvisation method for jazz musicians. It spans thirty-five chapters moving from the simplest major-key building blocks — triads, sixths, sevenths, ninths — through modal derivation of dominant and minor harmony, into non-diatonic and symmetrical scale territories (whole-tone, diminished, augmented, polychords, and altered extensions), and concluding with fourths-based improvisation and chromatic integration. The book's organizing premise, stated at the outset and reiterated at every subsequent stage, is that chord tones are never memorized in isolation: every chord is built by extracting numbered scale degrees from a named parent mode, and every pattern produced by that extraction must be transposed through all twelve keys as a non-negotiable condition of adequate results.

The method's pedagogical architecture rests on four interlocking pillars: **formulaic extraction** (every chord reduces to a scale-degree formula applied to a parent mode); **directional alternation** (ascending and descending forms are practiced in systematic alternation to prevent directional habits); **compositional economy through pattern recycling** (mastered short-form vocabulary is extended to longer progressions rather than new material being introduced); and **modal unification** (multiple chord qualities sharing one parent mode are labeled with a single chord symbol for notational convenience, collapsing what might appear to be separate chord families into a single scalar discipline). These four principles, taken together, constitute a single internally consistent method: harmonic mastery and improvisational fluency are treated as the same competency, achievable only through disciplined, bidirectional, all-keys internalization of a small set of scale-degree formulas.

The structural arc of the book follows a deliberate pedagogical sequence from chord-centric thinking (triads and chord tones, Chapters 1–8) through scale-centric thinking (modal sources for dominant and minor harmony, Chapters 9–17) through group-centric thinking (the IIm7–V7–IM7 as a single harmonic unit, Chapters 16–20) and finally to symmetry-centric thinking (diminished, whole-tone, augmented, and Lydian Augmented systems, Chapters 18–35). Each domain is introduced conceptually, immediately converted into transposable practice patterns, and the student is never permitted to remain in a single key.

---

## Systems

### Modal Derivation System

The Modal Derivation System is the central organizing mechanism of the entire book. Every chord quality is derived by extracting numbered scale tones from a named parent mode — the chord is never an isolated voicing to be memorized but always a formulaic product of a scale source. Major chord types share the major scale of the chord root. Dominant seventh and ninth chords share the same Mixolydian mode. All four minor chord qualities share the Dorian mode. Diminished chords derive from the diminished scale. Augmented triads and augmented seventh chords derive from the whole-tone scale. The M7+5 chord derives from the augmented scale. The Lydian Augmented Scale is deployed over dominant seventh chords via two distinct root-alignment positions. The IIm7–V7–IM7 progression is the primary traversal axis binding these families into a working harmonic grammar.

**Members:**
- Major Family (Ionian/Major Scale)
- Dominant Family (Mixolydian Mode)
- Minor Family (Dorian Mode)
- Diminished Family (Diminished Scale)
- Whole-Tone Family
- Augmented Scale Family
- Lydian Augmented Scale Family

**Traversal Rules:**

- **IIm7–V7–IM7 Chord-Group Traversal** — `FamilyCoherence` — Navigate the progression as a single unit sharing one parent key signature. (Chapter 16 summary; ch16.md quotes, p. 83–84.)
- **Shared Parent Key Continuity (IIm7–V7)** — `FamilyCoherence` — A single scalar pattern begun on the IIm7 may continue unaltered through the V7. (Chapter 17 summary, p. 95; Chapter 20 summary, p. 97.)
- **Directional Alternation Traversal** — `SymmetryMovement` — Systematically alternate ascending and descending directions. (Chapter 3 summary, p. 12; Chapter 5, p. 25; Chapter 17, p. 94.)
- **All-Twelve-Keys Mandatory Transposition** — `_pending:mandatory-transposition` — Every pattern must be transposed through all twelve keys. (Chapter 1 summary, p. 4; Chapter 5, p. 26; Chapter 22, p. 116.)

**Modification Rules:**

- **Formulaic Extraction** — `_pending:formulaic-extraction` — Any chord is built by extracting named scale degrees from its parent mode. (Chapter 1, p. 1; Chapter 9, p. 50; Chapter 11, p. 62; Chapter 21, p. 110; Chapter 19, p. 106.)
- **Family Unification — Single Symbol Convenience** — `FamilyCoherence` — One symbol labels all patterns in a shared-scale family. (Chapter 4, p. 16; Chapter 15, p. 79; Chapter 22, p. 116.)
- **Two-Fragment Coverage Rule** — `SubstitutionExpand` — Pair two complementary scale-degree fragments for complete coverage. (Chapter 7, p. 27; Chapter 17, p. 88; Chapter 20, p. 97.)
- **Enharmonic Equivalence / Extension Collapse** — `_pending:extension-collapse` — Upper extensions collapse to lower scale degrees (9=2, 11=4, 13=6); enharmonic substitution preserved. (Chapter 1, p. 3; Chapter 19, p. 106.)
- **Compositional Economy — Pattern Recycling** — `_pending:pattern-recycling-extension` — Extend mastered short-form patterns to longer progressions. (Chapter 17, p. 90; Chapter 20, p. 98.)
- **Dominant Seventh Color Tone Alteration** — `ColorToneRequire` — Dominant 7 freely alters 9/5/11/13 with major-3rd, minor-7th invariants. (Chapter 25, pp. 119, 121; Chapter 27, p. 131.)

---

### Symmetrical Scale Reduction System

This system governs all non-diatonic scale territories. Its governing insight is that the symmetrical interval structure of each non-diatonic scale limits the total number of distinct pitch collections across all twelve roots: whole-tone yields two collections, diminished yields three, augmented yields four. Rather than learning twelve scales per family, the student learns two/three/four pitch sets and maps all chromatic roots onto them. This economy is extended by the diminished-fifth substitution rule, the half-step offset rule for diminished over dominant, and the Lydian Augmented two-position deployment.

**Members:**
- Whole-Tone Scale (2 distinct collections)
- Diminished Scale (3 distinct collections)
- Augmented Scale (4 distinct collections)

**Traversal Rules:**

- **Four-Root Diminished Symmetry Traversal** — `SymmetryMovement` — Any of four roots sharing a diminished scale serves as starting point. (Chapter 21 summary, p. 109; Chapter 27, p. 130.)
- **Two-Collection Whole-Tone Traversal** — `SymmetryMovement` — All twelve starting points map to two pitch collections. (Chapter 18 summary, p. 104.)
- **Four-Collection Augmented Scale Traversal** — `SymmetryMovement` — Only four augmented scales exist; transposition cycles through these. (Chapter 28, p. 134; Chapter 35, p. 168.)

**Modification Rules:**

- **Diminished-Fifth (Tritone) Substitution Rule** — `SubstitutionExpand` — Roots within the same diminished-seventh chord may substitute. (Chapter 27, p. 131.)
- **Diminished Scale Half-Step Rule for Dominant Chords** — `ColorToneRequire` — Diminished scale a half-step above the dominant supplies ♭9/+9/+11/13. One scale serves four dominants. (Chapter 27, pp. 130–131.)
- **Lydian Augmented Scale Two-Position Deployment** — `SubstitutionExpand` — Two distinct root-alignment positions over dominant sevenths. (Chapter 33 summary, pp. 145–146.)
- **Chromatic Non-Harmonic Tone Insertion** — `NCTHarmonization` — Chromatic passing tones fill whole-step intervals while preserving diminished character. (Chapter 27, p. 130.)
- **Polychord Upper Structure Selection** — `SubstitutionExpand` — Upper triad from chord substitutions or from 9/11/13 extensions, preserving bottom function. (Chapter 25, p. 121.)

---

### Turnaround Chord-Type Permutation System

A compact, self-contained harmonic device for solving excessive tonic repetition at phrase endings. Defined by a single distinguishing principle: the root remains stationary while the chord quality and harmonic function change across successive chords. Explicitly contrasted in the book against cycle-of-fifths and chromatic-descent progressions, where root motion drives harmonic change; in a turnaround, quality variation alone generates harmonic movement. Begins with a tonic chord (about two beats) and ends with V7 or a flat-II7/flat-IIM7 dominant substitute.

**Members:**
- Tonic Major Seventh (IM7)
- Minor Seventh Quality on Same Root
- Dominant Seventh / Dominant Substitute Quality

**Traversal Rules:**

- **Stationary-Root Chord-Type Permutation** — `_pending:stationary-root-permutation` — Root held while quality and function change. (Chapter 23 summary, p. 115.)

**Modification Rules:**

- **Turnaround Endpoint Constraint** — `_pending:turnaround-endpoint` — Begin with tonic (~2 beats), end with V7 or flat-II7/flat-IIM7. (Chapter 25 summary, p. 118.)

---

## Pending Work

The following `_pending:<kebab>` engine payload kinds appear in the systems draft. Each signals a rule fully documented from the source but not yet assigned a finalized engine kind in the current schema vocabulary:

| `_pending` kind | What it signals |
|---|---|
| `_pending:mandatory-transposition` | A standing pedagogical mandate that every pattern must be executed in all twelve keys before the work is considered complete. A practice-completion constraint, not a pitch-class navigation rule. |
| `_pending:formulaic-extraction` | The foundational generative operation: chord = parent mode + scale-degree formula. Operates at the chord-construction layer, distinct from substitution, color-tone, or family-coherence. |
| `_pending:extension-collapse` | Upper extensions (9, 11, 13) treated as enharmonically equivalent to lower scale degrees (2, 4, 6); a notational/equivalence rule. |
| `_pending:pattern-recycling-extension` | A pedagogical economy constraint at the pattern-generation layer: short-form patterns are reused and extended into longer progressions. |
| `_pending:stationary-root-permutation` | A traversal kind unique to the turnaround system: root motion suppressed while chord quality cycles. |
| `_pending:turnaround-endpoint` | A structural boundary constraint on the turnaround device: fixed starting and ending quality classes. |

---

## Provenance Notes

All systems and rules derive exclusively from the book-level distillation and the structured systems-draft JSON. Direct quote excerpts trace to specific page numbers in *Patterns for Jazz* (1970) and are cited by chapter and page throughout. No content has been invented outside the supplied summaries and quote files.

**Chapters that did not yield a system (notation-only, no load-bearing prose):**

- Chapter 2 — Major Sixth Chords
- Chapter 10 — Mixolydian Mode (Dominant Scale)
- Chapter 24 — Altered Ninth Chords
- Chapter 26 — Polychords for Diminished Scale
- Chapter 29 — Major Scale in Fourths
- Chapter 30 — Digital Pattern on Major Scale

**Chapters subsumed into existing systems without generating new systems:**

- Chapter 6 (Major Scale Intervals) and Chapter 8 (Diatonic Chords) — covered by Modal Derivation System's formulaic extraction and family-coherence rules.
- Chapter 31 (Harmonic Minor Scale) and Chapter 32 (More on the Whole-tone Scale) — focus on fourths-in-improvisation as a practice technique built on existing scale sources and all-keys directive.
- Chapter 34 (Interval Studies) — chromatic extension of directional-alternation traversal.
- Chapter 35 (Chromatic Scale) — augmented-triad and diminished-seventh transposition cases captured by Four-Collection Augmented Scale Traversal.
