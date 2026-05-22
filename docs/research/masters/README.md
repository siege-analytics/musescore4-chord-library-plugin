# Masters' principles — research notes

This directory documents the sources behind each entry in
`plugin/data/masters.json`. One file per master, recording:

- which sources we consulted
- which specific claims in our principle entries are sourced where
- which claims are inferred / general-knowledge and need verification
- what we tried that didn't work (blocked URLs, OCR failures, etc.)

The plugin's runtime only reads `masters.json`. These research files
are maintainer reference — the "show your work" for the principle
entries.

## Why this directory exists

Earlier in this project we shipped principle entries seeded from
general knowledge without explicit source attribution. When we
revisited Wes Montgomery's entry (October 2026), we found that two
of the five principles couldn't be supported by accessible sources
and had to be revised. The lesson: **encode only what can be
documented.** This directory holds the documentation.

The discipline going forward: for each master, before encoding a
principle in `masters.json`, write the corresponding section in the
research file. Cite the source verbatim where possible. If you can't
find a source for a claim, either drop it or mark it explicitly as
an inference.

## Methodology

1. **Primary sources first.** Original books and recordings (paraphrased
   in our own words for the plugin; cited verbatim here for reference).
2. **Corpus extracts second.** The Ted Greene corpus we scraped to
   `plugin/data/masters-corpus/greene/` is primary text Greene wrote
   himself. Extracted text + the original PDFs are both available;
   citations in `ted-greene.md` reference specific files by name.
3. **Web sources third.** Lesson sites and analyses (jazzguitar.be,
   Jens Larsen, Voicelid Jazz Guitar, Fundamental Changes, Wikipedia,
   etc.). URLs cited inline. Note blocks where we hit paywalls or 403s.
4. **Hedge what isn't documented.** If a claim made it into `masters.json`
   without a source, the research file says so explicitly and either
   notes a follow-up (find the source) or recommends revising the
   principle.

## Status by master

| Master | Research file | Status |
|---|---|---|
| George Van Eps | (not yet) | research pending — #228 |
| Ted Greene | `ted-greene.md` | corpus-extracted, 5 documented principles |
| Joe Pass | (not yet) | research pending — #230 |
| Martin Taylor | (not yet) | research pending — #231 |
| Wes Montgomery | `wes-montgomery.md` | web-researched, 5 documented principles |
| Lenny Breau | (not yet) | research pending — #232 |
| Jim Hall | (not yet) | research pending — #233 |
| Johnny Smith | (not yet) | research pending — #234 |
| Jody Fisher | (not yet) | research pending — #235 |

Each ticketed master gets a research file when its principle entries
are refined past the original seeds.
