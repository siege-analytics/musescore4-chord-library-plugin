---
run_id: 2026-05-22T21-15-00-benson-vol-1
stage: s4
source_pdf: THE-GEORGE-BENSON-METHOD-VOL-1-Chord-Construction-Beginning-Harmony-1st-Edition.pdf
model: qwen2.5:72b
extracted_at: 2026-05-22T21:32:47+00:00
schema_version: 0.1
---

# The George Benson Method, Vol. 1 — Chord Construction & Beginning Harmony — Statement of Outputs

## Overview

The George Benson Method, Vol. 1 is a strict bottom-up curriculum that moves from notation literacy to a working theory of diatonic harmony on the guitar. Chapters 1–3 establish notational vocabulary, the diatonic/chromatic interval system, and the Circle of Fourths/Fifths as the system of key relationships. Chapter 4 constructs the chord universe by tertian stacking and is the densest chapter in the book. Chapters 5–6 organize those chords into harmonic fields and the seven modes and prescribe how to practice them, and Chapter 7 extends the field idea to Harmonic Minor, Melodic Minor, and Harmonic Major as color sources rather than progression engines (book-level distillation, Overall Arc).

The book's load-bearing thesis is that the fretboard is a matrix to be visualized chord-first: arpeggios, scales, and phrases all derive from chord knowledge, organized into four root-string zones (6th, 5th, 4th, and — for triads only — 3rd strings), anchored by bass-note Guide Notes on the 5th and 6th strings. Across every harmonic field and every derived family, a universal practice rule applies: locate the bass-note root on the 5th and 6th strings first, and defer 4th-string voicings until those are mastered (book-level distillation, The Fretboard-as-Matrix System).

Taken as a unit, the method has four interlocking commitments: fixed load-bearing terminology (harmonic field, diatonic chords, the seven mode names, Chord/Extended/Avoid/Characteristic note categories, Chord Skeletons, Guide Notes, Drop 2/Drop 3, leading tone, scale modes, Bach Scale); a chord-first fretboard taught with shapes-and-intervals-as-one-unit; a rule-governed practice protocol (one key at a time, with a groove, mastery before modulation); and an analytic frame that separates structural diatonic harmony from chromatic color, with explicit voicing rules constraining every choice (book-level distillation, The Method as a Unit).

## Systems

## System: Fretboard Matrix (Root-String Zones)

The Fretboard Matrix is Benson's chord-first spatial backbone. Every voicing, arpeggio, and scale is learned by which string carries the root, so position on the neck is identified by root-string zone rather than by scale shape. Chord families and harmonic fields are practiced through these zones before being moved across the neck, with the 5th- and 6th-string Guide Notes serving as the Root reference for every interval and chord shape.

Members:
- Root on 6th String Zone
- Root on 5th String Zone
- Root on 4th String Zone
- Root on 3rd String Triad Zone

Traversal rules:
- Bass-Note Anchoring — `PositionContinuity`: identify and hold the root string as the positional anchor before adding upper voices.
- String-Set Transition (6 to 5 to 4 to 3) — `StringSetTransition`: translate a chord shape onto the next string set, preserving function while changing fingering.

Modification rules: none.

Citations: Chapter 2 summary (Root splits fretboard, Guide Notes on 5th/6th strings, shapes-with-intervals rule; ch02.md quotes); Chapter 4 summary (fretboard-as-matrix, four root-string zones, 3rd-string zone for triads only; ch04.md quotes); Chapter 6 summary (Visualization via bass note; ch06.md quotes); Chapter 7 summary (universal 6th/5th-string-before-4th-string rule restated per family; ch07.md quotes).

## System: Chord Families (Triads, Tetrads, Extended Chords)

This system is Benson's taxonomy of chord qualities from Chapter 4: triads, seventh-chord tetrads, and extended chords (9, 11, 13), with sus and drop voicings as transformations. Density and voice-leading policies govern how members are voiced and connected — the smallest-movement principle for transitions, omission of the 5th in 13ths, prohibition of a flat-9 between bass and top, the #11-vs-natural-11 substitution policy, and sus as strict 3rd-replacement. A load-bearing instrument constraint sits behind all of it: unlike the piano, the guitar must edit and omit notes.

Members:
- Triads (major, minor, diminished, augmented; root, 1st, 2nd inversions; symmetric chords have no inversions)
- Seventh-Chord Tetrads (maj7, 7, m7, m7b5, dim7, mMaj7; 4-position inversions)
- Extended Chords (9, 11, 13 and altered variants)
- Suspended Voicings (sus2, sus4)
- Drop-2 and Drop-3 Voicings

Traversal rules:
- Smallest-Movement Voice Leading — `VoiceMotion`: prefer the next voicing whose voices move by the smallest collective interval.

Modification rules:
- Omit 5th in 13th Chords — `OmissionAllow`.
- No b9 Interval Above Bass — `DensityCeiling`.
- #11 vs Natural 11 Policy — `SubstitutionExpand`.
- Suspended Substitution — `SubstitutionExpand`.
- Drop-2 / Drop-3 Respacing — `_pending:voicing-respacing`.

Citations: Chapter 4 summary (three families, Chord Skeletons, tertian justification, inversion frameworks, Drop 2/Drop 3 restricted to tetrads, #11-vs-11 rule, no-flat-9-between-bass-and-top, omit-5th-in-13ths, sus as 3rd-replacement, no-inversions-for-symmetric-chords, guitar-must-edit-and-omit; ch04.md quotes); book-level distillation, The Chord-Family System.

## System: Harmonic Fields (Diatonic Modes and Degrees)

The Harmonic Field is the book's organizing frame for diatonic harmony in practice. Chapter 5 builds it by stacking thirds on each degree of the natural major scale to yield seven diatonic chords (I, IIm, IIIm, IV, V, VIm, VIIm) and pairs each degree with one of the seven modes (Ionian through Locrian) as rotations of the parent scale. A four-category note taxonomy — Chord Notes, Extended Notes, Avoid Notes, Characteristic Notes — governs how each mode is voiced and improvised over. Chapter 6 then prescribes the Study Devices protocol and a degree-by-degree substitution catalog (e.g., G7 to Gsus9/Gsus13 on V; Em7(b6) and Cmaj7/E on IIIm; Bo recast as G7(9)/B on VIIm with the 9th forbidden because it produces a b9 avoid note).

Members:
- Ionian (characteristic note: major 7)
- Dorian (characteristic note: natural 6)
- Phrygian (characteristic note: b2)
- Lydian (characteristic note: #4)
- Mixolydian (characteristic note: b7)
- Aeolian (characteristic note: b6)
- Locrian (characteristic note: b5)

Traversal rules:
- Study Devices Protocol — `TextureCycle`: one key at a time, always with a rhythmic groove, mastery before key change, and 6th/5th-string voicings before 4th-string voicings.

Modification rules:
- Characteristic Note Required — `ColorToneRequire`.
- Extension Omission Allowed — `OmissionAllow`.
- Avoid Note Suppression — `NCTHarmonization`.
- Modal Substitution Catalog — `SubstitutionExpand`.

Citations: Chapter 5 summary (harmonic field construction, seven modes, four-category note taxonomy, Natural Major vs Natural Minor frames, extensions as melodic options; ch05.md quotes); Chapter 6 summary (Study Devices protocol, Visualization via bass note, degree-by-degree substitution catalog, VIIm locrian 9-forbidden rule; ch06.md quotes); book-level distillation, The Harmonic Field System.

## System: Chromatic Color Scales (Harmonic Minor, Melodic Minor, Harmonic Major)

Chapter 7 grounds the book's chromatic vocabulary in a single functional definition: the leading tone is the VII of the Natural Major Scale, the half-step tension the Natural Minor lacks. That absence historically motivated raising the natural minor's VII to produce the Harmonic Minor Scale, then the Melodic Minor Scale (treated per the Bach Scale as one symmetric form), and finally Rimsky-Korsakov's Harmonic Major Scale. Each parent generates seven scale modes — deliberately called scale modes rather than harmonic fields — because their derived chord families are not progression-guiding structures but coloristic devices layered over existing chords. A recurring VERY IMPORTANT rule restates that extended notes need not sit in the voicing; many belong only as passing tones in the melody.

Members:
- Harmonic Minor (Parent)
- Melodic Minor (Parent)
- Harmonic Major (Parent)
- Altered Scale (VII of melodic minor)
- Lydian Dominant (IV of melodic minor)
- Lydian Augmented (III of melodic minor)
- Phrygian Dominant (V of harmonic minor)
- Locrian Natural 6 (II of harmonic minor)

Traversal rules: none.

Modification rules:
- Characteristic Color Note Required — `ColorToneRequire`.
- Diminished o7(b13) Coloration — `SubstitutionExpand`.
- Harmonic Major (11) Coloration — `SubstitutionExpand`.

Citations: Chapter 7 summary (leading-tone definition, three parent scales, Bach Scale, derived signature modes, characteristic and avoid notes per mode, extended-notes-as-melodic-passing-tones rule, restated 6th/5th-string-first practice rule; ch07.md quotes); book-level distillation, Color Scales and the Leading-Tone Argument.

## Pending Work

- `_pending:voicing-respacing` — signals that Drop-2 / Drop-3 respacing (open-voiced derivations from a close voicing by lowering the 2nd or 3rd voice from the top by an octave) does not yet have a stable engine payload kind. A dedicated voicing-respacing operator is required to model the close-to-open transformation cleanly; until then, the Drop-2/Drop-3 modification rule is parked under this pending kind rather than coerced into a generic substitution.

## Provenance Notes

- The Fretboard Matrix system draws primarily from Chapter 2 (Root, Guide Notes, shapes-with-intervals rule) and Chapter 4 (matrix declaration, four root-string zones), with the cross-family practice restatements in Chapters 6 and 7.
- The Chord Families system is drawn almost entirely from Chapter 4; the smallest-movement rule, sus-as-3rd-replacement, Drop 2/Drop 3, #11-vs-11, no-flat-9-above-bass, omit-5th-in-13ths, and the no-inversions-for-symmetric-chords rule are all sourced there.
- The Harmonic Fields system is drawn from Chapter 5 (construction, modes, note taxonomy) and Chapter 6 (Study Devices protocol, substitution catalog, VIIm 9-forbidden rule).
- The Chromatic Color Scales system is drawn entirely from Chapter 7.
- Chapter 1 did not yield a system. Per its own summary, it is pure notation literacy (staff, clefs, grand staff) and contains no master's stylistic moves — it underpins everything notationally but contributes no traversal or modification rules of its own.
- Chapter 3 did not yield a standalone system. Its content (Circle of Fourths/Fifths, orders of sharps/flats, key-signature mechanics, relative minor as VI degree) supplies the key-relationship scaffolding used implicitly by the Harmonic Fields and Chromatic Color Scales systems, but the book does not operationalize the circle as a separate traversal/modification structure within Vol. 1's chord-construction scope.
