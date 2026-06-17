---
run_id: 2026-05-28T15-05-20-taylor-complete-method-compilation
stage: s4
source_pdf: 883234647-Martin-Taylors-Complete-Jazz-Guitar-Method-Compilation-Master-Jazz-Guitar-ChordMelody-Walking-Basslines-SingleNote-Soloing-Play-Jazz-Guitar-Full-Downl.pdf
model: claude-sonnet
extracted_at: 2026-05-28T23:57:06+00:00
schema_version: 0.1
---

# Martin Taylor's Complete Jazz Guitar Method Compilation — STATEMENT

## Overview

Martin Taylor's *Complete Jazz Guitar Method Compilation* (Fundamental Changes, 2015) is a 408-page omnibus combining three method volumes — Chord-Melody, Walking Basslines, and Single-Note Soloing — that together codify Taylor's tradition of solo jazz guitar. The compilation is one of the canonical references for self-accompanied solo jazz guitar in the post-Van-Eps lineage, with Taylor distilling decades of solo-performance practice into a graduated three-volume curriculum.

This STATEMENT documents a distillation run that did NOT succeed in extracting the book's actual content. It is preserved as a faithful audit trail of an OCR failure rather than as a curatorial reading of Taylor's method.

## What the run produced

The run yielded one synthetic chapter (the entire 408-page compilation treated as a single chapter), zero verbatim quotes from the source, a chapter summary explicitly marking the absence of load-bearing prose, a book-level summary documenting the OCR-failure context, and one `_pending:` system stub flagging the work as blocked on re-OCR.

## Why the run did not extract content

The OCR transcript surfaced two distinct failure modes:

1. **Front matter is digital-storefront marketing, not book content.** The first ~20 pages sampled for table-of-contents extraction (s2-toc) contained product-page boilerplate, unrelated catalog listings, and pricing badges from the ebook marketplace where the PDF was sourced. No table of contents, chapter headings, or author preface were present.

2. **Body OCR is degraded to near-empty.** The 408-page body returned roughly 83KB of text, or about 206 characters per page on average. Of that, the overwhelming majority was page-end markers, horizontal-rule dashes, dollar signs (from engraving artifacts), and short stray strings such as 'BEGINNING OF THE END', 'BEGINNING OF THE BOOK', 'THEME: SUMMER NIGHT', and 'TRANSLATION AND REVIEW BY A FRIEND' that do not correspond to identifiable section divisions in the published volume. No paragraph of teaching prose was recoverable.

Given those conditions, fabricating chapter titles, quotes, or systems would have been the wrong call. The s2-toc LLM did initially hallucinate a 29-chapter table of contents whose titles appeared nowhere in the OCR transcript; that response was discarded in favor of a single fallback chapter per the s2-toc spec's 'short and not subdivided' rule. s2-extract returned `quotes: []`. s3 chapter and book summaries explicitly document the gap. s4-systems emitted a single `_pending:` stub.

## Pending Work

- **`_pending:ocr-recovery`** (system `martin-taylor:complete-jazz-guitar-method:_pending-ocr-recovery`): signals that the source PDF must be re-OCR'd with a different vision pipeline (or a cleaner source obtained) before any meaningful systems extraction can be attempted. The current transcript at ~206 chars/page is below the threshold where prose extraction is viable. Until this is resolved, no traversal or modification rules can be cited back to real chapter quotes from this work, and no chord-melody / walking-bass / single-note-soloing systems can be derived from this source.

## Provenance Notes

- Only one synthetic chapter (Chapter 1, pages 1–408) was created, covering the entire compilation. The actual three-volume internal structure (Chord-Melody, Walking Basslines, Single-Note Soloing) was not recoverable from the OCR.
- Chapter 1 yielded zero quotes — not because the underlying book lacks load-bearing prose, but because the OCR rendered the body as essentially empty. The chapter summary explicitly states this.
- The book-level summary in s3 documents the OCR-failure context for downstream Stage B curation.
- No systems were derived from source quotes; the only system present is the `_pending:ocr-recovery` stub. Stage B should NOT promote this stub into `masters.json` as if it represented Taylor's actual method; it represents only the run's audit trail.
- The fabricated 29-chapter TOC that s2-toc initially returned (titles like 'Chord Forms', 'Symetric Cycles', 'Pedal Point', 'Just Bobi') was rejected because none of those strings appeared in the OCR transcript. Future runs against a clean source should not be biased by those titles.

## Recommended follow-up

File a re-OCR ticket for this PDF using a vision pipeline tuned for engraved-notation pages with multi-column prose (qwen2.5vl:7b at 200 DPI did not handle this source). Once re-OCR'd, re-run the full pipeline; the Stage B curator should treat the present run as null and not attempt to merge its outputs into the master corpus.
