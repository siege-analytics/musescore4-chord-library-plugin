---
run_id: 2026-05-28T15-05-20-bertoncini-arrangements-solo-guitar
stage: s4
source_pdf: _m Bertoncini Arrangements for Solo Guitar.pdf
model: claude-sonnet
extracted_at: 2026-05-31T03:11:34+00:00
schema_version: 0.1
---

# Arrangements for Solo Guitar — Statement of Outputs

## Overview

Gene Bertoncini's *Arrangements for Solo Guitar* (Ambient Records, 2011; compiled by Jason Ennis, Chris Ullrich, and Gene Bertoncini) is a notated performance folio rather than a method book. It contains twenty-four solo-guitar arrangements drawn from two Bertoncini recordings — *Body and Soul* (chapters 1–13) and *Quiet Now* (chapters 14–24) — followed by a Glossary of Open-String Voicings (chapter 25). The book's entire written argument is concentrated in two short front-matter texts (the Preface and Jason Ennis's Notes about the Transcriptions and Notation); the twenty-four arrangement chapters themselves are notation only, and the Glossary is a measure-indexed reference chart rather than a prose chapter.

The Preface frames the project through Berlioz's description of the guitar as a "little orchestra," and every arrangement was conceived in that spirit. Bertoncini's premise is that any composed music — folksong, operatic aria, big-band shout chorus, orchestral excerpt — can find its way to the guitar if the arranger thinks orchestrally rather than idiomatically. The Notes on Transcription locate the book between transcription and arrangement: editing began from Bertoncini's handwritten manuscripts, was fleshed out by transcribing missing material from the recordings, and uses parentheses in the score to mark notes restored from the recorded version. Bertoncini's fingerings are preserved throughout, placed to the lower right of the notes to which they correspond. The editors call out one technique as distinctively his: the unorthodox use of open strings inside voicings, and they extract a cross-referenced catalog of these voicings as the closing Glossary.

This statement reflects only what the front-matter prose and the Glossary index make explicit. Chapters 1–24 yielded no extractable prose passages in Stage 2 (the OCR transcript of each arrangement is musical notation without prose annotations), so no chapter-quote–backed rules are asserted. The systems below are member-only taxonomies: the structural vocabularies the book names, without traversal or modification rules drawn from source quotes.

## Systems

### Open-String Voicing Glossary

`gene-bertoncini:arrangements-for-solo-guitar:open-string-voicing-glossary`

The book's most explicit organizing system is the Glossary of Open-String Voicings (chapter 25, pages 77–81). Bertoncini's distinctive practice is to incorporate ringing open strings as harmonic color inside chord voicings rather than stopping every note. The editors extracted these voicings from across the twenty-four arrangements and indexed them by chord label and source measure. The Glossary thus functions as a harmonic index to one of the book's defining characteristics — it makes visible, in condensed form, the harmonic vocabulary that is otherwise distributed across the notated arrangements.

**Members** (twenty-two voicings cataloged from the chapter-25 index, drawn from arrangements in chapters 1–9 of the folio):

- The Shadow of Your Smile — Em9 (m. 9); A13 (mm. 19–20); Bm9 (m. 39)
- My Funny Valentine — Abm13; F(add9)/A (m. 28)
- How Are Things in Glocca Morra — Em11 (mm. 31–32); A13 (mm. 31–32)
- Body and Soul — Dbmaj7(♯11) (m. 7); Amaj9 (m. 13); Db13 (m. 13); Em9 (mm. 22–23); Dm11 (mm. 22–23); E9(♯11) (mm. 22–23); A13(♭9) (mm. 22–23)
- Edelweiss — Ebmaj9 (m. 35)
- 'Round Midnight — Abm9 (m. 3)
- But Beautiful — Bb13(♭9) (m. 26); G13 (m. 13)
- I Remember You — C♯m11 (m. 11); F♯(sus4) (m. 26); F9 (m. 26); E7(♯9) (m. 48)

**Traversal rules**: none (no source-quote backing exists for inter-voicing motion or substitution patterns; the Glossary catalogs the voicings without describing the moves between them).

**Modification rules**: none.

*Backing:* Chapter 25 summary (`ch25.md`); Glossary index entries visible in the chapter-25 raw transcript at pages 77–81.

### Little-Orchestra Textural Roles

`gene-bertoncini:arrangements-for-solo-guitar:little-orchestra-textures`

Bertoncini's framing premise — taken from Berlioz's description of the guitar as a "little orchestra" — treats the solo guitar as a polyphonic ensemble distributing musical material across distinct textural roles. The Preface names the roles and techniques explicitly: melody can be stated in the soprano voice, given to the bass voice, or nestled within the voicing, and the surrounding material uses counterpoint, cluster voicings, open-string voicings, and the particular timbral color of each individual string. The twenty-four arrangements in chapters 1–24 realize this taxonomy in notation.

**Members**:

- Melody stated in the soprano voice (default placement)
- Melody given to the bass voice (mood/message-driven inversion)
- Melody nestled within an inner voice of the voicing (inner-voice melody requiring the listener to track a middle line)
- Counterpoint between voices
- Cluster voicings
- Open-string voicings
- Per-string timbral color (the "special color of each string")

**Traversal rules**: none (the Preface prose names the roles but does not prescribe transitions between them).

**Modification rules**: none.

*Backing:* book-level distillation, drawn from the Preface text visible in the raw transcript. Note that the Preface is not extracted as a numbered chapter because the table of contents begins with the first arrangement; this system's backing is the front-matter prose summarized at the book level, not a chapter quote file.

## Provenance Notes

- **Front matter (Preface; Notes about the Transcriptions and Notation by Jason Ennis):** the only prose in the book. Visible in the Chapter 1 OCR region of the raw transcript but not assigned a chapter number by the TOC. The book-level distillation draws from this material; the "Little-Orchestra Textural Roles" system summarizes its taxonomy.
- **Chapters 1–24 (the arrangements):** notation-only. Stage 2 correctly returned empty `quotes[]` for all twenty-four. Stage 3 chapter summaries note this explicitly. No rules are asserted from these chapters because no source quotes back them.
- **Chapter 25 (Glossary of Open-String Voicings, pp. 77–81):** the most data-dense chapter for systems extraction. Glossary entries are chord labels keyed to specific measures in the arrangements; they index a harmonic vocabulary but do not describe the moves between voicings. The "Open-String Voicing Glossary" system enumerates the cataloged voicings as members; no rules are asserted because the Glossary itself does not prescribe traversal or modification logic.
- **Why no `_pending:` kinds:** because no rules are asserted at all — not because the rules are uncertain, but because the source prose does not name them. A future pass that works directly from the notation (e.g., analyzing voice-leading patterns across the twenty-four arrangements) could populate traversal and modification rules, but that is outside the scope of this distillation, which is grounded in the book's prose and the Glossary index.
