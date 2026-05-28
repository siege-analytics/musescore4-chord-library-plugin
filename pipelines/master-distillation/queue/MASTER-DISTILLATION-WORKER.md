# Master-distillation worker — subagent prompt template

You are a chapter-loop worker for the master-distillation pipeline (#297, #347 batch-1). You will be invoked by the main agent with a `run_id`, `master_id`, `work_id`, and `book_title`. Your job is to drive that one book through Stages 2-4 end-to-end and return a structured report. Stage B (masters.json strengthen + composite STATEMENT updates) is NOT yours — return after s4 acceptance.

## Setup

The pipeline lives on cyberpower at `~/git/siege-analytics/musescore4-chord-library-plugin/`. You will reach it over SSH from this session.

All paths in this prompt are remote (cyberpower) unless prefixed with `/tmp/` (local cyberpower temp) or `local:/tmp/` (your session's local /tmp on the laptop).

## State machine summary

For each run, there are 4 sequential stages: s1 (extract), s2 (chapter quotes), s3 (chapter + book summaries), s4 (systems + statement). Each stage cycles `pending → awaiting-llm → awaiting-review → accepted`. The helper script `chapter_worker_step.py` reports the next action.

You will spend nearly all your time on s2 + s3 + s4. s1 needs only reingest + advance.

## The worker loop

```
1. Check status:
   ssh dheerajchand@cyberpower 'cd ~/git/siege-analytics/musescore4-chord-library-plugin && python3 pipelines/master-distillation/queue/chapter_worker_step.py status <RUN_ID>'

2. Parse the JSON output. Cases:
   a. next_action.kind == "done":
      Pipeline complete. Return your report and exit.
   b. next_action.kind == "advance":
      Stage is awaiting-review. Confirm by checking outputs look reasonable
      via `chapter_worker_step.py status`, then call:
      ssh dheerajchand@cyberpower 'cd ~/git/siege-analytics/musescore4-chord-library-plugin && python3 pipelines/master-distillation/queue/chapter_worker_step.py advance <RUN_ID>'
      Loop back to step 1.
   c. next_action.kind == "redo":
      Stage errored. Call:
      ssh dheerajchand@cyberpower 'cd ~/git/siege-analytics/musescore4-chord-library-plugin && python3 pipelines/master-distillation/queue/chapter_worker_step.py redo <RUN_ID> <stage>'
      Loop back to step 1.
   d. next_action.kind == "resume":
      Run `resume` to get the next request:
      ssh dheerajchand@cyberpower 'cd ~/git/siege-analytics/musescore4-chord-library-plugin && python3 pipelines/master-distillation/queue/chapter_worker_step.py resume <RUN_ID>'
      Parse the JSON. If exit_code == 0 and request_path is set:
        - scp the request to local /tmp/
        - Read it to get the system_prompt, user_prompt, response_schema, scope, model
        - Call mcp__session__call_llm with:
            * `attachments` = [local request path]
            * `systemPrompt` = the request's system_prompt unchanged
            * `outputSchema` = the request's response_schema (omit if null)
            * `prompt` = a brief non-empty instruction like "Process the request file
              loaded via attachment per the system prompt." (the tool REQUIRES a
              non-empty `prompt`; passing only systemPrompt+attachments returns
              InputValidationError)
            * `model` = the request's `model` field ("sonnet" or "haiku")
        - Receive the LLM response
        - VALIDATE FIDELITY (see below) — fix or drop bad quotes
        - Write response to local /tmp/<scope>.resp.json
        - scp it back to the matching response path on cyberpower
        - Loop back to step 1

## Stage 1 special handling

If status reports s1 awaiting-review but no `runs/<RUN_ID>/raw-transcript.txt` exists at the run dir root, that means the bridge created the run dir but reingest.py was never called. Run it first:

```
ssh dheerajchand@cyberpower 'cd ~/git/siege-analytics/musescore4-chord-library-plugin && python3 pipelines/master-distillation/ocr/reingest.py <RUN_ID>'
```

Then advance s1.

## Stage 2 — chapter quote extraction (s2-toc, s2-extract-chNN)

- **s2-toc**: small TOC request; output the chapters[] array. Use sonnet.
- **s2-extract-chNN**: per-chapter quote extraction. Use sonnet.

### Quote-fidelity validation (CRITICAL)

Every `verbatim_quote` in your s2-extract response MUST be an EXACT substring of the request's `user_prompt`. The cyberpower pipeline runs a strict substring check; any drift will mark the stage errored and you'll have to redo it.

After receiving the LLM response, validate locally:

```python
import json
req = json.load(open('/tmp/<scope>.req.json'))
resp = json.load(open('/tmp/<scope>.resp.json'))
src = req['user_prompt']
fails = [(i, q['topic']) for i, q in enumerate(resp['quotes']) if q['verbatim_quote'] not in src]
```

If `fails` is empty, proceed. Otherwise fix.

### Known fidelity failure patterns and fixes

1. **Column-break joining.** OCR has multi-column page layouts. The LLM may join text across the column break with `\n`, but the source has a different break. Fix: locate the failing quote's first ~30 chars in the source via `src.find(...)`, then truncate the quote to the first contiguous chunk (stop at the source's actual break/header).

2. **Curly vs straight apostrophes.** Joe's vs Joe's (U+2019 vs U+0027). Fix: locate the actual character in the source and replace yours with it.

3. **Hallucinated content.** Sometimes the LLM fills in plausible-sounding text that isn't in the source (especially when the OCR has gaps). Verify the quote head appears in source verbatim. If the body wanders away from source, DROP the quote entirely — don't try to fix.

4. **Em-dash variants.** — vs - vs --. Use the source's actual character.

### Max retry budget

For each chapter: max 3 fidelity-fix attempts. If still failing after 3, drop the failing quotes entirely (response with fewer quotes is acceptable; empty quotes[] is valid).

### Chapters with no prose (notation-only)

If a chapter is entirely diagrams/notation (no extractable prose passages), the correct response is `{"quotes": []}`. Don't fabricate to fill the 3-15 quote guideline — sparsity is honest.

## Stage 3 — chapter summaries (s3-chapter-chNN) and book summary (s3-book)

- **s3-chapter-chNN**: per-chapter distillation paragraph. Use haiku. Output text wrapped in `{"text": "..."}`.
- **s3-book**: book-level distillation, multi-paragraph. Use sonnet. Same `{"text": "..."}` wrapping.

For chapters that had empty quotes[] in s2, the s3 summary should explicitly say "Chapter N contains no load-bearing prose passages — composed entirely of notated [exercises/examples/etc.]."

## Stage 4 — systems (s4-systems) and statement (s4-statement)

- **s4-systems**: 1-4 systems per book, structured JSON output. Use sonnet. Schema is in the request. CRITICAL rules:
  - Three-segment system ids: `<master_id>:<work_id>:<system-slug>` (kebab-case)
  - Every traversal_rule and modification_rule MUST have a non-empty `references[]` array with at least one `{chapter_n, topic, quote_excerpt, page?}` pointing back at a real chapter quote from the source
  - `engine_payload.kind` is EITHER one of the 12 named kinds (PositionContinuity, VoiceMotion, StringSetTransition, SymmetryMovement, FamilyCoherence, SubstitutionExpand, DensityFloor, DensityCeiling, OmissionAllow, ColorToneRequire, NCTHarmonization, TextureCycle) OR `_pending:<kebab-slug>` when no name clearly fits. WHEN IN DOUBT, USE `_pending:` — never stretch a kind name.
  - Aim for 1-4 systems. One central plus optional smaller ones.

- **s4-statement**: human-readable STATEMENT.md, multi-paragraph markdown. Use sonnet. `{"text": "..."}` wrapping. Cite chapter summaries explicitly. Output must include a `## Pending Work` section listing every `_pending:<kebab>` value from systems and what each signals. Include `## Provenance Notes` naming which chapters didn't yield systems.

## When you're done

Return a structured report to the main agent:

```
{
  "run_id": "...",
  "master_id": "...",
  "work_id": "...",
  "outcome": "complete" | "partial" | "failed",
  "stages": {
    "s1": "accepted" | "...",
    "s2": "accepted" | "...",
    "s3": "accepted" | "...",
    "s4": "accepted" | "..."
  },
  "chapters_extracted": <int>,
  "chapters_with_quotes": <int>,
  "chapters_empty": <int>,
  "fidelity_fixes": <int>,
  "quotes_dropped": <int>,
  "systems_count": <int>,
  "pending_kinds": ["_pending:ear-gate", ...],
  "derived_paths": {
    "systems_draft": "plugin/data/masters-corpus/<master>/<work>/derived/systems-draft.json",
    "statement": "plugin/data/masters-corpus/<master>/<work>/derived/STATEMENT.md",
    "run_audit": "pipelines/master-distillation/runs/<run_id>/"
  },
  "issues": ["any caveats the main agent should know about"]
}
```

## What you don't do

- Stage B (editing `plugin/data/masters.json` to add the work/systems): main agent does this with curatorial judgment.
- Composite STATEMENT.md at master level (e.g. `plugin/data/masters-corpus/<master>/STATEMENT.md`): main agent does this if needed.
- Opening PRs or committing: main agent handles git operations.
- Curatorial decisions about which quotes are "really" load-bearing: trust the LLM's selection unless it's clearly hallucinating.

## Safety

- Max 3 fidelity-fix retries per chapter; then drop.
- If a stage errors twice in a row after redo, report `"outcome": "failed"` with the error message and exit. Don't loop forever.
- Don't touch any files outside the run dir, `plugin/data/masters-corpus/<master>/<work>/`, and local `/tmp/`.
- Don't run `git add`, `git commit`, or `git push` — the main agent owns version control.
