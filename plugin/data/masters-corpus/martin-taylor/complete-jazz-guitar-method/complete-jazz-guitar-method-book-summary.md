---
run_id: 2026-05-28T15-05-20-taylor-complete-method-compilation
stage: s3
source_pdf: 883234647-Martin-Taylors-Complete-Jazz-Guitar-Method-Compilation-Master-Jazz-Guitar-ChordMelody-Walking-Basslines-SingleNote-Soloing-Play-Jazz-Guitar-Full-Downl.pdf
model: claude-sonnet
extracted_at: 2026-05-28T23:56:04+00:00
schema_version: 0.1
---

# Book-level distillation — complete-jazz-guitar-method

_Aggregated from per-chapter summaries under `summaries/`._

Martin Taylor's Complete Jazz Guitar Method Compilation (Fundamental Changes, 2015) is a 408-page omnibus combining three method volumes — Chord-Melody, Walking Basslines, and Single-Note Soloing — covering the core craft of solo jazz guitar playing in Taylor's tradition.

For this distillation run, the source PDF rendered as severely degraded OCR. The front matter that was sampled for table-of-contents extraction contained only digital-storefront marketing (product page boilerplate, unrelated catalog listings, pricing badges) and no recoverable book structure. The body OCR (~83KB across 408 pages, roughly 206 chars/page) returned almost exclusively page-end markers, separator rules, dashes and dollar signs from the underlying notation engraving, and a small number of stray heading-like strings ('BEGINNING OF THE END', 'BEGINNING OF THE BOOK', 'THEME: SUMMER NIGHT', 'TRANSLATION AND REVIEW BY A FRIEND') that do not correspond to identifiable chapter or section divisions in the actual published volume.

Because no extractable prose was recovered, this run produced one synthetic chapter spanning the full page range and zero verbatim quotes. The compilation's actual content — Taylor's chord-melody voicing system, walking-bass-with-chord-comping construction, and bebop-line vocabulary for single-note soloing — is not represented in the audit trail and would require a re-OCR with a different vision pipeline or a clean source PDF before any meaningful systems extraction can be attempted.

The scaffolding produced here (single chapter, empty quotes, this summary, downstream stub systems) is deliberately honest about the OCR failure rather than fabricated to fill schema slots. A re-OCR ticket is the appropriate follow-up; the systems and STATEMENT produced in s4 will be _pending: stubs documenting the gap, not extractions from the source.
