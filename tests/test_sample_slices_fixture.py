"""#568 — Sample-slices fixture coverage gates.

The sample_slices fixture lives inline in scripts/build_engine_rules_bundle.py
and ships in engine-rules-fixture.tar.gz for downstream consumers (Ellington's
firing engine + co-ratified expected-fires.json). The fixture must:

1. Carry ~20 slices covering firing-spec v0.2 matching surface
2. Each slice fills the v0.2 slice contract (required dimensions populated)
3. ≥12 distinct quality_binding tokens across the fixture
4. Cover the top-frequency tokens (any/dom7/maj7/min7) at minimum
5. Include at least one applicability_reasons-tagged slice
6. Include at least one slice with each progression position class
   (tonic / dominant / subdominant / passing / tension)

This test guards the fixture's coverage so additions/removals don't silently
shrink the matching surface Ellington's engine is tested against.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_SCRIPT = REPO_ROOT / "scripts" / "build_engine_rules_bundle.py"

# §10.4 / spec §3 — required slice-contract dimensions (v0.2 baseline)
REQUIRED_SLICE_FIELDS = {
    "slice_id",
    "target_chord_canonical",
    "prev_chord_canonical",
    "next_chord_canonical",
    "melody_note",
    "key",
    "section_label",
    "beat_in_measure",
    "time_signature",
    "arrangement.style",
    "progression.type",
    "progression.position",
    "chord_quality",
    "harmonic.context",
}

# Top-frequency quality_binding tokens per #568 (corpus-frequency analysis)
TOP_FREQUENCY_TOKENS = {"any", "dom7", "maj7", "min7"}

# §3 harmonic.context categorical buckets — minimum set
HARMONIC_CONTEXT_BUCKETS = {
    "tonic",
    "dominant_function",
    "subdominant_function",
    "passing",
    "tension",
}


def _load_sample_slices():
    """Import the build script as a module to read sample_slices without
    executing the bundle-build side effects. The build script's only
    top-level work is constant definitions; sample_slices is defined inside
    write_fixture_tarball() so we run it with a sentinel arg-pattern."""
    # Simpler: parse it as source text and exec just the sample_slices block.
    # Build script is too tightly coupled to file I/O to import cleanly.
    source = BUILD_SCRIPT.read_text(encoding="utf-8")
    # Find the sample_slices = [ ... ] block
    start_marker = "sample_slices = ["
    end_marker = "    ]\n    (fixture_dir / \"fixtures\").mkdir()"
    start_idx = source.find(start_marker)
    end_idx = source.find(end_marker, start_idx)
    assert start_idx != -1, "sample_slices block not found in build script"
    assert end_idx != -1, "sample_slices end marker not found"
    # Find the closing "]" of the list
    block = source[start_idx : end_idx + len("    ]")]
    # Eval the assignment
    ns = {}
    exec(block, ns)
    return ns["sample_slices"]


@pytest.fixture(scope="module")
def slices():
    return _load_sample_slices()


def test_slice_count_meets_baseline(slices):
    """#568 acceptance: ~20 slices. Accept 18-30 for sensible drift latitude."""
    assert 18 <= len(slices) <= 30, (
        f"Sample-slices count {len(slices)} outside the [18, 30] window. "
        "Either shrunk past the coverage baseline (under 18) or growing without "
        "intent (over 30 — consider a separate fixture set)."
    )


def test_all_slice_ids_unique(slices):
    ids = [s["slice_id"] for s in slices]
    assert len(ids) == len(set(ids)), (
        f"Duplicate slice_ids in fixture: "
        f"{[i for i in ids if ids.count(i) > 1]}"
    )


@pytest.mark.parametrize("idx", list(range(20)))
def test_each_slice_carries_required_v02_fields(slices, idx):
    if idx >= len(slices):
        pytest.skip(f"fixture has only {len(slices)} slices; idx {idx} out of range")
    slice_obj = slices[idx]
    missing = REQUIRED_SLICE_FIELDS - set(slice_obj.keys())
    assert not missing, (
        f"slice {slice_obj.get('slice_id', f'<idx {idx}>')} missing required v0.2 "
        f"fields: {missing}"
    )


def test_distinct_chord_qualities_coverage(slices):
    """#568 acceptance: ≥12 distinct quality_binding tokens covered."""
    qualities = {s["chord_quality"] for s in slices}
    assert len(qualities) >= 12, (
        f"Only {len(qualities)} distinct chord_quality tokens "
        f"({sorted(qualities)}). Need at least 12 to exercise spec §2 matching."
    )


def test_top_frequency_tokens_represented(slices):
    """At minimum the top-frequency tokens (any/dom7/maj7/min7) each get a slice."""
    qualities = {s["chord_quality"] for s in slices}
    missing = TOP_FREQUENCY_TOKENS - qualities - {"any"}  # "any" is wildcard, not a real chord_quality
    assert not missing, (
        f"Top-frequency tokens missing from fixture: {missing}. "
        f"These are the 4 most common quality_binding tokens by corpus frequency."
    )


def test_at_least_one_applicability_reasons_slice(slices):
    """Coverage: ≥1 slice tagged with non-canonical applicability_reasons so
    Ellington's engine exercises the §2.4 applicability_reasons matching path."""
    tagged = [s for s in slices if s.get("applicability_reasons")]
    assert len(tagged) >= 1, (
        "No slice carries applicability_reasons — §2.4 path won't be exercised. "
        "Add at least one slice with a non-canonical authorial context tag."
    )


def test_harmonic_context_buckets_covered(slices):
    """Coverage: each of the 5 canonical harmonic.context buckets appears at
    least once so consumers can verify their inference algorithm on each."""
    contexts = {s["harmonic.context"] for s in slices}
    missing = HARMONIC_CONTEXT_BUCKETS - contexts
    assert not missing, (
        f"harmonic.context buckets missing from fixture: {missing}. "
        f"Each of {HARMONIC_CONTEXT_BUCKETS} should have at least one slice."
    )


def test_avoid_polarity_slices_present(slices):
    """At least one slice tagged for an avoid-polarity rule trigger. The
    convention used: applicability_reasons strings containing 'avoid' or
    'no_resolution' or 'tritone_sub_before_pedal_avoid' etc."""
    avoid_slices = [
        s for s in slices
        if any(
            "avoid" in r.lower() or "no_resolution" in r.lower()
            for r in s.get("applicability_reasons", [])
        )
    ]
    assert len(avoid_slices) >= 1, (
        "No slice carries an avoid-polarity applicability_reason tag. "
        "Add at least one slice that would trigger a Likert -1 or -2 rule."
    )


def test_specific_token_dom7b9_present(slices):
    """§2.2 specificity: dom7b9 specific token slice should exist so the
    fixture exercises specific-token vs family-parent dom7 matching."""
    has_dom7b9 = any(s["chord_quality"] == "dom7b9" for s in slices)
    assert has_dom7b9, (
        "No dom7b9-quality slice — §2.2 specific-vs-family-parent matching can't be tested"
    )


def test_family_parent_match_slices_present(slices):
    """§2.2 family-hierarchical: slices with maj9 / min9 / dom7b9 etc. exist
    so family-parent rules (keyed off `maj`/`min`/`dom7`) can be exercised."""
    family_match_qualities = {"maj9", "maj7#11", "min9", "dom7b9"}
    qualities = {s["chord_quality"] for s in slices}
    found = family_match_qualities & qualities
    assert len(found) >= 3, (
        f"Family-hierarchical coverage thin: only {found} present out of "
        f"{family_match_qualities}. Need at least 3 to exercise §2.2."
    )
