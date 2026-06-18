---
run_id: 2026-06-18T15-10-00-slonimsky-thesaurus
stage: s0-corpus-setup
source_pdf: Nicolas Slonimsky - Thesaurus OfScales And Melodic Patterns.pdf
model: maintainer-curated
extracted_at: 2026-06-18T15:10:00+00:00
schema_version: 0.1
---

# Book-level distillation — thesaurus-of-scales-and-melodic-patterns (v0.1 stub)

_This is the stage-0 setup commit. Full distillation (chapters → summaries → systems → engine_rules) lands in follow-up PRs._

## Bibliographic

- **Title**: Thesaurus of Scales and Melodic Patterns
- **Author**: Nicolas Slonimsky (1894–1995)
- **First published**: 1947 (Charles Scribner's Sons; later editions by Amsco/Schirmer)
- **Page count**: ~243 pages
- **Source provenance**: Internet Archive — [archive.org/details/nicolasslonimskythesaurusofscalesandmelodicpatterns](https://archive.org/details/nicolasslonimskythesaurusofscalesandmelodicpatterns)

## Position in the lineage

Foundational reference for the melodic-patterns dimension of post-bop and modern jazz vocabulary. Most famously studied by John Coltrane (whose *Giant Steps* cycle is the equal-division-of-octave-by-three pattern from the Thesaurus), Pat Martino, and John McLaughlin. Per Dheeraj's heroes list (Coltrane lineage / Martino linear concept / McLaughlin organic guitar), this corpus is high-priority foundational material for the engine's melodic dimension.

## Structural architecture

The book proceeds **systematically through every possible equal sub-division of the octave**:

1. **Tritone (½ octave)** — 2-tone equal division
2. **Major third (⅓ octave)** — 3-tone equal division → Coltrane's *Giant Steps* family
3. **Minor third (¼ octave)** — 4-tone equal division
4. **Whole tone (⅙ octave)** — 6-tone equal division
5. **Semitone (1/12 octave)** — full chromatic
6. Plus the more exotic divisions Slonimsky catalogs

Each equal-division creates a set of **principal tones**. Slonimsky then ornaments these principal tones using three operations:

| Operation | Definition |
|---|---|
| **Infrapolation** | Insert a note BELOW the principal tone |
| **Interpolation** | Insert a note BETWEEN principal tones |
| **Ultrapolation** | Insert a note ABOVE the next principal tone |

The patterns escalate combinatorially: *Ultrapolation of One Note* → *Infrapolation of One Note* → *Infra-Interpolation* → *Infra-Inter-Ultrapolation* and so on. The book yields **over 1500 melodic patterns**, each catalogued by the equal-division family and the polation operations applied.

## What's distillable

| Dimension | Source format | Distillable as |
|---|---|---|
| Scale catalog (equal divisions of octave) | Plain text + notation | Structured JSON: `{division_id, interval_sequence, name}` |
| Polation operations | Prose + worked examples | Structured `melodic_rules` predicates |
| Specific melodic patterns | Notation primarily | Pattern IDs + interval sequences (harder; OCR-on-music doesn't capture, manual extraction or notation-OCR pipeline needed) |
| Author commentary / theory | Front matter prose | Standard book-summary prose distillation |

## What's NOT distillable from OCR alone

The book is **overwhelmingly musical notation**. The OCR text dump is 53KB — most of the value is in 200+ pages of typeset notation that OCR can't capture. Distilling the actual melodic patterns requires either:

(a) Notation-OCR pipeline (e.g. Audiveris) producing MusicXML
(b) Manual transcription of representative patterns per equal-division family
(c) Acceptance that v0.1 melodic_rules cover only the polation TAXONOMY + the scale catalog, not the 1500+ specific patterns

V0.1 scope: (c). Distill the operational framework + scale catalog. The 1500+ specific patterns come in v0.2+ via (a) or (b).

## v0.1 status

- ✅ Source OCR text in this directory (`source-ocr.txt`)
- ⏳ Front-matter prose distillation (chapters/summaries) — follow-up PR
- ⏳ Systems-draft.json (polation operations + equal-division taxonomy) — follow-up PR
- ⏳ Engine_rules for melodic dimension — follow-up PR; new \`melodic-rules.json\` artifact distinct from harmonic \`engine-rules.json\`
- ⏸ Pattern catalog (1500+ patterns) — requires notation-OCR pipeline (Audiveris?) — separate workstream

## Pedagogical takeaway (for the eventual Master profile page)

Slonimsky is the **systematic enumeration of melodic possibility space** — the dictionary, not the prose. Practitioners don't read it cover-to-cover; they pick a target chord/scale context and look up patterns. The engine's job is to do that lookup automatically: given a slice, suggest patterns from the Thesaurus that fit, ranked by master-stylistic preference (Coltrane chose the 3-tone equal-division family heavily; McLaughlin reaches for symmetric-diminished, etc.).

That's where the melodic_rules engine eventually composes with the harmonic engine_rules — the harmonic side picks voicings, the melodic side picks lines through them.
