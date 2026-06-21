#!/usr/bin/env python3
"""Corpus migration #555 — normalize engine-rules.json to spec v0.2 shape.

For each rule across all 14 books:
  1. quality_binding: apply spec v0.2 alias table (§2.3); split canonical
     tokens from non-canonical (applicability_reasons); ["any"] if empty.
  2. preference: coerce freeform-prose values to signed Likert int [-2..+2]
     via the three approved mapping sources:
       (a) directly-mappable Likert dict (15 tokens, ~426 rules)
       (b) D5 lookup table from #555 sign-off (74 distinct, ~78 rules)
       (c) D4 LLM mapping over long-prose preferences (246 rules)
  3. Bump _provenance.schema_version 0.1 → 0.2.

Provenance: spec v0.2 (#549, #555 sign-off 2026-06-17), D5 lookup at
#555 comment-4736793419, D4 LLM mapping at /tmp/555-llm-mapping-compact.json
(authored 2026-06-17, sonnet model).
"""
from __future__ import annotations

import argparse
import collections
import json
import sys
from collections import OrderedDict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MASTERS_CORPUS = REPO_ROOT / "plugin" / "data" / "masters-corpus"

# ----- Spec v0.2 §2.1 Canonical token set --------------------------------

FAMILY_PARENTS = {"maj", "min", "dom7", "dim", "aug", "sus", "any"}

SPECIFIC_TOKENS = {
    # MAJOR family
    "maj", "maj6", "maj69", "maj7", "maj9", "maj13", "maj7#11", "maj7b5",
    # MINOR family
    "min", "min6", "min69", "min7", "min9", "min11", "min13", "minMaj7", "min7b5",
    # DOMINANT family
    "dom7", "dom9", "dom11", "dom13",
    "dom7b5", "dom7#5", "dom7b9", "dom7#9", "dom7#11",
    "dom7sus4", "alt7",
    # DIMINISHED family
    "dim", "dim7",
    # AUGMENTED family
    "aug", "aug7",
    # SUS family
    "sus2", "sus4",
    # Wildcard
    "any",
}

CANONICAL_TOKENS = FAMILY_PARENTS | SPECIFIC_TOKENS

# ----- Spec v0.2 §2.3 Alias table ----------------------------------------

ALIAS_TABLE = {
    "seventh": "dom7",
    "7": "dom7",
    "major": "maj",
    "major7": "maj7",
    "minor": "min",
    "minor7": "min7",
    "dominant": "dom7",
    "dominant7": "dom7",
    "dominant_7": "dom7",
    "dominant_7th": "dom7",
    "half-diminished": "min7b5",
    "diminished": "dim7",
    "+": "aug",
    "°": "dim",
    "ø": "min7b5",
    "m": "min",
    "M": "maj",
    "Δ": "maj7",
    # Extensions previously stored as numeric shorthand
    "9": "dom9",
    "11": "dom11",
    "13": "dom13",
    "7b9": "dom7b9",
    "7alt": "alt7",
    "dom7#11": "dom7#11",  # already canonical
    # Mickey Baker / Bruno variants
    "major_6_diminished": "min7b5",
    "minor_6_diminished": "dim7",
}

# ----- D4 LLM mapping (loaded from /tmp/555-llm-mapping-compact.json) ----

LLM_MAPPING_PATH = Path("/tmp/555-llm-mapping-compact.json")

# ----- D5 lookup (per #555 D5 sign-off, embedded inline for the PR) -----

D5_LOOKUP = {
    "required_plectrum": 2,
    "required for fretboard fluency": 2,
    "primary_cycle1_substitution": 2,
    "primary_construction_method": 2,
    "Practice both placements": 1,
    "optional_advanced": 0,
    "advanced_alternative": 0,
    "valid_alternative": 0,
    "advanced_optional": 0,
    "preferred_fingerstyle": 1,
    "advantage_of_plectrum": 1,
    "caution": -1,
    "recommended for interest": 1,
    "recommended for variety": 1,
    "required as orientation step": 2,
    "standard construction method": 1,
    "required by convention": 2,
    "definitional": 0,
    "first omission candidate": 1,
    "available simplification": 0,
    "exceptional use only": -1,
    "required for accurate analysis": 2,
    "preferred_for_inside_energy": 1,
    "recommended_for_modern": 1,
    "required_first_stage": 2,
    "required_second_stage": 2,
    "required_final_stage_for_jazz": 2,
    "take your time with this one": 1,
    "design invariant": 2,
    "required first step": 2,
    "required second step": 2,
    "strong preference": 2,
    "available": 0,
    "mandatory_replacement": 2,
    "required_for_beginners": 2,
    "required_for_comping": 2,
    "canonical_display": 0,
    "primary_invention_method": 2,
    "preferred_over_strum": 1,
    "mandatory_aesthetic": 2,
    "expanded_palette": 0,
    "constraint": 1,
    "primary_substitution_move": 2,
    "required_reference_artifact": 2,
    "required_for_horn_backing": 2,
    "universal_connector": 1,
    "required_classification": 2,
    "required_after_drill": 2,
    "primary_dual_function": 2,
    "required_for_b5_sub": 2,
    "primary_repertoire_framework": 2,
    "technique_acquisition_rule": 1,
    "required_companion_practice": 2,
    "workhorse_blues_ii_for_v": 1,
    "primary_v_to_i_run_template": 2,
    "required_internalization_step": 2,
    "primary_improvisation_scaffold": 2,
    "phrasing_aesthetic_required": 2,
    "primary_vamp_melodic_unit": 2,
    "required_for_fast_vamps": 2,
    "terminology_required": 2,
    "required_position_framework": 2,
    "exception_to_two_position_rule": 0,
    "required_internalization": 2,
    "convention_required": 2,
    "key_scoped_position": 1,
    "required_groove_riff_structure": 2,
    "placement_and_scope_rule": 1,
    "required_verification_step": 2,
    "primary_aesthetic_goal": 2,
    "required_pattern_discipline": 2,
    "primary_invention_procedure": 2,
    "meta_study_rule": 1,
    "either_acceptable": 0,
}

# ----- Direct Likert dict (covers 426 rules) -----------------------------

DIRECT_LIKERT = {
    "required": 2, "mandatory": 2, "invariant": 2, "non_negotiable": 2,
    "essential": 2, "must": 2, "strongly preferred": 2, "strong": 2,
    "preferred": 1, "recommended": 1, "moderate": 1, "advisory": 1,
    "default": 1, "standard": 1,
    "avoid": -1, "discouraged": -1,
    "optional": 0, "descriptive": 0, "tie-breaker": 0,
    "informational": 0, "flexible": 0, "permissive": 0,
}


# ----- migration ---------------------------------------------------------


def normalize_token(value: str) -> str:
    """Apply alias table to a single value. Returns the value if no alias."""
    return ALIAS_TABLE.get(value, value)


def split_quality_binding(qb: list) -> tuple[list[str], list[str]]:
    """Split a raw quality_binding list into (canonical_qb, applicability_reasons).

    1. Apply aliases.
    2. Canonical tokens stay in quality_binding.
    3. Non-canonical values move to applicability_reasons (deduplicated).
    4. If canonical_qb is empty after split, use ["any"].
    """
    if not isinstance(qb, list):
        qb = [qb] if qb else []
    canonical = []
    reasons = []
    for v in qb:
        if not isinstance(v, str):
            continue
        normalized = normalize_token(v)
        if normalized in CANONICAL_TOKENS:
            if normalized not in canonical:
                canonical.append(normalized)
        else:
            if v not in reasons:
                reasons.append(v)
    if not canonical:
        canonical = ["any"]
    return canonical, reasons


def coerce_preference(p, rule_id: str, llm_map: dict[str, int]) -> tuple[int, bool, str]:
    """Coerce preference to Likert int. Returns (value, mapped_ok, source)."""
    if p is None:
        return 0, True, "None→0"
    if isinstance(p, int):
        return max(-2, min(2, p)), True, "int passthrough"
    if not isinstance(p, str):
        return 0, False, f"non-str type:{type(p).__name__}"
    if p in DIRECT_LIKERT:
        return DIRECT_LIKERT[p], True, "direct"
    if p in D5_LOOKUP:
        return D5_LOOKUP[p], True, "D5"
    if rule_id in llm_map:
        return llm_map[rule_id], True, "D4-LLM"
    if len(p) > 30:
        # Long prose not in LLM map — shouldn't happen but fallback to 0
        return 0, False, "long-prose-unmapped"
    return 0, False, f"unmapped:{p[:30]!r}"


def discover_files() -> list[Path]:
    return sorted(MASTERS_CORPUS.glob("*/*/derived/engine-rules.json"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--llm-mapping",
        type=Path,
        default=LLM_MAPPING_PATH,
        help="Path to D4 LLM mapping JSON {m: {rule_id: int}}.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print diff summary; do not write changes.",
    )
    args = parser.parse_args()

    if not args.llm_mapping.exists():
        print(f"error: LLM mapping not found at {args.llm_mapping}", file=sys.stderr)
        return 1
    llm_map = json.loads(args.llm_mapping.read_text())["m"]

    files = discover_files()
    print(f"discovered {len(files)} engine-rules.json files")

    stats = collections.Counter()
    preference_sources = collections.Counter()
    likert_dist = collections.Counter()
    qb_token_dist = collections.Counter()
    unmapped_warnings: list[str] = []

    for f in files:
        with open(f) as fh:
            d = json.load(fh, object_pairs_hook=OrderedDict)
        engine_rules = d.get("engine_rules", [])

        for r in engine_rules:
            rule_id = r.get("rule_id", "")

            # quality_binding split
            qb_raw = r.get("quality_binding", [])
            canonical_qb, reasons_split = split_quality_binding(qb_raw)
            existing_reasons = r.get("applicability_reasons", []) or []
            merged_reasons = list(existing_reasons)
            for x in reasons_split:
                if x not in merged_reasons:
                    merged_reasons.append(x)
            r["quality_binding"] = canonical_qb
            if merged_reasons:
                r["applicability_reasons"] = merged_reasons
            for tok in canonical_qb:
                qb_token_dist[tok] += 1

            # preference coercion
            p_in = r.get("preference")
            p_int, mapped_ok, src = coerce_preference(p_in, rule_id, llm_map)
            r["preference"] = p_int
            preference_sources[src] += 1
            likert_dist[p_int] += 1
            if not mapped_ok:
                unmapped_warnings.append(f"{f.relative_to(REPO_ROOT)}::{rule_id} preference={p_in!r}")

            stats["rules_processed"] += 1

        # bump schema_version
        prov = d.get("_provenance", {})
        prov["schema_version"] = "0.2"
        d["_provenance"] = prov
        stats["files_processed"] += 1

        if not args.dry_run:
            with open(f, "w") as fh:
                json.dump(d, fh, indent=2, ensure_ascii=False)
                fh.write("\n")

    print(f"\n=== migration summary ===")
    print(f"files: {stats['files_processed']}; rules: {stats['rules_processed']}")
    print(f"\nLikert distribution:")
    for k in sorted(likert_dist):
        print(f"  {k:+d}: {likert_dist[k]}")
    print(f"\npreference source breakdown:")
    for k, v in preference_sources.most_common():
        print(f"  {v:4d}  {k}")
    print(f"\ntop 15 canonical quality_binding tokens:")
    for tok, n in qb_token_dist.most_common(15):
        print(f"  {n:4d}  {tok}")
    print(f"\nunmapped warnings: {len(unmapped_warnings)}")
    for w in unmapped_warnings[:5]:
        print(f"  {w}")

    if args.dry_run:
        print("\n(dry-run; no files modified)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
