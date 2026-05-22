"""Schema tests for plugin/data/masters.json (#276 Stage A).

Covers the dual-shape window introduced in schema/masters.schema.json:
each master may declare legacy `principles[]`, new `systems[]`, or both;
at least one is required. System ids follow `<master>:<slug>` and may
be prefixed with `_placeholder:`. Engine payload kinds are either one of
12 CamelCase canonical kinds or a `_pending:<kebab>` placeholder.
"""

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schema" / "masters.schema.json"
DATA_PATH = REPO_ROOT / "plugin" / "data" / "masters.json"


@pytest.fixture(scope="module")
def schema():
    return json.loads(SCHEMA_PATH.read_text())


@pytest.fixture(scope="module")
def validator(schema):
    return Draft202012Validator(schema)


def _base_master(extra=None):
    m = {
        "id": "van-eps",
        "name": "George Van Eps",
        "principles": [
            {
                "id": "harmonized-scale",
                "name": "Harmonized scale",
                "summary": "...",
            }
        ],
    }
    if extra:
        m.update(extra)
    return m


def _doc(masters):
    return {"version": "v1", "masters": masters}


# === Positive cases ===

def test_existing_masters_json_validates(validator):
    data = json.loads(DATA_PATH.read_text())
    errors = list(validator.iter_errors(data))
    assert errors == [], [e.message for e in errors]


def test_legacy_principles_only_is_valid(validator):
    doc = _doc([_base_master()])
    assert list(validator.iter_errors(doc)) == []


def test_systems_only_is_valid(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "van-eps:harmonized-scale",
                "name": "Harmonized scale",
                "members": [{"id": "triad-major", "name": "Major triad"}],
                "traversal_rules": [
                    {
                        "id": "step-up",
                        "name": "Step up",
                        "engine_payload": {"kind": "PositionContinuity"},
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


def test_placeholder_system_allows_empty_interior(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "_placeholder:van-eps:future-system",
                "name": "Future system",
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


def test_pending_payload_kind_is_valid(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "van-eps:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "modification_rules": [
                    {
                        "id": "swap",
                        "name": "Swap",
                        "engine_payload": {"kind": "_pending:swap-thing"},
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


def test_both_principles_and_systems_is_valid(validator):
    master = _base_master({
        "systems": [
            {
                "id": "van-eps:harmonized-scale",
                "name": "Harmonized scale",
                "members": [{"id": "m", "name": "M"}],
                "traversal_rules": [
                    {
                        "id": "t",
                        "name": "T",
                        "engine_payload": {"kind": "VoiceMotion"},
                    }
                ],
            }
        ],
    })
    assert list(validator.iter_errors(_doc([master]))) == []


# === Negative cases ===

def test_master_without_principles_or_systems_is_invalid(validator):
    bad = {"id": "x", "name": "X"}
    errors = list(validator.iter_errors(_doc([bad])))
    assert errors, "master with neither principles nor systems must fail"


def test_wrong_version_rejected(validator):
    doc = {"version": "v2", "masters": [_base_master()]}
    assert list(validator.iter_errors(doc))


def test_unknown_payload_kind_rejected(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "van-eps:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {
                        "id": "r",
                        "name": "R",
                        "engine_payload": {"kind": "MadeUpKind"},
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master])))


def test_pending_payload_must_be_kebab(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "van-eps:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {
                        "id": "r",
                        "name": "R",
                        "engine_payload": {"kind": "_pending:NotKebab"},
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master])))


def test_system_id_must_have_owner_prefix(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "harmonized-scale",
                "name": "Harmonized scale",
                "members": [{"id": "m", "name": "M"}],
                "traversal_rules": [
                    {
                        "id": "t",
                        "name": "T",
                        "engine_payload": {"kind": "PositionContinuity"},
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master])))


def test_real_system_must_have_members_and_a_rule(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {"id": "van-eps:empty", "name": "Empty"}
        ],
    }
    assert list(validator.iter_errors(_doc([master])))


def test_real_system_with_members_but_no_rules_is_invalid(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "systems": [
            {
                "id": "van-eps:members-only",
                "name": "Members only",
                "members": [{"id": "x", "name": "X"}],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master])))


# === Works layer (#293 Stage A.1) ===

def _real_system_3seg(master_id: str, work_id: str, slug: str = "harmonized-scale") -> dict:
    return {
        "id": f"{master_id}:{work_id}:{slug}",
        "name": "Harmonized scale",
        "members": [{"id": "triad-major", "name": "Major triad"}],
        "traversal_rules": [
            {
                "id": "step-up",
                "name": "Step up",
                "engine_payload": {"kind": "PositionContinuity"},
            }
        ],
    }


def test_works_only_master_is_valid(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [
            {
                "id": "1939-method",
                "title": "The George Van Eps Method for Guitar",
                "year": 1939,
                "instrument_scope": "6-string",
                "systems": [_real_system_3seg("van-eps", "1939-method")],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


def test_works_plus_systems_plus_principles_is_valid(validator):
    master = _base_master({
        "systems": [
            {
                "id": "van-eps:legacy-system",
                "name": "Legacy",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {
                        "id": "t", "name": "T",
                        "engine_payload": {"kind": "VoiceMotion"},
                    }
                ],
            }
        ],
        "works": [
            {
                "id": "1939-method",
                "title": "The George Van Eps Method",
                "systems": [_real_system_3seg("van-eps", "1939-method")],
            }
        ],
    })
    assert list(validator.iter_errors(_doc([master]))) == []


def test_placeholder_work_with_no_systems_is_valid(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [
            {
                "id": "_placeholder:harmonic-mechanisms",
                "title": "Harmonic Mechanisms for Guitar (7-string research pending)",
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


def test_work_scoped_system_with_2segment_id_is_rejected(validator):
    """A system inside a work must carry the 3-segment id pattern. The
    schema can't enforce structural location, but the consistency check
    (validate.py) flags it. Still, the system id itself must match the
    pattern; a 2-segment id inside a work is structurally wrong but
    schema-legal — covered by the validator-level test below."""
    # This is the schema-level companion: a deliberately-broken 1-segment
    # id (no colons) is rejected by the pattern.
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [
            {
                "id": "1939-method",
                "title": "Method",
                "systems": [
                    {
                        "id": "no-colons-at-all",
                        "name": "Bad",
                        "members": [{"id": "x", "name": "X"}],
                        "traversal_rules": [
                            {"id": "t", "name": "T",
                             "engine_payload": {"kind": "VoiceMotion"}},
                        ],
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master])))


def test_empty_works_array_rejected(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [],
        "principles": [
            {"id": "p", "name": "P", "summary": "..."}
        ],
    }
    # works[] present but empty violates minItems:1
    assert list(validator.iter_errors(_doc([master])))


def test_work_missing_title_rejected(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [{"id": "1939-method"}],
    }
    assert list(validator.iter_errors(_doc([master])))


def test_work_id_can_be_placeholder(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [
            {
                "id": "_placeholder:future-method",
                "title": "Future method",
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


def test_three_segment_placeholder_system_inside_work_is_valid(validator):
    master = {
        "id": "van-eps",
        "name": "George Van Eps",
        "works": [
            {
                "id": "harmonic-mechanisms",
                "title": "Harmonic Mechanisms",
                "systems": [
                    {
                        "id": "_placeholder:van-eps:harmonic-mechanisms:lap-piano",
                        "name": "Lap piano counterpoint (research pending)",
                    }
                ],
            }
        ],
    }
    assert list(validator.iter_errors(_doc([master]))) == []


# === Validator consistency checks (#293) ===

def test_consistency_flags_3seg_system_with_wrong_master_prefix(monkeypatch):
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "validate_mod",
        REPO_ROOT / "scripts" / "validate.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    data = _doc([{
        "id": "van-eps",
        "name": "Van Eps",
        "works": [{
            "id": "1939-method",
            "title": "Method",
            "systems": [{
                "id": "wrong-master:1939-method:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {"id": "t", "name": "T",
                     "engine_payload": {"kind": "VoiceMotion"}},
                ],
            }],
        }],
    }])
    warnings = mod._check_masters_consistency(data)
    assert any("master prefix 'wrong-master'" in w for w in warnings), warnings


def test_consistency_flags_3seg_system_with_wrong_work_segment():
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "validate_mod",
        REPO_ROOT / "scripts" / "validate.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    data = _doc([{
        "id": "van-eps",
        "name": "Van Eps",
        "works": [{
            "id": "1939-method",
            "title": "Method",
            "systems": [{
                "id": "van-eps:wrong-work:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {"id": "t", "name": "T",
                     "engine_payload": {"kind": "VoiceMotion"}},
                ],
            }],
        }],
    }])
    warnings = mod._check_masters_consistency(data)
    assert any("work segment 'wrong-work'" in w for w in warnings), warnings


def test_consistency_flags_2segment_system_inside_work():
    """A system schema-valid by pattern but structurally misplaced (2-segment
    id inside a work) is caught by the consistency check, not the schema."""
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "validate_mod",
        REPO_ROOT / "scripts" / "validate.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    data = _doc([{
        "id": "van-eps",
        "name": "Van Eps",
        "works": [{
            "id": "1939-method",
            "title": "Method",
            "systems": [{
                "id": "van-eps:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {"id": "t", "name": "T",
                     "engine_payload": {"kind": "VoiceMotion"}},
                ],
            }],
        }],
    }])
    warnings = mod._check_masters_consistency(data)
    assert any("expected 3 colon-separated segments" in w for w in warnings), warnings
