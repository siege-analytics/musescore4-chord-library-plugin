"""Tests for the queue daemon state-marker backfill script (#452).

The backfill scans pipelines/master-distillation/runs/*/stage-state.json and
writes ~/jazz-pipeline/state/<slug>.done for any run with s1=accepted.
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = (
    REPO_ROOT
    / "pipelines"
    / "master-distillation"
    / "queue"
    / "state_backfill.py"
)


def _load_module():
    spec = importlib.util.spec_from_file_location("state_backfill", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


backfill = _load_module()


def _write_run_state(
    run_dir: Path,
    config_path: str,
    s1_status: str,
    run_id: str | None = None,
) -> Path:
    """Write a minimal stage-state.json file. Returns its path."""
    run_dir.mkdir(parents=True, exist_ok=True)
    state_file = run_dir / "stage-state.json"
    state_file.write_text(
        json.dumps(
            {
                "run_id": run_id or run_dir.name,
                "config": config_path,
                "stages": {
                    "s1": {"status": s1_status},
                    "s2": {"status": "pending"},
                    "s3": {"status": "pending"},
                    "s4": {"status": "pending"},
                    "s5": {"status": "pending"},
                },
            },
            indent=2,
        )
        + "\n"
    )
    return state_file


def test_config_slug_from_canonical_repo_relative_path():
    assert (
        backfill._config_slug(
            "pipelines/master-distillation/configs/laukens-complete-chord-melody.toml",
            Path("/anything"),
        )
        == "laukens-complete-chord-melody"
    )


def test_config_slug_rejects_non_toml():
    assert backfill._config_slug("foo/bar.yaml", Path("/x")) is None


def test_collect_only_returns_s1_accepted_runs(tmp_path):
    runs_root = tmp_path / "runs"
    accepted_dir = runs_root / "2026-06-10T15-35-34-laukens-complete-chord-melody"
    running_dir = runs_root / "2026-06-10T22-47-48-goodrick-almanac-vol-1"
    pending_dir = runs_root / "2026-06-09T01-02-03-roberts-chord-melody"

    _write_run_state(
        accepted_dir,
        "pipelines/master-distillation/configs/laukens-complete-chord-melody.toml",
        "accepted",
    )
    _write_run_state(
        running_dir,
        "pipelines/master-distillation/configs/goodrick-almanac-vol-1.toml",
        "running",
    )
    _write_run_state(
        pending_dir,
        "pipelines/master-distillation/configs/roberts-chord-melody.toml",
        "pending",
    )

    completed = backfill.collect_completed_slugs(runs_root, tmp_path / "configs")
    assert set(completed.keys()) == {"laukens-complete-chord-melody"}, (
        "only s1=accepted runs should be in the result"
    )


def test_collect_handles_missing_runs_root(tmp_path):
    """No runs dir yet (fresh checkout) — should not raise."""
    assert backfill.collect_completed_slugs(tmp_path / "absent", tmp_path) == {}


def test_collect_dedupes_by_slug_keeping_most_recent(tmp_path):
    """When the same config slug has multiple runs (e.g. a redo), the
    most-recently-modified state file wins."""
    runs_root = tmp_path / "runs"
    older = runs_root / "2026-05-01T00-00-00-laukens-beginners-guide"
    newer = runs_root / "2026-06-10T00-00-00-laukens-beginners-guide"
    older_state = _write_run_state(
        older,
        "pipelines/master-distillation/configs/laukens-beginners-guide.toml",
        "accepted",
    )
    newer_state = _write_run_state(
        newer,
        "pipelines/master-distillation/configs/laukens-beginners-guide.toml",
        "accepted",
    )
    # Force monotonic mtime ordering — touch newer to a later time.
    import os
    import time

    os.utime(older_state, (time.time() - 100, time.time() - 100))
    os.utime(newer_state, (time.time(), time.time()))

    completed = backfill.collect_completed_slugs(runs_root, tmp_path / "configs")
    assert completed == {"laukens-beginners-guide": newer_state}


def test_write_marker_creates_file_with_audit_body(tmp_path):
    state_dir = tmp_path / "state"
    src = tmp_path / "stage-state.json"
    src.write_text("{}")
    marker = backfill.write_marker(state_dir, "laukens-beginners-guide", src)
    assert marker == state_dir / "laukens-beginners-guide.done"
    body = marker.read_text()
    # Two lines: ISO timestamp + BACKFILLED_FROM
    lines = body.strip().splitlines()
    assert len(lines) == 2
    assert lines[0].startswith("2026-") or lines[0].startswith("20")
    assert lines[1].startswith("BACKFILLED_FROM: ")
    assert str(src) in lines[1]


def test_main_dry_run_does_not_write(tmp_path, capsys):
    runs_root = tmp_path / "runs"
    state_dir = tmp_path / "state"
    _write_run_state(
        runs_root / "run-a",
        "pipelines/master-distillation/configs/example-book.toml",
        "accepted",
    )
    rc = backfill.main(
        [
            "--runs-root",
            str(runs_root),
            "--state-dir",
            str(state_dir),
            "--configs-root",
            str(tmp_path / "configs"),
            "--dry-run",
        ]
    )
    assert rc == 0
    assert not state_dir.exists(), "dry-run must not create state dir"
    captured = capsys.readouterr().out
    assert "WOULD WRITE" in captured
    assert "example-book.done" in captured


def test_main_actual_run_writes_markers(tmp_path):
    runs_root = tmp_path / "runs"
    state_dir = tmp_path / "state"
    _write_run_state(
        runs_root / "run-a",
        "pipelines/master-distillation/configs/example-book.toml",
        "accepted",
    )
    rc = backfill.main(
        [
            "--runs-root",
            str(runs_root),
            "--state-dir",
            str(state_dir),
            "--configs-root",
            str(tmp_path / "configs"),
        ]
    )
    assert rc == 0
    marker = state_dir / "example-book.done"
    assert marker.exists()
    assert "BACKFILLED_FROM" in marker.read_text()


def test_main_idempotent_when_marker_already_present(tmp_path, capsys):
    runs_root = tmp_path / "runs"
    state_dir = tmp_path / "state"
    state_dir.mkdir()
    (state_dir / "example-book.done").write_text("existing-marker\n")
    _write_run_state(
        runs_root / "run-a",
        "pipelines/master-distillation/configs/example-book.toml",
        "accepted",
    )
    rc = backfill.main(
        [
            "--runs-root",
            str(runs_root),
            "--state-dir",
            str(state_dir),
            "--configs-root",
            str(tmp_path / "configs"),
        ]
    )
    assert rc == 0
    # The existing marker is preserved (idempotent — don't clobber).
    assert (state_dir / "example-book.done").read_text() == "existing-marker\n"
    out = capsys.readouterr().out
    assert "ALREADY:" in out
    assert "wrote 0" in out


def test_collect_skips_runs_with_no_config_field(tmp_path):
    """A malformed stage-state.json with no `config` field should be
    silently skipped, not crash the script."""
    runs_root = tmp_path / "runs"
    run_dir = runs_root / "run-broken"
    run_dir.mkdir(parents=True)
    (run_dir / "stage-state.json").write_text(
        json.dumps({"run_id": "x", "stages": {"s1": {"status": "accepted"}}})
        + "\n"
    )
    assert backfill.collect_completed_slugs(runs_root, tmp_path) == {}


def test_collect_skips_malformed_json(tmp_path):
    """A garbage stage-state.json file should be silently skipped."""
    runs_root = tmp_path / "runs"
    run_dir = runs_root / "run-broken"
    run_dir.mkdir(parents=True)
    (run_dir / "stage-state.json").write_text("not-json{{{")
    assert backfill.collect_completed_slugs(runs_root, tmp_path) == {}
