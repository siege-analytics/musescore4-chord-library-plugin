# Ted Greene corpus

This directory contains an MVP sample of Ted Greene's openly-distributed
teaching materials, downloaded from [tedgreene.com](https://tedgreene.com)
for reference and principle-extraction.

## Source + license

Ted Greene's estate maintains his archive at tedgreene.com and publishes
everything free of charge. The materials live in this repo with the
estate's general permission for free distribution. If you redistribute
this corpus elsewhere, follow the estate's wishes: keep it free.

## What's here

- `*.pdf` — the original lesson PDFs as downloaded
- `*.txt` — extracted text (via pdfplumber or pdftotext), useful for grep
- `MANIFEST.json` — provenance: scrape mode, counts, entry-point URLs

The MVP corpus samples 2 PDFs from each subject area (chords, comping,
harmony, v_system, fundamentals, baroque, blues, jazz, singlenote,
arrangements). To pull the full archive (1700+ PDFs, several GB), run:

```bash
python scripts/fetch-greene-corpus.py --full
```

## How this corpus is used

The corpus is reference material for `plugin/data/masters.json` —
specifically, principle entries under the `ted-greene` master. Each
principle paraphrases insights from his teaching in our own words;
references back to specific files here let future maintainers verify
the source.

The plugin runtime does NOT load the corpus directly. Only the
distilled `masters.json` ships in the user-facing UI.

## Re-running

```bash
# Install deps if needed (recommend a venv).
python -m venv /tmp/greene-venv
/tmp/greene-venv/bin/pip install requests beautifulsoup4 pdfplumber

# MVP sample (idempotent — skips files already present).
/tmp/greene-venv/bin/python scripts/fetch-greene-corpus.py

# Re-extract text from existing PDFs (without re-downloading).
/tmp/greene-venv/bin/python scripts/fetch-greene-corpus.py --extract

# Full archive.
/tmp/greene-venv/bin/python scripts/fetch-greene-corpus.py --full
```
