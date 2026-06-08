#!/usr/bin/env python3
"""Build a Tally form for crowdsource voicing-tag review (#395 subtask 2).

Reads:
  - scripts/voicing-tags/pilot-50.csv (or any CSV with voicing_id +
    voicing_name + chord_quality + category + agent_proposed_voicingStyle
    + agent_proposed_playStyle + agent_confidence + agent_reasoning)
  - scripts/voicing-tags/diagrams/<voicing_id>.png (must exist on the
    branch that backs the configured image base URL)

Emits:
  - A Tally form payload JSON (default) — inspect before posting.
  - Optionally POSTs to https://api.tally.so/v1/forms when --post and
    TALLY_API_KEY env var are both set.

Form structure (per voicing):
  1. TITLE  — voicing_name + chord_quality + (agent confidence badge)
  2. IMAGE  — fretboard PNG, fetched from raw.githubusercontent.com
  3. TEXT   — "Agent proposed: <vs> | <ps>. Reasoning: <agent_reasoning>"
  4. MULTIPLE_CHOICE_OPTION × 3 — YES / NO / REFINE (single-select)
  5. TEXTAREA — "Why are you overriding the agent? (required if NO/REFINE)"
  6. INPUT_TEXT — "Tags to add (comma-separated, optional)"
  7. TEXTAREA — "Notes (optional)"

Each voicing's blocks share a single groupUuid so Tally renders them as
one logical question group.

Why Tally over Google Forms: see ticket #395. Tally's free tier includes
API access, supports image blocks via URL, and can ingest a full form's
worth of blocks in a single POST.
"""
import argparse
import csv
import json
import os
import sys
import uuid
from pathlib import Path

TALLY_API = "https://api.tally.so/forms"
DEFAULT_BASE_URL = (
    "https://raw.githubusercontent.com/"
    "siege-analytics/musescore4-chord-library-plugin/"
    "develop/scripts/voicing-tags/diagrams"
)


def new_uuid():
    return str(uuid.uuid4())


def _block(block_type, group_uuid, group_type, payload):
    return {
        "uuid": new_uuid(),
        "groupUuid": group_uuid,
        "groupType": group_type,
        "type": block_type,
        "payload": payload,
    }


def form_title_block(text):
    g = new_uuid()
    return [
        _block("FORM_TITLE", g, "TEXT", {"html": text, "title": text}),
    ]


def text_paragraph(html):
    g = new_uuid()
    return [_block("TEXT", g, "TEXT", {"html": html})]


def heading_block(text):
    """Standalone TITLE block at top level (not a question label)."""
    g = new_uuid()
    return [_block("TITLE", g, "TITLE", {"html": text})]


def image_question_group(image_url, alt_text):
    """IMAGE block alone — guess at payload shape from earlier doc sample."""
    g = new_uuid()
    return [_block("IMAGE", g, "IMAGE", {
        "images": [{"url": image_url, "name": alt_text}],
    })]


def _label(text):
    """Standalone label block — its own groupUuid per Tally's validator."""
    g = new_uuid()
    return _block("TITLE", g, "QUESTION", {"html": text})


def multiple_choice_question(label_html, options):
    """Label (own groupUuid) + N MULTIPLE_CHOICE_OPTION blocks sharing
    groupUuid with groupType=MULTIPLE_CHOICE."""
    blocks = [_label(label_html)]
    g = new_uuid()
    n = len(options)
    for i, opt in enumerate(options):
        blocks.append(_block("MULTIPLE_CHOICE_OPTION", g, "MULTIPLE_CHOICE", {
            "text": opt,
            "index": i,
            "isFirst": i == 0,
            "isLast": i == n - 1,
        }))
    return blocks


def textarea_question(label_html, placeholder="", required=False):
    return [
        _label(label_html),
        _block("TEXTAREA", new_uuid(), "TEXTAREA", {
            "isRequired": required,
            "placeholder": placeholder,
        }),
    ]


def input_text_question(label_html, placeholder=""):
    return [
        _label(label_html),
        _block("INPUT_TEXT", new_uuid(), "INPUT_TEXT", {
            "isRequired": False,
            "placeholder": placeholder,
        }),
    ]


def build_voicing_blocks(row, base_image_url):
    """Build the per-voicing block group. Returns a list of blocks all
    sharing one groupUuid so Tally treats them as one page/question.
    """
    group_uuid = new_uuid()
    vid = row["voicing_id"]
    name = row.get("voicing_name", vid)
    quality = row.get("chord_quality", "")
    category = row.get("category", "")
    vs = row.get("agent_proposed_voicingStyle", "") or "(none)"
    ps = row.get("agent_proposed_playStyle", "") or "(none)"
    conf = row.get("agent_confidence", "")
    reasoning = row.get("agent_reasoning", "")

    title_text = f"{name} — {quality} {category}".strip()
    image_url = f"{base_image_url}/{vid}.png"
    reasoning_html = (
        f"<p><b>Agent proposed:</b><br>"
        f"voicingStyle: <code>{vs}</code><br>"
        f"playStyle: <code>{ps}</code><br>"
        f"confidence: <b>{conf}</b></p>"
        f"<p><b>Reasoning:</b> {reasoning}</p>"
    )

    blocks = []
    blocks.extend(heading_block(title_text))
    blocks.extend(image_question_group(image_url, f"Fretboard diagram for {name}"))
    blocks.extend(text_paragraph(reasoning_html))
    blocks.extend(multiple_choice_question(
        "Do these tags fit this voicing?",
        ["YES", "NO", "REFINE"],
    ))
    blocks.extend(textarea_question(
        "If NO or REFINE, why are you overriding the agent?",
        placeholder="e.g. This Caug7 doesn't fit Joe Pass's chord-melody vocabulary",
    ))
    blocks.extend(input_text_question(
        "Tags to add (comma-separated, optional)",
        placeholder="e.g. van-eps, walking-bass",
    ))
    blocks.extend(textarea_question(
        "Anything else? (optional)",
        placeholder="Free-form notes",
    ))
    return blocks


def build_form_payload(rows, base_image_url, form_title):
    blocks = []
    blocks.extend(form_title_block(form_title))
    blocks.extend(text_paragraph(
        "<p>Thanks for helping. Each page shows one guitar voicing, "
        "the tags an automated tagger guessed, and a fretboard diagram. "
        "For each, click <b>YES</b>, <b>NO</b>, or <b>REFINE</b>, and "
        "tell us why if you disagree.</p>"
        "<p>You can skip rows you're unsure about — quality of judgment "
        "beats coverage.</p>"
    ))

    for row in rows:
        blocks.extend(build_voicing_blocks(row, base_image_url))

    return {
        "status": "DRAFT",
        "blocks": blocks,
    }


def post_to_tally(payload, api_key):
    import urllib.request
    import urllib.error
    req = urllib.request.Request(
        TALLY_API,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "voicing-tag-form-builder/1.0 (#395; curl-equivalent)",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} from Tally: {body}") from None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="scripts/voicing-tags/pilot-50.csv")
    ap.add_argument("--limit", type=int, default=0,
                    help="if > 0, only build N voicings (test-before-bulk)")
    ap.add_argument("--out", default="scripts/voicing-tags/tally-form-payload.json")
    ap.add_argument("--base-image-url", default=DEFAULT_BASE_URL)
    ap.add_argument("--title", default="Voicing-tag review — pilot (#395)")
    ap.add_argument("--post", action="store_true",
                    help="POST to Tally API (requires TALLY_API_KEY env var)")
    args = ap.parse_args()

    rows = list(csv.DictReader(open(args.csv)))
    if args.limit > 0:
        rows = rows[: args.limit]
    print(f"Building Tally form for {len(rows)} voicings", file=sys.stderr)
    print(f"Image base URL: {args.base_image_url}", file=sys.stderr)

    payload = build_form_payload(rows, args.base_image_url, args.title)
    n_blocks = len(payload["blocks"])
    print(f"Generated {n_blocks} blocks ({n_blocks // len(rows) if rows else 0} per voicing avg)", file=sys.stderr)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out}", file=sys.stderr)

    if args.post:
        api_key = os.environ.get("TALLY_API_KEY")
        if not api_key:
            print("ERROR: --post given but TALLY_API_KEY env var not set", file=sys.stderr)
            sys.exit(2)
        print(f"POSTing to {TALLY_API}…", file=sys.stderr)
        try:
            result = post_to_tally(payload, api_key)
        except Exception as e:
            print(f"POST failed: {e}", file=sys.stderr)
            sys.exit(1)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
