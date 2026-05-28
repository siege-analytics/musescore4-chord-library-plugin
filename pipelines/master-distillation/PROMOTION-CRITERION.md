# Promotion criterion — M / P / L / R / S taxonomy

**Supersedes #320** (which used a binary skip-promote / keep-corpus call). The post-#334 queue surfaced a richer set of authorial roles than the binary captures.

## The decision

A book's **primary product** determines its bucket. The author's reputation is one signal among many, not the call.

Authors are evaluated on two axes:

- **Impact** — how widely known and taught (pedagogue dimension)
- **Distinctiveness** — unique voice, attributable principles (master dimension)

Most authors sit clearly on one side; some sit on both (Jens Larsen is the canonical illustration: "pedagogue by impact but master by distinctiveness, like Nels Cline"). The two-axis framing makes the both case representable rather than forcing it to collapse.

## Five buckets

| status | Pipeline | masters.json role | Engine semantics |
|---|---|---|---|
| `master` | Stages 2-4 | distinct artistic voice | **Style-bound** principles — apply when user selects this voice |
| `pedagogue` | Stages 2-4 | known teacher / instructional impact | **General/received-wisdom** principles — apply as idiomatic baseline |
| `corpus` | none | reference-only material | not consumed by engine |

Plus two orthogonal harvest destinations — a book may route to **L** or **R** in addition to or instead of M/P:

- **L (library)** — encyclopedic / reference content (chord dictionaries, voicing catalogues, pattern compendia). Goes into `plugin/data/` as library extensions with source attribution. No principles[] or STATEMENT.md.
- **R (rules)** — algorithmic content (substitution rules, fingering principles, voice-leading patterns, technique sequences). Goes into a rules config namespace with source attribution. Engine consumes rules across styles, not as one style.

And one terminal disposition:

- **S (skip)** — beginner overlap with stronger texts, or low signal for both voice and rules. Kept on disk as corpus reference; no pipeline work.

A single author can produce books in multiple buckets (Laukens: chord-dictionary → L, tritone-substitution → R, beginners-guide → S). An `M`-status author does not preclude later harvesting their other books into L/R.

## Worked examples

### M — distinct artistic voice
- **Pat Martino** (linear-expressions, tonal-convergence). Linear/convergence is uniquely his theory; principles attributable.
- **Van Eps** (1939 method, harmonic mechanisms vol 1). 7-string-as-structural-enabler is a distinctive choice; composite STATEMENT spans works.
- **Mickey Baker** (complete course vol 1, vol 2). Historical voice; everyone was impacted by him.

### P — pedagogue with real influence, not claimed as voice
- **Greg O'Rourke** (complete-chord-melody). Institutional attribution: JazzGuitar.Be. Curated pedagogical material drawn from many voices.
- **Brent Greenan** (jazz-standards-playbook). Known to people who read about him; influence without distinctive principles.
- **Bill Carter** (fingerstyle-jazz). Well-known pedagogue in fingerstyle circles. Real teaching impact; not a unique artistic voice.

### L — library / reference content
- **Dirk Laukens** (chord-dictionary). Catalogue of chord shapes.
- **Heussenstamm-Silbergleit** (goldmine-100-jazz-lessons). 100-lesson catalogue.
- **Jerry Coker** (patterns-for-jazz). Pattern compendium.

### R — algorithmic / rules content
- **Randy Felts** (reharmonization-techniques). Substitution catalogue → engine rule layer.
- **Dirk Laukens** (tritone-substitution-licks). Substitution rules.
- **Jerry Coker** (elements-jazz-language). Vocabulary rules.

### S — skip
- **Matt Warnock** (beginners-guide). Overlap with stronger beginner texts.
- **Dirk Laukens** (beginners-guide). Same.

## The decision questions

For a book under consideration:

1. **Is there a distinctive artistic voice?** If the book lets you state what makes this person *this person* — and you would lose something specific if their voice disappeared from the canon — it is M-material.
2. **If not, is the author's pedagogical impact non-trivial?** If their books sold to tens of thousands, were taught in studios for years, or shaped a generation's vocabulary, the book is P-material. Their principles still get extracted; they are tagged so the engine knows they are received-wisdom, not style-bound.
3. **Independently — does the content shape itself suggest L or R?** A chord dictionary is L regardless of author status. A substitution catalogue is R regardless. M and P entries can additionally have works that route to L/R.
4. **Does the book duplicate stronger texts at lower fidelity?** S.

## Engine semantics

The status flag is consumed by the (future) engine's style-application layer:

- User selects "play in Martino's style" → engine prefers master-role principles attributed to Martino.
- User selects "play correctly within the idiom" → engine uses pedagogue-role principles as baseline plus a chosen master-role overlay.
- L material feeds chord lookup and voicing catalogues regardless of style selection.
- R material applies as rule transformations across styles.

The detailed engine architecture is out of scope for this document. What this document guarantees is that the **flag is present in the data** so the engine can sort later.

## Refs
- #320 (superseded — binary skip-promote criterion)
- #334 (queue rewrite that surfaced the need)
- #297 (master-distillation pipeline)
- #345 (this document)
