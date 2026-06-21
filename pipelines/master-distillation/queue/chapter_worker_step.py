#!/usr/bin/env python3
"""Single-step helper for the chapter-loop subagent worker.

Given a run_id, this tool drives one step of the Stages 2-4 dispatch:
inspecting the current state, advancing where possible, and reporting
back the next request file path that needs an LLM response.

The subagent loop uses this instead of scraping run.py stdout.

Usage:
    chapter_worker_step.py status <run_id>
        -> prints JSON: {state, current_stage, current_status,
                         next_action}
        where next_action is one of:
          - {"kind": "advance"}     stage is awaiting-review; call --advance
          - {"kind": "respond", "request_path": "...", "model": "..."}
                                    stage is awaiting-llm; fill response
          - {"kind": "redo", "stage": "sN"}  stage errored; reset + retry
          - {"kind": "done"}        run is fully through s4 accepted
          - {"kind": "blocked", "reason": "..."}

    chapter_worker_step.py advance <run_id>
        -> calls run.py advance (only if current stage is awaiting-review)

    chapter_worker_step.py resume <run_id>
        -> calls run.py resume (emits next request file)

    chapter_worker_step.py redo <run_id> <stage>
        -> calls run.py redo and then resume

Ticket: #353
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
RUNS_DIR = REPO_ROOT / "pipelines" / "master-distillation" / "runs"
RUN_PY = REPO_ROOT / "pipelines" / "master-distillation" / "run.py"

TERMINAL_OK_STAGES = ("s4",)


def load_state(run_id: str) -> dict:
    state_path = RUNS_DIR / run_id / "stage-state.json"
    if not state_path.exists():
        raise SystemExit(f"run dir not found: {state_path.parent}")
    return json.loads(state_path.read_text())


def call_runpy(*args: str) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["python3", str(RUN_PY), *args],
        capture_output=True, text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def parse_request_path(stdout: str) -> tuple[str | None, str | None]:
    """Find the 'request:' and 'response:' lines emitted by run.py resume."""
    req = None
    scope = None
    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith("request:"):
            req = line.split("request:", 1)[1].strip()
        if "[awaiting-llm]" in line and "scope=" in line:
            try:
                scope = line.split("scope='", 1)[1].split("'", 1)[0]
            except IndexError:
                pass
    return req, scope


def cmd_status(run_id: str) -> dict:
    state = load_state(run_id)
    stages = state["stages"]
    # Find the first non-accepted stage
    for stage_id in ("s1", "s2", "s3", "s4"):
        st = stages.get(stage_id, {})
        status = st.get("status", "pending")
        if status == "accepted":
            continue
        # This is the current frontier stage
        if status == "pending":
            # Need to call resume to start it
            return {"state": "frontier", "current_stage": stage_id, "current_status": status,
                    "next_action": {"kind": "resume"}}
        if status == "awaiting-llm":
            return {"state": "frontier", "current_stage": stage_id, "current_status": status,
                    "next_action": {"kind": "resume"}}  # resume re-emits the request
        if status == "awaiting-review":
            return {"state": "frontier", "current_stage": stage_id, "current_status": status,
                    "next_action": {"kind": "advance"}}
        if status == "error":
            return {"state": "frontier", "current_stage": stage_id, "current_status": status,
                    "next_action": {"kind": "redo", "stage": stage_id},
                    "error_message": st.get("error_message")}
    # All s1-s4 are accepted
    return {"state": "done", "next_action": {"kind": "done"}}


def cmd_resume(run_id: str) -> dict:
    code, stdout, stderr = call_runpy("resume", run_id)
    req_path, scope = parse_request_path(stdout)
    return {
        "exit_code": code,
        "stdout_tail": stdout.splitlines()[-5:] if stdout else [],
        "stderr_tail": stderr.splitlines()[-3:] if stderr else [],
        "request_path": req_path,
        "scope": scope,
    }


def cmd_advance(run_id: str) -> dict:
    code, stdout, stderr = call_runpy("advance", run_id)
    return {
        "exit_code": code,
        "stdout_tail": stdout.splitlines()[-3:] if stdout else [],
        "stderr_tail": stderr.splitlines()[-3:] if stderr else [],
    }


def cmd_redo(run_id: str, stage: str) -> dict:
    code, stdout, stderr = call_runpy("redo", run_id, stage)
    return {
        "exit_code": code,
        "stdout_tail": stdout.splitlines()[-3:] if stdout else [],
        "stderr_tail": stderr.splitlines()[-3:] if stderr else [],
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("status")
    sp.add_argument("run_id")

    sp = sub.add_parser("resume")
    sp.add_argument("run_id")

    sp = sub.add_parser("advance")
    sp.add_argument("run_id")

    sp = sub.add_parser("redo")
    sp.add_argument("run_id")
    sp.add_argument("stage")

    args = p.parse_args()

    if args.cmd == "status":
        out = cmd_status(args.run_id)
    elif args.cmd == "resume":
        out = cmd_resume(args.run_id)
    elif args.cmd == "advance":
        out = cmd_advance(args.run_id)
    elif args.cmd == "redo":
        out = cmd_redo(args.run_id, args.stage)
    else:
        return 2

    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
