---
run_id: 2026-05-22T21-15-00-benson-vol-1
stage: s4
source_pdf: THE-GEORGE-BENSON-METHOD-VOL-1-Chord-Construction-Beginning-Harmony-1st-Edition.pdf
model: qwen2.5:72b
extracted_at: 2026-05-23T20:05:28+00:00
schema_version: 0.1
---

# The George Benson Method, Vol. 1 — Chord Construction & Beginning Harmony — Statement of Outputs

## Overview

The George Benson Method, Vol. 1 is a strict bottom-up curriculum that moves from notation literacy to a working theory of diatonic harmony on the guitar. The pedagogical sequence is itself a thesis: notation (Ch. 1), then scales and intervals (Ch. 2), then key relationships via the Circles of Fourths and Fifths (Ch. 3), then the chord universe by tertian stacking (Ch. 4), then harmonic fields and the seven modes (Ch. 5), then a practice methodology for those fields (Ch. 6), and finally chromatic color via Harmonic Minor, Melodic Minor, and Harmonic Major (Ch. 7). The book-level distillation frames these as four interlocking commitments: fixed load-bearing terminology, a chord-first fretboard, rule-governed practice, and a clean separation between structural diatonic harmony and chromatic color.

The load-bearing organizing system is a chord-first visualization of the fretboard: arpeggios, scales, and phrases are derived from chord knowledge rather than the reverse. The Root splits the fretboard into left and right sides, the layout repeats at the 12th fret, and two Guide Notes on the 5th and 6th strings serve as the Root reference for every interval and chord shape. A universal practice rule restated across Chapters 6 and 7 anchors voicings to bass-note roots on the 5th and 6th strings first, deferring 4th-string voicings until those are mastered.

A load-bearing instrument constraint runs throughout: unlike the piano, the guitar must edit and omit notes, and this constraint sits behind nearly every voicing choice. The analytic frame deliberately separates structural diatonic harmony (Chapters 5–6) from chromatic color (Chapter 7), with explicit rules — smallest-movement voice leading, #11-vs-natural-11, no-flat-9 between bass and top, sus-as-3rd-replacement, no-inversions-for-symmetric-chords, VIIm 9th forbidden in Locrian, and omit-the-5th-in-13ths — constraining every voicing choice.

## Systems

### Fretboard-as-Matrix Visualization System

Benson's organizing system treats the fretboard as a matrix to be navigated chord-first. The Root splits the fretboard into left and right sides; the layout repeats at the 12th fret; and two Guide Notes on the 5th and 6th strings serve as the Root reference for every interval and chord shape. Chord shapes are organized into four root-string zones (6th, 5th, 4th, and 3rd-string for triads only). A practice protocol surrounds the system rather than functioning as a voicing-engine rule: one key at a time, always with a rhythmic groove, mastery before key changes, and 6th/5th-string voicings before 4th-string ones.

Members: 6th-String Root Zone; 5th-String Root Zone; 4th-String Root Zone; 3rd-String Root Zone (triads only); Guide Notes (5th and 6th strings); 12th-Fret Octave Mirror.

Traversal rules:
- Visualization via Bass Note — `PositionContinuity` (Chapter 6 summary; Chapter 7 summary; references: ch06 "Visualization via bass note", ch07 "Universal fretboard-visualization rule").
- Defer 4th-String Voicings Until 6th/5th Mastery — `StringSetTransition` (Chapter 6 summary; Chapter 7 summary; references: ch06 "Study Devices protocol", ch07 "Universal fretboard-visualization rule").
- 12th-Fret Octave Mirror — `SymmetryMovement` (Chapter 2 summary; reference: ch02 "Spatial framework").
- Proximity-Based Chord Selection — `PositionContinuity` (Chapter 7 summary; reference: ch07 "Study devices").

Modification rules:
- Learn Shapes and Intervals Together — `_pending:shapes-with-intervals-coupling` (Chapter 2 summary; reference: ch02 "Shapes vs intervals warning").

### Chord-Family System (Triads, Tetrads, Extended)

Chapter 4 partitions the chord universe into three families — Triads, Tetrads, and Extended Chords — all justified by tertian harmony (R, 3, 5, 7, 9, 11, 13). The signature device is the Chord Skeleton: pre-set Root/3rd/5th shapes on the 6th, 5th, and 4th strings with right-side and left-side variants. Suspended chords are defined strictly as 3rd-replacement (sus2/sus4) and visualized by anchoring to known dominant-7 shapes. The instrument constraint that the guitar must edit and omit notes shapes voicing decisions throughout.

Members: Triads (four qualities, three inversion positions); Tetrads (Seventh, Sixth, Added-Tone subfamilies; 4-position inversion framework); Extended Chords (9, 11, 13 as tertian-with-exceptions); Suspended Chords (sus2/sus4 as 3rd-replacement); Chord Skeletons (Root/3rd/5th on 6th/5th/4th strings, right- and left-side variants).

Traversal rules:
- Smallest-Movement Voice Leading — `VoiceMotion` (Chapter 4 summary; reference: ch04 "Voice leading").
- Sus Chords Anchored to Dominant-7 Shapes — `FamilyCoherence` (Chapter 4 summary; reference: ch04 "Suspended chords").
- 4th-String Extended Voicings Derived From 6th/5th — `StringSetTransition` (Chapter 4 summary; reference: ch04 "4th-string extended voicings").

Modification rules:
- Drop 2 / Drop 3 Restricted to Tetrads — `FamilyCoherence` (Chapter 4 summary; reference: ch04 "Tetrad Chords").
- No Inversions for Symmetric Chords — `FamilyCoherence` (Chapter 4 summary; reference: ch04 "Triads").
- Omit the 5th in 13th Chords — `OmissionAllow` (Chapter 4 summary; reference: ch04 "Extended Chords").
- No b9 Between Bass and Top on Major/Minor — `_pending:forbidden-vertical-interval` (Chapter 4 summary; reference: ch04 "Voicing prohibitions").
- #11 vs Natural 11 Rule — `ColorToneRequire` (Chapter 4 summary; reference: ch04 "Extended Chords").
- Sus Is 3rd-Replacement Only — `FamilyCoherence` (Chapter 4 summary; reference: ch04 "Suspended chords").
- Guitar Must Edit and Omit Notes — `OmissionAllow` (Chapter 4 summary; reference: ch04 "Instrument constraint").
- Unmarked 7 Is Minor (Maj7 Must Be Marked) — `_pending:notation-default` (Chapter 4 summary; reference: ch04 "Tetrad Chords").

### Harmonic Field System (Diatonic Modes and Substitutions)

Chapter 5 builds the harmonic field by stacking thirds on each degree of the natural major scale, yielding seven diatonic chords (I, IIm, IIIm, IV, V, VIm, VIIm) and pairing each degree with one of the seven modes (Ionian through Locrian). Scale notes are classified into four categories: Chord Notes, Extended Notes, Avoid Notes, and Characteristic Notes. Chapter 6 prescribes a degree-by-degree substitution catalog grounded in modal character; listed extensions are melodic options, not mandatory voicing components. The Natural Major and Natural Minor Harmonic Fields are framed as the 'happy' vs 'sad' organizing systems that share the same chords but differ in analytic frame.

Members: I (Ionian); IIm (Dorian); IIIm (Phrygian); IV (Lydian); V (Mixolydian); VIm (Aeolian); VIIm (Locrian); Natural Major Harmonic Field; Natural Minor Harmonic Field.

Traversal rules:
- V Dominant-to-Sus Substitution — `SubstitutionExpand` (Chapter 6 summary; reference: ch06 "V dominant-to-sus substitution").
- IIIm Phrygian Slash-Chord Recasting — `SubstitutionExpand` (Chapter 6 summary; reference: ch06 "IIIm phrygian additions").
- VIIm Locrian Recast as G7(9)/B — `SubstitutionExpand` (Chapter 6 summary; reference: ch06 "VIIm locrian avoid-note rule").
- I Degree C6/Cmaj7 Interchange — `SubstitutionExpand` (Chapter 6 summary; reference: ch06 "I degree C6/Cmaj7 interchange").

Modification rules:
- Modes Drive Both Harmony and Melody — `FamilyCoherence` (Chapter 5 summary; reference: ch05 "7 Modes").
- Avoid Notes Usable Mid-Phrase, Never as Endings — `_pending:avoid-note-suppression` (Chapter 5 summary; reference: ch05 "Avoid Notes").
- Listed Extensions Are Melodic Options, Not Voicing Requirements — `OmissionAllow` (Chapter 5 summary; Chapter 7 summary; references: ch05 "Extended notes clarification", ch07 "VERY IMPORTANT rule").
- Characteristic Notes Define Modal Identity — `ColorToneRequire` (Chapter 5 summary; reference: ch05 "Characteristic Notes").
- 9th Forbidden on the VIIm Locrian Chord — `_pending:degree-extension-forbidden` (Chapter 6 summary; reference: ch06 "VIIm locrian avoid-note rule").
- IIm Dorian Extensions With m6 Deferred — `ColorToneRequire` (Chapter 6 summary; reference: ch06 "IIm dorian extensions").
- VIm Aeolian Extensions and Slash Voicings — `ColorToneRequire` (Chapter 6 summary; reference: ch06 "VIm aeolian extensions").

### Chromatic Color-Scale System (Harmonic Minor, Melodic Minor, Harmonic Major)

Chapter 7 grounds the rest of the book's chromatic vocabulary in a single functional definition: the leading tone is the VII degree of the Natural Major Scale, the half-step tension the Natural Minor lacks. This historical absence motivated raising the natural minor's VII to produce the Harmonic Minor Scale, then the Melodic Minor Scale (treated per the Bach Scale as one symmetric form), and finally Rimsky-Korsakov's Harmonic Major Scale. The book deliberately calls the seven rotations of these parent scales scale modes rather than harmonic fields, because their derived chord families are not progression-guiding structures but coloristic devices layered over existing chords.

Members: Harmonic Minor Scale (Im, min 3rd / min 6th / maj 7th); Melodic Minor Scale (Bach Scale form, Im with min 3rd / maj 6th / maj 7th); Harmonic Major Scale (major with b6); VII Altered Scale (from Melodic Minor); bIII Lydian Augmented (from Melodic Minor); IV Lydian Dominant (from Melodic Minor); bVI Lydian Augmented #2/#5 (from Harmonic Major); VIIm Locrian bb7 (from Harmonic Major, sources o7(b13) and (11) colors).

Traversal rules:
- Color Scales Layer Over Existing Chords — `NCTHarmonization` (Chapter 7 summary; reference: ch07 "Derived chord families as color").

Modification rules:
- Leading-Tone Restoration Generates Color Scales — `ColorToneRequire` (Chapter 7 summary; reference: ch07 "Leading tone definition").
- Each Derived Mode Specified by Avoid and Characteristic Notes — `ColorToneRequire` (Chapter 7 summary; reference: ch07 "Avoid notes and characteristic notes").
- Extended Notes as Passing Tones, Not Voicing Requirements — `OmissionAllow` (Chapter 7 summary; reference: ch07 "VERY IMPORTANT rule").

## Pending Work

Four `_pending:` engine_payload kinds remain in the draft and need engine-layer kinds defined before promotion into masters.json:

- `_pending:shapes-with-intervals-coupling` — signals a pedagogical coupling rule (shapes and intervals must be learned as a single unit, anchored by the two Guide Notes) for which no existing engine kind expresses the learning-coupling constraint between geometric shape memory and interval semantics.
- `_pending:notation-default` — signals a notation-level default-interpretation rule (an unmarked 7 means minor 7; a major 7 must be explicitly indicated). The existing voicing/harmonization kinds don't cover symbol-parsing defaults; this likely needs a parser-side rather than engine-side kind.
- `_pending:forbidden-vertical-interval` — signals a generic prohibition against a specified vertical interval between two designated voices in a voicing (here, no flat-9 between bass and top on major/minor chords). Distinct from `VoiceMotion` (horizontal) and `ColorToneRequire` (presence-positive); it needs a presence-negative vertical-interval constraint kind.
- `_pending:avoid-note-suppression` — signals a positional suppression rule for a class of notes (Avoid Notes are usable mid-phrase but never as ending tones). This is not a flat prohibition (`ColorToneRequire` negated) but a context-sensitive one keyed to phrase position, and warrants its own kind.
- `_pending:degree-extension-forbidden` — signals that on a specific degree of a harmonic field, a specific extension is forbidden (here, no 9th on VIIm Locrian because it produces a b9 against the root). This may eventually reduce to `_pending:forbidden-vertical-interval` once the latter is concrete, but it is currently scoped at the degree/extension level rather than the voice/interval level.

## Provenance Notes

All system blocks and rules are drawn from the book-level distillation and the seven per-chapter summaries (ch01–ch07.md). Each rule carries `references[]` pointing back to the specific chapter and topic, with quote excerpts from the chapter summaries.

Chapter 1 (Staff, Clefs & Musical Notes) yielded no system: it is pure notation literacy with no master's stylistic moves, as its own summary states. Chapter 3 (Circle of Fourths/Fifths) also yielded no standalone system in this draft; its content (sharp/flat orders, mirror-image key identification, relative-key definition) is upstream theory consumed by the Harmonic Field System (Roman numerals, degree analysis) rather than a navigation/voicing system in its own right.

The three audit fixes from #298 are reflected here: the no-b9-between-bass-and-top rule is mapped to `_pending:forbidden-vertical-interval` (was previously a misfit under an existing kind); the avoid-notes rule is mapped to `_pending:avoid-note-suppression` (separating positional suppression from flat prohibition); and the Study Devices four-rule protocol has been folded into the Fretboard-as-Matrix System's summary prose rather than reified as a standalone rule, since it is a practice prescription surrounding the system rather than a voicing-engine rule. The systems-draft now carries `references[]` on every rule, giving each engine claim a direct line back to a chapter quote.
