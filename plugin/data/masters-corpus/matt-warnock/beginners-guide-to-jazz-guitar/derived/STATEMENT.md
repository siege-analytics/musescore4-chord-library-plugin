---
run_id: 2026-05-28T15-05-20-warnock-beginners-guide
stage: s4
source_pdf: Warnock, Matt - Beginner's Guide to Jazz Guitar.pdf
model: claude-sonnet
extracted_at: 2026-05-31T03:33:43+00:00
schema_version: 0.1
---

# Beginner's Guide to Jazz Guitar — Statement of Outputs

## Overview

*Beginner's Guide to Jazz Guitar* by Matt Warnock is a compact, systematically sequenced method that builds a complete beginning jazz guitar curriculum around a single harmonic vehicle: the **ii V I progression** (Dm7–G7–Cmaj7). Every element of the book—chord vocabulary, comping rhythms, picking-hand technique, chromatic harmony, scale shapes, chromatic ornaments, and mixed solo texture—is introduced, practiced, and applied within that same progression. Chapter 1 establishes the method's governing meta-protocol: watch video alongside the PDF, review the chapter, practice each section until comfortable, then advance. This iterative-reinforcement-with-deliberate-pacing structure is not merely advice; it is re-instantiated in domain-specific form in every subsequent chapter.

The book's pedagogy follows a consistent three-stage arc within each chapter: **isolate → internalize → integrate**. A technique is introduced in isolation (with metronome), applied over a backing track, and then combined with previously learned material. Chapter 2 makes this arc explicit (solo practice → metronome → backing track → rhythmic variation); Chapter 5 repeats it for scale shapes (memorize shape → apply over backing track → combine both shapes); Chapter 7 elaborates it most fully into the four-stage imitation-to-improvisation sequence. This last sequence—imitate the written solo, substitute your own single-note lines, retain the single notes while improvising new chord rhythms, improvise both layers freely—represents the method's most complete articulation of its core pedagogical conviction: improvisation is acquired by progressively loosening constraints, not by open-ended playing from the start.

The book's techniques are encoded as **named, rule-governed systems** rather than stylistic suggestions. The Freddie Green rhythm, the Charleston rhythm, approach chords from above and below, the 134 chromatic ornament pattern, and the two positional scale shapes all carry precise structural definitions that apply mechanically across contexts. This characteristic move—naming a technique, defining its rule, sequencing its acquisition, then prescribing self-extension through variation—is the method's organizing epistemology from Chapter 2 through Chapter 7.

---

## Systems

### ii V I Comping System

The foundational harmonic-rhythmic system of the book, organized entirely around the ii V I progression. It supplies the chord vocabulary (Dm7, G7, Cmaj7, Cmaj9) and two named comping rhythms—the Freddie Green rhythm and the Charleston rhythm—each with a precise structural definition enabling isolated mastery before free combination. Approach chords extend the system chromatically: any target voicing can be displaced one fret above or below and then resolved back, adding tension and release to the comping texture. Lead-sheet symbol enrichment completes the system: performers are taught to read a simplified chord symbol and voice a richer color tone above it, reflecting real-world jazz performance practice. Every element is sequenced: Freddie Green before Charleston before mixing; approach from above before approach from below before mixing directions; exercise-as-written before rhythmic variation. (Chapter 2 summary; Chapter 3 summary; Chapter 4 summary.)

**Members**
- Dm7 Chord Voicing — the ii chord of the C major ii V I; the first chord shape students learn
- G7 Chord Voicing — the V chord of the C major ii V I
- Cmaj7 Chord Voicing — the I chord of the C major ii V I
- Cmaj9 Chord Voicing — a color variant of Cmaj7, illustrating lead-sheet symbol enrichment
- Freddie Green Rhythm — quarter-note chords on every beat, accented on beats 2 and 4 to imitate swing feel
- Charleston Rhythm — chord placement on beat 1 and the & of 2
- Approach Chord From Above — target voicing moved one fret higher, resolving down into the target
- Approach Chord From Below — target voicing moved one fret lower, resolving up into the target

**Traversal Rules**

1. **Freddie Green Quarter-Note Pulse** — Play one chord voicing per beat across all four beats, establishing a continuous harmonic pulse. *"The rhythm is all quarter notes, meaning you play one chord per beat."* (Chapter 2, p. 5.) Engine payload kind: `_pending:rhythmic-pulse-continuity`

2. **Freddie Green Beats-2-and-4 Accent Rule** — Accent chords on beats 2 and 4 to produce authentic swing feel, imitating the hi-hat. *"accent the 2 and 4 chords/beats in each bar. This imitates the hi-hat."* (Chapter 2, p. 5.) Engine payload kind: `_pending:rhythmic-accent-placement`

3. **Charleston Beat-1 and &-of-2 Placement** — Place chords on beat 1 and the & of 2, producing the syncopated Charleston rhythmic feel. *"places the first chord on beat 1 of each bar, then the second chord is on the & of 2."* (Chapter 2, p. 6.) Engine payload kind: `_pending:rhythmic-accent-placement`

4. **Comping Rhythm Combination Rule** — Once both named rhythms are internalized, mix Freddie Green and Charleston freely to generate original comping rather than playing either verbatim. *"mix the Freddie Green and Charleston rhythms together to expand on this idea in your comping."* (Chapter 2, p. 6.) Engine payload kind: `TextureCycle`

5. **Approach Chord Mandatory Resolution** — An approach chord—whether from above or below—must always resolve into the target chord voicing; the chromatic displacement is incomplete without the resolution step. *"play the same shape one fret higher, then resolve into your target chord."* (Chapter 4, pp. 11–12.) Engine payload kind: `PositionContinuity`

6. **Approach Direction Sequence: Above → Below → Mixed** — Students must practice approach chords from above first, then from below, then combine both directions. *"Start with the approach chords from above, then from below, then mix both together."* (Chapter 4, p. 11.) Engine payload kind: `_pending:prescribed-practice-sequence`

**Modification Rules**

1. **Lead-Sheet Symbol Color Expansion** — A chord symbol on a lead sheet represents minimum harmonic content; the performer adds color (e.g., voicing Cmaj9 when the chart reads Cmaj7). *"you normally see the simplest chord symbol written on a lead sheet, then you as the performer color that chord."* (Chapter 4, p. 11.) Engine payload kind: `ColorToneRequire`

2. **Approach Chord One-Fret Chromatic Displacement** — Any target voicing can be modified into an approach chord by transposing the entire shape exactly one fret up or down; the shape itself is preserved unchanged. *"play a chromatic chord one fret above or below the target chord."* (Chapter 4, p. 11.) Engine payload kind: `SubstitutionExpand`

3. **Rhythm and Picking Pattern Variation After Internalization** — Once any comping exercise is secure, the player must vary rhythms and picking patterns to self-extend the exercise beyond the written version. *"feel free to change the rhythms and picking patterns when comfortable to expand this approach chord exercise."* (Chapter 4, p. 13; Chapter 3, p. 9.) Engine payload kind: `_pending:self-extension-variation`

---

### Two-Shape Major Scale Fretboard System

The soloing system of the book, built on a single harmonic premise: because all three chords of a ii V I belong to the parent major key, one major scale is the correct and sufficient soloing choice across the entire progression. The system delivers this through exactly two positional fingering shapes—Shape 1 rooted on the 6th string, Shape 2 rooted on the 5th string—each memorized in isolation and applied over a backing track before the two are combined to cover the full neck. Chromatic ornament is integrated into this system through the 134 pattern: a four-note ornament triggered whenever a 1-3-4 fingering appears anywhere in a scale passage, on any string, in any key. The pattern carries a non-negotiable resolution law and an overplay-first acquisition philosophy. (Chapter 5 summary; Chapter 6 summary.)

**Members**
- Major Scale Shape 1 (6th-String Root) — positional fingering anchored to the 6th string root; the first shape to memorize and apply
- Major Scale Shape 2 (5th-String Root) — positional fingering anchored to the 5th string root; the second shape, completing two-position neck coverage
- 134 Chromatic Ornament Pattern — a four-note chromatic ornament triggered by any 1-3-4 fingering on any string in any key within either scale shape

**Traversal Rules**

1. **Single Tonic Major Scale Over Entire ii V I** — Because all three chords of the ii V I belong to the parent major key, a single tonic major scale covers all three chord changes. *"all 3 chords in a ii V I are in the parent key… you can use the tonic major scale to solo over all of those chords."* (Chapter 5, p. 14.) Engine payload kind: `FamilyCoherence`

2. **Shape Sequence: Individual Shape → Combined Neck Coverage** — Students learn each positional shape one at a time—memorize, then apply over backing track—before combining both shapes to solo across the full fretboard. *"Start by learning these scale shapes one at a time, add them to your soloing workout, then combine them."* (Chapter 5, pp. 14–15.) Engine payload kind: `PositionContinuity`

3. **134 Pattern Application Trigger** — Whenever a 1-3-4 fingering appears within a scale passage on any string, in any key, the 134 ornament is available to be inserted. *"This pattern is used whenever you have a 134 fingering on any string, any key, and in any scale."* (Chapter 6, p. 17.) Engine payload kind: `_pending:ornament-trigger-condition`

4. **134 Pattern Mandatory Resolution to Third Finger** — The ornament must always complete all four notes and resolve to the third finger; an incomplete pattern sounds like a mistake. *"The essential item is that you resolve the pattern to the 3 finger. If you leave things hanging and don't resolve the pattern by playing all 4 notes, you sound like you made a mistake."* (Chapter 6, p. 18.) Engine payload kind: `NCTHarmonization`

5. **Ornament Integration Sequence: Isolated Position → Combined → Free** — The 134 pattern is first worked in one positional shape with metronome, then combined across both shapes in technical studies, then applied freely over backing tracks. *"Work this position with a metronome, then combine it in your technical studies with the 6-string shape. When ready, solo over the backing track."* (Chapter 6, p. 20.) Engine payload kind: `PositionContinuity`

**Modification Rules**

1. **Earn-Before-Restraint: Deliberate Overplay of Ornament** — Students must consciously overuse the 134 ornament first to train the ear fully; only after saturation can they pull back and deploy it with musical taste. *"overplay it in the beginning. When your ears get used to this sound, you can pull back and add the 134 pattern here and there in a more musical way."* (Chapter 6, p. 19.) Engine payload kind: `_pending:earn-before-restraint`

2. **134 Pattern Rhythmic Freedom** — The rhythmic placement of the 134 ornament is not fixed; players have wide latitude to experiment with rhythm so long as the mandatory resolution rule is respected. *"The rhythms you use aren't that important, meaning you have a lot of freedom to experiment with rhythms when using the 134 pattern."* (Chapter 6, p. 18.) Engine payload kind: `_pending:self-extension-variation`

---

### Mixed Solo Texture System (Chords + Single Notes)

The synthesis system of the book, combining harmonic accompaniment and melodic soloing into a single mixed-solo texture. Its motivation is practical and ensemble-specific: in a duo or pianoless trio, the guitarist must supply harmonic space without a dedicated chord instrument. The system's two texture layers—chord layer and single-note layer—are drawn from the preceding systems (the ii V I comping system and the two-shape major scale system respectively), and its traversal rules govern how a player progressively dismantles a fixed written model across four discrete stages until both layers are improvised freely. No modification rules are defined; the system's complexity is entirely in its staged traversal sequence. (Chapter 7 summary.)

**Members**
- Written Mixed Solo (Imitation Model) — the fully notated solo combining chord hits and single-note lines; the starting reference point students learn verbatim before substituting their own material
- Chord Layer — the harmonic accompaniment component of the mixed solo; voicings and comping rhythms drawn from the ii V I comping system
- Single-Note Layer — the melodic soloing component of the mixed solo; lines drawn from the two-shape major scale system and ornamented with the 134 pattern

**Traversal Rules**

1. **Four-Stage Imitation-to-Improvisation Sequence** — Students traverse the mixed solo in four discrete, verifiable stages: (1) learn as written with metronome and backing track, (2) replace single notes with own lines, (3) retain single notes while improvising new chord rhythms, (4) improvise both layers freely over the chord changes. *"learn the solo as written… replace the single notes with your own soloing lines… keep the single notes as written… replace both the chords and single notes."* (Chapter 7, p. 23.) Engine payload kind: `_pending:progressive-constraint-release`

2. **Mixed Texture Ensemble Context Rule** — The mixed chord-and-single-note texture is the required approach when the guitarist must fill harmonic space in a duo or pianoless trio. *"By learning how to mix chords and single notes in your solos, you're prepared to jam in a duo or pianoless trio."* (Chapter 7, p. 22.) Engine payload kind: `_pending:ensemble-texture-requirement`

**Modification Rules**

None defined. The system's variation logic is inherited from its constituent systems (rhythm variation from the comping system; ornament freedom from the scale system).

---

## Pending Work

The following `_pending:` engine payload kinds appear in the systems-draft and require engine-side implementation before these rules can be executed programmatically:

| Kind | What It Signals |
|---|---|
| `_pending:rhythmic-pulse-continuity` | A rule that enforces unbroken beat-by-beat chord placement; no engine model for pulse continuity exists yet |
| `_pending:rhythmic-accent-placement` | A rule that specifies which metric positions receive accent weight; accent-placement logic is not yet formalized in the engine |
| `_pending:prescribed-practice-sequence` | A rule that enforces a fixed traversal order through discrete technique states (e.g., above → below → mixed); no engine model for ordered-state traversal exists yet |
| `_pending:self-extension-variation` | A rule that instructs a player to depart from the written exercise and generate variation once mechanics are secure; the engine has no model for sanctioned open variation within a rule |
| `_pending:ornament-trigger-condition` | A rule that fires the 134 ornament whenever a matching fingering condition is detected; trigger-condition logic for ornament insertion is not yet formalized |
| `_pending:earn-before-restraint` | A rule encoding deliberate acquisition-by-saturation: overplay before restraint; no engine model exists for time-sequenced acquisition philosophy |
| `_pending:progressive-constraint-release` | A rule that stages improvisation by releasing one fixed layer at a time across four discrete steps; multi-stage constraint-release traversal is not yet modeled |
| `_pending:ensemble-texture-requirement` | A rule that conditions a texture requirement on ensemble context (duo / pianoless trio); context-conditional texture selection is not yet modeled |

---

## Provenance Notes

**Chapter 1** (pp. 3–3) established the meta-protocol (watch video, review chapter, practice until comfortable, advance) and the curriculum roadmap. It did not yield a standalone system; its content is absorbed into the book-level distillation's pedagogical framework and surfaces implicitly in the traversal sequences of all three systems.

**Chapter 2** (pp. 4–8) is the primary source for the ii V I comping system's chord vocabulary and both named comping rhythms (Freddie Green, Charleston), including their structural definitions and combination logic.

**Chapter 3** (pp. 9–10) contributes the picking-hand pattern vocabulary (bass-first, melody-first) and the variation-and-transposition prescription, captured in the `_pending:self-extension-variation` modification rule. The bass-first and melody-first patterns themselves are not modeled as discrete system members in the current draft; they are subsumed under the picking-pattern variation rule. A future revision may warrant extracting them as named members of the comping system.

**Chapter 4** (pp. 11–13) is the primary source for approach chords (above, below, mandatory resolution), lead-sheet color expansion, chromatic displacement mechanics, and the rhythm/pattern variation rule.

**Chapter 5** (pp. 14–16) is the primary source for the Two-Shape Major Scale Fretboard System, including the harmonic justification (single scale over ii V I), the two positional shapes, and the individual-then-combined practice sequence.

**Chapter 6** (pp. 17–21) is the primary source for the 134 chromatic ornament pattern, its trigger condition, mandatory resolution law, earn-before-restraint acquisition philosophy, and integration practice sequence.

**Chapter 7** (pp. 22–24) is the sole source for the Mixed Solo Texture System, including the ensemble rationale and the four-stage imitation-to-improvisation traversal sequence.

**Chapter 8** (p. 25) contains no load-bearing technical content. By the chapter summary's explicit finding, it consists entirely of promotional and motivational material directing students to the author's free study group. It did not yield any system, member, rule, or citation.
