# Pipeline queue (post-#334 cyberpower-routing rewrite)

Every config in `configs/` is either already-promoted (status ✅) or queued
to run via `source.host = "cyberpower"` against the canonical PDF corpus at
`~/jazz_docs/...` on cyberpower. Local-laptop PDFs are no longer needed.

## Conventions

- **Status**: ✅ promoted to masters.json · 🟦 in pipeline · 🟨 queued · 🎓 pedagogue · 📚 library/reference (L) · ⚙️  rules/algorithmic (R) · ⏭️  skip (S) · 🟥 corpus-only (no pipeline)
- **Bucket criterion**: see [PROMOTION-CRITERION.md](PROMOTION-CRITERION.md) — M/P/L/R/S taxonomy (#345 supersedes #320)
- **OCR?**: y = `needs_ocr=true`; cyberpower OCR runner routes via #316/#318
- All PDFs verified to exist on cyberpower via batch ssh-test before this PR shipped (36/36)

## Already-promoted

| Master | Work | Stage B PR | Source |
|---|---|---|---|
| benson | method-vol-1-chord-construction | #304 | digital |
| jimmy-bruno | the-art-of-picking | #313 | digital |
| peter-bernstein | improvisation-method-as-documented-2023 | #314 | digital |
| mickey-baker | complete-course-in-jazz-guitar | #319 | OCR |
| van-eps | harmonic-mechanisms-vol-1 | #322 | OCR |
| greg-orourke | complete-chord-melody | #321 corpus-only | digital |

## Queue (36 configs, all routed to cyberpower)

### Tier 1 — Fill existing master slots (high curatorial value, low risk)

| # | Config | Master:Work | Pages | OCR? | Notes |
|---|---|---|---|---|---|
| 1 | `van-eps-1939-method` | van-eps:1939-method | 42 | y | FILL existing slot (currently summary+refs only, no corpus/systems) |
| 2 | `greene-chord-chemistry` | ted-greene:chord-chemistry | TBD | y | Sibling work — THE canonical Greene text |
| 3 | `greene-single-note-soloing-vol-1` | ted-greene:single-note-soloing-vol-1 | TBD | y | Sibling work |
| 4 | `greene-modern-chord-progressions` | ted-greene:modern-chord-progressions | 106 | y | Sibling work |
| 5 | `pass-guitar-method` | joe-pass:guitar-method | 34 | y | Sibling work |
| 6 | `pass-guitar-chords` | joe-pass:guitar-chords | 26 | y | Sibling work |
| 7 | `baker-vol-2` | mickey-baker:complete-course-vol-2 | 49 | y | Sibling work |
| 8 | `fisher-jazz-guitar-method-vol-1` | jody-fisher:jazz-guitar-method-vol-1-beginning | 98 | y | Sibling work (master currently has no works[]) |
| 9 | `fisher-jazz-guitar-method-vol-2` | jody-fisher:jazz-guitar-method-vol-2-intermediate | 98 | y | Sibling work |
| 10 | `fisher-jazz-guitar-method-vol-3` | jody-fisher:jazz-guitar-method-vol-3-mastering-chord-melody | 63 | y | Sibling work |
| 11 | `taylor-complete-method-compilation` | martin-taylor:complete-jazz-guitar-method | TBD | y | Sibling — fills empty martin-taylor.works[] |

### Tier 2 — New primary-source masters

| # | Config | Master:Work | Pages | OCR? | Notes |
|---|---|---|---|---|---|
| 12 | `martino-linear-expressions` | pat-martino:linear-expressions | 63 | y | NEW master |
| 13 | `martino-tonal-convergence` | pat-martino:system-of-tonal-convergence | TBD | y | Sibling — NEW pat-martino has TWO real works |
| 14 | `coker-elements-jazz-language` | jerry-coker:elements-of-the-jazz-language | 154 | y | NEW master |
| 15 | `coker-patterns-for-jazz` | jerry-coker:patterns-for-jazz | TBD | y | Sibling (1970 edition; canonical) |
| 16 | `bergonzi-melodic-rhythms-vol-4` | jerry-bergonzi:melodic-rhythms-vol-4 | TBD | y | NEW master (Inside Improvisation series) |
| 17 | `galbraith-jazz-solo-guitar` | barry-galbraith:jazz-solo-guitar | TBD | y | NEW master (recognized chord-melody specialist) |
| 18 | `aebersold-vol-1-how-to-play-jazz` | jamey-aebersold:vol-1-how-to-play-jazz-and-improvise | TBD | y | NEW master (foundational Vol 1) |

### Tier 3 — Benson sibling works (digital, big books)

| # | Config | Master:Work | Pages | OCR? | Notes |
|---|---|---|---|---|---|
| 19 | `benson-vol-2-advanced-harmony` | benson:method-vol-2-advanced-harmony | 322 | n | Sibling |
| 20 | `benson-vol-3-technique-arpeggios` | benson:method-vol-3-technique-arpeggios | 351 | n | Sibling |
| 21 | `benson-vol-4-approach-tones` | benson:method-vol-4-approach-tones | 372 | n | Sibling |
| 22 | `benson-vol-5-melodic-minor` | benson:method-vol-5-melodic-minor | 434 | n | Sibling (largest book in queue; tight-cap Stage 4) |
| 23 | `benson-vol-6-giant-lines` | benson:method-vol-6-giant-lines | 145 | n | Sibling |
| 24 | `benson-vol-7-blues-ideas` | benson:method-vol-7-blues-ideas | 227 | n | Sibling |

### Tier 4 — Exegetical (NEW masters, exegesis_of[] populated after #333 lands)

| # | Config | Master:Work | Pages | OCR? | Notes |
|---|---|---|---|---|---|
| 25 | `faria-brazilian-guitar-book` | nelson-faria:brazilian-guitar-book | TBD | y | 📚 NEW. Brazilian/jazz exegesis of Jobim & bossa-nova lineage. |
| 26 | `bertoncini-arrangements-solo-guitar` | gene-bertoncini:arrangements-for-solo-guitar | TBD | y | 📚 NEW. Chord-melody arrangements of standards repertoire. |

### Tier 5 — Corpus-only per #320 (contemporary teach-yourself / academic textbook)

| # | Config | Master:Work | Pages | OCR? | Notes |
|---|---|---|---|---|---|
| 27 | `felts-reharmonization-techniques` | randy-felts:reharmonization-techniques | 190 | y | 🟥 Berklee academic textbook author |
| 28 | `laukens-jazz-guitar-patterns-vol-1` | dirk-laukens:jazz-guitar-patterns-vol-1 | TBD | y | 🟥 jazzguitar.be |
| 29 | `laukens-beginners-guide` | dirk-laukens:beginners-guide | 197 | y | 🟥 |
| 30 | `laukens-jazz-guitar-chord-dictionary` | dirk-laukens:jazz-guitar-chord-dictionary | TBD | y | 🟥 |
| 31 | `laukens-tritone-substitution-licks` | dirk-laukens:tritone-substitution-licks | TBD | y | 🟥 |
| 32 | `warnock-beginners-guide` | matt-warnock:beginners-guide-to-jazz-guitar | TBD | y | 🟥 Contemporary online instructor |
| 33 | `larsen-modern-jazz-guitar-concepts` | jens-larsen:modern-jazz-guitar-concepts | TBD | y | 🟥 |
| 34 | `greenan-jazz-standards-playbook` | brent-greenan:jazz-standards-playbook | TBD | y | 🟥 |
| 35 | `heussenstamm-goldmine-100-jazz-lessons` | heussenstamm-silbergleit:goldmine-100-jazz-lessons | TBD | y | 🟥 Online-lesson compilation |
| 36 | `carter-fingerstyle-jazz` | bill-carter:complete-fingerstyle-jazz-guitar | TBD | y | 🟥 Mel Bay teach-yourself genre |

## Out of scope (NOT queued; per project decisions)

- **Foundational theory** per (2a) in May 27 session: Schillinger, Hindemith, Slonimsky, Russo, Aebersold Free Jazz Handbook. These pre-date or sit outside the jazz-guitar-master tradition.
- **Alt-tuning niche material**: All Fourths Tuning for Jazz Guitar (master would be obscure; track only if revisited).
- **Fakebooks / repertoire**: Real Book, Aebersold play-alongs, Charlie Parker Omnibook, Brazilian Real Book, etc. — engine consumes, doesn't ingest.
- **iGigbook system content**: app config, the iGigBook DVD notes / Setup notes, etc.
- **Country & Fingerstyle**: outside the jazz-guitar-master initiative.
- **Private materials**: Trevor's teaching, "Heads as Scale Practice" co-authored, Equipment manuals.
- **Audio albums**: Ted Greene "Solo Guitar 1977" (.flac files), backing tracks under Fundamental Changes/Jazz Guitar Chord Mastery.

## Operational notes

- **Run one book at a time.** Cyberpower vision-rescue serializes on Ollama anyway.
- **Per-book branch.** `feature/<book-slug>` off `develop`; Stage B merges into develop.
- **For books over ~150 pages** (most of Tier 3 + Tier 4 Felts): apply tight-cap Stage 4 prompt from PR #322 to avoid systems-draft subagent timeout.
- **Recovery**: if local orchestrator dies mid-run, `python3 pipelines/master-distillation/ocr/reingest.py <run-id>` pulls the cyberpower outbox + rebuilds Stage 1 outputs.

## How to run a queued book

```bash
python3 pipelines/master-distillation/run.py new-run \
  pipelines/master-distillation/configs/<config-slug>.toml

# at each `awaiting-llm` gate, fill the response file via subagent
# at each `awaiting-review` gate, run --advance to move forward
python3 pipelines/master-distillation/run.py advance <run-id>
python3 pipelines/master-distillation/run.py resume <run-id>

# Stage 1 OCR runs survive laptop close (see #318); recovery via:
python3 pipelines/master-distillation/ocr/reingest.py <run-id>
```

## Refs

#220 #297 #313 #314 #315 #316 #318 #319 #320 #321 #322 #323 #324 #325 #326 #327 #328 #329 #330 #331 #332 #333 #334.
