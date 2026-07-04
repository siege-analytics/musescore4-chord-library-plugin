#!/usr/bin/env python3
"""Build the reviewer-facing data dictionary for #398.

Reads:
  - plugin/data/voicings.json (for categories)
  - plugin/data/masters.json (for master + principle summaries)
  - plugin/data/voicings-tag-proposal.json (to know which tags are
    actually emitted, so we only define what reviewers will see)

Writes:
  - scripts/voicing-tags/data-dictionary.md  — human-readable doc
  - scripts/voicing-tags/data-dictionary.json — same content as
    structured data so tally-form-builder.py can inject per-voicing
    glossary snippets into the form.

Sections:
  A. Voicing categories — hand-written here (not derivable from JSON)
  B. Masters — one line per master, derived from each master's primary
     principle summary (since masters.json has no master-level bio yet)
  C. Tags — one summary per voicingStyleTag actually emitted in the
     proposal, pulled from the source principle's summary in masters.json
  D. Confidence levels — boilerplate explanation
"""
import argparse
import json
import re
import textwrap
from collections import OrderedDict
from pathlib import Path


# Section A — voicing category definitions. Hand-written because the
# categories aren't documented in the JSON. Keep these short and
# guitarist-friendly.
CATEGORY_DEFINITIONS = {
    "drop2": {
        "title": "Drop-2",
        "definition": (
            "A 4-note voicing built by taking a close-position chord and "
            "dropping the second-highest note an octave."
        ),
        "sound": (
            "The bread-and-butter chord-melody and comping shape — clean, "
            "balanced, easy to voice-lead. Most jazz chord-solo arrangements "
            "live here."
        ),
        "example": (
            "The Cm7 shape you'd play across strings 6–3 or 5–2 with the b7 "
            "on top — the same shapes Joe Pass plays through Autumn Leaves."
        ),
    },
    "drop3": {
        "title": "Drop-3",
        "definition": (
            "Like drop-2, but the THIRD-highest voice is dropped an octave — "
            "producing a wider, more open spread across the strings."
        ),
        "sound": (
            "Bigger sound, more piano-like. Common when you want a bass note "
            "to ring under a chord-melody phrase."
        ),
        "example": (
            "The Cm7 voicing with root on the 6th string, skipping the 5th "
            "string, and the rest of the chord on strings 4–2."
        ),
    },
    "shell": {
        "title": "Shell voicing",
        "definition": (
            "A skeleton voicing — usually just the root, third, and seventh "
            "(R-3-7) — with no fifth or extensions."
        ),
        "sound": (
            "Minimal, dry, leaves space. Common in bebop comping and as a "
            "starting point that you 'dress' with extensions and tensions."
        ),
        "example": (
            "Peter Bernstein's go-to comping shape: R-3-7 on strings 6, 4, 3 "
            "or 5, 3, 2 — under a melody on the top strings."
        ),
    },
    "quartal": {
        "title": "Quartal voicing",
        "definition": (
            "A voicing built by stacking perfect-fourths rather than thirds."
        ),
        "sound": (
            "Open, ambiguous, modern. Doesn't commit to a single tonality — "
            "perfect for modal contexts and McCoy Tyner / Jim Hall sounds."
        ),
        "example": (
            "Three fourths stacked on the middle strings — works equally well "
            "as Dm7, G7sus, or Cmaj9 depending on the bass."
        ),
    },
    "extended": {
        "title": "Extended voicing",
        "definition": (
            "A voicing that includes upper-structure extensions: 9th, 11th, "
            "13th."
        ),
        "sound": (
            "Rich, modern, harmonically saturated. Sounds 'jazzy' on a Cmaj7 "
            "vamp; sounds 'wrong' on a country progression."
        ),
        "example": (
            "Cmaj9 with the 9 on top instead of the root — turns a static "
            "chord into a color."
        ),
    },
    "altered": {
        "title": "Altered voicing",
        "definition": (
            "A dominant-7 voicing with one or more altered tensions: b5, #5, "
            "b9, #9, #11, b13."
        ),
        "sound": (
            "Tense, leaning hard toward resolution. The Tristano / Coltrane "
            "language."
        ),
        "example": (
            "G7#9 with the #9 on top, used as the V chord into Cm in a minor "
            "ii-V-i."
        ),
    },
}


# Section E — form-labels glossary. What each column / label on the form
# means, plus the underlying concepts (master, tag, voicingStyle, playStyle).
# Written for a guitarist who hasn't been on the project — minimum jargon.
FORM_LABELS_CONCEPTS = OrderedDict([
    ("master", (
        "A guitarist whose chord-melody / comping vocabulary the engine "
        "knows about. Examples: `joe-pass`, `van-eps`, `dirk-laukens`, "
        "`peter-bernstein`, `pat-martino`. Tagging a voicing with a master "
        "means 'this voicing belongs to that master's tradition.'"
    )),
    ("tag", (
        "A short label connecting a voicing to either (a) a master "
        "(`joe-pass`, `van-eps`, ...) or (b) a specific principle of "
        "voicing or playing (`chord-melody`, `walking-bass`, "
        "`function-assigned`). Tags are how the engine decides what to "
        "recommend when a guitarist selects 'show me Joe Pass voicings.'"
    )),
    ("voicingStyle", (
        "The set of tags describing **what tradition the voicing belongs "
        "to** — usually master ids or principle names. Used by the engine "
        "to filter and rank voicings when a user picks a master."
    )),
    ("playStyle", (
        "The set of tags describing **how the voicing is used in a tune**: "
        "`block`, `chord-melody`, `walking-bass`, `altered-dominant`, "
        "`drop-2`, etc. Independent of voicingStyle — a Joe Pass voicing "
        "can be played as `block` or as `walking-bass`."
    )),
    ("category", (
        "The voicing's broad shape family: `drop2`, `drop3`, `shell`, "
        "`quartal`, `extended`, `altered`. See section A for definitions."
    )),
])

FORM_LABELS_AGENT_COLUMNS = OrderedDict([
    ("agent_proposed_voicingStyle", (
        "The voicingStyle tags the automated tagger guessed for this "
        "voicing. Comma-separated."
    )),
    ("agent_proposed_playStyle", (
        "The playStyle tags the tagger guessed. Comma-separated."
    )),
    ("agent_confidence", (
        "`HIGH` / `MED` / `NONE` — see section D for what each level "
        "means. Higher confidence = stronger evidence behind the guess."
    )),
    ("agent_reasoning", (
        "A one-line trace of *why* the tagger picked each tag. Format is "
        "`tag (CONFIDENCE): short-reason | next-tag (CONFIDENCE): ...`. "
        "Example: `dirk-laukens (MED): master 'dirk-laukens' (id-as-tag) | "
        "chord-function-driven (MED): discriminating tag`. Read it as a "
        "chain — each segment explains one tag the agent emitted. You can "
        "ignore the technical reasons (`id-as-tag`, `discriminating tag`) "
        "and just use the tags themselves as the signal."
    )),
])

FORM_LABELS_YOUR_COLUMNS = OrderedDict([
    ("verdict", (
        "**YES** — the proposed tags fit; move on. "
        "**NO** — these tags do not belong on this voicing. "
        "**REFINE** — some are right, some are wrong, or some are "
        "missing; use `additions` to add what's missing and "
        "`override_reason` to explain what's wrong."
    )),
    ("override_reason", (
        "Required if your verdict is NO or REFINE. **Briefly say why** "
        "you're disagreeing with the agent. Examples: "
        "\"Caug7 doesn't fit Joe Pass's chord-melody vocabulary\"; "
        "\"This shell is sus2 — Bernstein's R-3-7 shell principle "
        "doesn't apply\"; \"Should also be van-eps, not just pass\"."
    )),
    ("additions", (
        "Tags you would add, comma-separated. Use kebab-case (e.g. "
        "`van-eps`, not `Van Eps`). Reuse names from the proposed "
        "columns above so the vocabulary stays consistent. If you don't "
        "know the exact name, write a phrase in `notes` and the project "
        "owner will canonicalize."
    )),
    ("notes", (
        "Free-form text. Anything that doesn't fit `additions` or "
        "`override_reason` — context about a specific voicing, a "
        "question, an aside. Optional."
    )),
])

# Section D — confidence levels boilerplate
CONFIDENCE_DESCRIPTIONS = OrderedDict([
    ("HIGH", (
        "The voicing's existing tags directly named a master tag, so the "
        "automated tagger is reasonably sure the attribution is right."
    )),
    ("MED", (
        "The tag was derived: from a 'coverage' marker on the voicing, "
        "from a master-id alias in the voicing's tags, or from a category "
        "rule (e.g. category=quartal → quartal + jim-hall). The tagger "
        "thinks this fits but it's less certain."
    )),
    ("NONE", (
        "The tagger couldn't attribute this voicing to any master with "
        "confidence and left the voicingStyle blank. These are exactly the "
        "rows your judgment helps most."
    )),
])


def shorten(text, max_chars=220):
    text = (text or "").strip()
    text = re.sub(r"\s+", " ", text)
    if len(text) <= max_chars:
        return text
    cut = text[: max_chars - 1]
    last_period = max(cut.rfind(". "), cut.rfind("? "), cut.rfind("! "))
    if last_period > 0:
        return cut[: last_period + 1].strip()
    return cut.rstrip() + "…"


def first_principle_summary(master):
    for p in master.get("principles", []):
        s = p.get("summary")
        if s:
            return p["id"], s
    return None, None


def build_masters_section(masters):
    """One line per master, pulled from the first principle's summary."""
    entries = []
    for m in sorted(masters, key=lambda x: x["id"]):
        pid, summary = first_principle_summary(m)
        entries.append({
            "id": m["id"],
            "summary": shorten(summary or "(no summary in masters.json)", 240),
            "source_principle": pid,
        })
    return entries


def build_tags_section(masters, emitted_tags):
    """For each tag actually emitted in the proposal, find the principle
    that declared it and pull that principle's summary."""
    # Find first principle declaring each tag
    tag_lookup = {}
    for m in masters:
        for p in m.get("principles", []):
            for t in p.get("voicingStyleTags", []):
                if t in emitted_tags and t not in tag_lookup:
                    tag_lookup[t] = {
                        "tag": t,
                        "from_master": m["id"],
                        "from_principle": p.get("id", ""),
                        "summary": shorten(p.get("summary") or "", 280),
                    }
    entries = []
    for t in sorted(emitted_tags):
        if t in tag_lookup:
            entries.append(tag_lookup[t])
        else:
            entries.append({
                "tag": t,
                "from_master": None,
                "from_principle": None,
                "summary": f"(no principle summary found for tag {t!r})",
            })
    return entries


def emitted_tag_set(proposal):
    tags = set()
    for p in proposal["proposals"]:
        for t in p.get("proposed_voicingStyle", []):
            tags.add(t)
    return tags


def render_form_labels_section(concepts, agent_cols, your_cols):
    """Section E — Form labels glossary. Returns a list of markdown lines."""
    out = []
    out.append("## E. Form labels glossary")
    out.append("")
    out.append(
        "What every column on the form means. Read this once; it'll save "
        "you decoding each row."
    )
    out.append("")
    out.append("### E.1 Background concepts")
    out.append("")
    for label, desc in concepts.items():
        out.append(f"- **`{label}`** — {desc}")
    out.append("")
    out.append("### E.2 Agent's columns (what the form shows you)")
    out.append("")
    out.append(
        "Three or four columns on each row are the **agent's guess** at "
        "what tags this voicing should carry, plus its reasoning."
    )
    out.append("")
    for label, desc in agent_cols.items():
        out.append(f"- **`{label}`** — {desc}")
    out.append("")
    out.append("### E.3 Your columns (what we're asking you to fill in)")
    out.append("")
    out.append(
        "The remaining columns are yours. Fill them in for the rows you "
        "have judgment on; skip rows you don't."
    )
    out.append("")
    for label, desc in your_cols.items():
        out.append(f"- **`{label}`** — {desc}")
    out.append("")
    return out


def render_markdown(categories, masters, tags, confidences):
    out = []
    out.append("# Voicing data dictionary")
    out.append("")
    out.append(
        "A guide for the #395 voicing-tag review. Defines the **voicing "
        "categories**, **master tags**, and **principle tags** you'll see "
        "on the form. Generated from `plugin/data/voicings.json` + "
        "`plugin/data/masters.json` + the #389 proposer output — keep in "
        "sync via `scripts/voicing-tags/build-data-dictionary.py`."
    )
    out.append("")

    out.append("## A. Voicing categories")
    out.append("")
    out.append("Each voicing has one `category` — its broad shape family.")
    out.append("")
    for slug, defn in categories.items():
        out.append(f"### `{slug}` — {defn['title']}")
        out.append("")
        out.append(f"**What it is:** {defn['definition']}")
        out.append("")
        out.append(f"**What it sounds like:** {defn['sound']}")
        out.append("")
        out.append(f"**Example:** {defn['example']}")
        out.append("")

    out.append("## B. Master tags")
    out.append("")
    out.append(
        "Master tags (`joe-pass`, `van-eps`, `dirk-laukens`, …) mean "
        "\"voicings in this master's tradition.\" One line per master, "
        "drawn from each master's primary principle in `masters.json`."
    )
    out.append("")
    for m in masters:
        out.append(f"- **`{m['id']}`** — {m['summary']}")
    out.append("")

    out.append("## C. Principle tags")
    out.append("")
    out.append(
        "Principle tags describe a specific way of organizing voicings. "
        "Pulled from the source principle's `summary` field in "
        "`masters.json` — only tags the #389 proposer actually emits "
        "are listed."
    )
    out.append("")
    for t in tags:
        source = (
            f"from `{t['from_master']}/{t['from_principle']}`"
            if t["from_master"] else "no source"
        )
        out.append(f"### `{t['tag']}` ({source})")
        out.append("")
        out.append(t["summary"])
        out.append("")

    out.append("## D. Confidence levels")
    out.append("")
    out.append(
        "Each row on the form shows an `agent_confidence` of `HIGH`, "
        "`MED`, or `NONE`."
    )
    out.append("")
    for level, desc in confidences.items():
        out.append(f"- **`{level}`** — {desc}")
    out.append("")

    out.extend(render_form_labels_section(
        FORM_LABELS_CONCEPTS,
        FORM_LABELS_AGENT_COLUMNS,
        FORM_LABELS_YOUR_COLUMNS,
    ))

    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voicings", default="plugin/data/voicings.json")
    ap.add_argument("--masters", default="plugin/data/masters.json")
    ap.add_argument(
        "--proposal", default="plugin/data/voicings-tag-proposal.json"
    )
    ap.add_argument("--out-md", default="scripts/voicing-tags/data-dictionary.md")
    ap.add_argument("--out-json", default="scripts/voicing-tags/data-dictionary.json")
    args = ap.parse_args()

    masters_raw = json.load(open(args.masters))["masters"]
    proposal = json.load(open(args.proposal))
    emitted = emitted_tag_set(proposal)

    masters_section = build_masters_section(masters_raw)
    tags_section = build_tags_section(masters_raw, emitted)
    md = render_markdown(
        CATEGORY_DEFINITIONS, masters_section, tags_section,
        CONFIDENCE_DESCRIPTIONS,
    )

    Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out_md).write_text(md, encoding="utf-8")
    print(f"Wrote {args.out_md} ({len(md)} bytes)")

    data = {
        "categories": CATEGORY_DEFINITIONS,
        "masters": {m["id"]: m for m in masters_section},
        "tags": {t["tag"]: t for t in tags_section},
        "confidences": dict(CONFIDENCE_DESCRIPTIONS),
        "form_labels": {
            "concepts": dict(FORM_LABELS_CONCEPTS),
            "agent_columns": dict(FORM_LABELS_AGENT_COLUMNS),
            "your_columns": dict(FORM_LABELS_YOUR_COLUMNS),
        },
    }
    Path(args.out_json).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.out_json}")


if __name__ == "__main__":
    main()
