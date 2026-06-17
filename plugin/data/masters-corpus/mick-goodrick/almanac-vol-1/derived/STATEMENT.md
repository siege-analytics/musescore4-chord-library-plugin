---
run_id: 2026-06-10T22-47-48-goodrick-almanac-vol-1
stage: s4
source_pdf: Goodrick, Mick - Almanac of Guitar Voice Leading, Vol 1.pdf
model: claude-sonnet
extracted_at: 2026-06-15T20:21:29+00:00
schema_version: 0.1
---

# Almanac of Voice-Leading for Guitar — Volume 1 — Statement of Outputs

## Overview

*Almanac of Voice-Leading for Guitar — Volume 1* by Mick Goodrick is a reference compendium rather than a pedagogical text: it contains no instructional prose, no exercises, and no explanatory narrative. The book's entire content is delivered through exhaustive tabular enumeration of voicings organized across six interval cycles (Cycle 2 through Cycle 7) and three parent scales (C Major, C Melodic Minor, C Harmonic Minor), yielding 18 discrete voice-leading environments. Volume One covers tertian sonorities exclusively — triads, seventh chords, and two categories of tertian-by-name voicings (TBN I and TBN II) — presented in both Close Position and Spread Position. Volume Two extends the same framework to quartal and cluster sonorities. The book teaches by saturation: a player absorbs the logic of voice-leading by moving through the tables rather than by reading about it.

Each voicing entry in the tables is analyzed through three superimposed layers. The Intervallic Voice-Leading layer identifies the interval of motion each voice undergoes as harmony changes. The Functional Voice-Leading layer maps those motions onto harmonic function and names common-tone relationships, guide-tone transfers, and resolution tendencies. The M.S.R.P. (Most Stepwise Resolution Pattern) layer selects the specific voice-leading path — among the options the intervallic and functional layers identify — that minimizes top-voice displacement and maximizes stepwise motion. These three layers are applied uniformly across all 18 environments and all voicing families, making the analytical framework itself a portable system that can be extracted from any single table and applied elsewhere.

The corpus distillation captures three interdependent systems: the Cycle-Indexed Voice-Leading System, which defines the 18-environment grid and its traversal logic; the Voicing Family Parallelism System, which defines how sonority types and density positions are organized as orthogonal parameters; and the Three-Layer Analytical System, which defines the analytical vocabulary applied consistently throughout. Together these three systems constitute the book's full intellectual output. The voicing tables themselves remain authoritative in the original PDF and are not transcribed into the masters-corpus.

---

## Systems

### System 1: Cycle-Indexed Voice-Leading System (id: mick-goodrick:almanac-vol-1:cycle-indexed-voice-leading)

The Cycle-Indexed Voice-Leading System is the primary organizational scaffold of the book. It treats interval cycle and parent scale as two independent axes, producing a grid of 18 voice-leading environments. Each cycle defines the interval of root motion (e.g., Cycle 5 = motion by perfect fourths/fifths); each parent scale constrains the available chord qualities diatonic to that collection. A player traversing the grid is not practicing chord changes in a tonal sense — they are exercising the voice-leading consequences of a fixed interval cycle applied inside a fixed scale environment. The six cycles and three scales are not weighted or ranked; the system treats all 18 combinations as peers requiring equal coverage.

**Members:** Cycle 2, Cycle 3, Cycle 4, Cycle 5, Cycle 6, Cycle 7, C Major, C Melodic Minor, C Harmonic Minor.

**Traversal rules:**

- **M.S.R.P. Top-Voice Minimization** (`VoiceMotion`) — pick the path that yields the most stepwise top-voice line; when two voicings in sequence offer multiple common-tone or near-common-tone options, the one that keeps the soprano voice moving by step or common tone is selected. (Chapter 1 summary; ch01.md no quotes — book is reference-only)
- **Common-Tone Preference Per Voice** (`VoiceMotion`) — sustain or minimally displace any voice that carries a common tone between adjacent chords in the cycle; the displacement budget is allocated first to voices with no available common tone. (Chapter 1 summary; ch01.md no quotes — book is reference-only)
- **Six-Cycle by Three-Scale Grid Traversal** (`PositionContinuity`) — cycle and parent scale are orthogonal traversal axes; every voicing family is run through all 18 combinations, ensuring no environment is treated as a special case or subordinated to another. (Chapter 1 summary; ch01.md no quotes — book is reference-only)

---

### System 2: Voicing Family Parallelism System (id: mick-goodrick:almanac-vol-1:voicing-family-parallelism)

The Voicing Family Parallelism System governs how different sonority types and density positions are treated as structurally parallel rather than hierarchically ordered. Every voicing family — whether a simple triad or a four-voice seventh chord or a TBN variant — receives the identical analytical treatment across all 18 environments. Density (Close vs. Spread) is a parameterized axis applied uniformly rather than a special-case variation. Volume Two extends the same parallelism to quartal and cluster sonorities, which are analyzed without privileging a tonal identity for the harmonized tones. The system's design principle is that the analytical apparatus must be family-agnostic: nothing about the three-layer framework is specific to any one sonority type.

**Members:** Triad, Seventh Chord, TBN I, TBN II, 3-Part Quartal, 4-Part Quartal, Spread Cluster, Close Position, Spread Position.

**Modification rules:**

- **Uniform Analytical Layers Across Families** (`FamilyCoherence`) — every family gets the same three layers (Intervallic, Functional, MSRP) applied in the same order and with the same notation conventions, so a reader moving from a triad table to a seventh-chord table encounters no methodological discontinuity. (Chapter 2 summary; ch02.md no quotes — book is reference-only)
- **Close to Spread Density Axis** (`_pending:voicing-density-axis`) — every entry is paired in Close and Spread position; density is a parameterized axis rather than a qualitative distinction, meaning the voicing tables treat Close and Spread as two values of a single variable rather than as categorically different voicing philosophies. (Chapter 2 summary; ch02.md no quotes — book is reference-only)
- **Quartal / Cluster NCT Harmonization — Resist Naming** (`NCTHarmonization`) — Volume 2 sonorities harmonize tones without privileging a tonal identity; non-chord tones in quartal and cluster voicings are analyzed intervalically and functionally but are not forced into a tertian naming frame, preserving ambiguity the composer/improviser may wish to exploit. (Chapter 2 summary; ch02.md no quotes — book is reference-only)

---

### System 3: Three-Layer Analytical System (id: mick-goodrick:almanac-vol-1:analytical-layer-system)

The Three-Layer Analytical System is the portable analytical vocabulary the book deploys uniformly across all environments and all families. The three layers — Intervallic Voice-Leading, Functional Voice-Leading, and M.S.R.P. — are sequentially dependent: the intervallic layer identifies what motion is happening in each voice; the functional layer interprets those motions in terms of harmonic role and substitution potential; and the MSRP layer selects the preferred path from among the options the first two layers open up. The system is designed to be extracted and applied outside the book's tables: a player who has internalized all three layers can analyze any voice-leading situation using the same three-step procedure, regardless of cycle, scale, or voicing family.

**Members:** Intervallic Voice-Leading, Functional Voice-Leading, M.S.R.P. (Most Stepwise Resolution Pattern).

**Traversal rules:**

- **Intervallic Voice Motion Mapping** (`VoiceMotion`) — the intervallic layer is applied first and identifies the motion budget per voice (unison, half-step, whole-step, third, etc.) before any functional interpretation is imposed; this ordering prevents functional assumptions from distorting the measurement of actual voice displacement. (Chapter 1 summary; ch01.md no quotes — book is reference-only)
- **Functional Layer Substitution Expansion** (`SubstitutionExpand`) — shared functional voice-leading profiles across different cycle/scale combinations identify substitution relationships; two voicings from different environments that share a functional layer profile are flagged as substitutable, expanding the harmonic palette available at any given structural moment. (Chapter 1 summary; ch01.md no quotes — book is reference-only)

---

## Pending Work

- `_pending:voicing-density-axis` — The Close/Spread parameterization is currently tagged with a pending kind identifier rather than a first-class system kind. The modification rule **Close to Spread Density Axis** in System 2 surfaces this gap: density behaves as a true parameterized axis throughout the book's tables, and that behavior warrants a formally defined kind in the catalog schema. This kind should be defined and backfilled into the relevant entries in #298.

---

## Provenance Notes

This book contains no extractable prose quotes — Stage 2 extraction returned empty arrays for both chapters, as expected for a reference volume whose content is delivered entirely through tabular structure. All three systems documented here are derived from the book-level distillation and chapter summaries, which synthesize what the book's tabular organization teaches by its structure rather than by its language. Voicing-table content itself is not transcribed into the masters-corpus; the original PDF remains the authoritative source for specific voicing fingerings, interval annotations, and table entries. Cycles, parent scales, voicing families, and analytical layers are all directly named in the catalog's table headers throughout pages 12–378 and are treated as primary named entities in the corpus accordingly.
