# Master distillation pipeline

Converts a master's source book(s) into a **statement of outputs** — structured `systems[]` in the masters.json shape, backed by curated quotations and hierarchical summaries.

Tracked in #297. Design note: `../../sessions/260522-ruby-vista/plans/think-297-master-distillation-pipeline.md` (one session out from the repo; not committed).

## The code layer is demonstrably free

This pipeline makes **no LLM API calls** and depends on **no LLM SDK**. Stages that need LLM work hand off via the filesystem:

1. Stage writes a request file (`runs/<id>/llm-calls/<stage>-<scope>.request.json`) containing the prompt + JSON Schema for the expected response, then exits in `awaiting-llm`.
2. A human or agent fills the response file (`<stage>-<scope>.response.json`) using whatever LLM interface they prefer — Claude CLI, Craft Agents, an Ollama wrapper script, even hand-typing.
3. The pipeline picks back up on `resume`, validates the response against the schema, and continues.

No surprise spend lives in `git diff`. Cost responsibility sits at the human/agent layer.

## Bucket criterion (M / P / L / R / S)

Not every book in the queue becomes a master entry. The decision is governed by [PROMOTION-CRITERION.md](PROMOTION-CRITERION.md) — five buckets (`master` / `pedagogue` / library / rules / skip) along two evaluation axes (impact, distinctiveness). #345 supersedes the older binary criterion (#320).

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

## Filling response files

When a stage hits `awaiting-llm`, its request file describes what's needed:

- `system_prompt` + `user_prompt` — feed these to your LLM of choice
- `response_schema` — if present, the response must match this JSON Schema; if absent, the response is free-form prose wrapped as `{"text": "..."}`
- `model` — informational only; you decide what model produces the response

Drop a JSON file at the response path, then `resume`. The pipeline validates against the schema and continues.

This contract is intentionally backend-agnostic. Some ways to fill:
- Craft Agents / Claude desktop — paste request, paste response back. Subagents can parallelize this for per-chapter stages.
- Claude CLI — `cat request.json | claude ... > response.json` (your own wrapper)
- Local LLM (Ollama, llama.cpp, etc.) — your own wrapper script that posts the prompt and writes the response
- Hand-typed — for short prose stages, sometimes the right move

The pipeline doesn't care which.

## Adding a new book

1. Copy `configs/benson-vol-1.toml` to `configs/<your-book-slug>.toml`.
2. Fill in `[master]`, `[work]`, `[source]` sections.
3. Run `new-run` and walk it through.

## Provenance discipline

Every committed artifact starts with a frontmatter block naming the run, stage, source PDF, page range, model, and timestamp. Stage 4 `engine_payload.kind` values are either one of the 12 names traced to `schema-systems-model.md` (post-#295) OR `_pending:<kebab>` placeholders — invented names are structurally blocked by the schema.

## Quote-fidelity validator

Every quote in a committed `chapters/*.md` file must be an exact substring of the run's gitignored raw transcript. Hallucination fails the Stage 2 gate.
