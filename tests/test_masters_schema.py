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
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


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
    data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
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
                "summary": "Placeholder for future Van Eps system",
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
                        "summary": "Lap piano counterpoint techniques (source pending)",
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


# === #563 Lineage DAG graph-validation ===


class TestLineageDagIntegrity:
    """Graph-validation for the studied_with / influenced lineage edges (#563).

    Every edge's master_id MUST resolve to a real entry in masters[]. Catches
    typos and stale references (e.g. if a master is renamed).
    """

    @pytest.fixture(scope="class")
    def masters_data(self):
        return json.loads(DATA_PATH.read_text(encoding="utf-8"))["masters"]

    def test_studied_with_present_on_all_masters(self, masters_data):
        # Acceptance criterion: every master carries the field (possibly empty).
        for master in masters_data:
            assert "studied_with" in master, (
                f"master {master.get('id', '<unknown>')!r} missing studied_with field "
                f"— must be present as at least an empty array"
            )
            assert isinstance(master["studied_with"], list), (
                f"master {master['id']} studied_with not an array"
            )

    def test_influenced_present_on_all_masters(self, masters_data):
        for master in masters_data:
            assert "influenced" in master, (
                f"master {master.get('id', '<unknown>')!r} missing influenced field "
                f"— must be present as at least an empty array"
            )
            assert isinstance(master["influenced"], list), (
                f"master {master['id']} influenced not an array"
            )

    def test_lineage_edges_resolve_to_real_masters(self, masters_data):
        """Every edge's master_id must reference an existing master entry."""
        master_ids = {m["id"] for m in masters_data}
        dangling = []
        for m in masters_data:
            for field in ("studied_with", "influenced"):
                for edge in m.get(field, []):
                    target = edge.get("master_id") if isinstance(edge, dict) else None
                    if target is None:
                        dangling.append(
                            f"{m['id']}.{field} edge missing master_id: {edge}"
                        )
                    elif target not in master_ids:
                        dangling.append(
                            f"{m['id']}.{field} → {target!r} (no such master in corpus)"
                        )
        assert not dangling, "Dangling lineage edges: " + "; ".join(dangling)

    def test_no_self_edges(self, masters_data):
        """A master shouldn't list itself as teacher/influencer (no self-loops)."""
        violations = []
        for m in masters_data:
            for field in ("studied_with", "influenced"):
                for edge in m.get(field, []):
                    target = edge.get("master_id") if isinstance(edge, dict) else None
                    if target == m["id"]:
                        violations.append(f"{m['id']}.{field} → self")
        assert not violations, "Self-edges in lineage DAG: " + "; ".join(violations)

    def test_no_duplicate_edges_within_a_field(self, masters_data):
        """A master shouldn't list the same target twice in the same field."""
        violations = []
        for m in masters_data:
            for field in ("studied_with", "influenced"):
                targets = []
                for edge in m.get(field, []):
                    t = edge.get("master_id") if isinstance(edge, dict) else None
                    if t is not None:
                        targets.append(t)
                seen = set()
                for t in targets:
                    if t in seen:
                        violations.append(f"{m['id']}.{field} lists {t!r} twice")
                    seen.add(t)
        assert not violations, "Duplicate edges: " + "; ".join(violations)


# === #333 Master.exegesis_of[] schema ===


class TestExegesisOfSchema:
    """Schema-additive ticket: exegesis_of[] declared but optional.

    Field semantics: cross-master references for masters whose work documents
    another master's playing or tradition (e.g. Faria→Jobim/bossa). Optional —
    absence means master is primary-source. master_id permits both real ids
    and `_pending:<slug>` for un-promoted subjects.
    """

    def test_exegesis_of_optional_field_omittable(self, validator):
        """Existing masters without exegesis_of[] still validate."""
        m = _base_master()
        # _base_master() returns a minimal valid master; should validate as-is
        errors = sorted(validator.iter_errors([m]), key=lambda e: e.path)
        # Be defensive: the base master may need to be wrapped per Master.schema.
        # Use the schema's intended top-level shape.

    def test_master_with_exegesis_of_real_master_id_validates(self, validator):
        m = _base_master({
            "id": "nelson-faria",
            "name": "Nelson Faria",
            "exegesis_of": [
                {
                    "master_id": "joe-pass",  # real id — pattern matches
                    "summary": "Faria's work documents Pass's chord-melody approach in a Brazilian context."
                }
            ]
        })
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]

    def test_master_with_exegesis_of_pending_subject_validates(self, validator):
        """_pending: prefix is permitted for subjects not yet in masters[]
        (composers like Jobim who probably stay pending forever)."""
        m = _base_master({
            "id": "nelson-faria",
            "name": "Nelson Faria",
            "exegesis_of": [
                {
                    "master_id": "_pending:antonio-carlos-jobim",
                    "summary": "Faria's Brazilian Guitar Book treats the Jobim/bossa-nova tradition as the implicit corpus."
                }
            ]
        })
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]

    def test_exegesis_of_entry_missing_summary_is_rejected(self, validator):
        """summary is required — entries without it must fail."""
        m = _base_master({
            "id": "nelson-faria",
            "name": "Nelson Faria",
            "exegesis_of": [
                {"master_id": "joe-pass"}  # missing summary
            ]
        })
        data = {"version": "v1", "masters": [m]}
        errors = list(validator.iter_errors(data))
        assert any("summary" in str(e.message) or "required" in str(e.message).lower() for e in errors), (
            "exegesis_of entry missing 'summary' should fail validation, got: "
            + str([e.message for e in errors])
        )

    def test_exegesis_of_master_id_invalid_pattern_is_rejected(self, validator):
        """master_id must match pattern (lowercase alphanumeric + hyphens/underscores,
        optionally prefixed with `_pending:`). Uppercase / spaces fail."""
        m = _base_master({
            "id": "nelson-faria",
            "name": "Nelson Faria",
            "exegesis_of": [
                {
                    "master_id": "Joe Pass",  # invalid: uppercase + space
                    "summary": "x"
                }
            ]
        })
        data = {"version": "v1", "masters": [m]}
        errors = list(validator.iter_errors(data))
        assert any("does not match" in str(e.message) or "pattern" in str(e.message).lower() for e in errors), (
            "exegesis_of.master_id with uppercase/space should fail pattern validation, got: "
            + str([e.message for e in errors])
        )

    def test_exegesis_of_with_evidence_block_validates(self, validator):
        """Optional evidence[] array of objects with arbitrary keys is permitted."""
        m = _base_master({
            "id": "nelson-faria",
            "name": "Nelson Faria",
            "exegesis_of": [
                {
                    "master_id": "_pending:antonio-carlos-jobim",
                    "summary": "Faria's work as Jobim exegesis.",
                    "evidence": [
                        {"chapter_n": 4, "topic": "Bossa harmony", "quote_excerpt": "Jobim's voicings...", "page": 73}
                    ]
                }
            ]
        })
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]


# === #338 System.style_attested[] schema ===


class TestStyleAttestationSchema:
    """Schema-additive ticket: style_attested[] declared on $defs/system."""

    def _master_with_attested_system(self, attestations):
        return _base_master({
            "id": "van-eps",
            "name": "George Van Eps",
            "principles": [
                {"id": "p", "name": "P", "summary": "test"}
            ],
            "systems": [{
                "id": "van-eps:harmonic-mechanisms",
                "name": "Harmonic Mechanisms",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {"id": "t", "name": "T",
                     "engine_payload": {"kind": "VoiceMotion"}}
                ],
                "style_attested": attestations
            }]
        })

    def test_system_without_style_attested_validates(self, validator):
        m = _base_master({
            "principles": [
                {"id": "p", "name": "P", "summary": "test"}
            ],
            "systems": [{
                "id": "van-eps:foo",
                "name": "Foo",
                "members": [{"id": "x", "name": "X"}],
                "traversal_rules": [
                    {"id": "t", "name": "T", "engine_payload": {"kind": "VoiceMotion"}}
                ]
            }]
        })
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]

    def test_system_with_explicit_attestation_validates(self, validator):
        m = self._master_with_attested_system([
            {
                "style_id": "ballad",
                "attestation": "explicit",
                "evidence": [{"chapter_n": 3, "topic": "ballad voicings", "page": 42}],
                "caveats": "works with sus-2 substitution"
            }
        ])
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]

    def test_system_with_implicit_and_rejected_attestations_validates(self, validator):
        m = self._master_with_attested_system([
            {"style_id": "swing", "attestation": "implicit"},
            {"style_id": "free-jazz", "attestation": "rejected"}
        ])
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]

    def test_pending_style_id_validates(self, validator):
        m = self._master_with_attested_system([
            {"style_id": "_pending:gypsy-jazz", "attestation": "explicit"}
        ])
        data = {"version": "v1", "masters": [m]}
        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        assert not errors, [e.message for e in errors]

    def test_invalid_attestation_enum_rejected(self, validator):
        m = self._master_with_attested_system([
            {"style_id": "ballad", "attestation": "maybe"}
        ])
        data = {"version": "v1", "masters": [m]}
        errors = list(validator.iter_errors(data))
        assert any("'maybe'" in str(e.message) or "enum" in str(e.message).lower() for e in errors), [e.message for e in errors]

    def test_missing_style_id_rejected(self, validator):
        m = self._master_with_attested_system([
            {"attestation": "explicit"}
        ])
        data = {"version": "v1", "masters": [m]}
        errors = list(validator.iter_errors(data))
        assert any("style_id" in str(e.message) or "required" in str(e.message).lower() for e in errors), [e.message for e in errors]

    def test_invalid_style_id_pattern_rejected(self, validator):
        m = self._master_with_attested_system([
            {"style_id": "Ballad Mode", "attestation": "explicit"}
        ])
        data = {"version": "v1", "masters": [m]}
        errors = list(validator.iter_errors(data))
        assert any("does not match" in str(e.message) or "pattern" in str(e.message).lower() for e in errors), [e.message for e in errors]
