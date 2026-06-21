"""#578: lint gate — no bare console.log() in plugin/model/*.qml or model/*.js.

Model-layer .pragma library modules and QML controllers should route diagnostic
output through DebugLog.log/warn so production stays quiet and developers can
enable verbose logs without re-editing call sites.

Surfaced by external hostile review 2026-06-21 (P4 finding).
"""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = REPO_ROOT / "plugin" / "model"


def _model_files():
    return sorted(list(MODEL_DIR.glob("*.qml")) + list(MODEL_DIR.glob("*.js")))


def test_model_dir_exists():
    assert MODEL_DIR.is_dir()


def test_at_least_one_model_file_exists():
    assert len(_model_files()) > 5  # sanity floor


def test_no_bare_console_log_in_model():
    """No file under plugin/model/ may contain `console.log(` calls — use DebugLog."""
    offenders = []
    bare_pattern = re.compile(r"\bconsole\.log\s*\(")
    for f in _model_files():
        # DebugLog.js is the canonical exception — it implements the gated wrapper
        if f.name == "DebugLog.js":
            continue
        text = f.read_text()
        for ln, line in enumerate(text.splitlines(), start=1):
            if bare_pattern.search(line):
                offenders.append(f"{f.relative_to(REPO_ROOT)}:{ln}: {line.strip()}")
    assert not offenders, (
        "Bare console.log calls found in plugin/model/. Use DebugLog.log() or "
        "DebugLog.warn() instead (import \"DebugLog.js\" as DebugLog).\n  "
        + "\n  ".join(offenders)
    )
