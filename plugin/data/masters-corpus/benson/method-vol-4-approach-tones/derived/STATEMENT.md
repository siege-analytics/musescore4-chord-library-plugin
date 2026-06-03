---
run_id: 2026-05-28T15-05-20-benson-vol-4-approach-tones
stage: s4
source_pdf: Benson, George - The George Benson Method, Vol 4 (Approach Tones, Dorian, Mixolydian & Harmonic Minor World).pdf
model: claude-sonnet
extracted_at: 2026-06-03T05:40:48+00:00
schema_version: 0.1
---

# The George Benson Method, Vol. 4 (Approach Tones, Dorian, Mixolydian & Harmonic Minor World) — Statement of Outputs

## Overview

*The George Benson Method, Vol. 4* teaches a systematic method for constructing single-line melodic improvisations over common jazz chord progressions. As the book-level distillation states, the pedagogy is organized around three interlocking layers of knowledge: a precise taxonomy of melodic decoration (target tones and approach tones), a method for generating bebop-style lines over II–V cadences using superimposed arpeggios in the Dorian and Mixolydian modes, and an extension of those same techniques into the harmonic minor sound for V7–I resolutions landing on either minor or major tonic chords. Each layer builds directly on the grammar established before it.

The methodology throughout is taxonomic before it is expressive. Every technique is first fully classified, sub-typed, and rule-bounded — and only then demonstrated in musical context. Superimposition — using arpeggios from related chords to generate lines over the target chord — is the book's signature compositional move, applied identically whether the harmonic context is Dorian, Mixolydian, or harmonic minor. A standing methodological note applies throughout: time signatures in exercises are visualization aids, not rhythmic prescriptions; the student's task is to extract melodic cells and deploy them where they sound best.

Across all three chapters the book consistently enforces several master rules: avoid notes are structurally excluded from melodic emphasis; scale choice is always subordinate to harmonic function; and chromatic devices must be applied with restraint to stay on the musical side of the line. The fretboard is consistently organized into five zones — anchored to guide chord shapes — to enforce horizontal, melodic thinking over vertical, scale-pattern thinking. Practice is directed toward extracting ideas and integrating them musically rather than executing exercises as written.

---

## Systems

### Approach Tone Taxonomy System

Chapter 1 establishes the foundational grammar for all melodic decoration in the method. Target tones — defined as either chord tones or scale tension notes — anchor every line, and avoid notes are structurally excluded from that role unless they have been absorbed into the chord itself. The three categories of approach tones (Scale Tone, Chromatic, and Enclosure) form a closed taxonomy: each category is fully enumerated into sub-types, directionally specified (ascending vs. descending), and rule-bounded (chromatic availability varies by chord type and interval distance). This system operates over the members of that taxonomy — the approach-tone sub-types — and governs how they may be selected and combined to ornament any target tone. The characteristic pedagogical move is exhaustive enumeration: every sub-type receives a precise definition, directional specification, and mechanical boundary. (Chapter 1 summary; ch01.md quotes.)

**Members:**
- **Chord Target Tone** (`target-tone-chord`) — A chord tone used as the structural anchor of a melodic phrase.
- **Scale Target Tone / tension note** (`target-tone-scale`) — A scale tension note used as a structural anchor; avoid notes are explicitly excluded.
- **Simple Scale Tone Approach** (`scale-tone-approach-simple`) — One diatonic step immediately before (ascending) or after (descending) the target tone.
- **Double Scale Tone Approach** (`scale-tone-approach-double`) — Two diatonic steps leading into or away from the target tone.
- **Triple Scale Tone Approach** (`scale-tone-approach-triple`) — Three diatonic steps leading into or away from the target tone.
- **Quadruple Scale Tone Approach** (`scale-tone-approach-quadruple`) — Four diatonic steps leading into or away from the target tone.
- **Simple Chromatic Approach** (`chromatic-approach-simple`) — One half-step ascending or descending into the target tone; uniquely available across all chord types.
- **Double Chromatic Approach** (`chromatic-approach-double`) — Two consecutive half-steps approaching the target tone.
- **Triple Chromatic Approach** (`chromatic-approach-triple`) — Three consecutive half-steps approaching the target tone.
- **Mixed Chromatic Approach** (`chromatic-approach-mixed`) — A combination of chromatic and diatonic half-steps approaching the target tone.
- **Enclosure Approach** (`enclosure-approach`) — Surrounding the target tone with notes from above and below before landing on it.

**Traversal Rules:**

- **Avoid Note Exclusion Rule** (`avoid-note-exclusion`) — Avoid notes are prohibited as target tones in all contexts except when the avoid note has been absorbed into the chord itself. Engine payload kind: `_pending:avoid-note-gate`. (Chapter 1 summary; ch01.md: *"we can only use chord tones or chord tension notes as target tones, but not avoid notes"*, p. 1.)

- **Chord-Dependent Chromatic Approach Selection** (`chromatic-chord-dependent-selection`) — The available sub-types of chromatic approach vary by chord type because interval distances differ across chord families. Engine payload kind: `_pending:chord-conditioned-approach-filter`. (Chapter 1 summary; ch01.md: *"depending on the chord, the possibilities of chromatic approaches can be different"*, p. 5.)

- **Ascending vs. Descending Scale Tone Direction** (`scale-tone-direction-rule`) — Notes immediately before the target tone are Ascending Scale Tone Approach; notes immediately after are Descending Scale Tone Approach. Engine payload kind: `VoiceMotion`. (Chapter 1 summary; ch01.md: *"Notes used immediately before the target tone are called Ascending Scale Tone Approach"*, p. 3.)

**Modification Rules:**

- **Chromatic Approach Restraint Rule** (`chromatic-restraint-rule`) — Chromatic approaches must be applied with taste because the boundary between musical and non-musical melody is very thin. Engine payload kind: `_pending:quality-gate-chromatic`. (Chapter 1 summary; ch01.md: *"the 'borderline' between building a beautiful melody or a non-musical melody is very thin"*, p. 5.)

---

### II-V Superimposition System (Dorian / Mixolydian)

Chapter 2 translates the approach-tone grammar into a generative system for constructing bebop single lines over the II–V cadence, explicitly tracing the method to Charlie Parker and Dizzy Gillespie. The core move is superimposition: tetrads and triads drawn from the parent major scale are chained over IIm7 and V7 chords using an eight-option arpeggio-connection taxonomy (Options A–H). The fretboard is divided into five key-relative zones and horizontal zone-to-zone thinking is enforced over vertical scale-shape thinking. A signature modification is adding the major 7th as a leading tone to the Dorian scale, which creates the illusion of dominant resolution over a minor chord and unlocks the recycling of I-chord and IV-chord major-7th arpeggio lines as Dorian vocabulary. An explicit avoid-note rule governs the dominant side: the 4th (C over G7) is forbidden and must be replaced by emphasis on the 3rd (B). Scales are treated as fretboard maps rather than melodies; authentic lines emerge from mixing scales, arpeggios, and chromatic tones. (Chapter 2 summary; ch02.md quotes.)

**Members:**
- **D Dorian Scale (IIm7 context)** (`dorian-scale`) — A static scale with no avoid notes, valid over any minor chord; all parent-key tetrads and triads may be superimposed over it.
- **G Mixolydian Scale (V7 context)** (`mixolydian-scale`) — The dominant side of the unified II–V vocabulary; the 4th (C) is an avoid note over a standalone G7.
- **Parent-Key Tetrads** (`parent-key-tetrads`) — The seven diatonic seventh chords (Cmaj7, Dm7, Em7, Fmaj7, G7, Am7, Bø) used as superimposed arpeggios over the IIm7.
- **Parent-Key Triads** (`parent-key-triads`) — The seven diatonic triads (C, Dm, Em, F, G, Am, B°) used as superimposed arpeggios over the IIm7.
- **Dorian Scale + Major 7th (Leading-Tone Extension)** (`dorian-with-major7`) — Dorian with an added major 7th functioning as a leading tone to the root, creating the illusion of dominant resolution over a minor chord.
- **Fretboard Zone 1** (`fretboard-zone-1`) — The zone anchored to the chord shape closest to the first fret in the given key.
- **Fretboard Zone 2** (`fretboard-zone-2`) — Second fretboard zone in key-relative ordering.
- **Fretboard Zone 3** (`fretboard-zone-3`) — Third fretboard zone in key-relative ordering.
- **Fretboard Zone 4** (`fretboard-zone-4`) — Fourth fretboard zone in key-relative ordering.
- **Fretboard Zone 5** (`fretboard-zone-5`) — Fifth fretboard zone in key-relative ordering.
- **Connection Option A** (`option-a`) — Ascending arpeggio → down to next scale tone → ascending arpeggio.
- **Connection Option B** (`option-b`) — Ascending arpeggio → down to next scale tone → descending arpeggio.
- **Connection Option C** (`option-c`) — Ascending arpeggio → up to next scale tone → ascending arpeggio.
- **Connection Option D** (`option-d`) — Ascending arpeggio → up to next scale tone → descending arpeggio.
- **Connection Option E** (`option-e`) — Descending arpeggio → down to next scale tone → ascending arpeggio.
- **Connection Option F** (`option-f`) — Descending arpeggio → down to next scale tone → descending arpeggio.
- **Connection Option G** (`option-g`) — Descending arpeggio → up to next scale tone → ascending arpeggio.
- **Connection Option H** (`option-h`) — Descending arpeggio → up to next scale tone → descending arpeggio.

**Traversal Rules:**

- **Horizontal Zone Connection Rule** (`horizontal-zone-connection`) — Lines are built by connecting neighboring fretboard zones using scale-tone links rather than staying within a single vertical position. Engine payload kind: `PositionContinuity`. (Chapter 2 summary; ch02.md: *"connect scale/arpeggios in different keys will help us start playing and thinking horizontally"*, p. 151.)

- **Arpeggio Connection Options A–D (Ascending Entry)** (`arpeggio-connection-options-a-d`) — Four directional combinations for linking two arpeggios via a scale-tone step, all beginning with an ascending arpeggio. Engine payload kind: `StringSetTransition`. (Chapter 2 summary; ch02.md: *"ascending arpeggio / go down to the next scale tone / ascending arpeggio"*, p. 180.)

- **Arpeggio Connection Options E–H (Descending Entry)** (`arpeggio-connection-options-e-h`) — Four directional combinations for linking two arpeggios via a scale-tone step, all beginning with a descending arpeggio. Engine payload kind: `StringSetTransition`. (Chapter 2 summary; ch02.md: *"descending arpeggio / go down to the next scale tone / ascending arpeggio"*, p. 180.)

- **Key-Dependent Zone Ordering** (`zone-key-dependent-ordering`) — The five zone shapes appear in a different order depending on the key; the first zone always begins at the chord shape closest to the first fret. Engine payload kind: `PositionContinuity`. (Chapter 2 summary; ch02.md: *"the five chord shapes related with the five zones will appear in a different order depending on the key"*, p. 150.)

- **Dorian Lines Universalize Across All Parent-Key Modes** (`dorian-universalizes-to-all-parent-modes`) — Every Dorian exercise simultaneously provides valid vocabulary for every chord mode derived from the parent major key. Engine payload kind: `FamilyCoherence`. (Chapter 2 summary; ch02.md: *"all the melodic lines in this chapter can be used over any chord derived from 'C' major scale"*, p. 180.)

**Modification Rules:**

- **Avoid Note C Over Standalone G7** (`avoid-note-c-over-g7`) — The 4th (C) is an avoid note over a standalone G7 and must be replaced by emphasis on the 3rd (B); C is freely usable over G7sus. Engine payload kind: `OmissionAllow`. (Chapter 2 summary; ch02.md: *"we must be careful with the avoid note 'C'... emphasize the 'B' note instead the 'C' note"*, p. 144.)

- **Major 7th Leading-Tone Addition to Dorian** (`major7-leading-tone-addition`) — Adding the major 7th to the Dorian scale creates a leading-tone illusion of dominant resolution and unlocks recycling of major-7th arpeggio lines from the I and IV chords. Engine payload kind: `ColorToneRequire`. (Chapter 2 summary; ch02.md: *"we can add the major 7th to the dorian scale... works as a leading tone to the root"*, p. 144.)

- **Cmaj7 + Fmaj7 Line Recycling for D Dorian** (`cmaj7-fmaj7-line-recycling`) — Combining existing Cmaj7 and Fmaj7 arpeggio lines generates Dorian vocabulary without learning new material. Engine payload kind: `SubstitutionExpand`. (Chapter 2 summary; ch02.md: *"combining Cmaj7 lines with Fmaj7 lines, we can build a beautiful D dorian line"*, p. 145.)

- **Pre-Arpeggio Chromatic Approach** (`chromatic-pre-arpeggio-color`) — Inserting a chromatic approach note before each arpeggiated chord adds color and disguises the mechanical regularity of the pattern. Engine payload kind: `ColorToneRequire`. (Chapter 2 summary; ch02.md: *"there is a chromatic note before each chord arpeggio, making them sound more 'colorful'"*, p. 198.)

- **Odd/Even Rhythmic Displacement** (`odd-even-rhythmic-displacement`) — Applying odd rhythmic cells to even-note patterns (and vice versa) removes the exercise feel and makes arpeggio sequences sound like improvisation. Engine payload kind: `_pending:rhythmic-displacement`. (Chapter 2 summary; ch02.md: *"use odd rhythmic cells when we have even notes... take out the 'exercise feel'"*, p. 198.)

- **Scales-as-Maps Anti-Scalar Rule** (`scales-as-fretboard-maps`) — Scales serve only as fretboard guides; authentic improvisation requires mixing scales, superimposed arpeggios, and chromatic tones. Engine payload kind: `_pending:anti-scalar-mix-mandate`. (Chapter 2 summary; ch02.md: *"we use scales only to guide us through the guitar fretboard... mix scales, superimposed arpeggios and chromatic tones"*, p. 147.)

---

### Harmonic Minor Superimposition System

Chapter 3 extends the superimposition method into the harmonic minor sound, framing harmonic minor as an *active* scale — distinguished from *static* scales by its 6th degree — and positions it specifically as a cadential tool for V7–I resolutions landing on either minor or major tonic chords. The fretboard is organized into five vertical zones anchored to two guide chord shapes — Cm(maj7) and Eb+(maj7) — paralleling the zone architecture of Chapter 2. Scale arpeggios are derived by degree substitution: the perfect 5th is replaced by #5 in major arpeggios, and the minor 7th is replaced by the major 7th in minor arpeggios. Two symmetric structures — the diminished chord (functioning as rootless V7b9) and the augmented chord — each provide four enharmonic spellings that can be embedded as melodic cells within the dominant. Chromatic approach notes inserted between arpeggiated notes produce the characteristic *chromatic illusion* of multiple overlapping scales. Strict boundary rules govern application throughout. (Chapter 3 summary; ch03.md quotes.)

**Members:**
- **C Harmonic Minor Scale** (`harmonic-minor-scale`) — An active, cadential scale generating its own dominant chord; used over V7–I resolutions to minor or major.
- **Ionian (#5) Scale** (`ionian-sharp5-scale`) — The relative major of harmonic minor; used as the parallel major-key resource and anchor for the zone system.
- **Harmonic Minor Fretboard Zone 1 — Cm(maj7)** (`harmonic-minor-zone-1`) — First of five vertical zones, anchored to the Cm(maj7) guide chord shape.
- **Harmonic Minor Fretboard Zone 2 — Eb+(maj7)** (`harmonic-minor-zone-2`) — Second zone, anchored to the Eb+(maj7) guide chord shape.
- **Harmonic Minor Fretboard Zone 3** (`harmonic-minor-zone-3`) — Third zone; returns to the Cm(maj7) shape at a higher register.
- **Harmonic Minor Fretboard Zone 4** (`harmonic-minor-zone-4`) — Fourth vertical zone in the harmonic minor zone system.
- **Harmonic Minor Fretboard Zone 5** (`harmonic-minor-zone-5`) — Fifth and highest vertical zone in the harmonic minor zone system.
- **Diminished Chord (Rootless V7b9)** (`diminished-chord-rootless-v7`) — The VII° of harmonic minor functioning as G7b9 without the root; four enharmonic spellings (B°, D°, F°, Ab°) are interchangeable.
- **Augmented Chord (Melodic Cell)** (`augmented-chord-melodic-cell`) — Derived from harmonic minor; three symmetric rotations (G+, B+, D#+) all function within G7 and are used as embedded melodic fragments.
- **Minor 7th (Aeolian Color Tone)** (`minor7-color-tone`) — A non-scale tone borrowed from Aeolian, available as a color addition to harmonic minor lines.
- **Harmonic Minor Major Arpeggio (#5 substitution)** (`harmonic-minor-major-arpeggio-sharp5`) — A major arpeggio with perfect 5th replaced by #5, characteristic of harmonic minor.
- **Harmonic Minor Minor Arpeggio (maj7 substitution)** (`harmonic-minor-minor-arpeggio-maj7`) — A minor arpeggio with minor 7th replaced by major 7th, characteristic of harmonic minor.

**Traversal Rules:**

- **Five-Zone Guide Chord Navigation** (`five-zone-guide-chord-navigation`) — All harmonic minor lines are organized across five vertical fretboard zones anchored to Cm(maj7) and Eb+(maj7) guide chord shapes. Engine payload kind: `PositionContinuity`. (Chapter 3 summary; ch03.md: *"Guide Chords: Harmonic Minor & Ionian (#5) = Cm(maj7) & Ebmaj7(#5)"*, p. 238.)

- **Diminished Symmetry Interchangeability** (`diminished-symmetry-interchangeability`) — The four enharmonic diminished spellings (B°, D°, F°, Ab°) are interchangeable over G7b9 because each contains the same four pitch classes. Engine payload kind: `SymmetryMovement`. (Chapter 3 summary; ch03.md: *"B° will provide us three more equal chords: D°, F° and Ab°... all fake diminished chords"*, p. 246.)

- **Augmented Symmetry Interchangeability** (`augmented-symmetry-interchangeability`) — The three augmented rotations (G+, B+, D#+) derived from C harmonic minor are interchangeable as melodic cells over G7. Engine payload kind: `SymmetryMovement`. (Chapter 3 summary; ch03.md: *"augmented chord which is also symmetric, giving us three equal augmented chords"*, p. 281.)

- **Chromatic Illusion (Ascending Only Over Diminished)** (`chromatic-illusion-ascending-only`) — Chromatic approach notes are inserted ascending between arpeggiated notes to create the illusion of multiple scales; descending chromatics over diminished arpeggios follow a separate set of rules. Engine payload kind: `NCTHarmonization`. (Chapter 3 summary; ch03.md: *"we will only use simple ascending chromatic approaches over the diminished arpeggios"*, p. 260.)

**Modification Rules:**

- **Degree Substitution: #5 and Maj7 Replacements** (`degree-substitution-sharp5-maj7`) — Harmonic minor arpeggios are derived by replacing the perfect 5th with #5 in major shapes and the minor 7th with major 7th in minor shapes. Engine payload kind: `SubstitutionExpand`. (Chapter 3 summary; ch03.md: *"replace the perfect 5th with the #5th, and in the minor scale arpeggio replace the minor 7th with the major 7th"*, p. 243.)

- **Chord-Family Degree Substitution Options** (`chord-family-degree-substitution-options`) — Specific scale degrees may be replaced by diminished or half-diminished variants to avoid landing on the tonic C note during the dominant. Engine payload kind: `SubstitutionExpand`. (Chapter 3 summary; ch03.md: *"Second degree = Dø: can be replaced by D° / Fourth degree = Fm7: can be replaced by F°"*, p. 335.)

- **Minor 7th Color Tone Addition** (`minor7-color-tone-addition`) — The b7 (minor 7th) from Aeolian may be added to harmonic minor lines as a non-scale color tone because both scales share the same harmonic function. Engine payload kind: `ColorToneRequire`. (Chapter 3 summary; ch03.md: *"we can also use the minor 7th, which is a note that is not derived from this scale but sounds great"*, p. 235.)

- **Natural 6th Forbidden Over V7–Im Cadences** (`natural6-forbidden-over-v7-im`) — The natural 6th (A natural in C minor) is derived from Dorian — a static scale — and cannot be used over any V7–Im cadence. Engine payload kind: `OmissionAllow`. (Chapter 3 summary; ch03.md: *"cannot use the 'A' note (major 6th)... derived from the dorian scale and cannot be played over any cadence"*, p. 261.)

- **Resolution Note Must Match Destination Chord** (`resolution-note-must-match-destination`) — The ending note of any harmonic minor line must fit the tonic chord even when the line is drawn from harmonic minor, which does not contain the destination chord tone. Engine payload kind: `_pending:cadential-resolution-gate`. (Chapter 3 summary; ch03.md: *"always pay attention to the resolution note because we must always respect the ending chord"*, p. 235.)

- **Tonic Root Omission Over Dominant** (`tonic-root-omission-over-dominant`) — When superimposing the harmonic minor chord family over G7, the tonic root (C) must be avoided as a landing note to preserve melodic tension. Engine payload kind: `OmissionAllow`. (Chapter 3 summary; ch03.md: *"be careful when using the root of the Cm(maj7), because it can sound weird... forget the root for now"*, p. 308.)

- **Tonic-Note Chords as Passing Only** (`passing-chord-tonic-note-rule`) — Chords containing the tonic C (Dø, Fm7, Abmaj7) may only be used as passing material in a line moving from G7 to Cm7, not as melodic targets. Engine payload kind: `_pending:passing-chord-gate`. (Chapter 3 summary; ch03.md: *"We can use the triads and tetrads that contain the 'C' note only as passing chords"*, p. 308.)

- **Augmented Chords as Embedded Melodic Cells** (`augmented-as-melodic-cell-not-harmonic`) — Augmented chord shapes are never played consecutively as independent harmonic material; they function only as small melodic cells embedded within harmonic minor single lines. Engine payload kind: `_pending:cell-embedding-constraint`. (Chapter 3 summary; ch03.md: *"these augmented chords are not to be played consecutively, they are just small melodic cells"*, p. 284.)

- **Descending Augmented Arpeggios: Horizontal Alternate Picking** (`descending-augmented-horizontal-picking`) — Descending augmented arpeggio shapes must be played horizontally (one shape per string) to maintain the George Benson alternate-picking technique. Engine payload kind: `_pending:technique-constraint-picking`. (Chapter 3 summary; ch03.md: *"descending augmented chord shapes will be played horizontally... George Benson picking technique works much better"*, p. 284.)

- **Harmonic Minor Forbidden Over IIm7 in Major Cadence** (`harmonic-minor-forbidden-over-iim7`) — When the full major cadence IIm7–V7–Imaj7 is present, harmonic minor lines cannot be applied over the IIm7 chord — only over the V7 and resolution. Engine payload kind: `_pending:cadential-scope-gate`. (Chapter 3 summary; ch03.md: *"when we have a complete 'C' major cadence such as Dm7 / G7 / Cmaj7, we cannot use 'C' harmonic minor ideas over the Dm7"*, p. 236.)

---

## Pending Work

The following `engine_payload.kind` values in the systems-draft are marked pending and have not yet been mapped to a concrete engine implementation. Each signals a rule category that requires a specialized engine node or gate:

| Pending Kind | System | What It Signals |
|---|---|---|
| `_pending:avoid-note-gate` | Approach Tone Taxonomy | A gate that checks whether a candidate target tone is an avoid note for the active chord; blocks selection unless the avoid note has been absorbed into the chord voicing. |
| `_pending:chord-conditioned-approach-filter` | Approach Tone Taxonomy | A filter that restricts available chromatic approach sub-types based on the chord family and interval distances present in that chord. |
| `_pending:quality-gate-chromatic` | Approach Tone Taxonomy | A subjective / heuristic restraint gate on chromatic approach density; signals the need for a tasteful-application metric or density cap. |
| `_pending:rhythmic-displacement` | II-V Superimposition | A transformation that shifts a rhythmic grid (odd vs. even) to disguise mechanical arpeggio patterns; requires a rhythmic re-quantization engine node. |
| `_pending:anti-scalar-mix-mandate` | II-V Superimposition | A compositional mandate requiring that generated lines mix at least scales, arpeggios, and chromatic tones rather than drawing from any single source; a line-composition validator. |
| `_pending:cadential-resolution-gate` | Harmonic Minor Superimposition | A gate enforcing that the terminal note of any harmonic minor line is a member of the destination (tonic) chord; checked at line-end before output. |
| `_pending:passing-chord-gate` | Harmonic Minor Superimposition | A gate constraining chords containing the tonic C (Dø, Fm7, Abmaj7) to passing-chord role only; blocks use as a melodic target or landing point. |
| `_pending:cell-embedding-constraint` | Harmonic Minor Superimposition | A constraint preventing augmented chord shapes from appearing in consecutive, independent positions; enforces their role as embedded cells within a larger line. |
| `_pending:technique-constraint-picking` | Harmonic Minor Superimposition | A technique-level constraint requiring that descending augmented arpeggio shapes be executed horizontally (one note per string) per the George Benson alternate-picking method. |
| `_pending:cadential-scope-gate` | Harmonic Minor Superimposition | A scope gate that restricts harmonic minor line application to the V7 (and resolution) portion of a IIm7–V7–Imaj7 cadence, excluding the IIm7 chord when the full major cadence is present. |

---

## Provenance Notes

**What is drawn from what.** All content in this statement is derived exclusively from:
1. The book-level distillation (`s3` run, `2026-06-02T05:17:35+00:00`), which aggregated the per-chapter summaries.
2. The three per-chapter summaries (Chapter 1 `source_pages: 1–143`, Chapter 2 `source_pages: 144–234`, Chapter 3 `source_pages: 235–372`), each extracted by `claude-haiku` and backed by their respective `ch01.md`, `ch02.md`, `ch03.md` quote files.
3. The systems-draft JSON (`benson:method-vol-4-approach-tones`), which structured the taxonomy, members, rules, and engine payload kinds.

**Chapter yield:**
- **Chapter 1** → yielded the **Approach Tone Taxonomy System** in full. The chapter's sole purpose is definitional classification; it does not generate a fretboard system or superimposition method of its own.
- **Chapter 2** → yielded the **II-V Superimposition System (Dorian / Mixolydian)** in full, including the eight connection options and five-zone architecture.
- **Chapter 3** → yielded the **Harmonic Minor Superimposition System** in full, including the two symmetric structures (diminished and augmented), degree-substitution arpeggio set, and the expanded boundary-rule set.

**No chapters were excluded.** All three chapters yielded systems. The book contains no introductory, biographical, or appendix material identified in the summaries that would fall outside a system boundary.
