# Master distillation pipeline

Converts a master's source book(s) into a **statement of outputs** — structured `systems[]` in the masters.json shape, backed by curated quotations and hierarchical summaries.

Tracked in #297. Design note: `../../sessions/260522-ruby-vista/plans/think-297-master-distillation-pipeline.md` (one session out from the repo; not committed).

## What the pipeline produces

Per book, COMMITTED under `plugin/data/masters-corpus/<master>/<work>/`:

```
chapters/
  ch01.md ... chNN.md          curated verbatim quotes per chapter
summaries/
  ch01-summary.md ... chNN-summary.md   per-chapter distillations
<work>-book-summary.md         book-level distillation
derived/
  systems-draft.json           candidate systems[] for masters.json
  STATEMENT.md                 the statement of outputs (prose + citations)
```

Per book, COMMITTED under `runs/<timestamp>-<slug>/` (audit trail):

```
pages.json                     page index
chapter-bounds.json            page-to-chapter mapping
llm-calls/                     every LLM request + response
stage-state.json               state machine
```

Per book, GITIGNORED under `runs/<timestamp>-<slug>/`:

```
raw-transcript.txt             full PDF extraction (copyrighted book text)
```

The committed canonical outputs are what the system knows. The committed `runs/` state is the reproducible audit trail. Only the full-book transcript stays out of the repo for copyright; curated quotes (subsets, attributed, used for commentary) are fair use and committed under `chapters/`.

## Stages

1. **`s1_extract`** — PDF → raw transcript + per-page index. No LLM.
2. **`s2_chapters`** — Curated verbatim quote extraction per chapter. Haiku.
3. **`s3_distill`** — Per-chapter summaries + book-level distillation. Haiku + Sonnet.
4. **`s4_systems`** — Statement of outputs + systems-draft.json. Sonnet.

## Usage

### Start a new run

```sh
python pipelines/master-distillation/run.py new-run \
  pipelines/master-distillation/configs/benson-vol-1.toml
```

Creates a fresh run dir, writes `stage-state.json`, runs Stage 1, exits in `awaiting-review`.

### Advance through stages

```sh
python pipelines/master-distillation/run.py advance <run-id>
python pipelines/master-distillation/run.py resume <run-id>
```

`advance` accepts the current `awaiting-review` stage. `resume` runs the next pending stage.

### Re-run a stage

```sh
python pipelines/master-distillation/run.py redo <run-id> <s2|s3|s4>
```

Resets the named stage AND all downstream stages to `pending`. Re-run with `resume`.

### Inspect state

```sh
python pipelines/master-distillation/run.py status <run-id>
```

## LLM invocation (interim)

Until the Anthropic SDK is wired up, LLM-driven stages (2-4) write their prompts to `runs/<run-id>/llm-calls/<stage>-<scope>.request.json` and exit in `awaiting-llm`. The agent (or a human) runs the LLM with that prompt, drops the parsed JSON response at `runs/<run-id>/llm-calls/<stage>-<scope>.response.json`, then `resume`s.

A follow-up ticket will add direct SDK support so the pipeline can run autonomously.

## Adding a new book

1. Copy `configs/benson-vol-1.toml` to `configs/<your-book-slug>.toml`.
2. Fill in `[master]`, `[work]`, `[source]` sections.
3. Run `new-run` and walk it through.

## Provenance discipline

Every committed artifact starts with a frontmatter block naming the run, stage, source PDF, page range, model, and timestamp. Stage 4 `engine_payload.kind` values are either one of the 12 names traced to `schema-systems-model.md` (post-#295) OR `_pending:<kebab>` placeholders — invented names are structurally blocked by the schema.

## Quote-fidelity validator

Every quote in a committed `chapters/*.md` file must be an exact substring of the run's gitignored raw transcript. Hallucination fails the Stage 2 gate.
