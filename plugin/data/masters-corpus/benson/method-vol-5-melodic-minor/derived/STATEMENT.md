---
run_id: 2026-05-28T15-05-20-benson-vol-5-melodic-minor
stage: s4
source_pdf: Benson, George - The George Benson Method, Vol 5 (Melodic Minor World, Bebop Scales, Symmetric Ideas & Concepts).pdf
model: claude-sonnet
extracted_at: 2026-06-02T05:04:06+00:00
schema_version: 0.1
---

# The George Benson Method, Vol. 5 (Melodic Minor World, Bebop Scales, Symmetric Ideas & Concepts) — Statement of Outputs

## Overview

This volume is the fifth in George Benson's method series and organizes its teaching around a concept the master calls "Giant Lines" — extended melodic runs derived primarily from the melodic minor scale family. The book spans thirteen chapters, but its explicit theoretical and methodological weight is carried almost entirely by two chapters (5 and 7); the remaining eleven are notation-only, delivering their content through written-out exercises and fretboard diagrams without a single verbatim instructional passage. The book's pedagogy is therefore demonstrative rather than expository: the student is expected to internalize the system by playing through accumulated notated examples, with the prose in Chapters 5 and 7 providing the conceptual scaffold for everything else.

The central claim of the volume is that the melodic minor scale is the master's preferred improvisation resource because it contains no avoid notes — meaning any tone in the scale may be sounded freely over its associated chord without creating a harmonic clash. This property, presented as unique among the scale families the book addresses, justifies organizing the entire melodic vocabulary of the volume around melodic minor derivations. The book frames this not as one option among many but as a defining advantage that unlocks what it calls "unlimited harmonic possibilities."

The book's arc moves from static applications of Giant Lines over fixed chord contexts (Chapters 2–4) through the theoretical grounding of the melodic minor system (Chapters 5 and 7) and into transitional, chord-type-specific, and active applications (Chapters 6, 8–13). The dominant chord D7(9) — and its variant D7(#9) — serves as the primary laboratory throughout. Minor 7th and major 7th contexts are introduced later (Chapters 10–11). Because nearly all chapters after the two prose sections consist solely of notation, the book implicitly argues that the conceptual system taught verbally in Chapters 5 and 7 is sufficient foundation; everything else is accumulated pattern exposure through playing.

## Systems

### Melodic Minor Improvisation System

The Melodic Minor Improvisation System is the single load-bearing system of the volume. It organizes the melodic minor scale as a complete improvisation resource by doing three things simultaneously: (1) establishing the theoretical justification for the scale's supremacy (no avoid notes), (2) providing a spatial framework for locating the scale across the guitar neck (five vertical zones, two guide chords), and (3) supplying an explicit procedure for selecting the correct melodic minor parent scale over any target chord (degree-mapping). The system operates over seven diatonic chord-members derived from A melodic minor, each associated with a distinct scale color and arpeggio set. Modification rules govern harmonic constraints on dual-identity chords, the epistemological relationship between theoretical tension knowledge and selective voicing practice, and the meta-rule that all notated patterns are to be re-deployed by ear rather than executed as rhythmic prescriptions.

**System ID:** `benson:method-vol-5-melodic-minor:melodic-minor-improvisation`

#### Members

- `am-maj7` — Am(maj7) — Melodic Minor I (tonic minor-major seventh; one of the two master guide chord shapes)
- `bsus-b9` — Bsus(b9) — Melodic Minor II
- `cmaj7-sharp5` — Cmaj7(#5) — Lydian(#5) / Melodic Minor III (the other master guide chord shape; Lydian(#5) relative)
- `d7-9-sharp11-13` — D7(9, #11, 13) — Melodic Minor IV, dual-identity (also a dominant diminished voicing)
- `e7-9-b13` — E7(9, b13) — Melodic Minor V
- `f-sharp-half-dim` — F#ø — Melodic Minor VI
- `g-sharp-7-alt` — G#7alt — Melodic Minor VII

#### Traversal Rules

**TR-1: Chord-Degree Mapping — Identify Parent Melodic Minor Scale.** Engine payload kind: `_pending:chord-degree-parent-selection`. To select the correct melodic minor scale over any target chord, locate that chord as a specific degree within the melodic minor scale family and use the parent scale associated with that degree position. The chapter demonstrates this with three worked examples: Gsus(b9) → F melodic minor (IInd degree); C#7alt → D melodic minor; C+maj7 → A melodic minor. *(Chapter 5 summary; ch05.md, p. 15.)*

**TR-2: Extended Scale Options Require Two Guide Chords.** Engine payload kind: `PositionContinuity`. When working with extended scale options, a player must employ at least two guide chords for proper fretboard visualization; a single anchor chord is insufficient. *(Chapter 7 summary; ch07.md, p. 27.)*

**TR-3: Relate Every Melodic Idea to Its Associated Chord Shape.** Engine payload kind: `_pending:melodic-chord-shape-anchoring`. Every melodic idea must be visualized in direct relation to its associated chord shape; a reference key (Cm) anchors the melodic pattern spatially on the fretboard, making the crucial Eb/E substitution visible. *(Chapter 7 summary; ch07.md, p. 30.)*

**TR-4: Five Vertical Zones with Alternating Guide Chords.** Engine payload kind: `PositionContinuity`. The melodic minor scale is traversed across the fretboard through five vertical zones, each anchored by one of two alternating guide chords — Cmaj7(#5) and Am(maj7) — reusing the same zonal framework as Ionian and Aeolian. All melodic minor tetrads should be related back to these two master guide chords. *(Chapter 5 summary; ch05.md, p. 15. Chapter 7 summary; ch07.md, p. 33.)*

#### Modification Rules

**MR-1: No Avoid Notes — Unlimited Harmonic Possibilities.** Engine payload kind: `ColorToneRequire`. Because the melodic minor scale contains no avoid notes, any tone in the scale may be sounded freely over its associated chord without harmonic clash. This yields a larger palette of scale arpeggios and guide chords than scales with avoid notes. *(Chapter 5 summary; ch05.md, p. 15. Chapter 7 summary; ch07.md, p. 28.)*

**MR-2: D7(#11) Dual Identity — Scale-Use Constraint.** Engine payload kind: `SubstitutionExpand`. D7(#11) carries dual identity as both melodic minor IV and dominant diminished voicing; this dual identity is a constraint, not an additive freedom. Certain scales and voicings permitted for a standard IV chord cannot be used here. *(Chapter 7 summary; ch07.md, p. 28.)*

**MR-3: All Tensions Must Be Known; Not All Must Be Voiced.** Engine payload kind: `OmissionAllow`. A player is not required to voice every available tension, but comprehensive theoretical knowledge of all tensions is a prerequisite for competent harmonization and improvisation. *(Chapter 7 summary; ch07.md, p. 28.)*

**MR-4: Apply Patterns by Ear, Not by Notated Time Signatures.** Engine payload kind: `_pending:ear-over-notation`. Time signatures attached to notated patterns serve an organizational function only — not rhythmic prescriptions. The student extracts pitch-and-interval content and re-deploys it according to what the musical moment demands. *(Chapter 5 summary; ch05.md, p. 15.)*

## Pending Work

Three engine payload kinds are marked `_pending`, signaling that no existing engine primitive fully captures the rule's logic. Each requires a new primitive specification before the system can be executed:

- **`_pending:chord-degree-parent-selection`** — A lookup/selection primitive that, given a target chord and a melodic minor scale family, identifies the degree position of that chord and returns the associated parent scale. This is an algorithmic selection rule, not a positional or color-tone rule — it requires a degree-indexed scale map as its data structure.
- **`_pending:melodic-chord-shape-anchoring`** — A spatial anchoring primitive that ties a melodic pattern to its associated chord voicing shape, using a reference-key mechanism (e.g., Cm) to make the pattern's target position visible. Distinct from zone-based position continuity in that it links melody to a specific chord geometry, not merely to a neck zone.
- **`_pending:ear-over-notation`** — A meta-rule primitive marking a pattern's notated time signature as non-prescriptive: the pitch/interval content is to be extracted and redeployed rhythmically by ear. This is a performance-mode flag governing interpretation, not a harmonic or positional rule.

## Provenance Notes

**Source of all extracted claims:** Every rule, member, and citation derives exclusively from the two chapters that contain load-bearing prose — **Chapter 5** ("Giant Lines Creating Flux & Reflux over D7(9) Chord," pp. 15–25) and **Chapter 7** ("Giant Lines — Going Deeper into the Flux & Reflux over D7(9)," pp. 27–37). These are the only chapters from which verbatim instructional passages were identified.

**Chapters that did not yield a system (eleven of thirteen):**

- **Chapters 1, 2, 3, 4** — Notation-only (exercises and fretboard diagrams). No load-bearing prose; no extractable rules or member definitions.
- **Chapter 6** — Notation-only (GB Chord Transition Ideas). No prose extractable as verbatim quotes; the chapter's structural concepts (First/Second GB Chord Transition) are present in section headings but the prose explanations did not pass verbatim-substring fidelity.
- **Chapters 8, 9, 10, 11, 12, 13** — Notation-only (Static Giant Lines 3rd Situation, D7(#9) Giant Lines, Minor 7th/Major 7th World, Dm7 Static Giant Lines, Active Giant Lines, Dm7 Active Giant Lines). No verbatim prose passages identified.

The reason these chapters contributed no system content is structural: the book's pedagogy is demonstrative throughout, with the conceptual architecture established verbally in Chapters 5 and 7 and then applied silently through notation in all other chapters. The book implicitly argues that the prose in those two chapters is sufficient theoretical foundation — the notation does not add new rules; it accumulates pattern exposure for the system the prose already defined.

**One system, not many:** Because all load-bearing prose falls within a single continuous theoretical project (the melodic minor improvisation system), the systems-draft correctly identifies one system. The chord members, traversal rules, and modification rules are all facets of that one system — not separate systems for separate chapters.
