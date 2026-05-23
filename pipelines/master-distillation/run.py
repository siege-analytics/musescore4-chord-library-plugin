#!/usr/bin/env python3
"""Master distillation pipeline orchestrator.

Usage:
  run.py new-run configs/benson-vol-1.yaml
      Create a new run dir, write a fresh stage-state.json, run the
      next pending stage. Exits in awaiting-review (or awaiting-llm).

  run.py resume <run-id>
      Continue the named run from wherever it left off.

  run.py advance <run-id>
      Mark the current awaiting-review stage as accepted. Queue the
      next stage (does not run it; call resume).

  run.py redo <run-id> <stage>
      Reset <stage> (and all downstream stages) to pending. Clears
      committed artifacts for those stages.

  run.py status <run-id>
      Print the current state machine.

Stage 1 is implemented today (`stages.s1_extract`). Stages 2-4 are
stubs that raise NotImplementedError; they get filled in as the user
walks through Benson Vol 1.
"""

from __future__ import annotations

import argparse
import importlib
import sys
import tomllib
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(PIPELINE_DIR))

from lib import paths, state  # noqa: E402
from lib.llm import PendingLLMOutput  # noqa: E402


def _load_config(config_path: Path) -> dict:
    return tomllib.loads(config_path.read_text())


def _book_paths(cfg: dict, run_id: str) -> paths.BookPaths:
    return paths.BookPaths(
        master_id=cfg["master"]["id"],
        work_id=cfg["work"]["id"],
        run_id=run_id,
    )


def _stage_module(stage: str):
    return importlib.import_module(f"stages.{_stage_module_name(stage)}")


def _stage_module_name(stage: str) -> str:
    return {
        "s1": "s1_extract",
        "s2": "s2_chapters",
        "s3": "s3_distill",
        "s4": "s4_systems",
    }[stage]


def cmd_new_run(args: argparse.Namespace) -> int:
    config_path = Path(args.config)
    if not config_path.exists():
        print(f"config not found: {config_path}", file=sys.stderr)
        return 1
    cfg = _load_config(config_path)
    slug = config_path.stem  # e.g. "benson-vol-1"
    run_id = state.make_run_id(slug)

    book = _book_paths(cfg, run_id)
    book.ensure_dirs()

    run = state.RunState.new(run_id, str(config_path))
    run.save(book.state_file)

    print(f"created run {run_id}")
    print(f"  config: {config_path}")
    print(f"  run dir: {book.run_dir}")
    print(f"  corpus dir: {book.committed_work_dir}")
    print()
    return _run_next(run_id)


def cmd_resume(args: argparse.Namespace) -> int:
    return _run_next(args.run_id)


def cmd_advance(args: argparse.Namespace) -> int:
    run_id = args.run_id
    run, book = _load_run(run_id)
    # Find the stage that's awaiting-review
    awaiting = [s for s, r in run.stages.items() if r.status == "awaiting-review"]
    if not awaiting:
        print(f"no stage in awaiting-review for run {run_id}")
        return 1
    stage = awaiting[0]
    run.advance(stage)
    run.save(book.state_file)
    print(f"advanced stage {stage} for run {run_id}")
    print("run --resume to continue with the next stage")
    return 0


def cmd_redo(args: argparse.Namespace) -> int:
    run_id = args.run_id
    stage = args.stage
    run, book = _load_run(run_id)
    run.redo(stage)
    run.save(book.state_file)
    print(f"reset stage {stage} (and downstream) for run {run_id}")
    print("run --resume to re-run from this stage")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    run, _ = _load_run(args.run_id)
    print(f"run: {run.run_id}")
    print(f"config: {run.config}")
    for stage in state.STAGE_ORDER:
        rec = run.stages[stage]
        ts = rec.ended_at or rec.started_at or ""
        print(f"  {stage}: {rec.status:18s} {ts}")
        if rec.error_message:
            print(f"      error: {rec.error_message}")
        if rec.outputs:
            for out in rec.outputs:
                print(f"      -> {out}")
    return 0


def _load_run(run_id: str) -> tuple[state.RunState, paths.BookPaths]:
    run_dir = paths.RUNS_ROOT / run_id
    state_file = run_dir / "stage-state.json"
    if not state_file.exists():
        raise SystemExit(f"no run found at {run_dir}")
    run = state.RunState.load(state_file)
    cfg = _load_config(Path(run.config))
    book = _book_paths(cfg, run_id)
    return run, book


def _run_next(run_id: str) -> int:
    run, book = _load_run(run_id)
    next_stage = run.next_runnable_stage()
    if next_stage is None:
        # Either complete, blocked on review, or blocked on error.
        if all(r.status == "accepted" for r in run.stages.values()):
            print(f"run {run_id} is complete.")
            return 0
        print(
            f"run {run_id} is blocked. Use --status to inspect, "
            f"--advance to accept an awaiting-review stage, or "
            f"--redo <stage> to re-run."
        )
        return 0

    cfg = _load_config(Path(run.config))
    mod = _stage_module(next_stage)
    run.mark_running(next_stage)
    run.save(book.state_file)
    print(f"running stage {next_stage}...")

    try:
        outputs = mod.run(cfg, book)
    except PendingLLMOutput as pending:
        # The stage needs an LLM response that hasn't arrived. Surface
        # to the user/agent and leave the state machine in 'running' so
        # that --resume will pick back up once the response is written.
        run.stages[next_stage].status = "awaiting-llm"  # type: ignore[assignment]
        run.save(book.state_file)
        print()
        print(f"[awaiting-llm] stage {next_stage} needs LLM output for scope='{pending.scope}'.")
        print(f"  request:  {pending.request_path}")
        print(f"  response: {pending.response_path}")
        print()
        print(
            "Fill the response file using any LLM interface (Craft Agents, "
            "Claude CLI, local Ollama wrapper, hand-typed). Re-running this "
            "stage will not regenerate the request prompt; if you want to "
            "edit it, edit the request file directly, then write the "
            "response. The pipeline does NOT auto-retry on schema or "
            "fidelity failure — edit the response file and re-resume."
        )
        print()
        print(
            "Run the LLM (e.g. via call_llm) using the request file, "
            "save the parsed JSON response to the response path, then "
            "run `run.py --resume " + run_id + "`."
        )
        return 0
    except Exception as e:  # noqa: BLE001
        run.mark_error(next_stage, str(e))
        run.save(book.state_file)
        print(f"stage {next_stage} errored: {e}", file=sys.stderr)
        return 2

    run.mark_awaiting_review(next_stage, outputs)
    run.save(book.state_file)
    print()
    print(f"[awaiting-review] stage {next_stage} completed.")
    for out in outputs:
        print(f"  -> {out}")
    print()
    print(
        "Review the outputs above. Run `run.py --advance " + run_id + "` "
        "to accept and queue the next stage, or `run.py --redo " + run_id +
        " " + next_stage + "` to re-run."
    )
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Master distillation pipeline")
    sub = p.add_subparsers(dest="command", required=True)

    p_new = sub.add_parser("new-run", help="start a fresh run")
    p_new.add_argument("config", help="path to per-book YAML config")
    p_new.set_defaults(func=cmd_new_run)

    p_resume = sub.add_parser("resume", help="continue an existing run")
    p_resume.add_argument("run_id")
    p_resume.set_defaults(func=cmd_resume)

    p_adv = sub.add_parser("advance", help="accept current awaiting-review stage")
    p_adv.add_argument("run_id")
    p_adv.set_defaults(func=cmd_advance)

    p_redo = sub.add_parser("redo", help="reset a stage")
    p_redo.add_argument("run_id")
    p_redo.add_argument("stage", choices=state.STAGE_ORDER)
    p_redo.set_defaults(func=cmd_redo)

    p_status = sub.add_parser("status", help="print run state")
    p_status.add_argument("run_id")
    p_status.set_defaults(func=cmd_status)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
