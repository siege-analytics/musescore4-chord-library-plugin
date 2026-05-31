---
run_id: 2026-05-28T15-05-20-laukens-beginners-guide
stage: s4
source_pdf: Laukens, Dirk - The Beginner's Guide to Jazz Guitar.pdf
model: claude-sonnet
extracted_at: 2026-05-31T16:27:57+00:00
schema_version: 0.1
---

# The Beginner's Guide to Jazz Guitar — Statement of Outputs

## Overview

*The Beginner's Guide to Jazz Guitar* by Dirk Laukens is a structured self-teaching method that moves a player from zero jazz vocabulary to functional improvisation and arrangement through a deliberate four-stage arc: harmonic foundation, rhythmic application, melodic improvisation, and synthesis in real repertoire. The book's central pedagogical commitment is depth over breadth — five canonical jazz standards and five chord qualities receive thorough treatment rather than a survey of many. The ear-first methodology runs throughout: the student is directed to listen to recordings before touching the fretboard, and named masters (Charlie Christian, Joe Pass, Kenny Burrell) are presented not as biographical figures but as technique templates to be absorbed and deployed.

The book operates on two interlocking master systems. The first is a moveable-root harmonic system in which every chord shape is anchored by a red-dot root, making transposition automatic ("root = chord name"). The second is a function-assigned scale and arpeggio system governed by Joe Pass's aphorism "When the chords change, you change" — scale and arpeggio selection is chord-specific rather than key-global. These two systems are complementary: the first governs comping and chord knowledge; the second governs improvisation choices. Two smaller systems — a Comping Rhythm system and a Chord-Melody Texture system — specify how chords are deployed rhythmically and how a solo guitarist arranges melody, harmony, and bass simultaneously.

The Roman numeral notation appendix (Chapter 7) supplies the labeling infrastructure the entire book presupposes: capital numerals (I, V7) for major and dominant chords; small numerals (ii, iii, vi, vii°) for minor and diminished. This notational layer is not instructional content but the grammar through which all chord charts in the book are read.

---

## Systems

### System 1: Moveable-Root Chord System

Every chord in the book is treated as a transposable unit defined by a single red-dot root position. Five chord qualities — major 7, dominant 7, minor 7, half-diminished 7, and diminished 7 — form the complete taxonomy. Because the root dot determines the chord's name, any shape can be slid to any fret to produce all twelve transpositions without learning new fingerings. These five qualities are organized functionally around the ii–V–I–vi progression derived from the major scale, and the system governs both chord construction and the comping figures that animate those chords in accompaniment. The Roman numeral system (Chapter 7) supplies the labeling infrastructure, encoding chord quality through capitalization.

**Members**
- Major 7 Chord (`maj7`) — tonic major quality; capital Roman numeral Imaj7
- Dominant 7 Chord (`dom7`) — unstable dominant quality; capital Roman numeral V7
- Minor 7 Chord (`min7`) — minor quality; small Roman numeral ii or vi
- Half-Diminished 7 Chord (`half-dim7`) — minor ii chord in minor key contexts; small Roman numeral with ø
- Diminished 7 Chord (`dim7`) — symmetrical chord; only two moveable grips required due to symmetry

**Traversal Rules**

- Root = Chord Name Transposition Rule — Move any shape so the red-dot root lands on the desired pitch; the chord's name follows automatically. Engine payload: `PositionContinuity`. (Chapter 1 summary; ch01.md — "the red note...tells you what the name of the chord is," p. 15)

- ii–V–I–vi Functional Progression Order — Chords are connected in the ii–V–I–vi sequence derived from the major scale. Engine payload: `FamilyCoherence`. (Chapter 1 summary; ch01.md — "These chords...are found in countless jazz standards," p. 15)

**Modification Rules**

- Tritone Substitution — Replace any dominant 7 chord with another dominant 7 a tritone away; the shared 3rd and 7th preserve harmonic function. Engine payload: `SubstitutionExpand`. (Chapter 5 summary; ch05.md — "play another 7th chord that occurs a tritone (#4 aka b5) away," p. 105)

- Color Tone Embellishment — Basic dominant 7 chord symbols on lead sheets may be expanded with 9ths, 13ths, and 6ths. Engine payload: `ColorToneRequire`. (Chapter 6 summary; ch06.md — "those chords can be embellished with 9ths, 13ths, 6ths, and other color tones," p. 159)

- Diminished Symmetry Grip Reduction — Because diminished 7 chords are symmetrical, only two moveable grips are required to cover all 12 keys. Engine payload: `SymmetryMovement`. (Chapter 3 summary; ch03.md — "You only need to learn 2 grips for diminished chords because diminished chords are symmetrical," p. 70)

- Minor Blues Turnaround Substitution Variants — The turnaround of a minor blues admits three standard substitution families: bVI–V–I, ii–V–I, and biii–bVI/ii–V–I. Engine payload: `SubstitutionExpand`. (Chapter 2 summary; ch02.md — "variations include bVI-V-I, ii-V-I, or even biii-bVI/ii V/I," p. 30)

- Sus Chord Dominant Delay — Replace or precede a dominant chord with its sus version to add rhythmic tension and delay resolution. Engine payload: `_pending:suspension-delay`. (Chapter 6 summary; ch06.md — "Sus chords are a nice way to delay and bring extra motion to dominant chords," p. 178)

---

### System 2: Function-Assigned Scale and Arpeggio System

The book's improvisation system assigns specific scales and arpeggios to specific harmonic functions rather than to a key center. Joe Pass's aphorism "When the chords change, you change" is the governing traversal rule: a player moving through a progression must shift their scale or arpeggio choice chord by chord, not hover on a single tonic scale. This system covers four scales and four arpeggio types and specifies numerous modification rules — some prescribing which scale handles which altered dominant, others permitting strategic omissions, and others expanding through substitution. Approach notes and enclosures operate as melodic decoration rules within this system, controlling how the player connects and embellishes chord tones.

**Members**
- Major Blues Scale — major pentatonic + b3
- Natural Minor / Aeolian
- Harmonic Minor
- Melodic Minor
- Phrygian Dominant Scale — fifth mode of harmonic minor
- Lydian Dominant Scale
- Minor 7 Arpeggio (`min7-arpeggio`)
- Dominant 7 Arpeggio (`dom7-arpeggio`)
- Major 7 Arpeggio (`maj7-arpeggio`)
- Diminished 7 / 3-to-9 Arpeggio (`dim7-arpeggio-3-to-9`)

**Traversal Rules**

- Chord-Specific Scale Change Rule — Scale selection must change with each chord change. Engine payload: `FamilyCoherence`. (Chapter 4 summary; ch04.md — "When the chords change, you change," p. 95)

- Arpeggio Proximity Voice-Leading Rule — Connect arpeggios by nearness of pitches rather than restarting from the root. Engine payload: `VoiceMotion`. (Chapter 3 summary; ch03.md — "switch to the nearest note of the second arpeggio," p. 61)

- Arpeggio Free-Start and Free-Order Rule — Arpeggios may be started on any chord tone and played in any order. Engine payload: `_pending:free-start-order`. (Chapter 3 summary; ch03.md — "Arpeggios can be started on any note and played in any order," p. 62)

- Minor Pentatonic Whole-Progression Bridge — On Summertime and similar minor progressions, the minor pentatonic or blues scale may traverse the entire form without chord-specific switching. Engine payload: `_pending:whole-progression-scalar`. (Chapter 2 summary; ch02.md — "you can use the minor pentatonic or minor blues scale to solo over this entire progression," p. 33)

**Modification Rules**

- Tonic Harmonic Minor over V7alt — Over V7alt in minor ii–V–I, use tonic harmonic minor rather than the chord's root harmonic minor. Engine payload: `ColorToneRequire`. (Chapter 4 summary; ch04.md — "you use the tonic harmonic minor scale," p. 87)

- Melodic Minor Raised-7th as Deliberate Tension — The raised 7th of melodic minor over Im7 is a context-dependent expressive choice. Engine payload: `ColorToneRequire`. (Chapter 4 summary; ch04.md — "experiment with this scale...where you want to use that raised 7th," p. 90)

- Major Blues Scale No-Clash Rule — Lacking a 7th, the major blues scale can be applied over both dominant 7 and major 7 chords without harmonic collision. Engine payload: `OmissionAllow`. (Chapter 4 summary; ch04.md — "Because there is not 7th in this scale, it can be applied to both G7 and Gmaj7 chords," p. 83)

- Phrygian Dominant as First-Choice V7 Scale — In bebop contexts, phrygian dominant is the primary color source over V7 and V7alt. Engine payload: `ColorToneRequire`. (Chapter 5 summary; ch05.md — "phrygian dominant scale is a first-choice sound when improvising over V7 and V7alt chords," p. 101)

- 3-to-9 Arpeggio Substitution — A diminished 7 arpeggio built from the 3rd of any 7th chord outlines the intervals 3–5–b7–b9. Engine payload: `SubstitutionExpand`. (Chapter 5 summary; ch05.md — "When playing a dim7 arpeggio from the 3rd of any 7th chord, you'll outline the 3-5-b7-b9 intervals," p. 104)

- Approach Note Chromatic Resolution Rule — Approach any chord tone from one fret below; the chromatic neighbor must resolve to a chord tone. Engine payload: `NCTHarmonization`. (Chapter 3 summary; ch03.md — "approach any note in an arpeggio by one fret below," p. 74)

- Enclosure Decoration — Surround the target chord tone with one fret above and one fret below before landing. Engine payload: `NCTHarmonization`. (Chapter 3 summary; ch03.md — "you play one fret above, then one fret below, then the chord tone," p. 76)

- Side-Stepping Minor Pentatonic Pair — Alternate two minor pentatonic scales a half step apart over a single 7th chord to produce modern jazz texture. Engine payload: `StringSetTransition`. (Chapter 5 summary; ch05.md — "Playing between two minor pentatonic scales over a 7th chord, a 1/2 step apart," p. 114)

- b3 / 3 Mixing for Jazz-Blues Color — Mix the minor blues b3 with the Mixolydian major 3rd to produce the characteristic jazz-blues sound. Engine payload: `ColorToneRequire`. (Chapter 6 summary; ch06.md — "Mixing b3 and 3 is often used by jazz musicians to create a bluesy sound," p. 182)

- Lydian Dominant over Tritone Substitute — On a tritone substitute chord, use the Lydian Dominant scale (= altered scale of the original chord). Engine payload: `SubstitutionExpand`. (Chapter 6 summary; ch06.md — "B Lydian Dominant scale (= F Altered scale). B7 is the tritone substitute of F7," p. 183)

- Harmonic Minor over Dom 7b9 — Use harmonic minor over a dominant 7 chord to produce the 7b9 color. Engine payload: `ColorToneRequire`. (Chapter 6 summary; ch06.md — "uses the G Harmonic Minor scale over D7, creating a 7b9 sound," p. 184)

---

### System 3: Comping Rhythm and Texture System

This system governs how chords are deployed rhythmically in accompaniment. It defines four comping figures as the player's palette and specifies rules for muting, metronome discipline, and ensemble alignment. The figures are not optional variety but constitute a rotating set to be cycled deliberately once chord changes are internalized.

**Members**
- Freddie Green Rhythm — steady four-to-the-bar with accents on 2 and 4
- Beats 2 and 4 Comping
- Anticipation — next bar's chord on the & of 4
- Charleston Pattern

**Traversal Rules**

- Comping Rhythm Figure Cycling — After learning chord changes, vary between the four comping figures rather than repeating one. Engine payload: `TextureCycle`. (Chapter 1 summary; ch01.md — "After you can play these chords and rhythms, change the rhythms," p. 24)

- Hi-Hat Ensemble Alignment — Beats-2-and-4 comping aligns with the drummer's hi-hat for ensemble swing. Engine payload: `_pending:ensemble-alignment`. (Chapter 1 summary; ch01.md — "line up with the hi-hat on the drum kit," p. 21)

**Modification Rules**

- Chord Cutoff Before Beats 2 and 4 — In Freddie Green rhythm, chords struck on beats 1 and 3 must be muted before they ring over onto beats 2 and 4. Engine payload: `_pending:duration-cutoff`. (Chapter 1 summary; ch01.md — "cut the chords off so they don't ring over on beats 2 and 4," p. 20)

- Metronome Requirement for Syncopated Figures — Syncopated comping figures (anticipation, Charleston) must be practiced with a metronome; rushing is the named failure mode. Engine payload: `_pending:practice-constraint`. (Chapter 1 summary; ch01.md — "work with a metronome and go slow until you're ready to speed this pattern," p. 22)

---

### System 4: Chord-Melody Texture System

This is the book's arrangement system for solo guitar performance of jazz standards. It defines a three-layer architecture — bass on the lower strings, chord voicings in the middle register, melody confined to the upper strings — and specifies how a single guitarist integrates accompaniment and improvisation into one continuous texture. Two named traversal rules govern how layers move in relation to each other: contrary motion (Chapter 6) and the Joe Pass bass/treble split (Chapter 5). Two modification rules govern what may occupy each layer and how texture may shift within a chorus.

**Members**
- Bass Layer — lower strings
- Chord Voicing Layer — middle register
- Melody Layer — upper strings

**Traversal Rules**

- Contrary Motion Voice Leading — Prefer contrary motion between bass and inner voices when moving between chords. Engine payload: `VoiceMotion`. (Chapter 6 summary; ch06.md — "Contrary motion in voice leading sounds nice," p. 178)

- Joe Pass Bass/Treble Split with Chord Accent — Alternate a bass note with the top chord voicing; accent only the chord portion, not the bass. Engine payload: `TextureCycle`. (Chapter 5 summary; ch05.md — "break up the chord into the bass note and the top 3 notes of the shape," p. 128)

**Modification Rules**

- Melody Confinement to Upper Strings — Melody must be moved to the top two strings to allow chord voicings to occupy the middle register below. Engine payload: `DensityFloor`. (Chapter 2 summary; ch02.md — "melody has been moved to mostly the top 2 strings," p. 43)

- Kenny Burrell Chord / Single-Note Mixing — Within a chorus, intersperse three-note chord shapes with single-note blues-scale lines. Engine payload: `TextureCycle`. (Chapter 6 summary; ch06.md — "mixing chords and single-lines during each phrase of an improvised chorus," p. 185)

---

## Pending Work

The following `_pending` engine payload kinds appear in the systems-draft and indicate engine behavior identified structurally but not yet mapped to a resolved payload type:

- `_pending:suspension-delay` (Moveable-Root Chord System / Sus Chord Dominant Delay) — A rule type for temporarily withholding harmonic resolution by substituting or preceding a dominant chord with its suspended version. The engine does not yet have a formalized payload kind for temporal delay of chord function.
- `_pending:free-start-order` (Function-Assigned Scale and Arpeggio System / Arpeggio Free-Start and Free-Order Rule) — A rule type for unconstrained entry point and traversal sequence within a set; distinct from proximity voice-leading.
- `_pending:whole-progression-scalar` (Function-Assigned Scale and Arpeggio System / Minor Pentatonic Whole-Progression Bridge) — A rule type for applying a single scalar source across an entire progression without chord-specific switching; the exception to `FamilyCoherence`.
- `_pending:ensemble-alignment` (Comping Rhythm and Texture System / Hi-Hat Ensemble Alignment) — A rule type for synchronizing a guitar comping figure to an external rhythmic reference (the drummer's hi-hat); an inter-voice ensemble constraint with no current solo-instrument payload equivalent.
- `_pending:duration-cutoff` (Comping Rhythm and Texture System / Chord Cutoff Before Beats 2 and 4) — A rule type for enforcing a maximum sustain duration on a voiced chord; distinct from articulation in that it constrains when a chord must end relative to a metric position.
- `_pending:practice-constraint` (Comping Rhythm and Texture System / Metronome Requirement for Syncopated Figures) — A pedagogical prescription rather than a harmonic or textural rule; signals a category of learning-protocol constraint that may not belong in a performance-facing engine payload at all.

---

## Provenance Notes

The four systems and all rules, members, traversal rules, and modification rules are derived exclusively from the book-level distillation (aggregated from per-chapter summaries) and the chapter-level summaries (ch01.md through ch07.md). Page numbers in citations come from the systems-draft JSON's `quote_excerpt` references, tied to the source PDF.

Chapter-to-system mapping:

- Chapter 1 (Jazz Guitar Chords, pp. 8–28) — primary source for the Moveable-Root Chord System (traversal rules, five-quality taxonomy) and the Comping Rhythm System (all four members, both modification rules, hi-hat alignment rule).
- Chapter 2 (Playing Jazz Standards, pp. 29–47) — Minor Blues Turnaround Substitution Variants, Melody Confinement rule, Minor Pentatonic Whole-Progression Bridge. The ear-first and depth-over-breadth principles informed the overall arc but did not resolve to a discrete system.
- Chapter 3 (Jazz Guitar Arpeggios, pp. 48–82) — primary source for arpeggio members and rules in the Scale and Arpeggio System: Proximity Voice-Leading, Free-Start and Free-Order, Approach Note Chromatic Resolution, Enclosure Decoration; Diminished Symmetry Grip Reduction in the Moveable-Root System.
- Chapter 4 (Jazz Guitar Scales, pp. 83–95) — Chord-Specific Scale Change Rule and the four scale-assignment modification rules.
- Chapter 5 (Jazz Guitar Licks, pp. 96–156) — Tritone Substitution, Phrygian Dominant V7 Assignment, 3-to-9 Arpeggio Substitution, Side-Stepping Pentatonic Pair, Joe Pass Bass/Treble Split.
- Chapter 6 (Jazz Blues, pp. 157–191) — Color Tone Embellishment, Sus Chord Dominant Delay, b3/3 Mixing, Lydian Dominant over Tritone Substitute, Harmonic Minor over Dom 7b9, Contrary Motion Voice Leading, Kenny Burrell Chord/Single-Note Mixing. The three-stage blues solo practice method (imitation → composition → ear training) informs the book-level arc but does not resolve to a separate system.
- Chapter 7 (Appendix — Roman Numeral System, pp. 192–197) — contributed no standalone system. It is a reference appendix providing notational infrastructure (capital vs. small Roman numerals encoding chord quality) that the Moveable-Root Chord System presupposes; cited in the Overview rather than assigned its own system entry.
