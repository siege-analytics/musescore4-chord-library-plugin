#!/usr/bin/env python3
"""Generate docs/glossary.md for the GitHub Pages site (#410).

Reads:
  - scripts/voicing-tags/data-dictionary.json — the canonical glossary
    data (categories, masters, tags, confidences, form_labels)

Writes:
  - docs/glossary.md — Jekyll-rendered glossary page with anchor links
    on every term so other docs can deep-link.

Source of truth is data-dictionary.json (which itself is rebuilt from
masters.json + voicings-tag-proposal.json by build-data-dictionary.py).
Run `build-data-dictionary.py` first if the upstream data changed.
"""
import argparse
import json
from pathlib import Path


def slugify(s):
    return s.replace("_", "-").replace(" ", "-").lower()


def render_glossary(dictionary):
    out = []
    out.append("---")
    out.append("title: Glossary")
    out.append("---")
    out.append("")
    out.append("# Glossary")
    out.append("")
    out.append(
        "Every term, label, tag, and concept that the project uses. "
        "Generated from `scripts/voicing-tags/data-dictionary.json` — "
        "if you spot drift, run "
        "`scripts/voicing-tags/build-data-dictionary.py` "
        "and then `scripts/voicing-tags/build-docs-site.py`."
    )
    out.append("")
    out.append(
        "*Looking for context first?* See "
        "[How it all fits]({{ site.baseurl }}/) for the overview, then "
        "come back here when you hit a term you don't recognize."
    )
    out.append("")

    # Table of contents
    out.append("## Sections")
    out.append("")
    out.append("- [Background concepts](#background-concepts)")
    out.append("- [Voicing categories](#voicing-categories)")
    out.append("- [Master tags](#master-tags)")
    out.append("- [Principle tags](#principle-tags)")
    out.append("- [Confidence levels](#confidence-levels)")
    out.append("- [Form labels — agent columns](#form-labels-agent)")
    out.append("- [Form labels — your columns](#form-labels-yours)")
    out.append("")

    fl = dictionary.get("form_labels", {})

    # Background concepts
    out.append("## Background concepts")
    out.append('<a id="background-concepts"></a>')
    out.append("")
    for label, desc in fl.get("concepts", {}).items():
        out.append(f'### `{label}`')
        out.append(f'<a id="{slugify(label)}"></a>')
        out.append("")
        out.append(desc)
        out.append("")

    # Voicing categories
    out.append("## Voicing categories")
    out.append('<a id="voicing-categories"></a>')
    out.append("")
    out.append("Each voicing has one `category` — its broad shape family.")
    out.append("")
    for slug, defn in dictionary.get("categories", {}).items():
        out.append(f"### `{slug}` — {defn['title']}")
        out.append(f'<a id="category-{slug}"></a>')
        out.append("")
        out.append(f"**What it is:** {defn['definition']}")
        out.append("")
        out.append(f"**What it sounds like:** {defn['sound']}")
        out.append("")
        out.append(f"**Example:** {defn['example']}")
        out.append("")

    # Master tags
    out.append("## Master tags")
    out.append('<a id="master-tags"></a>')
    out.append("")
    out.append(
        "Master tags (`joe-pass`, `van-eps`, `dirk-laukens`, …) mean "
        "\"voicings in this master's tradition.\" One line per master."
    )
    out.append("")
    for mid, m in dictionary.get("masters", {}).items():
        out.append(f'### `{mid}`')
        out.append(f'<a id="master-{slugify(mid)}"></a>')
        out.append("")
        out.append(m["summary"])
        out.append("")

    # Principle tags
    out.append("## Principle tags")
    out.append('<a id="principle-tags"></a>')
    out.append("")
    out.append(
        "Principle tags describe a specific way of organizing voicings. "
        "Only tags the #389 proposer actually emits are listed here."
    )
    out.append("")
    for tag, t in dictionary.get("tags", {}).items():
        source = (
            f" (from `{t['from_master']}/{t['from_principle']}`)"
            if t.get("from_master") else ""
        )
        out.append(f'### `{tag}`{source}')
        out.append(f'<a id="tag-{slugify(tag)}"></a>')
        out.append("")
        out.append(t["summary"])
        out.append("")

    # Confidence levels
    out.append("## Confidence levels")
    out.append('<a id="confidence-levels"></a>')
    out.append("")
    out.append(
        "Each row on the review form shows an `agent_confidence` of "
        "`HIGH`, `MED`, or `NONE`."
    )
    out.append("")
    for level, desc in dictionary.get("confidences", {}).items():
        out.append(f'### `{level}`')
        out.append(f'<a id="confidence-{level.lower()}"></a>')
        out.append("")
        out.append(desc)
        out.append("")

    # Agent columns
    out.append("## Form labels — agent columns")
    out.append('<a id="form-labels-agent"></a>')
    out.append("")
    out.append(
        "What the form shows you on each row — the automated tagger's "
        "guess at what tags this voicing should carry."
    )
    out.append("")
    for label, desc in fl.get("agent_columns", {}).items():
        out.append(f'### `{label}`')
        out.append(f'<a id="{slugify(label)}"></a>')
        out.append("")
        out.append(desc)
        out.append("")

    # Your columns
    out.append("## Form labels — your columns")
    out.append('<a id="form-labels-yours"></a>')
    out.append("")
    out.append("Columns you fill in.")
    out.append("")
    for label, desc in fl.get("your_columns", {}).items():
        out.append(f'### `{label}`')
        out.append(f'<a id="{slugify(label)}"></a>')
        out.append("")
        out.append(desc)
        out.append("")

    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src",
                    default="scripts/voicing-tags/data-dictionary.json")
    ap.add_argument("--out", default="docs/glossary.md")
    args = ap.parse_args()

    dictionary = json.load(open(args.src))
    md = render_glossary(dictionary)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(md, encoding="utf-8")
    print(f"Wrote {out} ({len(md)} bytes)")


if __name__ == "__main__":
    main()
