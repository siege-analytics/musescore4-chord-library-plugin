# Pipeline queue

A flat inventory of every PDF that has a config in `configs/`. Use this to decide
what to run next and to track Stage B disposition.

## Conventions

- **Status**: ✅ promoted to masters.json · 🟦 in pipeline · 🟨 queued, not started · 🟥 skip-promote, corpus-only · ❓ author TBD post-OCR
- **OCR?**: y = needs_ocr=true; cyberpower OCR branch routes it
- **Source**: digital (pdftotext) or scanned (OCR via #316/#318)
- Per-config disposition is in the config file's header comment

## Already-promoted (no work needed)

| Master | Work | Stage B PR | Source |
|---|---|---|---|
| benson | method-vol-1-chord-construction | #304 | digital (319pp) |
| jimmy-bruno | the-art-of-picking | #313 | digital (51pp) |
| peter-bernstein | improvisation-method-as-documented-2023 | #314 | digital (30pp) |
| mickey-baker | complete-course-in-jazz-guitar | #319 | OCR (65pp) |
| van-eps | harmonic-mechanisms-vol-1 | #322 | OCR (334pp) |
| greg-orourke | complete-chord-melody | #321 corpus-only | digital (318pp) |

## Queue (20 configs, ready to run)

OCR-required books route through the cyberpower OCR branch. Digital books run
straight through pdftotext. Order below is the suggested run order.

### Tier 1 — Fill existing master slots (high curatorial value, low risk)

| # | Config | Master:Work | Pages | OCR? | Stage B shape | Status |
|---|---|---|---|---|---|---|
| 1 | `van-eps-1939-method.toml` | van-eps:1939-method | 42 | y | FILL existing slot (master entry pre-dates pipeline; has summary+refs only, no corpus or systems[]) | 🟨 |
| 2 | `baker-vol-2.toml` | mickey-baker:complete-course-vol-2 | 49 | y | Sibling work[] | 🟨 |
| 3 | `pass-guitar-method.toml` | joe-pass:guitar-method | 34 | y | Sibling work[] | 🟨 |
| 4 | `pass-guitar-chords.toml` | joe-pass:guitar-chords | 26 | y | Sibling work[] | 🟨 |
| 5 | `greene-modern-chord-progressions.toml` | ted-greene:modern-chord-progressions | 106 | y | Sibling work[] | 🟨 |

### Tier 2 — New primary-source masters

| # | Config | Master:Work | Pages | OCR? | Stage B shape | Status |
|---|---|---|---|---|---|---|
| 6 | `martino-linear-expressions.toml` | pat-martino:linear-expressions | 63 | y | NEW master | 🟨 |
| 7 | `coker-elements-jazz-language.toml` | jerry-coker:elements-of-the-jazz-language | 154 | y | NEW master | 🟨 |

### Tier 3 — Benson sibling works (digital, batchable)

| # | Config | Master:Work | Pages | OCR? | Stage B shape | Status |
|---|---|---|---|---|---|---|
| 8 | `benson-vol-2-advanced-harmony.toml` | benson:method-vol-2-advanced-harmony | 322 | n | Sibling work[] | 🟨 |
| 9 | `benson-vol-3-technique-arpeggios.toml` | benson:method-vol-3-technique-arpeggios | 351 | n | Sibling work[] | 🟨 |
| 10 | `benson-vol-4-approach-tones.toml` | benson:method-vol-4-approach-tones | 372 | n | Sibling work[] | 🟨 |
| 11 | `benson-vol-5-melodic-minor.toml` | benson:method-vol-5-melodic-minor | 434 | n | Sibling work[] (largest book in queue) | 🟨 |
| 12 | `benson-vol-6-giant-lines.toml` | benson:method-vol-6-giant-lines | 145 | n | Sibling work[] | 🟨 |
| 13 | `benson-vol-7-blues-ideas.toml` | benson:method-vol-7-blues-ideas | 227 | n | Sibling work[] | 🟨 |

### Tier 4 — Author/disposition TBD (decide at Stage B per #320)

| # | Config | Master:Work (provisional) | Pages | OCR? | Stage B disposition | Status |
|---|---|---|---|---|---|---|
| 14 | `tbd-reharmonization-techniques.toml` | _pending:tbd-master | 190 | y | Identify author from Stage 1 transcript; promote (if recognized) or corpus-only (per #320) | ❓ |
| 15 | `tbd-tonal-convergence.toml` | _pending:tbd-master | 84 | y | Same: identify from Stage 1; promote or corpus-only | ❓ |
| 16 | `tbd-chord-melody-series-1-beginning.toml` | _pending:tbd-master | 98 | y | Identify from Stage 1; corpus-only is most likely outcome given series style | ❓ |
| 17 | `tbd-chord-melody-series-2-intermediate.toml` | _pending:tbd-master | 98 | y | Same series as 16 | ❓ |
| 18 | `tbd-chord-melody-series-3-mastering.toml` | _pending:tbd-master | 63 | y | Same series as 16 | ❓ |

### Tier 5 — Corpus-only (per #320 criterion)

| # | Config | Master:Work | Pages | OCR? | Stage B disposition | Status |
|---|---|---|---|---|---|---|
| 19 | `orourke-beginners-guide.toml` | greg-orourke:beginners-guide-to-jazz-guitar | 197 | n | Corpus-only (same author as #321 skip-promote) | 🟥 |
| 20 | `all-fourths-tuning.toml` | _pending:tbd-master | 66 | n | Alt-tuning niche material. Corpus-only or skip entirely; decide at Stage B | ❓ |

## Operational notes

- **Run one book at a time.** Cyberpower vision-rescue contention means concurrent Stage 1 runs serialize on Ollama anyway. Sequential is cleaner.
- **Per-book branch.** Each run gets its own `feature/<book-slug>` branch off `develop`; Stage B is the merge point. Mirrors what we did for Bruno / Bernstein / Baker / Van Eps Vol 1.
- **Stage 4 subagent timeout protocol.** For books over ~150 pages (Benson Vols 2-5, Reharmonization Techniques), use the tight-cap Stage 4 prompt shape from Van Eps Vol 1's PR #322 to avoid the systems-draft subagent stream timeout.
- **Stage B promotion eligibility.** Per #320, anything not clearly primary-source by a recognized jazz-tradition figure stays under `masters-corpus/` without masters.json promotion. Promote later if the criterion ticket #320 resolves to a less restrictive rule.

## How to run a queued book

```bash
# new run from config
python3 pipelines/master-distillation/run.py new-run \
  pipelines/master-distillation/configs/<config-slug>.toml

# at each `awaiting-llm` gate, fill the response file via subagent / direct write
# at each `awaiting-review` gate, run --advance to move forward

python3 pipelines/master-distillation/run.py advance <run-id>
python3 pipelines/master-distillation/run.py resume <run-id>

# Stage 1 OCR runs survive laptop close (see #318); recovery via:
python3 pipelines/master-distillation/ocr/reingest.py <run-id>
```

## Refs

#220 #297 #313 #314 #315 #316 #318 #319 #320 #321 #322 #323 #324 #325 #326 #327 #328 #329.
