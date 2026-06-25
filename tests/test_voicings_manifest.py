"""#593 — voicings.json top-level manifest contract.

Asserts the manifest block is present, schema-shaped, and that
`total_voicings` stays in sync with the actual `voicings[]` length.
The latter catches the most common drift mode: a voicing gets added/
removed without bumping the count.

See plugin/docs/engine-rules-firing-spec.md for the consumer-contract
pattern this mirrors (engine-rules-bundle manifest.json).
"""
from __future__ import annotations

import json
from pathlib import Path

import jsonschema
import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schema" / "voicings.schema.json"
DATA_PATH = REPO_ROOT / "plugin" / "data" / "voicings.json"


@pytest.fixture(scope="module")
def data():
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def schema():
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def test_manifest_present(data):
    assert "manifest" in data, "voicings.json missing top-level manifest block (#593)"
    assert isinstance(data["manifest"], dict)


def test_manifest_has_required_fields(data):
    required = {"bundle_version", "schema_version", "total_voicings"}
    actual = set(data["manifest"].keys())
    missing = required - actual
    assert not missing, f"manifest missing required fields: {missing}"


def test_total_voicings_matches_array_length(data):
    """The most common drift mode: voicings added/removed but the
    manifest count never gets bumped."""
    declared = data["manifest"]["total_voicings"]
    actual = len(data["voicings"])
    assert declared == actual, (
        f"manifest.total_voicings={declared} but voicings[] has {actual} entries — "
        "bump the manifest after any add/remove"
    )


def test_schema_version_is_known(data):
    """Sanity check on schema_version. Currently only voicings-v1; bump on breaking change."""
    assert data["manifest"]["schema_version"] == "voicings-v1", (
        "Unknown schema_version; spec change requires consumer-side migration"
    )


def test_committed_source_has_null_commit_sha_and_built_at(data):
    """Per the manifest contract: plugin_commit_sha and built_at are null in
    committed source (chicken-and-egg) and filled at release time. If they're
    non-null in the committed file, something's gone wrong — possibly a stale
    release artifact got committed."""
    sha = data["manifest"].get("plugin_commit_sha")
    built = data["manifest"].get("built_at")
    assert sha is None, (
        f"manifest.plugin_commit_sha should be null in committed source, got {sha!r} — "
        "release-time fill artifact got committed?"
    )
    assert built is None, (
        f"manifest.built_at should be null in committed source, got {built!r}"
    )


def test_full_voicings_schema_validates(data, schema):
    """The whole file (manifest + voicings) validates against the schema."""
    jsonschema.validate(instance=data, schema=schema)


def test_manifest_min_consumer_version_present(data):
    """min_consumer_version is the forward-compat guard (Hyrum's-law). Optional
    in the schema but should be present in practice so consumers can refuse
    incompatible corpus versions."""
    assert "min_consumer_version" in data["manifest"], (
        "min_consumer_version missing — set the forward-compat floor"
    )
