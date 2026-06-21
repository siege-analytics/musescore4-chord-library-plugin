"""#575: per-file gate for engine-rules.json files.

Validates plugin/data/masters-corpus/*/*/derived/engine-rules.json against
plugin/schemas/engine-rules.schema.json. Complements the bundle-time
validation in scripts/build_engine_rules_bundle.py with PR-time enforcement
so schema drift surfaces at PR review time, not at release time.

Schema is derived from firing-semantics spec v0.2
(plugin/docs/engine-rules-firing-spec.md).
"""

import json
from pathlib import Path

import jsonschema
import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "plugin" / "schemas" / "engine-rules.schema.json"
MASTERS_CORPUS = REPO_ROOT / "plugin" / "data" / "masters-corpus"


def _discover_engine_rules_files():
    return sorted(MASTERS_CORPUS.glob("*/*/derived/engine-rules.json"))


@pytest.fixture(scope="module")
def schema():
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def test_schema_file_exists():
    assert SCHEMA_PATH.is_file(), f"Schema not at {SCHEMA_PATH}"


def test_schema_is_valid_jsonschema(schema):
    """The schema itself must be a valid JSON Schema draft-2020-12 document."""
    jsonschema.Draft202012Validator.check_schema(schema)


def test_at_least_one_engine_rules_file_exists():
    files = _discover_engine_rules_files()
    assert len(files) >= 14, (
        f"Expected at least 14 engine-rules.json files; found {len(files)}. "
        "Either the corpus has shrunk unexpectedly or the discovery glob has drifted."
    )


@pytest.mark.parametrize("rules_file", _discover_engine_rules_files(), ids=lambda p: f"{p.parts[-4]}/{p.parts[-3]}")
def test_engine_rules_file_validates(schema, rules_file):
    """Every per-master engine-rules.json must validate against the schema."""
    data = json.loads(rules_file.read_text(encoding="utf-8"))
    try:
        jsonschema.validate(instance=data, schema=schema)
    except jsonschema.ValidationError as e:
        pytest.fail(
            f"{rules_file.relative_to(REPO_ROOT)} fails schema validation:\n"
            f"  path: {' -> '.join(str(p) for p in e.absolute_path)}\n"
            f"  message: {e.message}"
        )


def test_unique_rule_ids_within_file():
    """No duplicate rule_id within a single engine-rules.json file."""
    for rules_file in _discover_engine_rules_files():
        data = json.loads(rules_file.read_text(encoding="utf-8"))
        rule_ids = [r["rule_id"] for r in data.get("engine_rules", [])]
        dups = {rid for rid in rule_ids if rule_ids.count(rid) > 1}
        assert not dups, f"{rules_file.relative_to(REPO_ROOT)}: duplicate rule_ids {sorted(dups)}"


def test_schema_rejects_missing_required_top_level_field():
    """Sanity check: the schema must REJECT a malformed file (no engine_rules array)."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    bad = {"_provenance": {"schema_version": "0.2"}, "master_id": "x", "work_id": "y"}
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=bad, schema=schema)


def test_schema_rejects_invalid_master_id_pattern():
    """Sanity check: master_id with uppercase / spaces must fail."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    bad = {
        "_provenance": {"schema_version": "0.2"},
        "master_id": "BAD MASTER_ID",
        "work_id": "ok",
        "engine_rules": [],
    }
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=bad, schema=schema)


def test_schema_rejects_preference_out_of_likert_range():
    """Sanity check: preference must be int in [-2,2], not 5."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    bad = {
        "_provenance": {"schema_version": "0.2"},
        "master_id": "x",
        "work_id": "y",
        "engine_rules": [
            {
                "rule_id": "test-rule",
                "name": "test",
                "when": {},
                "then": {},
                "preference": 5,
                "quality_binding": ["any"],
                "anchor": "test",
            }
        ],
    }
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=bad, schema=schema)
