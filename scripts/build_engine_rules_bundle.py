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

    # #568 — Expanded sample_slices covering firing-spec v0.2 matching surface:
    # §2.2 family-hierarchical (family-parent → specific-quality), specific-token
    # vs family-parent specificity, avoid-polarity (Likert -1 / -2), applicability_reasons
    # matching, and at-least-one-each of the top quality_binding tokens by corpus
    # frequency (any/dom7/maj7/min7). Total: 20 slices covering 14 distinct
    # quality_binding tokens. expected-fires.json stays placeholder per the
    # ticket — Ellington runs their engine against these and posts first-cut
    # output for co-ratification.
    sample_slices = [
        # ────── Original baseline pair (kept for backwards-compat sanity) ──────
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
            "arrangement.style": "default",
            "progression.type": "ii-V-I",
            "progression.position": "V",
            "chord_quality": "dom7",
            "harmonic.context": "dominant_function",
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
            "arrangement.style": "default",
            "progression.type": "ii-V-I",
            "progression.position": "I",
            "chord_quality": "maj7",
            "harmonic.context": "tonic",
        },
        # ────── Top-frequency tokens (any/dom7/maj7/min7 each get a slice) ──────
        {
            "slice_id": "fix-003",
            "target_chord_canonical": "Dm7",
            "prev_chord_canonical": "Cmaj7",
            "next_chord_canonical": "G7",
            "melody_note": "F4",
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "ii-V-I",
            "progression.position": "ii",
            "chord_quality": "min7",
            "harmonic.context": "subdominant_function",
        },
        # ────── §2.2 Family-hierarchical: family-parent rules fire on specific qualities ──────
        {
            "slice_id": "fix-004-fam-maj9",
            "target_chord_canonical": "Cmaj9",
            "prev_chord_canonical": "Dm7",
            "next_chord_canonical": None,
            "melody_note": "B4",
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "ii-V-I",
            "progression.position": "I",
            "chord_quality": "maj9",
            "harmonic.context": "tonic",
        },
        {
            "slice_id": "fix-005-fam-maj7sharp11",
            "target_chord_canonical": "Cmaj7#11",
            "prev_chord_canonical": None,
            "next_chord_canonical": "Dm7",
            "melody_note": "F#4",
            "key": "G",
            "section_label": "B",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "modal",
            "progression.type": "lydian-vamp",
            "progression.position": "IVmaj7",
            "chord_quality": "maj7#11",
            "harmonic.context": "tonic",
        },
        {
            "slice_id": "fix-006-fam-dom-spec-dom7b9",
            "target_chord_canonical": "G7b9",
            "prev_chord_canonical": "Dm7",
            "next_chord_canonical": "Cmaj7",
            "melody_note": "Ab4",
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "bebop",
            "progression.type": "ii-V-I",
            "progression.position": "V",
            "chord_quality": "dom7b9",
            "harmonic.context": "dominant_function",
        },
        {
            "slice_id": "fix-007-alt-dominant",
            "target_chord_canonical": "Galt",
            "prev_chord_canonical": "Bm7b5",
            "next_chord_canonical": "Cm",
            "melody_note": None,
            "key": "Cm",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "bebop",
            "progression.type": "minor-ii-V-i",
            "progression.position": "V",
            "chord_quality": "alt7",
            "harmonic.context": "dominant_function",
        },
        {
            "slice_id": "fix-008-fam-min9",
            "target_chord_canonical": "Dm9",
            "prev_chord_canonical": None,
            "next_chord_canonical": "G7",
            "melody_note": "E4",
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "modal",
            "progression.type": "modal-vamp",
            "progression.position": "ii",
            "chord_quality": "min9",
            "harmonic.context": "subdominant_function",
        },
        # ────── More canonical tokens ──────
        {
            "slice_id": "fix-009-min7b5",
            "target_chord_canonical": "Bm7b5",
            "prev_chord_canonical": "Am7",
            "next_chord_canonical": "E7b9",
            "melody_note": None,
            "key": "Am",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "minor-ii-V-i",
            "progression.position": "ii",
            "chord_quality": "min7b5",
            "harmonic.context": "subdominant_function",
        },
        {
            "slice_id": "fix-010-dim7",
            "target_chord_canonical": "B°7",
            "prev_chord_canonical": "Cmaj7",
            "next_chord_canonical": "Am7",
            "melody_note": None,
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 3.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "passing-diminished",
            "progression.position": "passing",
            "chord_quality": "dim7",
            "harmonic.context": "passing",
        },
        {
            "slice_id": "fix-011-aug7",
            "target_chord_canonical": "G+7",
            "prev_chord_canonical": "Dm7",
            "next_chord_canonical": "Cmaj7",
            "melody_note": None,
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "ii-V-I",
            "progression.position": "V",
            "chord_quality": "aug7",
            "harmonic.context": "tension",
        },
        {
            "slice_id": "fix-012-sus4",
            "target_chord_canonical": "Csus4",
            "prev_chord_canonical": None,
            "next_chord_canonical": "Cmaj7",
            "melody_note": "F4",
            "key": "C",
            "section_label": "intro",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "modal",
            "progression.type": "modal-vamp",
            "progression.position": "I",
            "chord_quality": "sus4",
            "harmonic.context": "tonic",
        },
        # ────── applicability_reasons (non-canonical authorial context) ──────
        {
            "slice_id": "fix-013-bossa-groove",
            "target_chord_canonical": "Cmaj7",
            "prev_chord_canonical": "Am7",
            "next_chord_canonical": "Dm7",
            "melody_note": "G4",
            "key": "C",
            "section_label": "A",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "bossa-nova",
            "progression.type": "bossa-i-vi-ii-V",
            "progression.position": "I",
            "chord_quality": "maj7",
            "harmonic.context": "tonic",
            "applicability_reasons": ["bossa_groove"],
        },
        {
            "slice_id": "fix-014-solo-chord-melody",
            "target_chord_canonical": "G7",
            "prev_chord_canonical": "Dm7",
            "next_chord_canonical": "Cmaj7",
            "melody_note": "E4",
            "key": "C",
            "section_label": "head",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "solo-guitar",
            "progression.type": "ii-V-I",
            "progression.position": "V",
            "chord_quality": "dom7",
            "harmonic.context": "dominant_function",
            "applicability_reasons": ["solo_chord_melody"],
        },
        # ────── Avoid-polarity (Likert -1 and -2 triggers) ──────
        {
            "slice_id": "fix-015-avoid-tritone-sub-before-pedal",
            "target_chord_canonical": "Db7",
            "prev_chord_canonical": "Dm7",
            "next_chord_canonical": "C/G",
            "melody_note": None,
            "key": "C",
            "section_label": "bridge",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "tritone-sub-into-pedal",
            "progression.position": "V-sub",
            "chord_quality": "dom7",
            "harmonic.context": "tension",
            "applicability_reasons": ["tritone_sub_before_pedal_avoid"],
        },
        {
            "slice_id": "fix-016-strong-avoid-chromatic-mediant-no-resolution",
            "target_chord_canonical": "Ebmaj7",
            "prev_chord_canonical": "Cmaj7",
            "next_chord_canonical": "Dm7",
            "melody_note": None,
            "key": "C",
            "section_label": "vamp",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "chromatic-mediant-vamp",
            "progression.position": "bIII",
            "chord_quality": "maj7",
            "harmonic.context": "passing",
            "applicability_reasons": ["chromatic_mediant_no_resolution"],
        },
        # ────── Blues / vamp / turnaround variety ──────
        {
            "slice_id": "fix-017-blues-I7",
            "target_chord_canonical": "C7",
            "prev_chord_canonical": None,
            "next_chord_canonical": "F7",
            "melody_note": "Bb3",
            "key": "C",
            "section_label": "blues",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "blues",
            "progression.type": "12-bar-blues",
            "progression.position": "I7",
            "chord_quality": "dom7",
            "harmonic.context": "tonic",
        },
        {
            "slice_id": "fix-018-vamp-maj7",
            "target_chord_canonical": "Fmaj7",
            "prev_chord_canonical": "Cmaj7",
            "next_chord_canonical": "Cmaj7",
            "melody_note": "A4",
            "key": "C",
            "section_label": "vamp",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "modal",
            "progression.type": "Imaj7-IVmaj7-vamp",
            "progression.position": "IVmaj7",
            "chord_quality": "maj7",
            "harmonic.context": "subdominant_function",
        },
        {
            "slice_id": "fix-019-turnaround-vi",
            "target_chord_canonical": "Am7",
            "prev_chord_canonical": "Cmaj7",
            "next_chord_canonical": "Dm7",
            "melody_note": "C4",
            "key": "C",
            "section_label": "A-end",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "default",
            "progression.type": "vi-ii-V-I-turnaround",
            "progression.position": "vi",
            "chord_quality": "min7",
            "harmonic.context": "tonic",
        },
        {
            "slice_id": "fix-020-min6-any-wildcard",
            "target_chord_canonical": "Cm6/9",
            "prev_chord_canonical": "Fm9",
            "next_chord_canonical": "Cm6/9",
            "melody_note": "D4",
            "key": "Cm",
            "section_label": "modal-vamp",
            "beat_in_measure": 1.0,
            "time_signature": "4/4",
            "arrangement.style": "modal",
            "progression.type": "modal-vamp",
            "progression.position": "i",
            "chord_quality": "min6",
            "harmonic.context": "tonic",
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
