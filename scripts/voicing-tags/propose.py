#!/usr/bin/env python3
"""Heuristic voicing-tag proposer for #389 — v2 (post hostile review).

Reads:
  - plugin/data/voicings.json (820 voicings)
  - plugin/data/masters.json (master vocab: voicingStyleTags + playStyleTags)

Writes:
  - plugin/data/voicings-tag-proposal.json — per-voicing candidates + rationale.

Changes from v1 (driven by hostile review):
  1. GENERIC_DESCRIPTORS denylist — `chord-melody`, `shell`, `block`, `drop-2`,
     `drop-3` happen to appear in some master's vocab but they are content
     descriptors, not master attribution. They are only emitted when a SECOND
     signal (master alias in the same voicing, or category+quality rule)
     confirms attribution.
  2. Tag normalization — `drop3`→`drop-3`, `drop2`→`drop-2` applied before
     vocab lookup so the 20 drop3 voicings are no longer starved.
  3. Coverage marker no longer emits all 8 canonical tags. Emits ONLY the
     master_id (if it's in the vocab) and tags that are clearly principle-
     level descriptors (not pedagogical-method labels).
  4. Shell-as-bernstein restricted to chord_quality in BERNSTEIN_SHELL_QUALITIES
     so sus/dim/aug shells don't claim bernstein's R-3-7 attribution.
  5. Confidence demoted from HIGH to MED for generic-descriptor matches that
     pass the second-signal check.
  6. playStyle vocab misses are logged in _meta (was previously silent).

Confidence levels (calibrated):
  HIGH = tag is an existing voicing.tags entry AND a master-specific (not
         generic) voicingStyleTag.
  MED  = derived from -coverage marker, master alias, category rule, or
         a generic-descriptor passing second-signal check.
  LOW  = (reserved)
"""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


GENERIC_DESCRIPTORS = {
    "chord-melody", "shell", "block", "drop-2", "drop-3",
    "sparse", "narrative",
}

BERNSTEIN_SHELL_QUALITIES = {
    "maj7", "min7", "m7", "dom7", "7", "m7b5", "min7b5",
}

TAG_NORMALIZATION = {
    "drop2": "drop-2",
    "drop3": "drop-3",
}

PRINCIPLE_METHOD_TAGS = {
    "shape-based-pedagogy", "standard-anchored-practice",
    "named-relation-graph", "moveable-shapes",
}


def normalize_tag(t):
    return TAG_NORMALIZATION.get(t, t)


def load_master_vocabulary(masters_json_path):
    d = json.load(open(masters_json_path))
    voicing_tag_to_masters = defaultdict(set)
    play_tag_to_masters = defaultdict(set)
    master_canonical_voicing_tags = defaultdict(set)
    master_ids = set()
    for m in d["masters"]:
        master_ids.add(m["id"])
        for p in m.get("principles", []):
            for t in p.get("voicingStyleTags", []):
                voicing_tag_to_masters[t].add(m["id"])
                master_canonical_voicing_tags[m["id"]].add(t)
            for t in p.get("playStyleTags", []):
                play_tag_to_masters[t].add(m["id"])
    return {
        "voicing_tag_to_masters": dict(voicing_tag_to_masters),
        "play_tag_to_masters": dict(play_tag_to_masters),
        "all_voicing_tags": set(voicing_tag_to_masters.keys()),
        "all_play_tags": set(play_tag_to_masters.keys()),
        "master_canonical_voicing_tags": dict(master_canonical_voicing_tags),
        "master_ids": master_ids,
    }


def discriminating_master_tags(mid, vocab):
    """Tags this master declares that:
      - are single-master attributed (only this master uses them)
      - are NOT pedagogical-method tags (those are too abstract for
        per-voicing attribution)
    Returns sorted list.
    """
    own = vocab["master_canonical_voicing_tags"].get(mid, set())
    return sorted(
        t for t in own
        if len(vocab["voicing_tag_to_masters"].get(t, set())) == 1
        and t not in PRINCIPLE_METHOD_TAGS
    )


def build_master_alias_map(vocab):
    alias_to_master = {}
    for mid in vocab["master_ids"]:
        alias_to_master[mid] = mid
        parts = mid.split("-")
        alias_to_master.setdefault(parts[-1], mid)
        if len(parts) >= 2:
            alias_to_master.setdefault("-".join(parts[-2:]), mid)
    return alias_to_master


def category_to_play_tags(category, master_play_vocab):
    candidates = {
        "drop2": ["drop-2", "block"],
        "drop3": ["drop-3"],
        "quartal": ["quartal", "fourth-voicings"],
        "extended": ["extended", "extensions"],
        "altered": ["altered-dominant", "altered"],
        "shell": ["guide-tones", "guide-tone", "shell"],
    }
    raw = candidates.get(category, [])
    hits = [c for c in raw if c in master_play_vocab]
    misses = [c for c in raw if c not in master_play_vocab]
    return hits, misses


def voicing_has_master_signal(voicing, alias_to_master, normalized_tags):
    """True if the voicing carries any explicit master signal:
      - a *-coverage marker resolving to a master
      - an existing tag that is exactly a master_id or surname alias
    """
    for t in normalized_tags:
        if t.endswith("-coverage"):
            if alias_to_master.get(t[: -len("-coverage")]):
                return True
        if alias_to_master.get(t):
            return True
    return False


def propose_tags_for_voicing(voicing, vocab, alias_to_master, playstyle_misses):
    voicing_style = []
    play_style = []
    rationale = []
    seen_tags = set()
    conf_rank = {"HIGH": 3, "MED": 2, "LOW": 1, "NONE": 0}
    max_conf = "NONE"

    def emit_voicing(tag, conf, reason):
        nonlocal max_conf
        if tag in seen_tags or tag not in vocab["all_voicing_tags"]:
            return
        seen_tags.add(tag)
        voicing_style.append(tag)
        rationale.append({"tag": tag, "kind": "voicingStyle", "confidence": conf, "reason": reason})
        if conf_rank[conf] > conf_rank[max_conf]:
            max_conf = conf

    def emit_play(tag, conf, reason):
        nonlocal max_conf
        if tag in seen_tags or tag not in vocab["all_play_tags"]:
            return
        seen_tags.add(tag)
        play_style.append(tag)
        rationale.append({"tag": tag, "kind": "playStyle", "confidence": conf, "reason": reason})
        if conf_rank[conf] > conf_rank[max_conf]:
            max_conf = conf

    raw_tags = voicing.get("tags", []) or []
    normalized_tags = [normalize_tag(t) for t in raw_tags]
    category = voicing.get("category", "")
    chord_quality = voicing.get("chord_quality", "")

    has_master_signal = voicing_has_master_signal(voicing, alias_to_master, normalized_tags)

    # Heuristic A: existing tag in master voicing vocab
    for t in normalized_tags:
        if t not in vocab["voicing_tag_to_masters"]:
            continue
        attributing = sorted(vocab["voicing_tag_to_masters"][t])
        if t in GENERIC_DESCRIPTORS:
            # Generic descriptor: needs second signal (master alias present)
            if not has_master_signal:
                # Special case: 'shell' tag on shell-category, restricted by quality
                if t == "shell" and category == "shell" and chord_quality in BERNSTEIN_SHELL_QUALITIES:
                    emit_voicing(t, "MED",
                                 f"existing tag {t!r} + category=shell + quality={chord_quality!r} "
                                 f"matches bernstein R-3-7 shell principle")
                # Otherwise skip — would mis-attribute
                continue
            # Has master signal — emit at MED
            emit_voicing(t, "MED",
                         f"existing tag {t!r} (generic descriptor) confirmed by "
                         f"master signal in same voicing; vocab attributes to {attributing}")
        else:
            emit_voicing(t, "HIGH",
                         f"existing voicing.tags={t!r} matches master voicingStyleTag "
                         f"(attributes to {attributing})")

    # Heuristic B: -coverage marker → emit master_id tag + discriminating tags
    for t in normalized_tags:
        if not t.endswith("-coverage"):
            continue
        alias = t[: -len("-coverage")]
        mid = alias_to_master.get(alias)
        if not mid:
            continue
        # Always try master_id itself (if it's in vocab)
        if mid in vocab["voicing_tag_to_masters"]:
            emit_voicing(mid, "MED",
                         f"derived from voicing.tags={t!r} → master {mid!r} (id-as-tag)")
        # Plus discriminating tags (excludes pedagogical-method tags)
        for canonical in discriminating_master_tags(mid, vocab):
            if canonical == mid:
                continue
            emit_voicing(canonical, "MED",
                         f"derived from voicing.tags={t!r} → master {mid!r} "
                         f"→ discriminating tag {canonical!r}")

    # Heuristic C: existing tag IS a master alias (e.g. 'van-eps')
    for t in normalized_tags:
        mid = alias_to_master.get(t)
        if not mid:
            continue
        if mid in vocab["voicing_tag_to_masters"]:
            emit_voicing(mid, "HIGH" if t == mid else "MED",
                         f"voicing.tags={t!r} resolves to master {mid!r} (id-as-tag)")
        for canonical in discriminating_master_tags(mid, vocab):
            if canonical in (t, mid):
                continue
            emit_voicing(canonical, "MED",
                         f"voicing.tags={t!r} is alias for master {mid!r} "
                         f"→ discriminating tag {canonical!r}")

    # Heuristic D: category → playStyle
    if category:
        hits, misses = category_to_play_tags(category, vocab["all_play_tags"])
        for pt in hits:
            emit_play(pt, "MED", f"derived from category={category!r}")
        for m in misses:
            playstyle_misses[(category, m)] += 1

    return {
        "voicingStyle": voicing_style,
        "playStyle": play_style,
        "rationale": rationale,
        "max_confidence": max_conf,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", type=int, default=0)
    ap.add_argument("--voicings", default="plugin/data/voicings.json")
    ap.add_argument("--masters", default="plugin/data/masters.json")
    ap.add_argument("--out", default="plugin/data/voicings-tag-proposal.json")
    args = ap.parse_args()

    vocab = load_master_vocabulary(args.masters)
    alias_to_master = build_master_alias_map(vocab)

    print(f"Master vocab: {len(vocab['all_voicing_tags'])} voicingStyleTags, "
          f"{len(vocab['all_play_tags'])} playStyleTags, "
          f"{len(alias_to_master)} aliases")

    voicings = json.load(open(args.voicings))["voicings"]
    if args.sample > 0:
        voicings = voicings[:args.sample]

    playstyle_misses = Counter()
    proposals = []
    conf_counts = {"HIGH": 0, "MED": 0, "LOW": 0, "NONE": 0}
    tagged_count = 0
    for v in voicings:
        prop = propose_tags_for_voicing(v, vocab, alias_to_master, playstyle_misses)
        if prop["voicingStyle"] or prop["playStyle"]:
            tagged_count += 1
        conf_counts[prop["max_confidence"]] += 1
        proposals.append({
            "voicing_id": v["id"],
            "voicing_name": v.get("name", "?"),
            "existing_category": v.get("category", ""),
            "existing_tags": v.get("tags", []),
            "chord_quality": v.get("chord_quality", ""),
            "proposed_voicingStyle": prop["voicingStyle"],
            "proposed_playStyle": prop["playStyle"],
            "rationale": prop["rationale"],
            "max_confidence": prop["max_confidence"],
        })

    print(f"\nProcessed {len(voicings)} voicings; {tagged_count} tagged "
          f"({100*tagged_count/len(voicings):.1f}%)")
    print(f"Max-confidence distribution: {conf_counts}")

    drift = []
    for p in proposals:
        for t in p["proposed_voicingStyle"]:
            if t not in vocab["all_voicing_tags"]:
                drift.append(("voicingStyle", p["voicing_id"], t))
        for t in p["proposed_playStyle"]:
            if t not in vocab["all_play_tags"]:
                drift.append(("playStyle", p["voicing_id"], t))
    if drift:
        print(f"\n[!] TAG DRIFT: {len(drift)} tags not in master vocab")
        for kind, vid, t in drift[:5]:
            print(f"    {vid}: {kind}={t!r}")
    else:
        print("\n[✓] No tag drift")

    if playstyle_misses:
        print(f"\n[i] playStyle category misses (category → candidate not in master vocab):")
        for (cat, cand), n in playstyle_misses.most_common():
            print(f"    {cat!r} → {cand!r}: {n} voicings affected")

    out_payload = {
        "_meta": {
            "ticket": "#389",
            "purpose": "v2 heuristic voicing-tag proposal (post hostile review)",
            "voicings_processed": len(voicings),
            "voicings_tagged": tagged_count,
            "max_confidence_distribution": conf_counts,
            "tag_drift_count": len(drift),
            "playstyle_vocab_misses": {
                f"{cat}→{cand}": n
                for (cat, cand), n in playstyle_misses.most_common()
            },
            "v2_changes": [
                "GENERIC_DESCRIPTORS denylist requires master-signal second confirmation",
                "drop2/drop3 tag normalization",
                "coverage-marker emits only discriminating tags (no pedagogical-method)",
                "bernstein-shell restricted to standard 7th qualities",
            ],
        },
        "proposals": proposals,
    }
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(out_payload, indent=2) + "\n")
    print(f"\nWrote {args.out} ({len(proposals)} proposals)")


if __name__ == "__main__":
    main()
