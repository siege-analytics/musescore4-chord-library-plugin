---
run_id: 2026-05-28T15-05-20-greene-modern-chord-progressions
stage: s4
source_pdf: Modern Chord Progressions - Jazz And Classical Voicings For Guitar - Ted Greene.pdf
model: claude-sonnet
extracted_at: 2026-05-29T05:23:05+00:00
schema_version: 0.1
---

# Modern Chord Progressions: Jazz & Classical Voicings for Guitar — Statement of Outputs

## Overview

*Modern Chord Progressions: Jazz & Classical Voicings for Guitar* by Ted Greene is a progressive guitar method that moves from physical and notational prerequisites through increasingly complex harmonic formulas, culminating in the chromatic and altered-dominant language of jazz and classical voice leading. The book's organizing ambition is to equip the guitarist with a systematic, fingerboard-wide command of harmony — not as abstract theory, but as a set of reproducible physical and conceptual operations that can be deployed across every position on the neck in every key. Its authority rests on the conviction that theory, ear judgment, and physical technique are inseparable: a chord voicing is only as good as its cleanliness of execution, its register suitability to the ear, and its correct naming in context.

Greene structures the method in three conceptual layers. The first layer (Chapters 1-3) installs the technical and cognitive operating system: right-hand mechanics, diagram-reading conventions, fingerboard geography via five position areas, and the doctrine of chord homonyms. The second layer (Chapters 4-6) introduces diatonic logic — harmonic formulas, extensions, diatonic chord scales, stepwise voice leading, and scalewise root and bass movements — giving the player the tools to construct and navigate progressions systematically. The third layer (Chapters 7-11) applies those tools to the canonical harmonic formulas of jazz and popular music, one formula per chapter, with exhaustive voicing variations across the full fingerboard. Chapter 12 is a bibliography with no instructional content.

The method's deepest characteristic move is treating ear judgment as the final arbiter at every decision point: which register to use, whether to omit a chord tone, when to introduce altered dominants, and how aggressively to pursue a particular cycle or formula. Theory provides the vocabulary and the navigation rules; the ear provides the veto. This makes the method at once rigorously systematic and deliberately open-ended — a system of rules that culminates in personal taste as the governing principle.

---

## Systems

### Harmonic Formula Traversal System

The central system of the book. Greene organizes the fingerboard as a set of named harmonic formulas — I iii IV V, I vi ii V, iii vi ii V, the diatonic cycle of 4ths, iii7 VI7 ii7 V7, iii7 vi7 II7 V7, and III7 VI7 II7 V7 — each treated as a reusable compositional and improvisational template. These formulas are labeled with triad-level Roman numerals even when extended voicings are employed, establishing a consistent shorthand that allows the player to track harmonic function independently of voicing density. The traversal logic is built on two complementary movement principles: stepwise diatonic voice leading (each voice moves to the next scale degree of the same name) and cycle-of-4ths root motion (each root sits a diatonic fourth above the previous). String transference is the guitar-specific mechanism that extends these movements beyond the physical range of a single string group. Every formula is to be explored across the entire fingerboard in multiple keys; the ear governs register decisions, and physical difficulty is treated as a dexterity-training opportunity rather than a reason to discard a progression.

**Members:**
- **I vi ii V (and iii vi ii V)** — Foundational diatonic turnaround; most common opener formula. *(Chapter 7 summary)*
- **I iii IV V (I)** — First formula introduced; teaches extensions and the triad-symbol convention. *(Chapter 4 summary)*
- **Diatonic Chord Scale** — Ordered sequence of chords built exclusively from major-scale notes. *(Chapter 5 summary)*
- **Diatonic Cycle of 4ths (I IV vii° iii vi ii V I)** — Each root a fourth higher than the previous; reducible to two alternating descending chord scales. *(Chapter 8 summary)*
- **iii7 VI7 ii7 V7 (and I VI7 ii7 V7)** — Introduction of chromatic dominant substitution. *(Chapter 9 summary)*
- **iii7 vi7 II7 V7 (and I vi7 II7 V7)** — Derived by raising the 3rd of ii7. *(Chapter 10 summary)*
- **III7 VI7 II7 V7** — Fully chromaticized formula using altered dominant 7th chords. *(Chapter 11 summary)*

**Traversal Rules:**

1. **Stepwise Diatonic Voice Motion** — Each voice moves up or down to the next scale degree of the same name. Engine payload kind: `VoiceMotion`. *(Chapter 5 summary; ch05.md quotes)*
2. **Cycle-of-4ths Root Motion** — Each root a diatonic fourth higher; cycle reducible to two alternating descending chord scales. Engine payload kind: `_pending:cycle-root-motion`. *(Chapter 8 summary; ch08.md quotes)*
3. **String Transference — Moving to Higher Strings** — Relocate voicing to higher string group with 2nd-string fret correction, then drop five frets. Engine payload kind: `StringSetTransition`. *(Chapter 5 summary; ch05.md quotes)*
4. **String Transference — Moving to Lower Strings** — Relocate voicing to lower string group with 3rd-string fret correction, then raise five frets. Engine payload kind: `StringSetTransition`. *(Chapter 5 summary; ch05.md quotes)*
5. **Whole-Fingerboard Exploration via Key Transposition** — Explore every formula across the entire fingerboard in multiple keys. Engine payload kind: `PositionContinuity`. *(Chapter 7 summary; Chapter 8 summary)*
6. **V7 to I Resolution (Standing Cadential Rule)** — V7 chords must periodically resolve to I; rule recurs across Chapters 7, 9, 10, 11. Engine payload kind: `_pending:cadential-resolution`. *(Chapter 7, 9, 10, 11 summaries)*
7. **Bidirectional Chord Scale Practice** — Every chord scale practiced descending as well as ascending. Engine payload kind: `_pending:bidirectional-scale-traversal`. *(Chapter 6 summary; ch06.md quotes)*
8. **Cycle Start-Degree Flexibility** — Cycles and chord-scale patterns may begin on any scale degree. Engine payload kind: `_pending:cycle-root-motion`. *(Chapter 5 summary; Chapter 8 summary)*

**Modification Rules:**

1. **Omission of 5th or Root Allowed** — Voicings may omit the 5th or root; ear-appeal takes priority over completeness. Engine payload kind: `OmissionAllow`. *(Chapter 3 summary; Chapter 4 summary)*
2. **Ear-Governed Register / Transposition** — Register decisions governed by ear judgment; muddy low voicings avoided. Engine payload kind: `_pending:register-ear-filter`. *(Chapter 4 summary)*
3. **Chord Scale Decoration (Delay / Moving Lines / Team Concept)** — Decorate chord scales by delaying notes, moving lines from diatonic tones, or Van Eps's team concept (alternating two intervals with separate finger groups). Engine payload kind: `TextureCycle`. *(Chapter 5 summary; ch05.md quotes)*
4. **Voicing Note Omission for Physical Playability** — Notes may be omitted or changed when physical constraints make voicing impractical. Engine payload kind: `OmissionAllow`. *(Chapter 8 summary; ch08.md quotes)*
5. **Cycle Combination to Avoid Overuse** — Combine cycle patterns rather than use a single cycle in isolation. Engine payload kind: `_pending:pattern-combination-policy`. *(Chapter 8 summary; ch08.md quotes)*

---

### Dominant Substitution Lattice System

The book's secondary system governs how minor-seventh chords are replaced with dominant-seventh chords and how those dominants are then progressively altered. The foundational rule — stated in capitals in the source text — is that any m7-type chord may be replaced with a dominant 7th according to personal taste. Greene teaches a specific derivation mechanism: raise the 3rd of a ii7 shape by one fret to produce II7; when two 3rds are present, raise the lower-pitched one, typically yielding II7#9. The same mechanism applies to converting vi7 to VI7. The system permits iii7 in place of III7 and vi7 in place of VI7 throughout the altered-dominant formula. Altered dominants — voicings incorporating #9, b9, #5, or b5 — are introduced only after the ear has been prepared with diatonic, "major scaley" sounds. A boundary condition limits the 3rd-raising mechanism: it does not apply when a iim7/11 chord has its 11th as the highest voice. The acoustic justification for why diatonic substitutions sound natural is the overtone series.

**Members:**
- **Minor Seventh Type Chord (m7)** — Diatonic minor sevenths (iii7, vi7, ii7); the source class. *(Chapter 9 summary)*
- **Dominant Seventh Type Chord — Diatonic Preparation** — Unaltered dominant sevenths used as ear-preparation step. *(Chapter 9, 11 summaries)*
- **Altered Dominant Seventh Type Chord** — Dominant 7ths with #9, b9, #5, or b5. *(Chapter 11 summary)*
- **ii as Substitute for IV (Homonym Equivalence)** — ii substitutes for IV by shared tones (F#m7 = A6). *(Chapter 5, 9 summaries)*

**Traversal Rules:**

1. **Diatonic Preparation Before Altered Dominant Introduction** — Altered chords introduced only after preparing the ear with diatonic material. Engine payload kind: `_pending:ear-preparation-sequencing`. *(Chapter 11 summary; ch11.md quotes)*

**Modification Rules:**

1. **Dominant-for-Minor Substitution (Universal Rule)** — Any m7-type chord may be replaced with a dominant 7th-type chord. Engine payload kind: `SubstitutionExpand`. *(Chapter 9 summary; ch09.md quotes)*
2. **3rd-Raising Conversion: ii7 to II7 (and II7#9)** — Raise the 3rd of ii7 by one fret to produce II7; lower of two 3rds yields II7#9. Engine payload kind: `SubstitutionExpand`. *(Chapter 10 summary; ch10.md quotes)*
3. **Soprano Exception: iim7/11 with 11th in Soprano** — 3rd-raising conversion does not apply when iim7/11's 11th is the highest voice. Engine payload kind: `_pending:conversion-boundary-condition`. *(Chapter 10 summary; ch10.md quotes)*
4. **Diatonic-for-Chromatic Substitution: iii7 for III7, vi7 for VI7** — In III7 VI7 II7 V7, iii7/vi7 may substitute for III7/VI7. Engine payload kind: `SubstitutionExpand`. *(Chapter 11 summary; ch11.md quotes)*
5. **Altered Dominant Color Tone Introduction (#9, b9, #5, b5)** — Altered voicings incorporate one of four characteristic color tones. Engine payload kind: `ColorToneRequire`. *(Chapter 9, 11 summaries)*
6. **ii Substitutes for IV (Homonym/Overtone Basis)** — ii7 substitutes for IV by shared tones; grounded in overtone series. Engine payload kind: `SubstitutionExpand`. *(Chapter 5, 9 summaries)*

---

### Fingerboard Geography and Homonym Naming System

The book's organizational meta-system and the prerequisite infrastructure that enables the other two systems. Greene partitions the fingerboard into five position areas used as spatial reference anchors for all major and minor chord forms. Within each position, chord voicings are memorized by three methods — shape-based, interval-based, and root-anchored — with experienced players combining all three eclectically. The governing concept is chord homonyms: any given physical voicing may function as multiple chords depending on harmonic context (e.g., the same shape operates as Em6, C#m7b5, or A9). Context and common sense determine naming, and mastery requires knowing every useful homonym name for each chord form. Failure to do so is explicitly identified as a source of long-term difficulty. This system was introduced across Chapters 1-3 and underlies every harmonic and navigational operation in the book.

**Members:**
- **Neck Area 1** through **Neck Area 5** — Five fingerboard zones used as positional anchors. *(Chapter 2 summary)*
- **Homonym Chord Form** — Voicing whose name depends on harmonic context. *(Chapter 3 summary)*

**Traversal Rules:**

1. **Five-Position Area Navigation** — Five neck areas serve as spatial reference anchors. Engine payload kind: `PositionContinuity`. *(Chapter 2 summary; ch02.md quotes)*

**Modification Rules:**

1. **Homonym Naming by Harmonic Context** — Harmonic context determines a chord form's correct name. Engine payload kind: `FamilyCoherence`. *(Chapter 3 summary; ch03.md quotes)*
2. **All Useful Homonym Names Must Be Known** — A player must learn every useful name for each chord form. Engine payload kind: `FamilyCoherence`. *(Chapter 3 summary; ch03.md quotes)*
3. **Eclectic Combination of Three Memorization Methods** — Players combine shape, interval, and root-anchor memorization eclectically. Engine payload kind: `_pending:memorization-method-policy`. *(Chapter 2, 3 summaries)*

---

## Pending Work

The following `_pending:` engine payload kinds appear in the systems-draft. Each signals a rule that has been identified and cited from the source text but has not yet been mapped to a finalized engine kind in the payload schema:

- **`_pending:cycle-root-motion`** — Used by *Cycle-of-4ths Root Motion* and *Cycle Start-Degree Flexibility*. Signals that cycle-based root progression (each root a diatonic fourth above the previous; patterns startable on any scale degree) requires a dedicated engine kind distinct from stepwise `VoiceMotion`. (Harmonic Formula Traversal System.)

- **`_pending:cadential-resolution`** — Used by *V7 to I Resolution (Standing Cadential Rule)*. Signals that a mandatory periodic cadential gesture (V7 resolving to I) needs its own engine kind. Recurs across Chapters 7, 9, 10, 11. (Harmonic Formula Traversal System.)

- **`_pending:bidirectional-scale-traversal`** — Used by *Bidirectional Chord Scale Practice*. Signals that descending traversal of chord scales must be explicitly enforced alongside ascending traversal; direction must be a represented axis. (Harmonic Formula Traversal System.)

- **`_pending:register-ear-filter`** — Used by *Ear-Governed Register / Transposition*. Signals a filter evaluating voicing register against an ear-quality heuristic (rejecting muddy low voicings); no existing kind covers subjective register suitability. (Harmonic Formula Traversal System.)

- **`_pending:pattern-combination-policy`** — Used by *Cycle Combination to Avoid Overuse*. Signals a meta-rule preventing any single cycle pattern from dominating without combination with other patterns. (Harmonic Formula Traversal System.)

- **`_pending:ear-preparation-sequencing`** — Used by *Diatonic Preparation Before Altered Dominant Introduction*. Signals an ordering constraint: altered dominants may not be introduced until the ear has been prepared with diatonic material. Requires a sequencing or prerequisite-state kind. (Dominant Substitution Lattice System.)

- **`_pending:conversion-boundary-condition`** — Used by *Soprano Exception: iim7/11 with 11th in Soprano*. Signals a boundary condition that blocks the 3rd-raising conversion under a specific voice-leading configuration. Requires a conditional-block or guard kind. (Dominant Substitution Lattice System.)

- **`_pending:memorization-method-policy`** — Used by *Eclectic Combination of Three Memorization Methods*. Signals a policy requiring multi-method coverage of chord-form internalization (no single method sufficient). (Fingerboard Geography and Homonym Naming System.)

---

## Provenance Notes

**What came from what:**

- The three systems are drawn entirely from the systems-draft JSON (run `2026-05-28T15-05-20-greene-modern-chord-progressions`), which was derived from the per-chapter summaries (ch01-ch12) and the book-level distillation.
- All citations trace to specific chapter summaries and the book-level distillation document. No content has been invented beyond what those sources state.
- Quote excerpts in the rule entries are drawn verbatim from the systems-draft `references[].quote_excerpt` fields, themselves extracted from the chapter quote files.

**Chapter-to-system mapping:**

| Chapter | Primary System(s) | Notes |
|---|---|---|
| 1 | Fingerboard Geography (technique prerequisites) | Right-hand technique, double stop, 5th finger principle; infrastructural — no standalone system |
| 2 | Fingerboard Geography | Five-position area framework, O notation, visual memorization |
| 3 | Fingerboard Geography | Homonym doctrine, three memorization methods, stacked-thirds chord construction |
| 4 | Harmonic Formula Traversal | I iii IV V; extensions; omission rules; ear-governed register |
| 5 | Harmonic Formula Traversal + Dominant Substitution | Diatonic chord scales; string transference; decoration; team concept; ii-for-IV substitution |
| 6 | Harmonic Formula Traversal | SWR/SWB; bidirectional practice rule. Brief chapter (6 quotes); SWB to be expanded in Volume 2 |
| 7 | Harmonic Formula Traversal | I vi ii V; fingerboard exploration; V-to-I rule (first occurrence) |
| 8 | Harmonic Formula Traversal | Diatonic cycle of 4ths; sequence concept; anti-overuse rule |
| 9 | Dominant Substitution Lattice | Universal dom-for-min rule; overtone-series justification |
| 10 | Dominant Substitution Lattice | 3rd-raising conversion; II7#9; soprano exception |
| 11 | Dominant Substitution Lattice | III7 VI7 II7 V7; altered dominants; diatonic preparation sequencing |
| 12 | *(none)* | Bibliography only; no instructional content. Empty `quotes[]` per chapter file |

**Chapters that did not yield standalone systems:**

- **Chapter 1** — Foundational physical-technique content (double stop, cleanliness, arpeggiation, 5th finger principle) is infrastructural, not a navigable system with its own traversal rules. Folded into Fingerboard Geography as context.
- **Chapter 6** — Introduced SWR and SWB but the chapter itself notes SWB will be expanded in Volume 2; contributed the bidirectional-practice rule but insufficient distinct rules for a standalone third system.
- **Chapter 12** — Reading list with no instructional content; explicitly excluded from system derivation.
