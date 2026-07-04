# Masters Corpus

Reference materials organized by master (author/teacher). Two layout
conventions coexist; the sub-folder name tells which convention a given
directory follows.

## Pipeline output (`<master>/<work>/{chapters,summaries,derived}/`)

Structured output from the master-distillation pipeline. Each `<work>/`
directory contains the pipeline's staged artifacts for one book or
method volume:

- `chapters/` -- per-chapter markdown extracts (Stage 2 output).
- `summaries/` -- chapter and book-level summaries (Stage 3 output).
- `derived/` -- systems, voicing tables, and other derived artifacts
  (Stages 4-5 output).

Example: `benson/method-vol-1-chord-construction/{chapters,summaries,derived}/`

Book-level summary files (`<work>-book-summary.md`) sit directly inside
`<work>/`.

## Raw archive (`<master>/raw-archive/`)

Flat collections of source materials (lesson sheets, manuscripts,
transcriptions) that predate the pipeline or whose structure does not
map to the pipeline's chapter-based layout. Files live directly inside
`raw-archive/` with no sub-directory hierarchy.

Example: `greene/raw-archive/` -- Ted Greene's openly-distributed
teaching archive from tedgreene.com, fetched by
`scripts/fetch-greene-corpus.py`.

## Adding a new master

- If the source material is a book or method with chapters, use the
  pipeline-output layout: create `<master>/<work-slug>/` and let the
  pipeline populate `chapters/`, `summaries/`, `derived/`.
- If the source material is a flat collection of individual documents,
  create `<master>/raw-archive/` and place files there.
- A single master may have both: pipeline-output for books and a
  raw-archive for supplementary materials.
