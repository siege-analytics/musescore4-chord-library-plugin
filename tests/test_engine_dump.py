"""Tests for scripts/engine_dump.js — the ranked-voicings shim (#400).

Uses the same Python-subprocess pattern as tests/test_js_modules.py:
invoke the Node CLI, parse its JSON output, assert shape + invariants.

Fixture battery matches the 12 masters Ellington uses for its Goal A
oracle diff (see ellington-systems#1 design note for the choice of
each master).
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SHIM = REPO_ROOT / "scripts" / "engine_dump.js"


# 12-master fixture battery from ellington-systems#1
ENGINE_STRESSERS = [
    "nelson-faria",
    "peter-bernstein",
    "mickey-baker",
    "ted-dunbar",
    "brent-vaartstra",
]
DHEERAJ_HEROES = [
    "joe-pass",
    "van-eps",
    "wes-montgomery",
    "jim-hall",
    "lenny-breau",
]
MELODIC_AXIS = ["pat-martino", "jens-larsen"]
FIXTURE_BATTERY = ENGINE_STRESSERS + DHEERAJ_HEROES + MELODIC_AXIS
assert len(FIXTURE_BATTERY) == 12


def run_shim(*args: str, expect_exit: int = 0) -> dict[str, Any] | str | None:
    """Invoke the shim with the given args, assert exit code, return parsed JSON.

    On non-zero expected exit, returns stderr string instead of JSON.
    When `--output` points at a real file (not `-`), stdout is empty by
    design; caller reads the file directly and we return None.
    """
    cmd = ["node", str(SHIM)] + list(args)
    result = subprocess.run(
        cmd, capture_output=True, text=True, cwd=REPO_ROOT, timeout=30
    )
    assert result.returncode == expect_exit, (
        f"Exit code {result.returncode} (expected {expect_exit}); "
        f"stderr=\n{result.stderr}\nstdout=\n{result.stdout[:500]}"
    )
    if expect_exit != 0:
        return result.stderr
    # Detect "--output FILE" (FILE != "-") and skip stdout parse.
    args_list = list(args)
    if "--output" in args_list:
        idx = args_list.index("--output")
        if idx + 1 < len(args_list) and args_list[idx + 1] != "-":
            return None
    return json.loads(result.stdout)


# ---------------------------------------------------------------------------
# Help + argument validation
# ---------------------------------------------------------------------------


class TestArguments:
    def test_help_exits_zero(self) -> None:
        # --help prints to stderr and exits 0
        cmd = ["node", str(SHIM), "--help"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0
        assert "Usage:" in result.stderr

    def test_missing_chord_exits_2(self) -> None:
        run_shim("--tuning", "EADGBE", "--master", "joe-pass", expect_exit=2)

    def test_missing_tuning_exits_2(self) -> None:
        run_shim("--chord", "Cmaj7", "--master", "joe-pass", expect_exit=2)

    def test_missing_master_exits_2(self) -> None:
        run_shim("--chord", "Cmaj7", "--tuning", "EADGBE", expect_exit=2)

    def test_master_and_no_master_conflict_exits_2(self) -> None:
        run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--no-master",
            expect_exit=2,
        )

    def test_unknown_master_exits_4(self) -> None:
        stderr = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "definitely-not-a-real-master-id",
            expect_exit=4,
        )
        assert isinstance(stderr, str)
        assert "definitely-not-a-real-master-id" in stderr

    def test_n_strings_out_of_range_exits_2(self) -> None:
        run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "20",
            expect_exit=2,
        )


# ---------------------------------------------------------------------------
# Response shape — every field the contract names must be present
# ---------------------------------------------------------------------------


class TestResponseShape:
    @pytest.fixture()
    def cmaj7_joepass(self) -> dict[str, Any]:
        return run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "6",
        )

    def test_top_level_keys(self, cmaj7_joepass: dict[str, Any]) -> None:
        assert set(cmaj7_joepass.keys()) == {
            "request",
            "ranked_voicings",
            "engine_version",
            "masters_version",
            "voicings_version",
        }

    def test_request_echoed_back(self, cmaj7_joepass: dict[str, Any]) -> None:
        req = cmaj7_joepass["request"]
        assert req["chord_symbol"] == "Cmaj7"
        assert req["tuning"] == "EADGBE"
        assert req["master_id"] == "joe-pass"
        assert req["category_filter"] is None
        assert req["context"]["n_strings"] == 6

    def test_version_objects_have_sha_and_clean(
        self, cmaj7_joepass: dict[str, Any]
    ) -> None:
        for key in ("engine_version", "masters_version", "voicings_version"):
            ver = cmaj7_joepass[key]
            assert isinstance(ver, dict), f"{key} should be an object"
            assert "sha" in ver
            assert "clean" in ver
            assert isinstance(ver["clean"], bool)

    def test_ranked_voicings_nonempty(
        self, cmaj7_joepass: dict[str, Any]
    ) -> None:
        rows = cmaj7_joepass["ranked_voicings"]
        assert len(rows) > 0, "Cmaj7/joe-pass should return SOME voicings"

    def test_each_row_has_required_fields(
        self, cmaj7_joepass: dict[str, Any]
    ) -> None:
        for row in cmaj7_joepass["ranked_voicings"]:
            assert set(row.keys()) == {
                "voicing_id",
                "rank",
                "score",
                "score_components",
                "payload_kind",
                "applied_principles",
            }
            assert set(row["score_components"].keys()) == {
                "base",
                "master_boost",
                "tolerance_match",
            }
            assert row["payload_kind"] is None
            assert row["applied_principles"] == []


# ---------------------------------------------------------------------------
# Score invariants — base + master_boost + tolerance_match == score
# ---------------------------------------------------------------------------


class TestScoreInvariants:
    def test_score_equals_components_sum(self) -> None:
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "6",
        )
        for row in resp["ranked_voicings"]:
            sc = row["score_components"]
            total = sc["base"] + sc["master_boost"] + sc["tolerance_match"]
            assert abs(total - row["score"]) < 1e-6, (
                f"score-components-sum mismatch on {row['voicing_id']}: "
                f"score={row['score']} but base+master_boost+tolerance_match={total}"
            )

    def test_ranks_are_one_indexed_dense(self) -> None:
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "6",
        )
        ranks = [r["rank"] for r in resp["ranked_voicings"]]
        assert ranks == list(range(1, len(ranks) + 1))

    def test_scores_descending(self) -> None:
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "6",
        )
        scores = [r["score"] for r in resp["ranked_voicings"]]
        assert scores == sorted(scores, reverse=True)

    def test_tolerance_match_is_zero_from_js(self) -> None:
        # The JS engine doesn't run a payload-kind dispatcher; the shim
        # always emits tolerance_match=0. Ellington's Python port populates
        # this on its own side.
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "6",
        )
        for row in resp["ranked_voicings"]:
            assert row["score_components"]["tolerance_match"] == 0


# ---------------------------------------------------------------------------
# master_boost behaviour
# ---------------------------------------------------------------------------


class TestMasterBoost:
    def test_no_master_yields_zero_master_boost(self) -> None:
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--no-master", "--n-strings", "6",
        )
        for row in resp["ranked_voicings"]:
            assert row["score_components"]["master_boost"] == 0

    def test_with_master_master_boost_is_zero_today(self) -> None:
        """Per Investigation Fact Sheet Entity 4: 0/820 voicings are tagged
        at SHA 628ed30. Master boost gate requires BOTH master tags AND
        voicing tags to be non-empty; with the corpus's current state,
        boost is always 0 even when --master is set. When voicing-tag
        crowdsourcing (plugin #389/#393/#395) lands first batches, this
        test SHOULD fail — that's the trigger to re-snapshot the oracle.
        """
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--n-strings", "6",
        )
        for row in resp["ranked_voicings"]:
            assert row["score_components"]["master_boost"] == 0, (
                f"Expected master_boost=0 (untagged corpus); "
                f"got {row['score_components']['master_boost']} on {row['voicing_id']}. "
                f"If voicings now carry voicingStyle tags, this is the signal "
                f"to refresh the oracle snapshot."
            )


# ---------------------------------------------------------------------------
# 12-fixture battery — every master in Ellington's spike runs cleanly
# ---------------------------------------------------------------------------


class TestFixtureBattery:
    @pytest.mark.parametrize("master_id", FIXTURE_BATTERY)
    def test_master_runs_cmaj7(self, master_id: str) -> None:
        resp = run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", master_id, "--n-strings", "6",
        )
        assert resp["request"]["master_id"] == master_id
        assert len(resp["ranked_voicings"]) > 0
        # Smoke invariant on every row.
        for row in resp["ranked_voicings"]:
            assert row["rank"] >= 1
            assert row["voicing_id"]

    @pytest.mark.parametrize("master_id", FIXTURE_BATTERY)
    def test_master_runs_dom7(self, master_id: str) -> None:
        resp = run_shim(
            "--chord", "G7", "--tuning", "EADGBE",
            "--master", master_id, "--n-strings", "6",
        )
        assert len(resp["ranked_voicings"]) > 0

    @pytest.mark.parametrize("master_id", FIXTURE_BATTERY)
    def test_master_runs_minor(self, master_id: str) -> None:
        resp = run_shim(
            "--chord", "Dm7", "--tuning", "EADGBE",
            "--master", master_id, "--n-strings", "6",
        )
        # Some quality variants may yield empty under the shim's filter;
        # the contract is that the response is well-formed even if empty.
        assert isinstance(resp["ranked_voicings"], list)


# ---------------------------------------------------------------------------
# Output to file
# ---------------------------------------------------------------------------


class TestOutputDestination:
    def test_output_to_file(self, tmp_path: Path) -> None:
        outfile = tmp_path / "result.json"
        run_shim(
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--output", str(outfile),
        )
        assert outfile.exists()
        data = json.loads(outfile.read_text())
        assert data["request"]["master_id"] == "joe-pass"

    def test_output_dash_writes_stdout(self) -> None:
        # Default behaviour also; this just makes the contract explicit.
        cmd = [
            "node", str(SHIM),
            "--chord", "Cmaj7", "--tuning", "EADGBE",
            "--master", "joe-pass", "--output", "-",
        ]
        result = subprocess.run(
            cmd, capture_output=True, text=True, cwd=REPO_ROOT, timeout=30
        )
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert "ranked_voicings" in data
