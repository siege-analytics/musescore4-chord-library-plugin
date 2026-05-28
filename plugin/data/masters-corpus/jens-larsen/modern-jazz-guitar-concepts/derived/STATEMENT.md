---
run_id: 2026-05-28T15-05-20-larsen-modern-jazz-guitar-concepts
stage: s4
source_pdf: jens-larsen-modern-jazz-guitar-concepts_compress.pdf
model: claude-sonnet
extracted_at: 2026-05-28T18:24:42+00:00
schema_version: 0.1
---

# Modern Jazz Guitar Concepts (Jens Larsen) — Statement of Outputs

## Overview

*Modern Jazz Guitar Concepts* is a pedagogical text for intermediate-to-advanced jazz guitarists that teaches improvisation as a unified harmonic and melodic system rather than a collection of licks or patterns. The book's organizing premise — stated in Chapter 1 and never abandoned — is that every arpeggio and scale choice in an improvised line must be grounded in shared tones with the underlying chord. Technique exists to serve harmony; pattern knowledge without harmonic rationale is treated as insufficient. The book proceeds cumulatively across six chapters: diatonic substitution (Chapter 1), chromatic enclosures (Chapter 2), harmonic minor on the V chord (Chapter 3), the altered scale (Chapter 4), the half-whole diminished scale (Chapter 5), and a complete solo analysis integrating all prior material (Chapter 6).

The book's pedagogical signature is isolating a small vocabulary item — one arpeggio type, one enclosure construction, one triad set — establishing its harmonic rationale through shared tones, applying it in a II–V–I or similar cadential context, and then connecting it explicitly to the broader system. This discipline is maintained throughout: Chapter 4's G#m7b5 arpeggio over Bb7alt is justified by its preservation of the guide tones F and Ab; Chapter 5's four major triads within the half-whole diminished scale are taught as upper-structure color devices rather than mechanical scale fragments; Chapter 6 closes the loop by demonstrating, bar by bar, how a complete solo draws simultaneously on diatonic substitution, chromatic enclosure, harmonic minor coloring, altered dominant tension, and diminished symmetry.

The resulting framework is layered and cross-referential. Shell voicings, guide tones, quartal/quintal harmony, chromatic enclosures, and the counterpoint rule that large intervals resolve stepwise in the opposite direction each appear in multiple chapters, reinforcing the same underlying logic across different harmonic territories. Voice-leading — by common tone, contrary motion, or encirclement — is the connective tissue throughout, and it is the criterion by which the book asks students to evaluate every melodic choice.

---

## Systems

### Harmonic Substitution Lattice

The Harmonic Substitution Lattice is the book's foundational system: a structured vocabulary of arpeggio types organized by their shared-tone relationships to underlying chord tones, with explicit rules governing which substitutions are safe, which require caution, and how to move between them across a chord progression. The core logic is that an improviser selects not the arpeggio of the chord root but the arpeggio — rooted on the chord's 3rd, 5th, or 7th — whose notes most efficiently express the chord's extensions and guide tones. This system is established completely in Chapter 1 and extended by Chapters 3, 4, 5, and 6.

**Members:** Diatonic 7th Chord Arpeggio; m7b5 on the 3rd of Dominant; Arpeggio on the 5th of Chord; Arpeggio on the 7th of Chord; Shell Voicing (Root + 3rd + 7th); Pentatonic Reframed as Extended Arpeggio; Quartal / Quintal Arpeggio; Tritone Substitute Arpeggio; Non-Diatonic Constructed Arpeggio.

**Traversal Rules:**

- **Guide-Tone Arpeggio Selection** — `FamilyCoherence`: Select the substitute arpeggio whose notes contain the chord's defining 3rd and 7th. The canonical example is selecting G#m7b5 over Bb7alt because it preserves F and Ab, the guide tones of the altered dominant. (Chapter 4 summary; page 54)
- **Shared-Tone Arpeggio Move** — `VoiceMotion`: Move to a substitute arpeggio by maximizing notes held in common with the underlying chord. (Chapter 1 summary; page 14)
- **Arpeggio Root Hierarchy (3rd > 5th > 7th)** — `SubstitutionExpand`: Prefer the arpeggio rooted on the chord's 3rd as the most versatile option; 5th- and 7th-rooted choices include progressively fewer shared tones and require more caution. (Chapter 1 summary; page 15)
- **5th-of-II Arpeggio Targets 3rd of V** — `VoiceMotion`: Arpeggiate from the 5th of the II chord to voice-lead toward the 3rd of the following V chord. (Chapter 3 summary; page 49)
- **Tritone Substitute Traversal** — `SubstitutionExpand`: Replace an altered dominant arpeggio with the arpeggio of its tritone substitute, preserving guide tones. (Chapter 4 summary; page 54)

**Modification Rules:**

- **Shell Voicing Reduction** — `DensityFloor`: Reduce any chord to root, 3rd, and 7th only to create a spare melodic skeleton. (Chapter 1 summary; page 19)
- **Pentatonic Reframe as Extended Arpeggio** — `SubstitutionExpand`: Reinterpret a pentatonic scale as a named extended arpeggio — D Minor Pentatonic becomes Dm7add11. (Chapter 1 summary; page 18)
- **Non-Diatonic Arpeggio Construction by Scale Rerooting** — `SubstitutionExpand`: Derive non-diatonic arpeggios (e.g., Bbm7b5, C7#5) by reading scale tones from an alternate root degree within the parent scale. (Chapter 3 summary; page 50)
- **Chord Tone Omission for Open Sound** — `OmissionAllow`: Omit a defining chord tone (e.g., the 3rd of Gm7) to create an open, ambiguous line acceptable within a clear harmonic context. (Chapter 3 summary; page 52)
- **Sus4 Tension Avoidance over Dominant** — `ColorToneRequire`: Avoid the 11th (C over G7) unless a sus4 color is explicitly desired. (Chapter 1 summary; page 23)

---

### Chromatic Enclosure System

The Chromatic Enclosure System governs how non-chord chromatic and diatonic passing tones are organized around target chord tones to produce characteristic bebop and hardbop melodic language. The foundational constraint of the system — stated in Chapter 2 as a rule, not a suggestion — is that chromatic passing notes belong on off-beats, with strong chord tones landing on the beat. Two- and four-note enclosure constructions are the primary members; resolution placement and diatonic gap-fill are the modification mechanisms. Chapter 2 introduces the full system; Chapters 3, 4, and 6 apply it in progressively complex harmonic contexts.

**Members:** Two-Note Enclosure; Four-Note Enclosure; Strong-Beat Resolution Placement; Off-Beat Displacement (Metheny Style); Diatonic Note Substitution for Missing Half-Step.

**Traversal Rules:**

- **Chromatic Notes on Off-Beats** — `_pending:rhythmic-placement-constraint`: Place all chromatic passing notes on off-beats, keeping strong chord tones on the beat. Stated as a foundational hardbop/bebop constraint. (Chapter 2 summary; page 29)
- **Enclosure Must Target Chord / Scale Tone** — `FamilyCoherence`: Every enclosure must resolve to a chord or scale tone; enclosures floating free of harmonic targets are explicitly forbidden. (Chapter 2 summary; page 42)
- **Beat-2 Enclosure Displacement** — `_pending:rhythmic-placement-constraint`: Place an enclosure on beat 2 so it resolves on beat 4, producing a Metheny-esque unresolved sound. (Chapter 2 summary; page 41)
- **Legato Technique for Chromatic Softening** — `_pending:articulation-rule`: Use hammer-ons, pull-offs, and slides so chromatic passing notes remain soft while scale tones are accented. (Chapter 2 summary; page 29)

**Modification Rules:**

- **Diatonic Gap Fill When Half-Step Absent** — `NCTHarmonization`: When a chromatic half-step gap does not exist between two enclosure notes, substitute the diatonic note above. (Chapter 2 summary; page 37)
- **Four-Note Enclosure: Suspension vs. Tension-Pull** — `_pending:enclosure-function-select`: Deploy a four-note enclosure either as a suspension device preceding a chord tone, or as a tension-and-pull device driving toward resolution. (Chapter 2 summary; page 39)

---

### Diminished Symmetry Triad System

The Diminished Symmetry Triad System exploits the half-whole diminished scale's inherent minor-third symmetry to generate four embedded major triads (F, Ab, B, D) and deploy them as upper-structure melodic material over dominant 7th chords, particularly the 13b9 voicing. Chapter 5's pedagogical key move is teaching these triads through positional cycling and neck-crossing exercises rather than scalar runs, leveraging the symmetry to reduce learning load — one shape, rotated by minor thirds, yields all four positions. Chapter 6 extends the system with specific triad-pair selections for targeted harmonic colors and introduces encirclement as a transition device between triads.

**Members:** F Major Triad (root upper-structure); Ab Major Triad; B Major Triad; D Major Triad; Triad Inversions (Root, 1st, 2nd).

**Traversal Rules:**

- **Minor-Third Symmetry Rotation** — `SymmetryMovement`: Transpose any triad shape or arpeggio by minor thirds to access all four positions within the diminished scale. (Chapter 5 summary; page 65)
- **Common-Tone Triad Chaining** — `VoiceMotion`: Connect consecutive triads by linking shared top or bottom notes across the triad boundary. (Chapter 6 summary; page 74)
- **Encirclement as Triad-to-Triad Transition** — `VoiceMotion`: Use the last two notes of one triad to encircle the first note of the next. (Chapter 6 summary; page 74)
- **Positional Cycling Before Neck Cross** — `PositionContinuity`: Cycle through all four triad inversions in a single neck position before crossing to the next position. (Chapter 5 summary; page 68)

**Modification Rules:**

- **Color-Tone Triad Pair Selection** — `ColorToneRequire`: Select the Ab+D triad pair to express b9+#9+13 color over F7; use the B+Ab pair for #11+b9+#9 color. (Chapter 5 summary; page 70; Chapter 6 summary; page 77)
- **Root-Position Triad Omission for Colour** — `OmissionAllow`: Omit the F major triad (root upper-structure) because it adds no harmonic color over F7. (Chapter 6 summary; page 74)
- **Altered-Diminished Bridge via B Major Triad** — `SubstitutionExpand`: Use the B major triad to bridge from diminished to altered territory, since it is shared by both the half-whole diminished scale and the altered scale. (Chapter 5 summary; page 72)

---

### Melodic Line Construction System

The Melodic Line Construction System is the procedural envelope that assembles the other three systems into complete improvised lines. Its members are named melodic gestures: the master's signature ascending-arpeggio-plus-descending-scale shape, the Coltrane 1-2-3-5 pattern (and its minor variant 1-b3-4-5), motif repetition with harmonic alteration, the large-interval counterpoint rule, and rhythmic subdivision variation. Traversal rules govern how one gesture connects to the next; modification rules govern rhythmic embellishment, scale-tone interpolation, and motivic reshaping across chord changes. It is introduced piecemeal across Chapters 1–4 and synthesized in Chapter 6's bar-by-bar solo analysis.

**Members:** Ascending Arpeggio + Descending Scale; Coltrane 1-2-3-5 Pattern (and reverse); Motif Repeat with Alteration; Large-Interval Stepwise Resolution; Triad in 1-3-5 Sequence / Quartal Pattern; Scale-Tone Interpolation in Arpeggio; Rhythmic Subdivision Variation.

**Traversal Rules:**

- **Target-Note Approach** — `_pending:target-note-approach`: Organize the line by working backward from a specific chord tone to land on the next strong beat. (Chapter 3 summary; page 48)
- **Motif Sequencing Across Chord Changes** — `_pending:motivic-sequencing`: Carry a rhythmic or intervallic motif across a chord change by restating it on the new harmony's arpeggio. (Chapter 3 summary; page 48)
- **Counterpoint Large-Interval Stepwise Resolution** — `VoiceMotion`: After a large ascending interval, resolve the line stepwise in the opposite (descending) direction. (Chapter 1 summary; page 21; Chapter 6 summary; page 76)
- **Harmonic Minor Dominant Pull** — `NCTHarmonization`: Over the V chord, apply harmonic minor material to create a pull toward the next tonic chord. (Chapter 6 summary; page 82)

**Modification Rules:**

- **Melodic Repeat with Slight Alteration to Fit New Harmony** — `_pending:motivic-alteration`: Restate a melodic phrase on a new chord, changing only one or two notes to align with the new harmony. (Chapter 6 summary; page 82)
- **Rhythmic Subdivision Embellishment** — `TextureCycle`: Introduce triplet or sixteenth-note subdivisions within an eighth-note arpeggio line to vary phrasing and imply unwritten passing chords. (Chapter 4 summary; page 59)
- **Scale-Tone Interpolation to Avoid Predictability** — `NCTHarmonization`: Add scale tones between arpeggio notes while ensuring chord tones still land on the beat. (Chapter 6 summary; page 76)
- **Coltrane Pattern Minor Variant (1-b3-4-5)** — `_pending:pattern-variant-select`: On minor chords, apply the 1-b3-4-5 variant of the Coltrane pattern; the major-chord variant uses 1-2-3-5. (Chapter 1 summary; pages 17, 24)

---

## Pending Work

The following `_pending:` engine payload kinds appear in the systems-draft. Each signals that the concept has a clear textual basis in the source material but has not yet been mapped to an existing engine kind — a new kind, or a refined specification of an existing one, is required before these rules can be executed by the engine.

- **`_pending:rhythmic-placement-constraint`** — Signals a rule that constrains *where in the rhythmic grid* a note or gesture must fall. Appears twice in the Chromatic Enclosure System: once for the foundational hardbop rule placing chromatic notes on off-beats, and once for the beat-2 enclosure displacement producing Metheny-style unresolved phrasing. Neither `VoiceMotion` nor `FamilyCoherence` captures metric placement; a dedicated rhythmic-grid constraint kind is needed.
- **`_pending:articulation-rule`** — Signals a rule governing *how* a note is physically produced (hammer-on, pull-off, slide) rather than *which* note is selected. Appears in the Chromatic Enclosure System for the legato technique that softens chromatic passing notes. This is a performance/articulation constraint with no current engine-kind analog.
- **`_pending:enclosure-function-select`** — Signals a binary-mode selection rule: given a four-note enclosure, the improviser must choose between deploying it as a suspension device or as a tension-and-pull device. Appears in the Chromatic Enclosure System. Functional/intentional rather than purely harmonic.
- **`_pending:target-note-approach`** — Signals a backward-planning traversal rule: identify a destination chord tone first, then construct the approach. Appears in the Melodic Line Construction System. Goal-directed rather than generative.
- **`_pending:motivic-sequencing`** — Signals a cross-barline gesture-replication rule: carry a rhythmic/intervallic cell across a chord change onto a new harmonic arpeggio. Distinct from `_pending:motivic-alteration` in that the motif is transplanted unchanged except for harmonic mapping. Appears in the Melodic Line Construction System.
- **`_pending:motivic-alteration`** — Signals a restatement-with-minimal-change rule: replay a phrase on a new chord, modifying only the notes required for harmonic alignment. Related to `_pending:motivic-sequencing` but distinguished by the intent to preserve perceptual identity across the alteration. Appears in the Melodic Line Construction System.
- **`_pending:pattern-variant-select`** — Signals a chord-quality-conditional selection rule: choose the major variant (1-2-3-5) or the minor variant (1-b3-4-5) of the Coltrane pattern based on chord quality at the moment of application. Appears in the Melodic Line Construction System.

---

## Provenance Notes

**Systems-draft sourcing:** All four systems are derived from the book-level distillation and the six per-chapter summaries. No content has been introduced from outside those sources.

- **Harmonic Substitution Lattice** — Draws primarily from Chapter 1 (foundational logic, shell voicings, pentatonic reframe, sus4 avoidance) with extensions from Chapter 3 (non-diatonic construction, chord-tone omission), Chapter 4 (guide-tone selection, tritone substitute), and Chapter 5 (quartal/quintal arpeggio confirmed).
- **Chromatic Enclosure System** — Draws entirely from Chapter 2, the dedicated enclosure chapter. Chapters 3, 4, and 6 confirm continued application but add no new enclosure constructions.
- **Diminished Symmetry Triad System** — Draws primarily from Chapter 5 (scale formula, triad isolation, symmetry rotation, positional cycling) with substantive additions from Chapter 6 (common-tone chaining, encirclement, triad-pair color selection, F major omission).
- **Melodic Line Construction System** — Draws from Chapters 1, 3, 4, and 6. Chapter 1 supplies the signature ascending-arpeggio/descending-scale shape, the Coltrane patterns, and the counterpoint rule. Chapter 3 introduces the motif-based vs. target-note distinction. Chapter 4 provides rhythmic subdivision embellishment. Chapter 6 provides motif repetition with alteration, scale-tone interpolation, and harmonic minor dominant pull.

**Chapters not yielding independent systems:**

- **Chapter 6** does not yield a standalone system because it is explicitly a synthesis chapter — its bar-by-bar solo analysis applies all four systems rather than introducing new harmonic or melodic territory. Its specific contributions are incorporated as traversal and modification rules in the three systems they extend.
- **Chapter 3** (Harmonic Minor on the V) does not yield a standalone system because its harmonic minor material functions as an extension of the Harmonic Substitution Lattice (non-diatonic arpeggio construction, 5th-of-II targeting) and the Melodic Line Construction System (harmonic minor dominant pull, motif-based approach), not as an independent organizing framework. The book treats harmonic minor as a color within the existing substitution logic.
