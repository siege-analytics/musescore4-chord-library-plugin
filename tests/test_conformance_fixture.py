"""Structural validation of the §10 Conformance Verdict Contract parity oracle.

The fixture at plugin/docs/fixtures/conformance-v0.2.1-fixture.json is the runnable
artifact for cross-project drift detection — both plugin v2 conformance and Ellington
apps.audio.comparator import it and assert their evaluators produce the listed
expected_rule_verdicts from the given inputs.

This test asserts the fixture itself is structurally well-formed against firing-spec
§10 (v0.2.1). It does NOT evaluate the comparator (plugin has no comparator
implementation; that lives on Ellington's side). It validates that the fixture is
internally consistent and structurally usable as a parity oracle.

If §10 evolves and the fixture isn't updated, this test catches the drift.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
FIXTURE_PATH = REPO_ROOT / "plugin" / "docs" / "fixtures" / "conformance-v0.2.1-fixture.json"

# §10.2 SliceObservation required fields (per spec)
SLICE_OBSERVATION_REQUIRED_FIELDS = {
    "slice_id",
    "played_pitches",
    "played_intervals_relative_to_root",
    "inferred_chord_quality",
    "matched_chord_tones",
    "total_chord_tones",
    "off_chord_tones",
    "off_scale_tones",
    "scale_drift_semitones",
    "alignment_confidence",
    "pitch_extraction_confidence",
    "observation_confidence",
}

# §10.3 RuleVerdict required fields
RULE_VERDICT_REQUIRED_FIELDS = {
    "slice_id",
    "rule_id",
    "rule_polarity",
    "verdict",
    "evidence",
    "rule_evaluability_confidence",
    "verdict_confidence",
}

# §10.4 verdict enum
VALID_VERDICTS = {"satisfies", "violates", "neutral", "indeterminate"}

# §10 polarity enum
VALID_POLARITIES = {"positive", "avoid"}

# §10.5 evidence discriminated-union variants — v0.1 locked
V0_1_EVIDENCE_TYPES = {"chord_tone_membership", "scale_drift", "deferred"}

# §10.5 evidence variant required fields by type discriminator
EVIDENCE_REQUIRED_FIELDS = {
    "chord_tone_membership": {"type", "matched", "total", "missing", "extra"},
    "scale_drift": {"type", "median_drift_semitones", "max_drift_semitones", "drift_frame_count"},
    "deferred": {"type", "reason", "deferred_until_version"},
}


@pytest.fixture(scope="module")
def fixture():
    """Load the parity-oracle fixture."""
    return json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))


def test_fixture_file_exists():
    assert FIXTURE_PATH.is_file(), f"Parity-oracle fixture missing at {FIXTURE_PATH}"


def test_fixture_has_required_top_level_keys(fixture):
    """Top-level fixture shape — slice_observation + fired_rules."""
    assert "slice_observation" in fixture
    assert "fired_rules" in fixture
    assert isinstance(fixture["fired_rules"], list)
    assert len(fixture["fired_rules"]) >= 1, "Need at least one fired_rule entry to be useful"


def test_slice_observation_required_fields(fixture):
    obs = fixture["slice_observation"]
    missing = SLICE_OBSERVATION_REQUIRED_FIELDS - set(obs.keys())
    assert not missing, f"slice_observation missing §10.2 required fields: {missing}"


def test_slice_observation_played_pitches_shape(fixture):
    """Each PlayedPitch entry has pitch_name + duration_s + confidence."""
    pitches = fixture["slice_observation"]["played_pitches"]
    for p in pitches:
        assert "pitch_name" in p, f"PlayedPitch missing pitch_name: {p}"
        assert "duration_s" in p, f"PlayedPitch missing duration_s: {p}"
        assert "confidence" in p, f"PlayedPitch missing confidence: {p}"
        assert 0.0 <= p["confidence"] <= 1.0, f"PlayedPitch confidence out of [0,1]: {p}"


def test_slice_observation_confidence_fields_in_unit_interval(fixture):
    obs = fixture["slice_observation"]
    for f in ("alignment_confidence", "pitch_extraction_confidence", "observation_confidence"):
        assert 0.0 <= obs[f] <= 1.0, f"slice_observation.{f} out of [0,1]: {obs[f]}"


@pytest.mark.parametrize("entry_idx", [0, 1, 2])
def test_each_fired_rule_has_input_and_expected_output(fixture, entry_idx):
    """Each fired_rules entry pairs a rule_fire_result input with expected_rule_verdict output."""
    if entry_idx >= len(fixture["fired_rules"]):
        pytest.skip(f"fixture has only {len(fixture['fired_rules'])} entries")
    entry = fixture["fired_rules"][entry_idx]
    assert "rule_fire_result" in entry
    assert "expected_rule_verdict" in entry


def test_expected_rule_verdicts_have_required_fields(fixture):
    for i, entry in enumerate(fixture["fired_rules"]):
        verdict = entry["expected_rule_verdict"]
        missing = RULE_VERDICT_REQUIRED_FIELDS - set(verdict.keys())
        assert not missing, f"fired_rules[{i}].expected_rule_verdict missing §10.3 fields: {missing}"


def test_expected_rule_verdicts_use_valid_enum_values(fixture):
    for i, entry in enumerate(fixture["fired_rules"]):
        v = entry["expected_rule_verdict"]
        assert v["verdict"] in VALID_VERDICTS, f"fired_rules[{i}] invalid verdict: {v['verdict']}"
        assert v["rule_polarity"] in VALID_POLARITIES, f"fired_rules[{i}] invalid polarity: {v['rule_polarity']}"


def test_expected_rule_verdict_confidence_fields_in_unit_interval(fixture):
    for i, entry in enumerate(fixture["fired_rules"]):
        v = entry["expected_rule_verdict"]
        assert 0.0 <= v["rule_evaluability_confidence"] <= 1.0, f"fired_rules[{i}] evaluability out of [0,1]"
        assert 0.0 <= v["verdict_confidence"] <= 1.0, f"fired_rules[{i}] verdict_confidence out of [0,1]"


def test_evidence_discriminator_is_v0_1_variant(fixture):
    """Every evidence block uses a v0.1-locked discriminator (chord_tone_membership / scale_drift / deferred)."""
    for i, entry in enumerate(fixture["fired_rules"]):
        evidence = entry["expected_rule_verdict"]["evidence"]
        assert "type" in evidence, f"fired_rules[{i}].evidence missing type discriminator"
        assert evidence["type"] in V0_1_EVIDENCE_TYPES, (
            f"fired_rules[{i}].evidence.type {evidence['type']!r} not in v0.1 locked set "
            f"{V0_1_EVIDENCE_TYPES}; v2 variants (voicing_match, rhythm_attack) are reserved, not usable yet"
        )


def test_evidence_variant_required_fields(fixture):
    """Each evidence variant carries its §10.5-required fields."""
    for i, entry in enumerate(fixture["fired_rules"]):
        evidence = entry["expected_rule_verdict"]["evidence"]
        required = EVIDENCE_REQUIRED_FIELDS[evidence["type"]]
        missing = required - set(evidence.keys())
        assert not missing, (
            f"fired_rules[{i}].evidence (type={evidence['type']!r}) missing §10.5 required fields: {missing}"
        )


def test_polarity_verdict_cross_product_consistent(fixture):
    """§10.4 cross-product invariants on the worked examples:
    - neutral verdicts MUST carry DeferredEvidence (the only honest way to be neutral)
    - non-neutral verdicts MUST NOT carry DeferredEvidence (deferred is reserved for rules we can't evaluate)
    """
    for i, entry in enumerate(fixture["fired_rules"]):
        v = entry["expected_rule_verdict"]
        is_deferred = v["evidence"]["type"] == "deferred"
        if v["verdict"] == "neutral":
            assert is_deferred, (
                f"fired_rules[{i}] verdict=neutral but evidence is not deferred — "
                f"§10.4 invariant: neutral verdicts MUST carry DeferredEvidence"
            )
        elif v["verdict"] in {"satisfies", "violates"}:
            assert not is_deferred, (
                f"fired_rules[{i}] verdict={v['verdict']} but evidence is deferred — "
                f"§10.4 invariant: evaluable verdicts must not use DeferredEvidence"
            )


def test_neutral_verdicts_have_zero_evaluability(fixture):
    """§10.6: a rule we can't evaluate has rule_evaluability_confidence = 0.0 by construction."""
    for i, entry in enumerate(fixture["fired_rules"]):
        v = entry["expected_rule_verdict"]
        if v["verdict"] == "neutral" and v["evidence"]["type"] == "deferred":
            assert v["rule_evaluability_confidence"] == 0.0, (
                f"fired_rules[{i}] neutral+deferred but rule_evaluability_confidence != 0.0"
            )
            assert v["verdict_confidence"] == 0.0, (
                f"fired_rules[{i}] neutral+deferred but verdict_confidence != 0.0"
            )


def test_verdict_confidence_is_composite_of_observation_and_evaluability(fixture):
    """§10.6: verdict_confidence = observation_confidence × rule_evaluability_confidence (within rounding)."""
    obs_conf = fixture["slice_observation"]["observation_confidence"]
    for i, entry in enumerate(fixture["fired_rules"]):
        v = entry["expected_rule_verdict"]
        expected_composite = obs_conf * v["rule_evaluability_confidence"]
        assert abs(v["verdict_confidence"] - expected_composite) < 0.01, (
            f"fired_rules[{i}] verdict_confidence={v['verdict_confidence']} != "
            f"observation_confidence × rule_evaluability_confidence = {expected_composite}"
        )


def test_slice_id_propagation(fixture):
    """The slice_id on the observation matches every verdict's slice_id."""
    obs_slice = fixture["slice_observation"]["slice_id"]
    for i, entry in enumerate(fixture["fired_rules"]):
        v_slice = entry["expected_rule_verdict"]["slice_id"]
        assert v_slice == obs_slice, (
            f"fired_rules[{i}] verdict.slice_id={v_slice!r} != observation.slice_id={obs_slice!r}"
        )


def test_rule_id_propagation(fixture):
    """The rule_id on the input matches the verdict's rule_id."""
    for i, entry in enumerate(fixture["fired_rules"]):
        input_rid = entry["rule_fire_result"]["rule_id"]
        verdict_rid = entry["expected_rule_verdict"]["rule_id"]
        assert input_rid == verdict_rid, (
            f"fired_rules[{i}] input.rule_id={input_rid!r} != verdict.rule_id={verdict_rid!r}"
        )


def test_rule_polarity_propagation(fixture):
    """The polarity on the RuleFireResult mirrors the verdict's rule_polarity (§6 / §10.3)."""
    for i, entry in enumerate(fixture["fired_rules"]):
        input_pol = entry["rule_fire_result"]["polarity"]
        verdict_pol = entry["expected_rule_verdict"]["rule_polarity"]
        assert input_pol == verdict_pol, (
            f"fired_rules[{i}] input.polarity={input_pol!r} != verdict.rule_polarity={verdict_pol!r}"
        )
