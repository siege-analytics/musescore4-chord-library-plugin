---
run_id: 2026-05-28T15-05-20-greene-single-note-soloing-vol-1
stage: s4
source_pdf: Greene, Ted - Jazz Guitar Single Note Soloing, Vol 1 (1992).pdf
model: claude-sonnet
extracted_at: 2026-05-29T06:47:40+00:00
schema_version: 0.1
---

# Jazz Guitar Single Note Soloing, Vol. 1 — Statement of Outputs

## Overview

Ted Greene's *Jazz Guitar Single Note Soloing, Vol. 1* (1992) is a systematic method for learning jazz single-note soloing on guitar, built from first principles and organized around three governing questions: what notes sound good over a chord progression, where those notes live on the instrument, and how to play them interestingly. The method's conceptual engine is the chord-scale pairing framework introduced in Chapter 1 and extended across every subsequent chapter. The major scale serves as the universal reference system; every other scale in the book is defined as a numeric transformation of it (e.g., the Lydian scale = major with a raised 4th; the Dominant 7th scale = major with a lowered 7th). Chords are expressed as numeric formulas derived from the same reference (major 7th = 1, 3, 5, 7; minor 7th = 1, b3, 5, b7), giving the student a single derivational system rather than isolated memorization tasks. The operational concept binding scales to chords — that a chord "takes" a scale when that scale sounds good over it — is stated in Chapter 1 and drives every chord-scale assignment that follows.

The book organizes its material around named chord groups and their paired scales, introduced in a deliberate pedagogical sequence. Chapter 1 establishes the first rule (major Group 1 chords take the major or Lydian scale); Chapter 3 introduces the Dominant 7th scale and the swing-feel framework; Chapter 4 extends dominant harmony into Group-1 and Group-2 families with the run-synchronization rule; Chapter 5 completes the dominant taxonomy with the Overtone/Lydian Dominant and the three Altered Dominant types (Types 1, 2, 3), defining Group 4 dominant chords and naming polytonality as a compositional device; Chapters 6 and 7 realize the entire framework through notated exercises across successive fingerboard areas and extended register. A standing prohibition against the relative-major transposition shortcut for both Dominant 7th and Minor 7th scales runs throughout the book, anchoring all scale thinking to root-based rather than positional reasoning.

Greene's characteristic pedagogical moves recur across chapters: the chord formula system as a single derivational reference; the "combining scales in one position" technique that keeps the player within a 5-6 fret fingerboard area across chord changes; fingerboard visualization named as the single most important internalization practice; register treated as a primary compositional variable governing extension color; and the "package deal" presentation of the three altered dominant types side by side in the same position so their color differences can be absorbed comparatively. The technical/rhythmic layer — swing and straight 8th-note practice, double-timing, hammer-ons constrained to scale tones, and the trill reframed as decoration of a held note rather than substitution — is introduced in Chapter 3 and governs every subsequent exercise.

## Systems

### Chord-Scale Pairing System

The central system of the book. Every chord type belongs to a named group, and each group is paired with one or more scales derived from the major scale as universal reference. A chord "takes" a scale when that scale sounds good over it; any chord containing only chord tones of a given scale may use that scale.

**Members:** Major Group 1 Chords; Major Scale; Lydian Scale; Group 1 Dominant Chords; Group 2 Dominant Chords; Dominant 7th Scale; Minor 7th Chord; Minor 7th Scale; Group 3 Dominant Chords; Overtone Dominant Scale (Lydian Dominant); Group 4 Dominant Chords; Altered Dominant Scale Types 1, 2, and 3.

**Traversal Rules:**
- **Run-to-Dominant-Group Synchronization** — `FamilyCoherence`: Runs containing the 3rd suit Group 1 dominants; runs containing the 11th suit Group 2 dominants; both/neither work over either group. (Chapter 4 summary; ch04.md, p. 59)
- **Root-Based Scale Internalization** — `_pending:root-anchor-prohibition`: Dominant 7th and Minor 7th scales must be internalized from their own root; the relative-major shortcut is prohibited. (Chapter 3 summary, p. 43; Chapter 4 summary, p. 69)
- **Overtone Dominant Categorical Boundary** — `FamilyCoherence`: The Overtone Dominant scale is categorically excluded from the altered dominant family; its #11 reflects the natural overtone series, not chromatic alteration. (Chapter 5 summary, p. 94)
- **Altered Dominant Package-Deal Positional Learning** — `PositionContinuity`: All three altered dominant types are presented juxtaposed in the same fingerboard position so their color differences can be absorbed comparatively. (Chapter 5 summary, p. 96)

**Modification Rules:**
- **Scale-to-Chord Compatibility Rule** — `FamilyCoherence`: Any chord containing some combination of (and only) the chord tones of a given scale can take that scale. (Chapter 3 summary, p. 41)
- **Altered Dominant Tone Requirement** — `ColorToneRequire`: A scale qualifies as an altered dominant only if it contains at least one of b9, #9, b5, or #5(b13); chords built from those tones are Group 4. (Chapter 5 summary, p. 94)
- **Type 3 Altered Dominant Chord Substitution** — `SubstitutionExpand`: A7+ may substitute for A7#9+ and D49 may substitute for D6/9 across all Type 3 pages. (Chapter 6 summary, p. 105)
- **#9 Substitution or Addition Rule** — `SubstitutionExpand`: The altered #9 may substitute for or be played alongside the natural 9. (Chapter 7 summary, p. 131)
- **Chord Form Visualization Prerequisite** — `_pending:visualization-prerequisite`: When a player cannot visualize scalar runs, return to the chord forms for that position first. (Chapter 5 summary, p. 99)
- **Lydian Dominant Upper-Structure Triad (Polytonality)** — `ColorToneRequire`: The 9, #11, and 13 of the Lydian Dominant scale form a major triad rooted a whole step above the chord root. (Chapter 5 summary, p. 83)

### Fingerboard Position and Register System

Governs physical navigation. Position continuity keeps the player in a 5-6 fret window across chord changes. Fingerboard visualization is the single most important internalization practice. Register is a primary compositional variable.

**Members:** Fingerboard Area (5-6 Fret Window); Lower Register; Upper / Mid Register; Alternate String Set.

**Traversal Rules:**
- **Stay-in-Position Multi-Chord Rule** — `PositionContinuity`: Know enough positions of each scale to remain within a 5-6 fret area across all chords in a progression. (Chapter 4 summary, p. 60)
- **Alternate Position Practice** — `PositionContinuity`: Each set of runs should also be fingered in at least one alternate position. (Chapter 6 summary, p. 109)
- **Octave-Higher Same-Position Practice** — `PositionContinuity`: Every pattern should be tried an octave higher within the same fingerboard position. (Chapter 7 summary, p. 120)
- **Arpeggio String-Set Flexibility** — `StringSetTransition`: Arpeggio tones may be voiced on alternate string sets (e.g., 5th and 4th strings). (Chapter 6 summary, p. 107)

**Modification Rules:**
- **Register Governs Extension Color** — `_pending:register-color-assignment`: The perceptual weight of b7 and 9 is determined by register; these tones "come alive" in higher registers. (Chapter 4 summary, p. 58)
- **Fingerboard Visualization as Primary Practice** — `_pending:visualization-prerequisite`: Visualizing the notes on the fingerboard is the single most important internalization technique. (Chapter 4 summary, p. 67)
- **Type 3 Area-4A Structural Boundary** — `_pending:instrument-boundary`: No Type 3 altered dominant material exists for fingerboard Area 4A; instrument-specific constraint. (Chapter 7 summary, p. 118)

### Rhythmic and Articulation System

Governs time and texture. The 8th note is jazz's baseline rhythmic unit at medium/fast tempos. Swing feel is straight 8ths played as triplet subdivisions. Double-timing adds a 16th-note layer. Slurring (hammer-ons, pull-offs, trills) is introduced with the trill reframed as decoration of a held note rather than substitution. Every 8th-note pattern must be practiced both swing and straight; clean playing must precede tempo increases.

**Members:** Straight 8th Notes; Swing 8th Notes (Jazz 8ths); Double-Timing (16th Notes); Hammer-On; Pull-Off; Trill.

**Traversal Rules:**
- **8th Note as Primary Jazz Unit** — `_pending:rhythmic-density-baseline`: The eighth note is jazz's normal rhythmic unit at medium and fast tempos. (Chapter 3 summary, p. 39)
- **Both-Feels Practice Rule** — `TextureCycle`: Every 8th-note run must be practiced in both swing and straight feel. (Chapter 3 summary, p. 39)
- **Clean Playing Before Tempo Increase** — `_pending:tempo-gate`: Tempo may only increase after clean execution is achieved. (Chapter 3 summary, p. 40)
- **Trill Placement on Strong Beat** — `_pending:articulation-placement`: The trill is more commonly placed on the strong part of the beat. (Chapter 3 summary, p. 41)

**Modification Rules:**
- **Trill as Decoration, Not Substitution** — `_pending:articulation-reframe`: A trill does not replace the decorated note; the underlying note is held and ornamented. (Chapter 3 summary, p. 41)
- **Hammer-On Scale-Tone Constraint** — `NCTHarmonization`: At this stage, hammer-on targets must be drawn from the current scale. (Chapter 3 summary, p. 41)
- **Double-Timing as Texture Escalation** — `TextureCycle`: Double-timing (16th notes) is an advanced texture layer above the baseline 8th-note texture. (Chapter 3 summary, p. 40)

## Pending Work

The following `_pending:` engine_payload kinds signal rule semantics not yet covered by a named engine kind:

- **`_pending:root-anchor-prohibition`** — A negative constraint rule prohibiting a specific cognitive shortcut (the relative-major transposition reframe). No existing kind covers prohibition-by-shortcut-path.
- **`_pending:visualization-prerequisite`** — A prerequisite gate: chord-form visualization must precede scalar fluency in a position. Used in both the Chord-Scale Pairing and Fingerboard Position systems.
- **`_pending:register-color-assignment`** — A rule mapping extension tones to perceptual quality categories (weighty bass vs. spicy mid-range) as a function of register, not note identity.
- **`_pending:instrument-boundary`** — A structural-absence rule arising from physical instrument constraints rather than music theory, blocking generation of material for specific area/type combinations.
- **`_pending:rhythmic-density-baseline`** — A baseline-setting rule establishing a default rhythmic density (8th notes) against which other densities (double-timing) are defined as escalations.
- **`_pending:tempo-gate`** — A progression gate tied to execution quality (clean playing) rather than to pitch or harmonic criteria.
- **`_pending:articulation-placement`** — A beat-position preference rule for an ornament (trill prefers strong beat), distinct from harmonic or texture rules.
- **`_pending:articulation-reframe`** — A conceptual boundary rule redefining the semantic category of an ornament (trill = decoration, not substitution).

## Provenance Notes

All content here is drawn from the book-level distillation, the per-chapter summaries (Chapters 1-7), and the systems-draft JSON derived from those sources.

- **Chapter 1** — foundational members and the operational rule (chord "takes" scale), plus the first concrete assignment (major Group 1 → major/Lydian).
- **Chapter 2** — yielded no system or new rules. The chapter summary explicitly states the chapter is composed entirely of notated exercises (major scale fingerings, arpeggios, position playing, Group-2/Group-3 major chord soloing) with no extractable load-bearing prose. Its material realizes content for Systems 1 and 2 but introduces no new rules.
- **Chapter 3** — primary source for the Rhythmic and Articulation System in its entirety, plus the Dominant 7th scale introduction and the root-based-thinking prohibition (System 1).
- **Chapter 4** — primary source for the dominant group synchronization rule, the register-color rule, the Minor 7th and Overtone Dominant scale introductions, and the stay-in-position rule (System 2).
- **Chapter 5** — primary source for the altered dominant taxonomy, the categorical boundary excluding the Overtone Dominant from the altered family, the package-deal traversal rule, the chord-form-prerequisite modification rule, and the upper-structure-triad / polytonality rule.
- **Chapters 6 and 7** — contributed practice rules (alternate position, octave-higher, arpeggio string flexibility, Type 3 chord substitution, #9 substitution, the Type 3/Area-4A structural boundary) but introduced no new theoretical systems. Both chapters are predominantly notated exercise material; their load-bearing prose is limited to standing practice directives attached to specific exercises.
