---
run_id: 2026-05-23T23-23-45-orourke-complete-chord-melody
stage: s4
source_pdf: complete_chord_melody.pdf
model: claude-sonnet
extracted_at: 2026-05-23T23:38:58+00:00
schema_version: 0.1
---

---
run_id: 2026-05-23T23-23-45-orourke-complete-chord-melody
stage: s4
source_pdf: complete_chord_melody.pdf
model: claude-sonnet
extracted_at: 2026-05-23T23:32:30+00:00
schema_version: 0.1
---

# Complete Chord Melody (Greg O'Rourke) — Statement of Outputs

## Overview

Greg O'Rourke's *Complete Chord Melody* is a recipe-first, top-down teach-yourself method whose central thesis is stated on page one as a four-step procedure: (1) pick a suitable tune, (2) transpose it into a workable key, (3) learn the melody on the top 2–3 strings, and (4) voice chords below the melody. Every later chapter in the 250-plus-page book is best read as a constraint, lookup table, or escape hatch attached to one of those four steps. The book-level distillation frames the whole enterprise as five interlocking commitments: the four-step recipe as operating system; a Three Harmonic Families taxonomy plus the chord-collection construct that makes vocabulary indexable by melody note; a load-bearing painting-by-numbers rule that executes the lookup; restraint as the aesthetic axiom that runs through every chapter; and a solo-guitar extension that adds bass responsibility to Step 4 along with five named substitution rules for reharmonization and a fingerstyle appendix that underwrites the right hand.

The load-bearing organizing system is the painting-by-numbers lookup: knowing each melody note's interval relative to its underlying chord enables dictionary lookup of a voicing with that interval on top. The chord dictionary is keyed on three inputs — melody string, chord type at that moment, and the melody note's interval relative to that chord — and a dictionary shape is transposed into the tune's key by sliding it until its top note lands on the melody fret. The closed chord-tone vocabulary used as index keys is fixed: 1, b9, 9, b3, 3, 11, #11, 5, b13, 13, b7, 7, plus PT (passing tone) as the explicit escape hatch for unharmonized chromatic notes. The 'golden rule of interval analysis' — intervals relate to the current chord, not the overall key — is named as the most common beginner mistake and elevated to a load-bearing prohibition.

A single aesthetic axiom — restraint — runs through every chapter and is the book's most consistent prescriptive voice. Chapter 1 states it as 'don't harmonize every note,' Chapter 4 restates it as 'less is more' and 'playability over ambition,' and Chapter 7 closes with the rule that subtlety beats density: substitutions are for occasional color, not for filling space. Chapter 4's three remediation strategies — cut notes, substitute diads or octaves, or remove the difficult voicing entirely (the author's most-used escape valve) — express the same axiom as concrete moves. Scope-wise, the book is a contemporary teach-yourself method by an instructor rather than a primary-source jazz-master method: its authority derives from procedural clarity and explicit escape hatches rather than from transcription of a historic player's practice. That positioning is consistent with its voice — procedural, permissive, and explicit about its own failure modes.

## Systems

### Chord-Melody Paint-by-Numbers Method (Four-Step Recipe)

The book's operating system: a four-step chord-melody recipe (pick tune, transpose for range, melody on top strings, voicings below) whose Step 4 is made mechanical by the painting-by-numbers rule — pick voicings whose top note is the same interval as the melody note relative to the underlying chord. Step 1 is constrained by the ballad-not-bebop selection rule (slower tempos with longer-held melody notes are practically easier for beginners). Step 2 is constrained by the range rule of thumb: find a key where the melody sits on the top 3 strings between roughly the 3rd and 9th frets, defended against two named failure modes (too high sounds thin, too low sounds dark and muddy). Step 3 imposes a horizontal rather than positional fretting approach with an explicit carve-out that occasional dips to the 3rd or 4th string are fine. Step 4 places chords on the first melody note of each bar and at chord changes, exploiting the guitar's quick decay so a chord change implies sustain rather than holding the note out.

Members: Step 1: Pick a Suitable Tune; Step 2: Transpose Into a Workable Key; Step 3: Learn the Melody on the Top 2–3 Strings; Step 4: Voice Chords Below the Melody; Closed Chord-Tone Interval Vocabulary (1, b9, 9, b3, 3, 11, #11, 5, b13, 13, b7, 7, PT).

Traversal rules:
- Top-3-Strings, 3rd-to-9th-Fret Range Rule — `PositionContinuity` (Chapter 1 summary; ch01 'Range rule of thumb', 'Range failure modes').
- Horizontal Melody Fingering on Top Strings — `PositionContinuity` (Chapter 1 and Chapter 3 summaries; ch01 'Horizontal melody fingering', ch03 'Top-2-string melody constraint').
- Transpose Dictionary Shape by Sliding to Melody Fret — `SymmetryMovement` (Chapter 4 summary; ch04 'Transpose by sliding shape').

Modification rules:
- Painting-by-Numbers Voicing Selection Rule — `ColorToneRequire` (Chapter 4 summary; ch04 'Painting by numbers rule', 'Adapt voicing for melody').
- Golden Rule: Intervals Relate to Current Chord, Not Key — `_pending:interval-reference-frame` (Chapter 3 summary; ch03 'Golden rule of interval analysis', 'Major scale reference rule').
- Don't Harmonize Every Melody Note — `DensityCeiling` (Chapter 1 summary; ch01 'Don't harmonize every note', 'Place chords on long notes', 'Sustain workaround').
- PT (Passing-Tone) Label as Escape Hatch — `NCTHarmonization` (Chapter 3 summary; ch03 'Passing-tone label', 'Melody anticipates next chord').
- Three Remediation Strategies for Awkward Passages — `OmissionAllow` (Chapter 4 summary; ch04 'Three options for hard passages', 'Diads/octaves alternative', 'Removing chord entirely').
- Playability Over Ambition (Less Is More) — `DensityCeiling` (Chapter 4 summary; ch04 'Less is more', 'Playability over ambition').
- Sanctioned Rhythmic Adjustment of Melody for Fingering — `_pending:melody-rhythm-flex` (Chapter 6 summary; ch06 'Manipulate melody rhythm for fingering').

### Three Harmonic Families Taxonomy

Chapter 2's organizing taxonomy partitions the chord universe into three harmonic families — Major, Minor, and Dominant — with minor refined into m7 and m7b5 sub-families and dominant refined into natural ('7') and altered ('7alt') sub-families. The sub-family distinction is what drives major-versus-minor ii-V-i voicing choice. The chapter formalizes the chord-construction principles that back the taxonomy: a chord symbol is 'an attempt to describe a sound,' chords are built by stacking thirds, and 9/11/13 extensions are explained as continuing to stack thirds past the 7th. A final terminological rule — surrounding chords define a chord's name as much as its notes do — foreshadows the substitution machinery of Chapter 7. Color is localized: the 'jazzy' sound is identified specifically with extensions and tensions added to dominant chords as the targeted chord type for color, consistent with Chapter 8's dictionary structure (a dedicated section for altered/extended dominants as the method's color resource).

Members: Major Family; Minor Family — m7 Sub-Family; Minor Family — m7b5 Sub-Family; Dominant Family — Natural ('7') Sub-Family; Dominant Family — Altered ('7alt') Sub-Family.

Traversal rules:
- Sub-Family Distinction Drives ii-V-i Voicing Choice — `FamilyCoherence` (Chapter 2 summary; ch02 'Minor and dominant sub-families').

Modification rules:
- Stacking Thirds as Construction Principle — `FamilyCoherence` (Chapter 2 summary; ch02 'Stacking thirds', 'Second-octave structures').
- Surrounding Chords Define a Chord's Name — `_pending:context-defined-naming` (Chapter 2 summary; ch02 'Context defines chord name').
- Color Localized in Dominant Extensions and Tensions — `ColorToneRequire` (Chapter 4 summary; ch04 'Tension from dominants').

### Chord Collection Library (ii-V-I Dictionary Keyed by String Set and Melody Note)

The central indexing unit of the method: a chord collection is defined as a group of chords covering every diatonic interval as the top note, which is what makes the dictionary indexable by melody note. The dictionary is structured around ii-V-I precisely because that single progression covers all three harmonic families, and collections are duplicated into 1st-string and 2nd-string variants to match the top-2-string melody constraint from Module 1. Chapter 8 consolidates the collections into a four-way split by quality and string set: Major ii-V-I on string set 4321 and on string set 5432, and Minor ii-V-i on the same two string sets with the b5 and b9 alterations characteristic of the minor cadence. A separate section catalogues altered/extended dominants as the method's color resource, and a solo-guitar voicing section backs Module 4 with 6th-string-root shell voicings plus a catalog of extensions stacked on those shells.

Members: Major ii-V-I, String Set 4321; Major ii-V-I, String Set 5432; Minor ii-V-i, String Set 4321 (b5/b9 alterations); Minor ii-V-i, String Set 5432 (b5/b9 alterations); Altered/Extended Dominants Catalog; Solo-Guitar Shell Voicings, 6th-String Root; Shell Voicing Extensions Catalog; 1st-String Top-Note Variants; 2nd-String Top-Note Variants.

Traversal rules:
- Three-Input Dictionary Lookup — `StringSetTransition` (Chapter 4 summary; ch04 'Three voicing-lookup inputs').
- 1st-String and 2nd-String Top-Note Variants — `StringSetTransition` (Chapter 2 summary; ch02 '2nd-string collection rationale').
- String-Set 4321 vs 5432 Split by Quality — `StringSetTransition` (Chapter 8 summary; ch08 'Major II V I string set 4321', 'Minor II V I string set 4321').

Modification rules:
- A Collection Covers Every Diatonic Interval as Top Note — `FamilyCoherence` (Chapter 2 summary; ch02 'Chord collection definition').
- ii-V-I as the Single Progression Covering All Three Families — `FamilyCoherence` (Chapter 2 summary; ch02 'Why ii V I for collections').
- Shell Voicing Extensions Stacked on 6th-String-Root Shells — `FamilyCoherence` (Chapter 8 summary; ch08 'Shell voicings root on 6th').

### Voicing Construction Rules (Omittable Notes, Shells, Density)

The load-bearing instrument constraint of the method: the gap between the theoretically correct chord and the playable guitar voicing, filled by an explicit omittable-notes list and a shell-voicing primitive. Chapter 2 establishes the omittable-notes priority — 5th, root, 11th, and 9th first, with 3rd and 7th sometimes omittable in complex chords. Chapter 5 makes the shell voicing (root, 3rd, and 7th only) the primitive for solo-guitar arranging, derived from bar chords by dropping the 5th first as the rule for which note to cut, with the 6th available as a substitute for the 7th for a warmer, more resolved color and a general rule to avoid doubled notes unless the doubling sounds good. Bass on the 5th and 6th strings is the load-bearing difference from trio playing, with bass-too-close-to-upper-harmony as the diagnostic for thin arrangements and a key-selection preference for A, E, or D so open strings can carry the bass. Chapter 9's right-hand cap closes the system: voicings cap at four notes, the pinky is omitted from the picking hand, and plucked notes must sound simultaneously to register as a chord rather than an arpeggiation.

Members: Shell Voicing (Root, 3rd, 7th); Omittable-Notes Priority List; Bass on 5th and 6th Strings; Open-String Keys (A, E, D).

Traversal rules:
- Bass-Too-Close-to-Upper-Harmony Diagnostic — `_pending:bass-upper-spacing` (Chapter 5 summary; ch05 'Bass-upper proximity issue').
- Key Selection Favors Open-String Bass (A, E, D) — `_pending:open-string-key-bias` (Chapter 5 summary; ch05 'Open-string keys').

Modification rules:
- Omittable-Notes Priority: 5th, Root, 11th, 9th, Then 3rd/7th — `OmissionAllow` (Chapter 2 summary; ch02 'Omittable notes list', 'Theoretical vs playable').
- Shell Voicing: Drop the 5th First — `OmissionAllow` (Chapter 5 summary; ch05 'Shell voicing definition', 'Drop the 5th').
- 6th Substitutable for 7th for Warmer Color — `ColorToneRequire` (Chapter 5 summary; ch05 '6 or 7 substitution').
- Avoid Doubled Notes Unless the Doubling Sounds Good — `_pending:avoid-doubling` (Chapter 5 summary; ch05 'Avoid doubled notes').
- Voicings Cap at Four Notes (Right-Hand Constraint) — `DensityCeiling` (Chapter 9 summary; ch09 'Four-finger maximum, skip pinky', 'Sound multi-string notes simultaneously').

## Pending Work

Six `_pending:` engine_payload kinds remain in the draft and need engine-layer kinds defined before promotion into masters.json:

- `_pending:interval-reference-frame` — signals the golden-rule prohibition against labeling melody-note intervals against the overall key rather than the current chord. This is a semantic-frame constraint on interval labels (which root anchors the major-scale reference) rather than a voicing-selection rule, and existing kinds don't express the reference-frame switch.
- `_pending:melody-rhythm-flex` — signals that rhythmic adjustment of the melody to facilitate fretboard jumps is a sanctioned arranger move, not a compromise. This is a melody-edit-permission rule distinct from voicing or harmonization kinds, and likely warrants its own kind covering the arranger's pragmatics layer.
- `_pending:context-defined-naming` — signals that surrounding chords define a chord's name as much as its notes do, a chord-symbol-parsing rule that depends on context rather than a voicing constraint. As with Benson's `_pending:notation-default`, this likely needs a parser-side rather than engine-side kind.
- `_pending:bass-upper-spacing` — signals a diagnostic (not a strict prohibition) for when bass is voiced too close to the upper harmony, producing a thin arrangement. Distinct from `VoiceMotion` (horizontal) and `ColorToneRequire` (presence-positive); it needs a register-spacing constraint kind.
- `_pending:open-string-key-bias` — signals that key selection should favor A, E, or D so open strings can carry bass notes and free the fretting hand. This is a key-selection heuristic keyed to instrument-mechanical affordances rather than a voicing-engine rule.
- `_pending:avoid-doubling` — signals a general refinement rule to avoid doubled notes unless the doubling happens to sound good. The carve-out ('unless it sounds good') makes this an aesthetic default rather than a hard prohibition, and warrants a soft-constraint kind rather than reduction to an existing presence-negative kind.

## Provenance Notes

All system blocks and rules are drawn from the book-level distillation and the nine per-chapter summaries (ch01–ch09.md). Each rule carries `references[]` pointing back to the specific chapter and topic, with quote excerpts from the chapter summaries.

Four systems were reified from the nine chapters. Chapter 1's four-step recipe and Chapters 3–4's painting-by-numbers operationalization fold into the Chord-Melody Paint-by-Numbers System as the book's operating system. Chapter 2's taxonomy becomes the Three Harmonic Families System. Chapter 2's chord-collection construct plus Chapter 8's appendix consolidation become the Chord Collection Library. Chapter 2's omittable-notes list plus Chapter 5's shell-voicing primitive plus Chapter 9's right-hand cap fold into the Voicing Construction Rules System.

Three chapters did not yield standalone systems and their content is consumed by the four systems above. Chapter 6 (solo-guitar arrangement examples) is study material rather than a system; its single load-bearing rule (sanctioned rhythmic adjustment of melody for fingering) sits in the Paint-by-Numbers System's modification rules. Chapter 7 (substitution and reharmonization) codifies five named substitution rules — tritone substitution, I-to-vi, I-to-iii, minor-for-dominant (Pat Martino's minor conversion), back-cycling through the circle of fourths, and melodic common-tone substitution — but in this draft these are reharmonization devices that operate on the painting-by-numbers output rather than a separate voicing system, and have not yet been split into their own system block; this is a candidate for a future Substitution-and-Reharmonization System once the engine kinds for chord-replacement-by-shared-guide-tones and circle-of-fourths back-cycling are concrete. Chapter 9 (fingerstyle appendix) supplies the right-hand foundation — PIMAC convention, rest stroke versus free stroke (free stroke preferred for jazz), thumb mechanics, wrist angle, two-finger pairs (p+i, i+m), three-finger groupings (pim, ima), and the four-note voicing cap — which is folded into the Voicing Construction Rules System's four-note density ceiling rather than reified as a separate technique system.

Scope honesty: this is a contemporary teach-yourself instructional book by an online instructor, not a primary-source method by a historic jazz master (in the sense Bernstein's documented improvisation method or a transcription of Wes Montgomery's practice would be). Its value to the masters corpus is procedural clarity, an explicit and unusually well-organized dictionary structure (string-set × chord-type × melody-interval), and a load-bearing aesthetic axiom (restraint with sanctioned escape valves). Where the book borrows from named players — Pat Martino's minor conversion in Chapter 7, Wes Montgomery octaves and Barney Kessel diads in Chapter 5, Rosenwinkel/Kreisberg-style melodic common-tone substitution in Chapter 7 — those borrowings are cited but second-hand, and the engine kinds derived here reflect O'Rourke's pedagogical framing rather than direct testimony from those players.
