#!/usr/bin/env python3
"""Build the engine-rules release bundle (#548).

Walks plugin/data/masters-corpus/*/*/derived/engine-rules.json, validates each file's
_provenance.schema_version and canonical {master_id, work_id, engine_rules} shape, and emits:

  - engine-rules-bundle.tar.gz   : full per-book directory tree
  - engine-rules-fixture.tar.gz  : Joe Pass + sample slices + expected-fires.json placeholder
  - manifest.json                 : top-level manifest, validated against plugin/schemas/engine-rules-manifest.schema.json

Conforms to:
  - Firing semantics spec v0.1 (plugin/docs/engine-rules-firing-spec.md, #549)
  - Manifest schema (plugin/schemas/engine-rules-manifest.schema.json, #548)

Invoked by .github/workflows/engine-rules-release.yml on engine-rules-v* tag push.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tarfile
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MASTERS_CORPUS = REPO_ROOT / "plugin" / "data" / "masters-corpus"
SCHEMA_PATH = REPO_ROOT / "plugin" / "schemas" / "engine-rules-manifest.schema.json"

REQUIRED_PROVENANCE_FIELDS = ["schema_version", "extracted_at"]
SUPPORTED_SCHEMA_VERSIONS = {"0.1", "0.2"}
# v0.2 introduces family-hierarchical matching (spec #549 §2.2) that
# consumers running v0.1 do NOT understand; force them to upgrade
# before ingesting v0.2 bundles.
MIN_CONSUMER_VERSION_BY_SCHEMA = {
    "0.1": "0.1.0",
    "0.2": "0.2.0",
}
REQUIRED_TOP_LEVEL_FIELDS = ["_provenance", "master_id", "work_id", "engine_rules"]


def discover_engine_rule_files() -> list[Path]:
    return sorted(MASTERS_CORPUS.glob("*/*/derived/engine-rules.json"))


def validate_file(path: Path) -> dict:
    """Load + validate a single engine-rules.json file. Returns parsed JSON."""
    data = json.loads(path.read_text())

    for field in REQUIRED_TOP_LEVEL_FIELDS:
        if field not in data:
            raise ValueError(f"{path}: missing top-level field {field!r}")

    prov = data["_provenance"]
    for field in REQUIRED_PROVENANCE_FIELDS:
        if field not in prov:
            raise ValueError(f"{path}: missing _provenance.{field}")
    if prov["schema_version"] not in SUPPORTED_SCHEMA_VERSIONS:
        raise ValueError(
            f"{path}: schema_version {prov['schema_version']!r} not in supported "
            f"set {SUPPORTED_SCHEMA_VERSIONS}"
        )
    if not isinstance(data["engine_rules"], list):
        raise ValueError(f"{path}: engine_rules must be an array")
    return data


def git_head_sha() -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, text=True
    ).strip()


def build_manifest(
    files: list[Path], parsed: dict[Path, dict], bundle_version: str
) -> dict:
    masters_by_id: dict[str, dict] = {}
    total_rules = 0
    schema_versions: set[str] = set()

    for path in files:
        data = parsed[path]
        master_id = data["master_id"]
        work_id = data["work_id"]
        rule_count = len(data["engine_rules"])
        total_rules += rule_count
        schema_versions.add(data["_provenance"]["schema_version"])
        entry = masters_by_id.setdefault(
            master_id, {"master_id": master_id, "work_ids": [], "rule_count": 0}
        )
        entry["work_ids"].append(work_id)
        entry["rule_count"] += rule_count

    if len(schema_versions) > 1:
        raise ValueError(
            f"Multiple schema_versions across bundle: {schema_versions}. "
            "Bundle a single schema_version per release."
        )
    schema_version = next(iter(schema_versions))

    manifest = OrderedDict(
        [
            ("schema_version", schema_version),
            ("bundle_version", bundle_version),
            ("min_consumer_version", MIN_CONSUMER_VERSION_BY_SCHEMA[schema_version]),
            ("plugin_commit_sha", git_head_sha()),
            (
                "built_at",
                datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00"),
            ),
            ("total_rules", total_rules),
            (
                "masters",
                sorted(masters_by_id.values(), key=lambda m: m["master_id"]),
            ),
        ]
    )
    return manifest


def validate_manifest_against_schema(manifest: dict) -> None:
    """Validate manifest against the committed JSON Schema. Lazy-import jsonschema."""
    try:
        import jsonschema  # type: ignore
    except ImportError:
        print(
            "warning: jsonschema not installed; skipping manifest schema validation",
            file=sys.stderr,
        )
        return
    schema = json.loads(SCHEMA_PATH.read_text())
    jsonschema.validate(instance=manifest, schema=schema)


def bundle_arcname(f: Path) -> str:
    """Map a repo-internal engine-rules.json path to its bundle-canonical arcname.

    The bundle layout (per #558) is ``masters/<master_id>/<work_id>/derived/engine-rules.json``.
    This avoids leaking the plugin's internal ``plugin/data/masters-corpus/`` directory
    structure to downstream consumers. Matches the fixture tarball's layout.
    """
    rel = f.relative_to(MASTERS_CORPUS)
    return "masters/" + str(rel)


def write_bundle_tarball(out_path: Path, files: list[Path]) -> None:
    with tarfile.open(out_path, "w:gz") as tar:
        for f in files:
            tar.add(f, arcname=bundle_arcname(f))


def write_fixture_tarball(
    out_path: Path, files: list[Path], parsed: dict[Path, dict]
) -> None:
    """Fixture: Joe Pass guitar-chords engine-rules + sample slices + expected-fires.json."""
    pass_files = [f for f in files if "joe-pass" in str(f) and "guitar-chords" in str(f)]
    if not pass_files:
        raise ValueError("Joe Pass guitar-chords engine-rules.json not found for fixture")

    fixture_dir = REPO_ROOT / "scripts" / "_fixture_staging"
    if fixture_dir.exists():
        shutil.rmtree(fixture_dir)
    fixture_dir.mkdir(parents=True)

    pass_dest = fixture_dir / "masters/joe-pass/guitar-chords/derived/engine-rules.json"
    pass_dest.parent.mkdir(parents=True)
    pass_dest.write_text(json.dumps(parsed[pass_files[0]], indent=2) + "\n")

    sample_slices = [
        {
            "slice_id": "fix-001",
            "target_chord_canonical": "G7",
            "prev_chord_canonical": "Dm7",
            "next_chord_canonical": "Cmaj7",
            "melody_note": None,
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "progression.type": "ii-V-I",
            "progression.position": "V",
        },
        {
            "slice_id": "fix-002",
            "target_chord_canonical": "Cmaj7",
            "prev_chord_canonical": "G7",
            "next_chord_canonical": None,
            "melody_note": "E4",
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "progression.type": "ii-V-I",
            "progression.position": "I",
        },
    ]
    (fixture_dir / "fixtures").mkdir()
    (fixture_dir / "fixtures" / "sample-slices.json").write_text(
        json.dumps({"slices": sample_slices}, indent=2) + "\n"
    )
    expected_fires = {
        "_note": "Populated against firing-semantics spec v0.1 once Ellington's firing engine ratifies the conformance baseline. Empty here as initial placeholder.",
        "fires": [],
    }
    (fixture_dir / "fixtures" / "expected-fires.json").write_text(
        json.dumps(expected_fires, indent=2) + "\n"
    )

    with tarfile.open(out_path, "w:gz") as tar:
        for item in sorted(fixture_dir.rglob("*")):
            if item.is_file():
                tar.add(item, arcname=str(item.relative_to(fixture_dir)))

    shutil.rmtree(fixture_dir)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bundle-version",
        required=True,
        help="SemVer for this release (e.g., 0.1.0). Must match git tag engine-rules-v{X}.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=REPO_ROOT / "dist",
        help="Output directory for bundle + manifest (default: dist/).",
    )
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    files = discover_engine_rule_files()
    if not files:
        print("error: no engine-rules.json files found", file=sys.stderr)
        return 1
    print(f"discovered {len(files)} engine-rules files")

    parsed: dict[Path, dict] = {}
    for f in files:
        try:
            parsed[f] = validate_file(f)
        except ValueError as exc:
            print(f"validation error: {exc}", file=sys.stderr)
            return 1
    print(
        f"validated: all files have canonical shape + _provenance.schema_version in {SUPPORTED_SCHEMA_VERSIONS}"
    )

    manifest = build_manifest(files, parsed, args.bundle_version)
    validate_manifest_against_schema(manifest)
    manifest_path = args.out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(
        f"wrote {manifest_path} ({manifest['total_rules']} rules across {len(manifest['masters'])} masters)"
    )

    bundle_path = args.out_dir / "engine-rules-bundle.tar.gz"
    write_bundle_tarball(bundle_path, files)
    print(f"wrote {bundle_path} ({bundle_path.stat().st_size} bytes)")

    fixture_path = args.out_dir / "engine-rules-fixture.tar.gz"
    write_fixture_tarball(fixture_path, files, parsed)
    print(f"wrote {fixture_path} ({fixture_path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
