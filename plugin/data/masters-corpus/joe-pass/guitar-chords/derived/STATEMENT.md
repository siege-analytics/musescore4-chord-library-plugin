---
run_id: 2026-06-03T05-51-57-pass-guitar-chords
stage: s4
source_pdf: Pass, Joe - Guitar Chords (2005).pdf
model: claude-sonnet
extracted_at: 2026-06-03T06:02:36+00:00
schema_version: 0.1
---

# Joe Pass Guitar Chords — Statement of Outputs

## Overview

*Joe Pass Guitar Chords* (2005) is a compact but dense practical reference for jazz guitarists, organized in two chapters that together constitute a vocabulary-then-application curriculum. Chapter 1 presents Pass's complete working voicing inventory as a silent catalog of fretboard diagrams across six chord-sound categories — Seventh, Augmented, Minor, Diminished, Minor Seventh Flat Fifth, and Major/Dominant Alteration forms — with pitch labels beneath each diagram and no prose instruction. Chapter 2 immediately deploys that catalog in seven distinct harmonic contexts, showing how the six categories interact in real jazz progressions. The pedagogical architecture is inductive and mimetic: the student absorbs shapes first through visual inspection and memorization, then watches those shapes move through functional harmonic situations before inferring the governing logic.

The book's core teaching is that harmonic color in jazz can be organized into a small set of sound-categories whose members are not fixed chords but mobile voicing resources, interchangeable and substitutable according to a handful of governing principles. These principles — tritone substitution for major-sound resolution, diminished forms as dominant-7b9 substitutes, augmented sounds as chromatic approach vehicles into cycle cadences, and common-tone sustain of lead notes across changes — are not stated abstractly. They emerge from the notated passages in Chapter 2, embedded in specific examples the player must read, finger, and internalize. The book does not offer graded exercises or step-by-step drilling; it offers a compressed window into one player's functional harmonic vocabulary.

One explicit prescriptive rule governs notation throughout: chord-symbol qualifier order equals voice order (e.g., D7+9+5 means D7 with the raised ninth in the next voice above the core and the raised fifth on top). This proprietary convention is load-bearing for the entire book — it is the decoding key for every altered chord diagram in Chapter 1 and every passage symbol in Chapter 2. A secondary prescription, given as a NOTE in Chapter 2, instructs the player to sustain top-voice lead notes from one chord to the next, establishing common-tone retention as an idiomatic comping principle. These two rules, one syntactic and one performative, together with the six-category taxonomy and the seven harmonic contexts, constitute the complete teachable content of the work.

---

## Systems

### System 1: Six Chord-Sound Category System

Pass organizes the entirety of his harmonic vocabulary into six chord-sound categories whose members are not merely chord types but functional roles within jazz harmony. The six categories form the taxonomic spine of the book: Chapter 1 presents each category as a silent voicing catalog, and Chapter 2 shows how members of those categories traverse into and modify one another across real progressions. The underlying harmonic armature against which all motion is measured is the cycle of fifths and the ii-V-I skeleton. Traversal between categories is governed by common-tone sustain, chromatic approach motion, and cycle-of-fifths movement; modification rules govern which members of one category may substitute for or approach members of another. The result is a closed but flexible system in which any functional harmonic situation in jazz can be described as a traversal path through the six categories, modified by substitution or approach logic. (Chapter 1 summary; Chapter 2 summary.)

**Members:**
- **Seventh Chord Forms** — Dominant and major seventh voicings; primary origin and target of cycle progressions and turnarounds.
- **Augmented Chord Forms** — Augmented voicings used as chromatic approach chords resolving into cycle cadences.
- **Minor Chord Forms** — Minor triad and minor seventh voicings; function as ii chords and harmonic color in minor-key passages.
- **Diminished Chord Forms** — Fully diminished voicings treated as mobile approach chords with multiple resolution targets; interchangeable with dominant 7b9 sounds.
- **Minor Seventh Flat Fifth (Half-Diminished) Forms** — Half-diminished voicings; function as iio in minor iio-V7b9 cadences, resolving to dominant and augmented forms.
- **Major and Dominant Alteration Forms** — Altered dominant and major voicings including tritone substitutes and upper-structure alterations; primary tonic-resolution targets.

**Traversal Rules:**

1. **Common-Tone Lead-Note Sustain** — When moving between any two chord-sound categories, sustain the top voice (lead note) if it is common to both chords, creating smooth voice-leading across the change. Engine payload kind: `VoiceMotion`. (Chapter 2 summary; ch02.md, p. 24: *"Try to sustain lead notes from one chord to the next."*)

2. **Chromatic Bass-Line Approach Motion** — Traverse from minor-seventh or augmented members to their resolution targets via chromatic bass-line motion. Engine payload kind: `VoiceMotion`. (Chapter 2 summary; ch02.md, p. 15: *"movement in Dm7, resolving into Ab13 to G13"*; *"Movement is used chromatically to get to the basic cycle."*)

3. **Cycle-of-Fifths Seventh Movement** — Traverse between seventh-category members by following the cycle of fifths, which serves as the default harmonic armature for seventh-chord passages. Engine payload kind: `_pending:cycle-motion`. (Chapter 2 summary; ch02.md, p. 15: *"followed by a cycle seventh movement"*; *"chromatically to get to the basic cycle."*)

4. **Diminished Chord Multi-Target Resolution** — A diminished member may resolve to any of several chord targets, allowing free traversal from diminished to multiple destination categories. Engine payload kind: `_pending:multi-target-resolution`. (Chapter 2 summary; ch02.md, p. 15: *"Resolve the last chord in this sequence into any chord."*)

5. **Half-Diminished to Dominant and Augmented Resolution** — Traverse from minor-seventh-flat-fifth members through dominant 7b9 forms to augmented resolution, as in the iio-V7b9-aug cadence. Engine payload kind: `FamilyCoherence`. (Chapter 2 summary; ch02.md, p. 15: *"A7b9 to Dm7b5 resolving finally to G aug"*; *"Dm7b5 chords to G aug."*)

**Modification Rules:**

1. **Tritone Substitute for Major-Sound Resolution** — A dominant seventh chord may be replaced by its tritone substitute when resolving to a major-sound tonic, with upper voices resolving by half-step. Engine payload kind: `SubstitutionExpand`. (Chapter 2 summary; ch02.md, p. 15: *"G13b5 (or Db7+9b5) which resolves into Cma9."*)

2. **Diminished Chord as Dominant 7b9 Substitute** — Any diminished voicing may substitute for the dominant 7b9 chord, replacing a seventh-flat-ninth member with a diminished member in the ii-V-I skeleton. Engine payload kind: `SubstitutionExpand`. (Chapter 2 summary; ch02.md, p. 15: *"Use of diminished chords for seventh flat ninth chord movement."*)

3. **Substitute Turnaround Replacement** — A standard I-VI-II-V turnaround may be replaced by a substitute turnaround sequence back to the dominant, introducing alternate harmonic pathways within a single passage. Engine payload kind: `SubstitutionExpand`. (Chapter 2 summary; ch02.md, p. 15: *"substitute turn-around back to G13."*)

4. **Augmented Sustained Color into Chromatic Resolution** — An augmented voicing may be sustained across multiple beats as a color chord and then resolved chromatically into a cycle cadence, functioning as an approach modification of the dominant. Engine payload kind: `ColorToneRequire`. (Chapter 2 summary; ch02.md, p. 15: *"first six chords are basically G aug. Movement is used chromatically."*)

---

### System 2: Chord-Symbol Voice-Order Notation Convention

Pass establishes a proprietary notation rule that governs how every chord symbol in the book must be read and fingered: the left-to-right order of qualifiers in a chord symbol corresponds directly to the bottom-to-top order of voices in the fretboard voicing. Under this convention, a symbol such as D7+9+5 denotes a D7 core with the raised ninth placed in the next voice above the core and the raised fifth placed on top. This is a small, single-member system, but it is load-bearing for the entire work: without internalizing this rule, neither the Chapter 1 diagram catalog nor the Chapter 2 passage notation can be correctly decoded. It is the one explicit procedural prescription the book states as a rule rather than embedding silently in notation or example. (Chapter 2 summary; ch02.md, p. 20.)

**Members:**
- **Chord Symbol String** — A chord symbol such as D7+9+5, where the root and quality appear first, followed by extension and alteration qualifiers listed in ascending voice order.

**Modification Rules:**

1. **Symbol Qualifier Order Equals Voice Layer Order** — Each qualifier appended to a chord symbol designates successive voices from the next available string upward, so that reading the symbol left-to-right maps directly onto the fretboard voicing bottom-to-top. Engine payload kind: `_pending:symbol-voice-mapping`. (Chapter 2 summary; ch02.md, p. 20: *"order of appearance of notes coincides with the spelling of the chord symbol."*)

---

## Pending Work

The following `_pending` engine payload kinds were recorded in the systems-draft and require further specification before the rule logic can be fully implemented:

- **`_pending:cycle-motion`** — Signals that the cycle-of-fifths traversal rule (Cycle-of-Fifths Seventh Movement) requires a formal engine representation of directed fifth-interval motion through a chord-root space. The source material confirms the cycle as the governing armature but does not specify a complete traversal algorithm beyond the examples given.

- **`_pending:multi-target-resolution`** — Signals that the Diminished Chord Multi-Target Resolution rule requires a formal enumeration of the permissible resolution targets for each diminished voicing. The source material establishes that multiple targets are valid and that the resolution is free, but does not bound the target set.

- **`_pending:symbol-voice-mapping`** — Signals that the Symbol Qualifier Order Equals Voice Layer Order rule requires a formal parsing specification: a procedure for reading a chord-symbol string and mapping each successive qualifier onto a specific voice layer in a fretboard voicing model. The source material states the convention clearly but does not supply a generalized algorithm.

---

## Provenance Notes

All content in this statement is drawn directly from two sources: the book-level distillation produced at the s3 stage (aggregated from per-chapter summaries), and the two chapter summaries for Chapter 1 (pages 6-14) and Chapter 2 (pages 15-26) of *Joe Pass Guitar Chords* (2005). The systems-draft JSON derived from those summaries supplied the structural organization; no content has been introduced beyond what those documents contain.

**Chapter 1** did not yield an independent system of its own. Its contribution is the six-category taxonomy and the voicing inventory that populates the Six Chord-Sound Category System; the chapter contains no prose, no rules, and no traversal logic — only the catalog of diagrams that Chapter 2 puts to work. It is therefore represented as the member inventory of System 1 rather than as a system in its own right.

**Chapter 2** is the source of all traversal rules, modification rules, the notation convention, and the seven functional harmonic contexts. All rule citations point to Chapter 2. The page references given in the systems-draft (uniformly p. 15 for the functional contexts, p. 20 for the notation rule, and p. 24 for the lead-note sustain NOTE) reflect the structure of ch02.md as extracted from the source PDF.
