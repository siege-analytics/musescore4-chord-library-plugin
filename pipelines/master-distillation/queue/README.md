# Stage 1 Autonomous Queue Runner

Drains the per-book Stage 1 (extraction / OCR) work on cyberpower without
interactive help. Closes #336.

## What it does

For every config in `pipelines/master-distillation/configs/*.toml` whose
`source.host = "cyberpower"`:

- **Digital books** (`needs_ocr = false`): runs `pdftotext -layout -enc UTF-8`
  directly into `~/jazz-pipeline/outputs/<slug>/raw-transcript.txt`.
- **OCR books** (`needs_ocr = true`): dispatches the existing `~/jazz-ocr/bin/run.sh`
  (tesseract + qwen2.5vl rescue from #316/#318), then copies the outbox
  transcript + page-confidence into `~/jazz-pipeline/outputs/<slug>/`.

Each book is marked `.done` (success), `.error` (failed), or `.lock` (running)
under `~/jazz-pipeline/state/`. Stale locks (pid not alive) are cleared on
daemon startup so the runner survives crashes.

## Files

- `config.sh` — variables (LIBRARY_ROOT, OUTPUT_DIR, OLLAMA_URL, etc.)
- `lib.sh` — sourced helpers (state predicates, eligibility filter)
- `process_one.sh` — per-book worker
- `queue_runner.sh` — daemon main loop
- `manifest_from_configs.py` — reads `configs/*.toml` and writes the
  flat manifest the bash runner consumes. Re-run when configs change.
- `deploy.sh` — rsyncs the bundle to cyberpower + regenerates manifest

## First-time setup

From the laptop:

```bash
./pipelines/master-distillation/queue/deploy.sh
```

This:
1. Creates `~/jazz-pipeline/{state,logs,outputs}` on cyberpower
2. scp's the scripts to `~/jazz-pipeline/`
3. rsyncs a snapshot of `configs/` to `~/jazz-pipeline/configs-snapshot/`
4. Runs `manifest_from_configs.py` on cyberpower to build `~/jazz-pipeline/manifest.tsv`

## Start the daemon

```bash
ssh dheerajchand@cyberpower 'nohup bash ~/jazz-pipeline/queue_runner.sh \
    >>~/jazz-pipeline/logs/daemon.stdout \
    2>>~/jazz-pipeline/logs/daemon.stderr & disown'
```

## Inspect progress

```bash
# State markers
ssh cyberpower 'ls ~/jazz-pipeline/state/'

# Daemon log
ssh cyberpower 'tail -f ~/jazz-pipeline/logs/daemon.stdout'

# Per-book log
ssh cyberpower 'tail -f ~/jazz-pipeline/logs/<slug>.stdout'

# How many done?
ssh cyberpower 'ls ~/jazz-pipeline/state/*.done 2>/dev/null | wc -l'
```

## Retry a failed book

Clear the `.error` marker; the daemon will pick it up on the next iteration.

```bash
ssh cyberpower 'rm ~/jazz-pipeline/state/<slug>.error'
```

## Stop the daemon

```bash
ssh cyberpower 'pkill -TERM -f queue_runner.sh'
```

## Refresh after config changes

After a queue-rewrite PR merges (e.g. #335), re-deploy to pick up new
configs:

```bash
./pipelines/master-distillation/queue/deploy.sh
```

This re-pushes the configs snapshot and regenerates the manifest. The
daemon will pick up the new manifest on its next iteration (no daemon
restart needed; the bash runner re-reads the manifest every cycle).

## Variable overrides

The config.sh file uses `: "${VAR:=default}"` form so any variable can be
overridden via the environment. Example: run with a different output dir
without editing the deployed config.sh:

```bash
ssh cyberpower 'OUTPUT_DIR=/tmp/test-outputs bash ~/jazz-pipeline/queue_runner.sh'
```

## What this does NOT do

- **Stages 2-4** (LLM-driven summaries / systems / STATEMENT) — those require
  subagent dispatch from the laptop. The daemon only drains Stage 1.
- **Concurrent multi-book runs** — single-threaded. OCR is GPU-serialized
  anyway via Ollama; parallel digital books would help marginally but
  isn't worth the complexity.
- **Auto-rsync to laptop** — after Stage 1 outputs land on cyberpower, the
  laptop-side `pipelines/master-distillation/ocr/reingest.py <run-id>`
  pulls them down and runs them through the local indexer.

## Refs

#297 #315 #316 #318 #329 #330 #331 #332 #334 #335 #336.
