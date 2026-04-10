#!/usr/bin/env python3
"""Verify voicings against the Uberchord API.

For each voicing, queries Uberchord's chord identification API to confirm
that the fret positions are recognized as the declared chord quality.

Usage:
    python uberchord_verify.py                          # verify all voicings
    python uberchord_verify.py --quality dom7            # verify only dom7
    python uberchord_verify.py --context CV6             # verify only CV6
    python uberchord_verify.py --limit 20                # first 20 only
    python uberchord_verify.py -o verification-report.json  # save report

Rate limits: 1 request per second (be a good API citizen).
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

API_BASE = "https://api.uberchord.com/v1/chords"
RATE_LIMIT = 1.0  # seconds between requests

# Map our quality IDs to Uberchord's chordName format (root,quality,tension,bass)
# Uberchord uses: root, quality (maj/min/etc), tension (7/9/etc), bass
QUALITY_MAP = {
    "dom7": ["", "7,"],
    "maj7": ["maj", "7,"],
    "min7": ["min", "7,"],
    "min7b5": ["min", "7,b5"],
    "dim7": ["dim", "7,"],
    "maj6": ["maj", "6,"],
    "min6": ["min", "6,"],
    "dom9": ["", "9,"],
    "maj9": ["maj", "9,"],
    "min9": ["min", "9,"],
    "dom7b9": ["", "7,b9"],
    "dom7sharp9": ["", "7,#9"],
    "sus4": ["sus", "4,"],
    "sus2": ["sus", "2,"],
    "aug7": ["aug", "7,"],
    "maj": ["maj", ","],
    "min": ["min", ","],
    "dim": ["dim", ","],
    "aug": ["aug", ","],
}

# Map Uberchord chord names to our quality IDs
REVERSE_MAP = {}
for our_q, (ub_qual, ub_tension) in QUALITY_MAP.items():
    REVERSE_MAP[f"{ub_qual},{ub_tension}"] = our_q


def voicing_to_uberchord_string(voicing: dict) -> str:
    """Convert a voicing to Uberchord's fret string format.

    Uberchord format: fret numbers from low E to high E, separated by hyphens.
    X for muted strings.
    """
    ns = voicing.get("strings", 6)
    result = ["X"] * ns

    for dot in voicing.get("dots", []):
        s = dot["string"]
        if 1 <= s <= ns:
            abs_fret = voicing["fret_number"] + (dot["fret"] - 1)
            result[s - 1] = str(abs_fret)

    for o in voicing.get("open", []):
        if 1 <= o <= ns:
            result[o - 1] = "0"

    # Reverse: our string 1 = high E, Uberchord expects low to high
    result.reverse()
    return "-".join(result)


def query_uberchord(voicing_str: str) -> dict | None:
    """Query the Uberchord API for a voicing string."""
    url = f"{API_BASE}?voicing={voicing_str}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ChordLibrary/1.3"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data[0] if isinstance(data, list) and data else data
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}"}
    except Exception as e:
        return {"error": str(e)}


def parse_uberchord_name(chord_name: str) -> dict:
    """Parse Uberchord's chord name format: 'root,quality,tension,bass'."""
    parts = chord_name.split(",")
    return {
        "root": parts[0] if len(parts) > 0 else "",
        "quality": parts[1] if len(parts) > 1 else "",
        "tension": parts[2] if len(parts) > 2 else "",
        "bass": parts[3] if len(parts) > 3 else "",
    }


def main():
    parser = argparse.ArgumentParser(description="Verify voicings against Uberchord API")
    parser.add_argument("--data", type=Path, default=REPO_ROOT / "plugin" / "data" / "voicings.json")
    parser.add_argument("--quality", help="Filter by quality")
    parser.add_argument("--context", help="Filter by context")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--limit", type=int, help="Max voicings to check")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be queried")
    parser.add_argument("-o", "--output", type=Path, help="Save report as JSON")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    with open(args.data) as f:
        data = json.load(f)
    voicings = data.get("voicings", [])

    # Filter
    if args.quality:
        voicings = [v for v in voicings if v.get("chord_quality") == args.quality]
    if args.context:
        voicings = [v for v in voicings if v.get("context") == args.context]
    if args.category:
        voicings = [v for v in voicings if v.get("category") == args.category]

    # Deduplicate by shape (don't query the same fingering twice)
    seen_shapes = {}
    unique_voicings = []
    for v in voicings:
        ub_str = voicing_to_uberchord_string(v)
        if ub_str not in seen_shapes:
            seen_shapes[ub_str] = v
            unique_voicings.append(v)

    if args.limit:
        unique_voicings = unique_voicings[:args.limit]

    print(f"Verifying {len(unique_voicings)} unique shapes "
          f"({len(voicings)} voicings, {len(voicings) - len(unique_voicings)} deduped)")

    if args.dry_run:
        for v in unique_voicings:
            ub_str = voicing_to_uberchord_string(v)
            print(f"  {v['id']:40s} → {ub_str}")
        return

    # Query Uberchord for each unique shape
    results = {
        "total": len(unique_voicings),
        "confirmed": 0,
        "mismatch": 0,
        "not_found": 0,
        "error": 0,
        "details": [],
    }

    for i, v in enumerate(unique_voicings):
        ub_str = voicing_to_uberchord_string(v)
        if args.verbose:
            print(f"  [{i+1}/{len(unique_voicings)}] {v['id']} → {ub_str} ... ", end="", flush=True)

        resp = query_uberchord(ub_str)
        time.sleep(RATE_LIMIT)

        if resp is None or "error" in resp:
            status = "error"
            results["error"] += 1
            ub_name = resp.get("error", "unknown") if resp else "no response"
        elif "chordName" not in resp:
            status = "not_found"
            results["not_found"] += 1
            ub_name = "not recognized"
        else:
            ub_name = resp["chordName"]
            parsed = parse_uberchord_name(ub_name)

            # Check if Uberchord's identification matches our declared quality
            our_quality = v["chord_quality"]
            ub_quality_key = f"{parsed['quality']},{parsed['tension']},"

            if our_quality in QUALITY_MAP:
                expected_qual, expected_tension = QUALITY_MAP[our_quality]
                ub_matches = (
                    parsed["quality"] == expected_qual
                    or our_quality in ub_quality_key.lower()
                )
            else:
                ub_matches = False

            if ub_matches:
                status = "confirmed"
                results["confirmed"] += 1
            else:
                status = "mismatch"
                results["mismatch"] += 1

        detail = {
            "id": v["id"],
            "our_quality": v["chord_quality"],
            "uberchord_query": ub_str,
            "uberchord_name": ub_name,
            "status": status,
        }
        if "fingering" in (resp or {}):
            detail["uberchord_fingering"] = resp["fingering"]

        results["details"].append(detail)

        if args.verbose:
            symbols = {"confirmed": "✓", "mismatch": "✗", "not_found": "?", "error": "!"}
            print(f"{symbols.get(status, '?')} {ub_name}")

    # Summary
    print(f"\nResults:")
    print(f"  Confirmed: {results['confirmed']}")
    print(f"  Mismatch:  {results['mismatch']}")
    print(f"  Not found: {results['not_found']}")
    print(f"  Errors:    {results['error']}")

    if results["mismatch"] > 0:
        print(f"\nMismatches:")
        for d in results["details"]:
            if d["status"] == "mismatch":
                print(f"  {d['id']}: ours={d['our_quality']}, "
                      f"uberchord={d['uberchord_name']}")

    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\nFull report saved to {args.output}")


if __name__ == "__main__":
    main()
