#!/usr/bin/env python3
"""Seed a Google-Sheets-ready CSV from the voicing-tag proposal JSON (#393).

Reads:
  - plugin/data/voicings-tag-proposal.json (output of scripts/voicing-tags/propose.py)

Writes:
  - <output>.csv — one row per voicing, columns described below.

Column shape (per #393 design):
  - voicing_id
  - voicing_name
  - chord_quality
  - category
  - existing_tags
  - agent_proposed_voicingStyle    ← what the heuristic tagger proposed
  - agent_proposed_playStyle
  - agent_confidence               ← HIGH / MED / NONE
  - agent_reasoning                ← one-line summary of the rationale chain
  - voter1_verdict                 ← YES / NO / REFINE (blank = skipped)
  - voter1_override_reason         ← required if verdict != YES (why disagreeing with the agent)
  - voter1_additions               ← extra tags to add (comma-separated, blank if none)
  - voter1_notes                   ← free text
  - voter2_verdict / override_reason / additions / notes
  - voter3_verdict / override_reason / additions / notes

The header row is human-friendly (with the column purposes visible).
Tag-list fields are emitted with ', ' separator (not commas alone) so a
Sheets cell renders 'pass, drop-2' not 'pass,drop-2' — and the csv module
handles surrounding-string quoting properly.
"""
import argparse
import csv
import json
import sys
from pathlib import Path


VOTER_COUNT = 3


def summarize_rationale(rationale, max_chars=180):
    """Collapse the rationale list-of-dicts into one human-legible line."""
    if not rationale:
        return ""
    parts = []
    for r in rationale:
        tag = r.get("tag", "?")
        conf = r.get("confidence", "?")
        reason = r.get("reason", "")
        reason_short = reason.split(" → ")[-1] if " → " in reason else reason
        parts.append(f"{tag} ({conf}): {reason_short}")
    text = " | ".join(parts)
    if len(text) > max_chars:
        text = text[: max_chars - 1] + "…"
    return text


def build_header():
    base = [
        "voicing_id",
        "voicing_name",
        "chord_quality",
        "category",
        "existing_tags",
        "agent_proposed_voicingStyle",
        "agent_proposed_playStyle",
        "agent_confidence",
        "agent_reasoning",
    ]
    for i in range(1, VOTER_COUNT + 1):
        base.extend([
            f"voter{i}_verdict",
            f"voter{i}_override_reason",
            f"voter{i}_additions",
            f"voter{i}_notes",
        ])
    return base


def proposal_to_row(p):
    return [
        p["voicing_id"],
        p.get("voicing_name", ""),
        p.get("chord_quality", ""),
        p.get("existing_category", ""),
        ", ".join(p.get("existing_tags", [])),
        ", ".join(p.get("proposed_voicingStyle", [])),
        ", ".join(p.get("proposed_playStyle", [])),
        p.get("max_confidence", ""),
        summarize_rationale(p.get("rationale", [])),
    ] + [""] * (4 * VOTER_COUNT)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--proposal", default="plugin/data/voicings-tag-proposal.json")
    ap.add_argument("--out", required=True, help="output CSV path")
    ap.add_argument("--pilot", type=int, default=0,
                    help="if > 0, emit a stratified pilot subset of this size")
    args = ap.parse_args()

    data = json.load(open(args.proposal))
    proposals = data["proposals"]

    if args.pilot > 0:
        proposals = stratified_pilot(proposals, args.pilot)
        print(f"Stratified pilot: {len(proposals)} rows", file=sys.stderr)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        w.writerow(build_header())
        for p in proposals:
            w.writerow(proposal_to_row(p))

    print(f"Wrote {out} ({len(proposals)} rows, {len(build_header())} columns)", file=sys.stderr)


def stratified_pilot(proposals, n):
    """Pick n proposals stratified by (category, max_confidence) so the pilot
    exposes reviewers to all categories AND all confidence levels.
    """
    from collections import defaultdict
    buckets = defaultdict(list)
    for p in proposals:
        key = (p.get("existing_category", "?"), p.get("max_confidence", "?"))
        buckets[key].append(p)
    keys = sorted(buckets.keys())
    picks = []
    idx = 0
    while len(picks) < n and keys:
        k = keys[idx % len(keys)]
        if buckets[k]:
            picks.append(buckets[k].pop(0))
        else:
            keys.pop(idx % len(keys))
            continue
        idx += 1
    return picks


if __name__ == "__main__":
    main()
