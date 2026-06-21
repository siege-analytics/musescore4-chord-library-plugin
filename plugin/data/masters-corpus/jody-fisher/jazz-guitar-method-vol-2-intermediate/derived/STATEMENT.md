---
run_id: 2026-05-28T15-05-20-fisher-jazz-guitar-method-vol-2
stage: s4
source_pdf: Fisher, Jody - Jazz Guitar Method, Vol 2 (Intermediate).pdf
model: claude-sonnet
extracted_at: 2026-05-29T06:08:47+00:00
schema_version: 0.1
---

# Jazz Guitar Method, Vol. 2: Intermediate (Jody Fisher) — Statement of Outputs

## Overview

*Jazz Guitar Method, Vol. 2: Intermediate* by Jody Fisher is a structured method for guitarists who already have foundational technique and are ready to enter the harmonic and improvisational language of jazz. The book's organizing spine is the **ii-V7-I progression**—introduced in Chapter 1 and never released from center stage—which serves as the harmonic substrate onto which every subsequent topic is grafted: chord voicing rules, comping technique, lick vocabulary, blues, rhythm changes, and turnarounds. The arc is explicitly cumulative: each chapter either introduces a new harmonic context or adds a new layer of vocabulary to apply over frameworks already in place, and Chapter 6 makes the pedagogy visible by naming it directly—students are asked to internalize the sound of rhythm changes with familiar scales *before* tackling the advanced alterations that arrive later.

The method's deepest prescription is the **hear-first principle**, crystallized in Chapter 9 but present as an underlying ethic throughout: improvisation is not pattern execution but creative reorganization of learned vocabulary, and that reorganization must be initiated by the brain—by hearing the musical idea—before the fingers execute it. Supporting this principle is a concrete technical program: single-string scale and arpeggio practice to escape positional thinking, singing along with playing to train the inner ear, and the relentless **learn-transpose-apply cycle** by which every lick or turnaround must be transposed to all twelve keys and inserted into real solos immediately. The book closes with a capstone prescription for advanced development: study one artist deeply and comprehensively—biography, compositions, transcribed solos, repeated listening—before moving on, making immersion depth the mark of mature musicianship.

Three interlocking systems emerge from the method: a harmonic framework built around the ii-V7-I progression with precise rules about which tones are essential and which may be altered or omitted; a lick-based improvisation vocabulary system organized by chord type, with blues and turnaround categories as specialized subsystems; and a swing comping texture system that governs the guitarist's rhythmic and social role when accompanying. Together these systems encode not just what to play, but how to think about what to play.

---

## Systems

## ii-V7-I Harmonic Framework

The ii-V7-I Harmonic Framework is the book's central load-bearing system. It organizes all harmonic and improvisational activity around the three chord-function roles—minor (ii), dominant (V7), and major tonic (I)—plus the altered and extended variants available at each slot. The system establishes what may be voiced, what must be retained, what may be omitted or altered, and how progressions are navigated across the fingerboard. All lick vocabulary, blues material, rhythm changes, and turnaround content in the book is subsequently grafted onto this framework.

**Members:**
- **ii chord (minor function):** Minor seventh chord a perfect fourth below the V7; typically Dmin7 or Dmin9 in examples.
- **V7 chord (dominant function):** Dominant seventh chord; the primary site of alteration and extension (7b5, 7#5, 7b9, 9th, 11th, 13th).
- **I chord (tonic function):** Major tonic chord that the progression resolves into, and whose major scale governs diatonic improvisation.
- **Altered/Extended Chord Variant:** Any ii, V7, or I chord with a raised or lowered 5th, 9th, or 11th; still counts as ii-V7-I if roots are a perfect fourth apart and qualities remain minor/dominant/major respectively.

**Traversal Rules:**

- **String-Set Shift for ii-V7-I** (`StringSetTransition`): Voice the ii-V7-I progression on each of the three string sets (6-5-4-3, 5-4-3-2, 4-3-2-1) and shift across sets to cover the full fingerboard. (Chapter 3 summary; Chapter 4 summary)

- **Position-Naming Continuity — lowest-root naming** (`PositionContinuity`): Identify all fingerings by the string and finger holding the lowest root (e.g., "6/2" for sixth string, second finger). (Chapter 1 summary)

- **Target-Note Melodic Motion — spelling out the changes** (`VoiceMotion`): Begin each improvised phrase on a chord tone, preferring 3rds and 7ths, to articulate harmonic voice motion through the progression. (Chapter 2 summary)

- **Maj7-from-b7 Arpeggio Over V7** (`VoiceMotion`): Over V7, play a Major 7th arpeggio rooted on the flat-7 degree of that chord to voice its upper extensions (9th, 11th, 13th). The arpeggio need not start on the root. (Chapter 3 summary)

- **Ascending Lines from Chord Tones** (`VoiceMotion`): Play ascending scalar lines beginning on a chord tone; optionally alternate with descending lines for melodic contour variety. (Chapter 3 summary)

**Modification Rules:**

- **3rd and 7th Density Floor — Essential Tones** (`DensityFloor`): Any voiced chord must retain the 3rd and 7th; these tones define chord quality and are non-expendable. (Chapter 2 summary)

- **Root and 5th Omission Allow** (`OmissionAllow`): Roots, 5ths, 9ths, and 11ths may be omitted; rootless voicings are preferred when more extensions are needed or when a bass player covers the root. (Chapter 2 summary; Chapter 3 summary)

- **Alterable Tones Ceiling — 5th/9th/11th Only** (`DensityCeiling`): Only the 5th, 9th, and 11th may be raised or lowered; no other chord degrees can be altered. (Chapter 2 summary)

- **Diminished Triad Substitution Over V7** (`SubstitutionExpand`): Over V7, substitute a diminished triad from the 3rd, 5th, or 7th of that chord to produce altered extensions that resolve convincingly into I. (Chapter 3 summary)

- **7b9 Rootless Minor-Third Symmetry** (`SymmetryMovement`): A rootless dominant 7b9 voicing moves at minor-third intervals around the fingerboard without changing the chord's quality—a practical fingerboard shortcut. (Chapter 2 summary)

- **Upper Extensions as Color Tones — 9th, 11th, 13th** (`ColorToneRequire`): On V7 chords, 9th/11th/13th extensions are required for jazz color; the Maj7-from-b7 arpeggio technique is the primary delivery mechanism. (Chapter 3 summary; Chapter 2 summary)

- **Context-and-Ear Substitution Constraint** (`_pending:ear-context-gate`): Chord substitutions are valid only when they sound good in context; theoretical correctness alone does not justify a substitution. (Chapter 2 summary)

- **Major-Scale Rule with Altered-Chord Exception** (`FamilyCoherence`): Use the I-chord major scale over diatonic ii-V7-I progressions. Suspend this rule entirely if any chord in the progression contains altered tones (raised or lowered 5ths, 9ths, or 11ths) that fall outside that major scale. (Chapter 1 summary)

---

## Lick-Based Improvisation Vocabulary System

The Lick-Based Improvisation Vocabulary System organizes the book's approach to building and deploying an improviser's personal vocabulary. The foundational philosophy, stated explicitly in Chapter 3, is that improvisation is *creative reorganization of learned vocabulary*—licks function as words, scales as alphabet. The system's members are four chord-type lick families (major, minor, dominant, half-diminished) plus two specialized categories (blues scalar tools, turnaround licks). Traversal rules govern how a soloist moves through a progression by deploying those licks. The central modification rule—learn-transpose-apply—is the engine of the entire method.

**Members:**
- **Major-Type Chord Lick Family:** Licks applicable over major 7th, 6th, 9th, and 13th chords.
- **Minor-Type Chord Lick Family:** Licks applicable over minor seventh and related minor voicings.
- **Dominant-Type Chord Lick Family:** Licks applicable over unaltered dominant 7th, 9th, 11th, and 13th chords.
- **Half-Diminished (min7b5) Lick Family:** Licks for the min7b5 chord; introduced as ear-training for an unfamiliar sound.
- **Blues Scalar Tool Set:** Minor pentatonic scale, blues scale, and Mixolydian mode as the three primary soloing tools over I-IV-V7 blues progressions.
- **Turnaround Lick Family:** Melodic phrases designed to create smooth harmonic transitions at first endings and tune conclusions; the guitarist's choice of turnaround governs how other players react.

**Traversal Rules:**

- **Neighbor-Tone Approach into Target Notes** (`VoiceMotion`): Approach each target chord tone with a half-step or whole-step neighbor tone above or below. (Chapter 2 summary)

- **Ascending/Descending Melodic Contour Alternation** (`_pending:melodic-contour-alternation`): Alternate ascending and descending lick patterns to create varied melodic contour. (Chapter 3 summary)

- **Whole-Neck Scale Combination — Anti-Positional** (`PositionContinuity`): Combine scalar tools fluidly across the entire fingerboard rather than staying in a single positional box; the single-string practice discipline (Chapter 9) is the training mechanism. (Chapter 5 summary; Chapter 9 summary)

**Modification Rules:**

- **Learn-Transpose-Apply Cycle** (`_pending:transpose-apply-cycle`): Every lick must be transposed to all twelve keys and immediately inserted into real solos. Appears repeatedly in Chapters 4, 7, and 8. (Chapter 4 summary; Chapter 7 summary)

- **Lick Extension Transfer — Related Voicings** (`SubstitutionExpand`): Licks written for a base chord type transfer to related extensions (major 6th, 9th, 13th; dominant 9th, 11th, 13th) through ear verification. (Chapter 4 summary)

- **Blues Scale Tool Selection — Pentatonic / Blues / Mixolydian** (`ColorToneRequire`): Over I-IV-V7 blues, choose among minor pentatonic, blues scale, and Mixolydian mode as interchangeable scalar color tools. (Chapter 5 summary)

- **Hear-First Initiation Principle** (`_pending:hear-first-initiation`): Every improvised idea must be heard mentally before executed; singing along with playing is the prescribed training mechanism. (Chapter 9 summary)

---

## Swing Comping Texture System

The Swing Comping Texture System governs the guitarist's accompanying role. Its members are four rhythmic-texture states: downbeat downstroke, upbeat upstroke, damped chord, and sustained chord. The aesthetic core is that swing rhythm is *implied* rather than mechanically predictable. A social-context rule adds a hard constraint: simultaneous free comping with a keyboard player is forbidden.

**Members:**
- **Downbeat Downstroke:** Strum direction on downbeats: down stroke.
- **Upbeat Upstroke:** Strum direction on upbeats: up stroke.
- **Damped Chord:** Chord cut short via left-hand pressure release or right-hand palm/wrist damping.
- **Sustained Chord:** Chord allowed to ring through its natural decay.

**Traversal Rules:**

- **Swing Rhythm Implied Accent Cycle** (`TextureCycle`): Cycle accents unpredictably across parts of each measure rather than mechanically; maintain implied-not-stated swing rhythm. (Chapter 3 summary)

**Modification Rules:**

- **No Simultaneous Free Comping with Keyboard** (`_pending:social-role-constraint`): When a keyboard player is present, the guitarist and keyboardist must alternate comping roles rather than both comping freely—doing otherwise produces, in Fisher's words, "a harmonic can of worms." (Chapter 3 summary)

- **Damp/Sustain Control During Rests** (`TextureCycle`): Damp strings during notated rests using left-hand pressure release or right-hand palm damping. (Chapter 3 summary)

---

## Pending Work

The following `_pending:<kebab>` engine_payload kinds appear in the systems-draft and require further specification:

- **`_pending:ear-context-gate`** (ii-V7-I Harmonic Framework, Context-and-Ear Substitution Constraint): Signals that substitution validity is aesthetic/contextual rather than computable from theory. The engine representation for an "ear gate" or perceptual filter has not yet been defined.

- **`_pending:melodic-contour-alternation`** (Lick-Based Improvisation Vocabulary System, Melodic Contour Alternation): Signals a directional-sequence preference (alternate up/down) that doesn't map cleanly onto an existing traversal kind.

- **`_pending:transpose-apply-cycle`** (Lick-Based Improvisation Vocabulary System, Learn-Transpose-Apply Cycle): Signals a procedural practice loop operating over twelve transpositions—a practice-method rule with no existing engine-kind for iterative transposition cycles.

- **`_pending:hear-first-initiation`** (Lick-Based Improvisation Vocabulary System, Hear-First Initiation Principle): Signals a cognitive-initiation ordering constraint (brain precedes fingers). No existing engine kind captures the ordering between internal audiation and physical execution.

- **`_pending:social-role-constraint`** (Swing Comping Texture System, No Simultaneous Free Comping with Keyboard): Signals a social/ensemble coordination constraint dependent on another player's presence and behavior. A social-role or ensemble-coordination kind is needed.

---

## Provenance Notes

**ii-V7-I Harmonic Framework** is drawn from Chapters 1, 2, and 3, with secondary support from Chapter 4. Chapter 1 provides the foundational rule (major scale over diatonic ii-V7-I; altered-chord exception), the position-naming convention (6/2 system), and the definition of arpeggios. Chapter 2 provides the essential/expendable tone distinction, the alterable-tones ceiling, rootless-voicing rules, the 7b9 minor-third symmetry, the target-note technique, and the context-and-ear substitution constraint. Chapter 3 contributes the string-set shift framework, the Maj7-from-b7 arpeggio technique, ascending lines from chord tones, the diminished-triad substitution over V7, and upper extensions as color tones.

**Lick-Based Improvisation Vocabulary System** is drawn from Chapters 2, 3, 4, 5, 7, 8, and 9. Chapter 3 provides the foundational philosophy. Chapter 4 provides the four chord-type lick families and the learn-transpose-apply cycle. Chapter 2 provides neighbor-tone approach. Chapter 5 provides the blues scalar tool set and anti-positional principle. Chapters 7 and 8 reinforce learn-transpose-apply in the turnaround context. Chapter 9 provides hear-first initiation and the single-string practice method.

**Swing Comping Texture System** is drawn entirely from Chapter 3.

**Chapters not yielding a dedicated system:**
- **Chapter 6 (Rhythm Changes):** Functions as an *application context* for systems already in place. Its primary contribution is the meta-pedagogical principle of *deferred complexity* (use familiar scales first), captured in the book-level distillation but not constituting a new system with members and rules.
- **Chapter 8 (Turnaround Solos / Synthesis Pieces):** Reinforces and applies the Turnaround Lick Family established in Chapter 7; its "Misty"-based synthesis pieces are capstone applications rather than new systems. Content is captured under the Lick-Based Improvisation Vocabulary System's turnaround-lick-family member.
- **Chapter 9 (Coda):** Meta-level practice strategies (hear-first, single-string practice, deep-artist study, focused-rotation practice). Its prescriptions are distributed as modification rules within the Lick-Based Improvisation Vocabulary System rather than constituting a distinct system.
