---
run_id: 2026-05-28T15-05-20-greene-chord-chemistry
stage: s4
source_pdf: Chord Chemistry by Ted Greene.pdf
model: claude-sonnet
extracted_at: 2026-05-29T06:01:00+00:00
schema_version: 0.1
---

# Chord Chemistry by Ted Greene — Statement of Outputs

## Overview

*Chord Chemistry* (Ted Greene) is a comprehensive guitar method book that proceeds from foundational theory to advanced application across twenty chapters. The book-level distillation characterizes its arc in three phases: Chapters 1–8 build the theoretical and referential infrastructure (fingerboard geography, notation, technique, scale and interval theory, chord formulas and families, and reference charts); Chapters 9–16 move from reference to application (ear training, harmonic motion through the cycle of 4ths, voice leading as a systematic discipline, chord melody, triads, and diatonic harmonization); and Chapters 17–20 apply all prior systems to idiomatic contexts — modal and non-diatonic scales, blues, and rock. Throughout, the book subordinates mechanical pattern-learning to formula-based reasoning: students are taught *why* a chord or substitution works before they are expected to play it.

The book's organizing principle is the **chord formula** — a specific combination of scale-degree numbers derived from the major scale built on the same root. Three foundational **chord families** (MAJOR, MINOR, DOMINANT 7TH) serve as parents from which all extensions, altered chords, and suspended chords descend (Chapters 5–6). The book's signature voicing tool, the **same-string inversion method**, generates exactly N distinct forms for any N-note chord on a fixed string set (Chapters 4–5). Fingerboard navigation is systematized through two sets of reference points (5th and 12th fret) and the 1st/6th string symmetry rule (Chapter 2). Chord synonyms and substitution rules are codified in Chapters 7–8 and extended through the tritone substitution principle in Chapters 10–12.

The book's explicit methodology, named in Chapter 13 as **systematic thinking**, requires breaking every chord into its individual tones, treating each as a separate voice, and analyzing how each voice moves to the next chord. **Back-cycling** (Chapters 14–15) and the **cycle of 4ths** (Chapter 12) are the principal compositional tools. Ear training (Chapter 9) is structured as categorical triage — any heard chord is first classified as major, minor, or dominant before finer identification. Modal, blues, and rock contexts (Chapters 17–20) are all presented as formula-derivable rather than memorized idioms, consistent with the book's overarching commitment to systematic harmonic reasoning over pattern accumulation.

---

## Systems

### Chord Formula and Family System

The central organizing system of *Chord Chemistry*. Every chord is defined by a formula — a specific combination of scale-degree numbers derived from the major scale built on the same root — rather than by a memorized shape. Three chord families (MAJOR, MINOR, DOMINANT 7TH) are the parents of all other chords. The same-string inversion method is the system's signature voicing engine: raise each chord tone on its string to the next higher chord tone, yielding exactly N distinct forms for any N-note chord on a fixed string set. (Chapter 4 summary; Chapter 5 summary; Chapter 6 summary)

**Members:** Major Family; Minor Family; Dominant 7th Family; Diminished / Augmented (Dominant-Functional); Suspended Chords; Extension Chords; Altered Chords.

**Traversal Rules:**

1. **Same-String Inversion Traversal** — Move between voicing forms by raising each tone on the same string. Engine payload kind: `StringSetTransition`. *(Chapter 4 / Chapter 5 summaries, ch04.md & ch05.md quotes)*
2. **Family Parent-to-Extension Traversal** — Navigate from parent chord to extensions or altered forms. Engine payload kind: `FamilyCoherence`. *(Chapter 5 / Chapter 6 summaries)*

**Modification Rules:**

1. **Altered Fifth Retention Rule** — Altered 5ths must be retained. Engine payload kind: `ColorToneRequire`. *(Chapter 5 summary)*
2. **Root or Fifth Omission in Five-Note Chords** — Root or 5th may be omitted; one remaining tone doubled. Engine payload kind: `OmissionAllow`. *(Chapter 5 summary)*
3. **Third Omission in 11th Chords** — 3rd is often omitted in 11th chords. Engine payload kind: `OmissionAllow`. *(Chapter 5 summary)*
4. **#9 and +11 Voice Placement Rule** — #9 above the 3rd; +11 above the 5th. Engine payload kind: `ColorToneRequire`. *(Chapter 5 summary)*
5. **Polychord Bottom Triad Fifth Omission** — Bottom triad may omit its 5th; uppers stay high over bassist. Engine payload kind: `OmissionAllow`. *(Chapter 7 summary)*
6. **Dominant-for-Major Substitution in Rock** — Dominant 7 may substitute for major in rock. Engine payload kind: `SubstitutionExpand`. *(Chapter 20 summary)*

---

### Voice Leading and Systematic Thinking System

Greene's primary methodology for connecting chords: each chord tone is treated as an independent voice. V7–I is the foundational laboratory. The chapter explicitly names the method "systematic thinking" and frames it as the reason every chord in the reference charts earns its place. (Chapter 13 summary; Chapter 14 summary; Chapter 12 summary)

**Members:** Voice; Leading Tone Voice; Common Tone Voice; Chromatic Approach Voice; Soprano / Top Note Voice.

**Traversal Rules:**

1. **Leading-Tone Resolution (V7 to I)** — 3rd of V7 → root of I. Engine payload kind: `VoiceMotion`. *(Chapter 13 summary)*
2. **Common-Tone Smoothing** — Retain shared tones across adjacent chords. Engine payload kind: `VoiceMotion`. *(Chapter 11 / Chapter 12 summaries)*
3. **Chromatic Approach Chord Motion** — Chord half-step above/below target with good voice leading. Engine payload kind: `VoiceMotion`. *(Chapter 13 summary)*
4. **ii-V-I Cycle Motion** — m7 followed by dominant a 4th higher. Engine payload kind: `PositionContinuity`. *(Chapter 13 / Chapter 12 summaries)*
5. **m(maj7) to m7 Voice-Leading Step** — 7 tone moves one fret up/down to root or b7. Engine payload kind: `VoiceMotion`. *(Chapter 14 summary)*
6. **Back-Cycling Motion** — Precede any chord with its V7 (or V and V-of-V). Engine payload kind: `PositionContinuity`. *(Chapter 14 / Chapter 15 summaries)*
7. **Dominant 3-Fret Cycle Motion** — Dominants move in 3-fret intervals. Engine payload kind: `SymmetryMovement`. *(Chapter 12 summary)*
8. **Altered Dominant 2-Fret Motion** — Altered dominants move in 2-fret intervals. Engine payload kind: `SymmetryMovement`. *(Chapter 12 summary)*

**Modification Rules:**

1. **Fifth Omission When Voice Leading Is Strong** — Omit 5th of I when VL is strong. Engine payload kind: `OmissionAllow`. *(Chapter 13 summary)*
2. **Major 7th from Double-Root Lowering** — Lower one root in a double-root major to get maj7. Engine payload kind: `VoiceMotion`. *(Chapter 13 summary)*
3. **Melody-on-Top Requirement** — Melody sits above the chord voicing. Engine payload kind: `DensityFloor`. *(Chapter 14 summary)*
4. **No Altered I7 at Song Opening (Except 7#9)** — Engine payload kind: `_pending:tonic-opening-constraint`. *(Chapter 10 / Chapter 11 summaries)*
5. **Lowering 3rd and b7 to Generate IV9 (Rock)** — Engine payload kind: `VoiceMotion`. *(Chapter 20 summary)*

---

### Substitution and Cycle-of-Fourths System

How chords are substituted for one another and how harmonic motion through the cycle of 4ths/5ths creates momentum and modulation. Dominant 7 is the engine; tritone substitution is the master rule. (Chapters 8, 10–12, 15, 16, 19, 20 summaries)

**Members:** Tonic Chord (I / Im); Dominant Chord; Subdominant Chord (IV / ii); Tritone Substitute Dominant; Secondary Dominant; Chord Synonym; Passing Chord; Turnaround Series.

**Traversal Rules:**

1. **Tritone Substitution Traversal** — Engine payload kind: `SubstitutionExpand`. *(Chapter 11 / Chapter 15 summaries)*
2. **Cycle-of-Fourths Dominant Motion** — Engine payload kind: `PositionContinuity`. *(Chapter 12 summary)*
3. **Duration-Splitting ii-V Interpolation** — Engine payload kind: `_pending:duration-split-substitution`. *(Chapter 10 summary)*
4. **Half-Bar Dominant Insertion** — Engine payload kind: `_pending:duration-split-substitution`. *(Chapter 10 summary)*
5. **vii° as Rootless V7 Substitution** — Engine payload kind: `SubstitutionExpand`. *(Chapter 16 summary)*
6. **Chord Synonym Substitution** — Engine payload kind: `SubstitutionExpand`. *(Chapter 8 summary)*
7. **Scale-Fragment Substitution** — Engine payload kind: `SubstitutionExpand`. *(Chapter 19 summary)*
8. **Resolving Diminished Substitution** — Engine payload kind: `SubstitutionExpand`. *(Chapter 20 summary)*
9. **Diminished Passing Chord Motion** — Engine payload kind: `SymmetryMovement`. *(Chapter 11 / Chapter 19 summaries)*

**Modification Rules:**

1. **m6 Avoidance in ii-V Context** — Engine payload kind: `_pending:harmonic-conflict-avoidance`. *(Chapter 11 summary)*
2. **Altered Minor Restriction to m7b5** — Engine payload kind: `FamilyCoherence`. *(Chapter 11 summary)*
3. **11b9 Reserved for Authentic V7 Function** — Engine payload kind: `_pending:function-restriction`. *(Chapter 12 summary)*
4. **Turnaround Must Cadence on V7** — Engine payload kind: `_pending:cadential-endpoint-constraint`. *(Chapter 19 summary)*
5. **Dominant Sus as Partial or Full V7 Replacement** — Engine payload kind: `SubstitutionExpand`. *(Chapter 11 summary)*
6. **9b5 Preferred Over +11** — Engine payload kind: `_pending:alteration-preference`. *(Chapter 11 / Chapter 8 summaries)*

---

### Fingerboard Geography and Navigation System

The foundational spatial system mapping theoretical knowledge onto the physical guitar neck via two sets of reference points and 1st/6th string symmetry. (Chapter 2 summary; Chapter 7 summary; Chapters 8, 11, 12 symmetry references)

**Members:** Open Strings (E A D G B E); 1st Reference Points (5th Fret / 4th Fret for String 3); 2nd Reference Points (12th Fret); 1st / 6th String Symmetry Axis; Moveable Chord Shape; Physically Related Chord Group.

**Traversal Rules:**

1. **Two-Reference-Point Navigation** — Engine payload kind: `PositionContinuity`. *(Chapter 2 summary)*
2. **1st/6th String Symmetry Traversal** — Engine payload kind: `SymmetryMovement`. *(Chapter 2 summary)*
3. **Moveable Shape Transposition** — Engine payload kind: `PositionContinuity`. *(Chapter 2 summary)*
4. **Physical Proximity Chord Grouping** — Engine payload kind: `PositionContinuity`. *(Chapter 7 summary)*

**Modification Rules:**

1. **Augmented 4-Fret Symmetry (Three Names)** — Engine payload kind: `SymmetryMovement`. *(Chapter 8 / Chapter 12 summaries)*
2. **Diminished 3-Fret Symmetry (Four Names)** — Engine payload kind: `SymmetryMovement`. *(Chapter 11 summary)*

---

## Pending Work

The following `_pending:<kebab>` engine payload kinds appear in the systems-draft. Each signals a rule whose logic has been captured but whose engine representation has not yet been formalized into an existing payload type:

- **`_pending:tonic-opening-constraint`** — Constraint on tonic-function chords at song-opening position. Altered I7 prohibited at song's opening (7#9 excepted). No existing payload type covers position-in-form constraints. *(Voice Leading System, modification rule `altered-i7-no-song-opening`)*
- **`_pending:duration-split-substitution`** — Substitution operating on temporal subdivision of a chord's duration. Two rules share this kind: ii-V interpolation and half-bar dominant insertion. No existing payload covers intra-bar duration splitting. *(Substitution System, traversal rules `duration-splitting-ii-v` and `half-bar-dominant-insertion`)*
- **`_pending:harmonic-conflict-avoidance`** — Prohibition triggered by forward-looking harmonic context (m6 vs. coming dominant a 4th higher). *(Substitution System, modification rule `m6-avoidance-ii-v`)*
- **`_pending:function-restriction`** — Restricts a chord type (11b9) to a single harmonic function (authentic V7). *(Substitution System, modification rule `11b9-restricted-to-v7`)*
- **`_pending:cadential-endpoint-constraint`** — Mandatory terminal chord of a formal pattern (turnaround must end on V7 / b5 voicing). *(Substitution System, modification rule `turnaround-cadence-v7`)*
- **`_pending:alteration-preference`** — Ranked preference between two valid altered dominant choices (9b5 over +11; 9b5 over 9#5b5). *(Substitution System, modification rule `9b5-preferred-over-plus11`)*

---

## Provenance Notes

**What is drawn from what:** The four systems derive directly from the systems-draft JSON (`master_id: ted-greene`, `work_id: greene-chord-chemistry`), which was itself derived from the per-chapter summaries (`summaries/ch01.md`–`ch20.md`) and the book-level distillation. All chapter citations trace back to per-chapter summary files and their quoted excerpts as preserved in the systems-draft references arrays. The book-level distillation's three-phase arc and methodology description are the primary synthesis layer; chapter summaries supply granular evidence.

**Chapters that did not yield systems:**

- **Chapter 1 (Fingerboard Chart and String Relationships):** The summary explicitly notes it is introductory rather than instructional with no load-bearing passages — it functions as a visual reference only and contributed no rules or system members.
- **Chapter 3 (Right Hand Technique):** The taxonomy of five right-hand techniques (flat pick; thumb pick + fingers; flat pick + fingers; fingers + thumb; thumb only) and chord-count-specific finger-assignment rules were not formalized as a standalone system. They appear as contextual annotations (e.g., the blues chapter's reminder that some progressions require fingers). A right-hand technique system is a candidate for a future pass.
- **Chapter 9 (Ear Training):** The three-stage categorical triage method and the "implied chords" concept appear in the book-level distillation but were not extracted as a standalone system, since they are perceptual-pedagogical guidance rather than voicing/substitution rules. Candidate for a future perceptual-categorization system.
- **Chapter 17 (Other Chords Built from Scales):** The modal scale equivalence (C major = G mixolydian = A natural minor = D dorian minor) and tonal-center thinking are referenced as contextual framing supporting the Substitution system's scale-fragment rules, rather than as a discrete modal-harmony system. Candidate for a future modal-equivalence system.
