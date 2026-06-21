# Engine-Rules Firing Semantics — v0.2

**Status**: canonical, ratified by maintainer 2026-06-17 (#549 v0.1, #555 v0.2 extension)
**Schema version**: `_provenance.schema_version = "0.2"`
**Consumers**: Ellington `apps.engine_rules` (#97), #71 comparator, future Phase 7 melodic-rules engine.

## v0.2 changes (additive over v0.1)

v0.2 extends the canonical chord-quality token set and introduces **family-hierarchical matching** for `quality_binding`, codifying Ted Greene's three-family taxonomy (MAJOR / MINOR / DOMINANT + DIMINISHED + AUGMENTED) as the parent layer over specific qualities.

The extension is **strict additive** — every rule that fires under v0.1 still fires the same way under v0.2. New surface area:

- Extended canonical token set (was 11, now 36 tokens)
- Family tokens (`maj`, `min`, `dom7`, `dim`, `aug`) explicitly defined as **family parents** that match any specific quality in their family
- Family-hierarchical matching rules (§2.2)
- Expanded alias table covering common shorthand (§2.3)

v0.1 bundles remain consumable by v0.2 engines (any rule's `quality_binding` still works); v0.2 bundles require `min_consumer_version >= 0.2.0` so older consumers don't silently mis-parse the new family-token semantics.

## Scope

Defines how a downstream engine matches a single `engine_rule` against a single lead-sheet slice and produces a `RuleFireResult`. Codifies the matching contract so all consumers compute the same thing.

## Non-goals (v0.1)

- Cross-rule conflict resolution (deferred — wait until confirmation-form responses tell us which rules generalize).
- Cross-master blended firing (Ellington v2).
- Machine evaluation of `falsifier` (prose-only in v0.1).
- Rule chaining where one rule's `then` becomes another's `when` input.
- Melodic rules / Slonimsky-style pattern firing (Phase 7, #554).

## Slice contract

A slice is the unit of harmonic context the engine matches against. Canonical dimensions:

| Dimension | Type | Source |
|---|---|---|
| `target_chord_canonical` | string | lead sheet |
| `prev_chord_canonical` | string \| null | lead sheet |
| `next_chord_canonical` | string \| null | lead sheet |
| `melody_note` | string \| null | source (null for chord-only iRealPro) |
| `key` | string | lead sheet |
| `section_label` | string | lead sheet |
| `beat_in_measure` | float | lead sheet |
| `time_signature` | string | lead sheet |
| `arrangement.style` | string | application context |
| `progression.type` | string | application context |
| `progression.position` | string | application context |

Slices are **augmented** with derived facets the engine computes once at firing time:

- `chord_quality` — canonical token derived from `target_chord_canonical`
- `scale.context` — inferred from `key` + chord function
- `harmonic.context` — heuristic (`tonic`, `tension`, `passing`, `secondary_dominant`)

Augmentations MUST be deterministic. The canonical augmentation table lives in §3 below.

## §1 — `when` predicate semantics

The `when` map is **conjunctive (AND)** across all keys. Each value is matched as follows:

| Value shape | Match rule |
|---|---|
| literal string | slice dimension equals literal (exact) |
| literal int | slice dimension equals int |
| array | slice dimension equals **any** element (OR within key) |
| `"any"` | matches any value (including null) |
| (key absent) | no constraint on that dimension |

Dotted keys (`scale.context`, `voicing.role`, `progression.position`) are namespaced facets of the slice — engine resolves by dotted lookup on the augmented slice.

If the slice lacks a dimension the rule's `when` requires (e.g. `melody_note: null` against a rule requiring melody), the rule **does not fire**.

## §2 — `quality_binding` hard prefilter

`quality_binding` is an array of canonical chord-quality tokens. Semantics:

- `["any"]` — rule applies to any chord quality. Fires if other `when` conditions match.
- `["dom7", "alt7"]` — rule fires only if the slice's augmented `chord_quality` is in the list (with family-hierarchical matching per §2.2). Hard prefilter — overrides any `chord_quality` value inside `when`.

### §2.1 Canonical chord-quality token set

Per Ted Greene's three-family framework (Chord Chemistry Ch. 5–6), the token set is organized as:

**Family parents** (match any specific quality in their family per §2.2):
```
maj, min, dom7, dim, aug, sus, any
```

**Specific qualities under MAJOR family**:
```
maj, maj6, maj69, maj7, maj9, maj13, maj7#11, maj7b5
```

**Specific qualities under MINOR family**:
```
min, min6, min69, min7, min9, min11, min13, minMaj7, min7b5
```
(Note: `min7b5` is also conventionally classified under DOMINANT-function in jazz analysis when it leads to V; classification here is by structural quality, not function.)

**Specific qualities under DOMINANT family**:
```
dom7, dom9, dom11, dom13,
dom7b5, dom7#5, dom7b9, dom7#9, dom7#11,
dom7sus4,
alt7
```

**Specific qualities under DIMINISHED family**:
```
dim, dim7
```

**Specific qualities under AUGMENTED family**:
```
aug, aug7
```

**Specific qualities under SUS family** (Greene treats sus as its own boundary family):
```
sus2, sus4
```

**Wildcard**: `any`

### §2.2 Family-hierarchical matching

A rule keyed off a **family parent token** matches any specific quality in that family. A rule keyed off a **specific token** matches only that exact quality.

| Rule's `quality_binding` | Slice's augmented `chord_quality` | Fires? | Reason |
|---|---|---|---|
| `["maj"]` | `maj7` | ✅ | family parent matches family member |
| `["maj"]` | `maj9` | ✅ | family parent matches family member |
| `["maj7"]` | `maj9` | ❌ | specific mismatch (maj7 ≠ maj9) |
| `["maj7", "maj9"]` | `maj9` | ✅ | specific match in array |
| `["dom7"]` | `dom7b9` | ✅ | family parent (`dom7` is the DOMINANT family head) matches family member |
| `["dom7b9"]` | `dom7` | ❌ | specific mismatch — plain dom7 is not altered |
| `["dom7", "min7"]` | `dom9` | ✅ | DOMINANT family parent matches dom9 |
| `["sus"]` | `sus4` | ✅ | family parent matches family member |
| `["sus4"]` | `sus2` | ❌ | specific mismatch |
| `["any"]` | any | ✅ | wildcard |

**Edge case — `dom7` as both family parent and specific token**: `dom7` is the family head AND a specific quality (plain dominant 7th, no extensions/alterations). When a rule has `quality_binding: ["dom7"]`, it matches:
- a slice with `chord_quality = "dom7"` (specific match), AND
- a slice with `chord_quality = "dom9"` / `"dom7b9"` / etc. (family match)

This collapsing is intentional — most rules authored against `dom7` mean "any dominant," not specifically the un-extended dom7. To restrict to plain dom7 only, authors should use the explicit token `dom7_plain` (reserved for future use; for v0.2, write `quality_binding: ["dom7"], when: {"chord_quality": "dom7"}` — the redundant `when` clause makes intent explicit).

The same collapsing applies to `min7`-as-specific vs `min`-as-family-head and `maj7`-as-specific vs `maj`-as-family-head. The rule: **family parent name does NOT require the `7` suffix**, while specific quality names DO require their full canonical form.

### §2.3 Alias table

Authors may write any of these legacy / shorthand tokens; engines normalize at firing time:

| Author wrote | Engine resolves to |
|---|---|
| `"seventh"` | `dom7` |
| `"7"` | `dom7` |
| `"major"` | `maj` (family) |
| `"major7"` | `maj7` (specific) |
| `"minor"` | `min` (family) |
| `"minor7"` | `min7` (specific) |
| `"dominant"` | `dom7` (family) |
| `"dominant7"` | `dom7` (specific) |
| `"dominant_7"` | `dom7` |
| `"half-diminished"` | `min7b5` |
| `"diminished"` | `dim7` |
| `"+"` | `aug` |
| `"°"` | `dim` |
| `"ø"` | `min7b5` |
| `"m"` | `min` (family) |
| `"M"` | `maj` (family) |
| `"Δ"` | `maj7` |

### §2.4 Non-canonical values → `applicability_reasons`

Per #549/#555: non-canonical values in `quality_binding` (e.g. Laukens's `["voice_leading", "clarity"]`) are NOT chord qualities — they are authorial annotations on **why** the rule applies. The #555 corpus migration moves them into the optional `applicability_reasons` field. The review UI surfaces them as "this rule applies because of *X*."

After #555 lands, every rule's `quality_binding` contains canonical tokens only. Consumers reading v0.1 bundles should split non-canonical tokens out at sync time using the conservative whitelist documented in #555.

## §3 — Augmented slice facets

The engine MUST produce these facets deterministically from the raw slice:

### `chord_quality` (v0.2 — extended specificity)

Extract from `target_chord_canonical` to the most-specific canonical token. Engine extracts the FULL specificity available:

| Slice's `target_chord_canonical` | Augmented `chord_quality` |
|---|---|
| `Cmaj7` | `maj7` |
| `Cmaj9`, `Cmaj7add9` | `maj9` |
| `Cmaj13` | `maj13` |
| `Cmaj7#11`, `Cmaj7(#11)` | `maj7#11` |
| `C6` | `maj6` |
| `C6/9`, `C69` | `maj69` |
| `C7` | `dom7` |
| `C9` | `dom9` |
| `C11`, `C7sus4(11)` | `dom11` |
| `C13` | `dom13` |
| `C7b5` | `dom7b5` |
| `C7#5`, `C7+5` | `dom7#5` |
| `C7b9`, `C7(b9)` | `dom7b9` |
| `C7#9` | `dom7#9` |
| `C7#11` | `dom7#11` |
| `C7sus4`, `C7sus` | `dom7sus4` |
| `C7alt`, `Calt`, `C7(alt)` | `alt7` |
| `Cm7`, `Cmin7` | `min7` |
| `Cm9`, `Cmin9` | `min9` |
| `Cm11` | `min11` |
| `Cm13` | `min13` |
| `Cm6`, `Cmin6` | `min6` |
| `Cm6/9`, `Cm69` | `min69` |
| `CmMaj7`, `Cm(maj7)` | `minMaj7` |
| `Cm7b5`, `C∅`, `Cø` | `min7b5` |
| `Cdim`, `C°` | `dim` |
| `Cdim7`, `C°7` | `dim7` |
| `Caug`, `C+` | `aug` |
| `Caug7`, `C7+5`, `C+7` | `aug7` |
| `Csus2` | `sus2` |
| `Csus4`, `Csus` (bare) | `sus4` (sus4 wins if no number) |

When the engine encounters an ambiguous symbol it cannot disambiguate (e.g. `C(13)` without `7`), it MUST augment to the most general canonical token (here: `maj13`) and surface the disambiguation in matched_dimensions for review-UI visibility.

**Family-augmentation invariant**: every specific token belongs to exactly one family per §2.1. The engine SHOULD ALSO produce a `chord_family` facet alongside `chord_quality` so rules keyed off `quality_binding: ["dom7"]` (family) match through to slices augmented with `dom9` or `dom7b9`. This is the dual-keying mechanism that makes §2.2 family-hierarchical matching efficient at firing time.

### `scale.context`

Inferred from `key` + chord function. Examples:

- `key=C`, `progression.position=I` → `C_major`
- `key=C`, `progression.position=V` → `C_major` (parent scale of V/I)
- `key=C`, `target_chord=Dm7`, `progression.position=ii` → `D_dorian`

### `harmonic.context`

Heuristic categorical:

- `tonic` — chord is I, vi, or IIImaj in the local key
- `dominant_function` — V, V/x, tritone sub
- `subdominant_function` — ii, IV
- `passing` — chromatic mediant, brief surface harmony
- `tension` — altered dominant, tritone sub, suspended without resolution

Engine implementations MAY add more categorical values; the canonical set above is the minimum.

## §4 — `preference` — signed Likert scale

Per #549 sign-off: `preference` is a **signed 5-point Likert** (−2 to +2), symmetric across zero.

| Value | Token | Source-text examples that map here |
|---:|---|---|
| **+2** | `strong_prefer` | "required", "essential", "must" |
| **+1** | `prefer` | "preferred", "recommended", "default" |
| **0** | `neutral` | null, prose without clear stance |
| **−1** | `avoid` | "avoid", "don't" |
| **−2** | `strong_avoid` | "never", "hazardous", non-negotiable prohibitions |

**Authoring**: rules authored going forward MUST use integer values −2 to +2 in the `preference` field. The corpus migration ticket (#555) normalizes existing freeform-prose `preference` values into the Likert scale using the mapping table above.

**Polarity is derived, not stored**: `polarity = "avoid" if preference < 0 else "positive"`. The UI rendering rule (see §6) uses polarity; the comparator (#71) uses the signed Likert value directly for scoring.

## §5 — `then` action semantics (v0.1: passthrough)

`then` maps are heterogeneous across the corpus (some concrete: `"voicing.shape": "shell (root + 3rd + 7th, omit 5th)"`; some abstract: `"reharm.target": "any_chord"`). In v0.1 the engine passes `then` through as JSON on the `RuleFireResult`. Concrete voicing realization (turning `"shell (root+3+7)"` into fret coordinates) is the **downstream consumer's responsibility**, not the engine's. The engine tells you which rules fired and what they said.

v0.2 will add a canonical `then` action vocabulary so the engine can produce a voicing directly.

## §6 — `RuleFireResult` output shape

```python
from dataclasses import dataclass
from typing import Literal

@dataclass
class RuleFireResult:
    rule_id: str
    preference: int                       # Likert: -2..+2
    polarity: Literal["positive", "avoid"]  # derived: "avoid" if preference < 0
    then_action: dict                     # passthrough of rule.then
    anchor: str
    source_page: int | None
    matched_dimensions: dict              # which when-keys matched and on what slice value
    confidence: float                     # placeholder; v0.1 = 1.0 if fired
    applicability_reasons: list[str]      # rule-author annotations from #555 split
```

### Review UI rendering rule (Ellington #98)

- `polarity == "positive"` → render as a normal voicing suggestion; magnitude (`preference`) determines visual prominence (strong_prefer = brightest)
- `polarity == "avoid"` → render with strikethrough + anchor quote as "don't do this here"; magnitude shows severity

### Comparator scoring rule (#71)

Sum signed `preference` across all firings for a given (slice, voicing-candidate) pair. Higher score = stronger collective preference. Negative scores indicate the voicing collectively triggers avoid-firings.

## §7 — `falsifier` (prose only, v0.1)

Each rule's `falsifier` is human-readable. NOT machine-evaluated in v0.1. Surfaces in the review UI so contributors can apply the falsifier judgmentally when verdict-ing. Future v2 may add structured machine-falsifiable predicates.

## §8 — Worked examples

### Example 1 — positive fire, Joe Pass

Rule (after #555 migration):
```json
{
  "rule_id": "pass-seventh-cycle-origin",
  "when": { "chord_quality": "dom7", "progression.position": "cycle_node" },
  "then": { "voicing.shape": "seventh_catalog_form" },
  "preference": 1,
  "quality_binding": ["dom7", "maj7", "min7"]
}
```

Slice: `target_chord_canonical = "G7"`, `progression.position = "cycle_node"`.

Engine augments `chord_quality = "dom7"`. Matches `quality_binding`; matches `when`. Fires.

`RuleFireResult`:
```json
{
  "rule_id": "pass-seventh-cycle-origin",
  "preference": 1,
  "polarity": "positive",
  "then_action": { "voicing.shape": "seventh_catalog_form" },
  "matched_dimensions": { "chord_quality": "dom7", "progression.position": "cycle_node" },
  "confidence": 1.0,
  "applicability_reasons": []
}
```

### Example 2 — avoid fire, Laukens (after #555)

Rule:
```json
{
  "rule_id": "laukens-back-cycling-not-band-context",
  "when": { "arrangement.style": "band_with_others_on_chart" },
  "then": { "chord_symbol.substitute": "none_use_original_chart" },
  "preference": -1,
  "quality_binding": ["any"],
  "applicability_reasons": ["arrangement_context"]
}
```

Slice with `arrangement.style = "band_with_others_on_chart"`. Fires.

`RuleFireResult`:
```json
{
  "rule_id": "laukens-back-cycling-not-band-context",
  "preference": -1,
  "polarity": "avoid",
  "then_action": { "chord_symbol.substitute": "none_use_original_chart" },
  "matched_dimensions": { "arrangement.style": "band_with_others_on_chart" },
  "confidence": 1.0,
  "applicability_reasons": ["arrangement_context"]
}
```

Review card renders the anchor *"this technique won't necessarily work well if you are playing in a band as the changes may clash with the original chord chart"* as a positive instruction (don't back-cycle here), with strikethrough on any suggested substitution.

### Example 3 — strong_avoid fire (Roberts)

Rule:
```json
{
  "rule_id": "roberts-20w-no-skip-days",
  "when": { "practice.schedule": "any" },
  "then": { "session.skip": false },
  "preference": -2,
  "quality_binding": ["any"]
}
```

Strong avoid (−2) renders with extra visual severity. Anchor: *"Avoid skipping a day, for whatever reason. The effect is hazardous to progress. Regularity is essential."*

## §9 — Open follow-ups

- **#555**: corpus migration splitting `quality_binding` into canonical + `applicability_reasons`; normalizing `preference` prose into Likert integers. Targets bundle `engine-rules-v0.2.0`.
- **#550**: source-book locator metadata for anchor deep-links (review UI v2 feature).
- **#554** (Phase 7): melodic_rules artifact + Slonimsky distillation.
- **v0.3** (future): canonical `then` action vocabulary; structured `falsifier` predicates; comparator-confidence model; melodic-layer composition with v0.2 harmonic engine.

## Version history

| Version | Date | Note |
|---|---|---|
| 0.1 | 2026-06-17 | Initial spec, ratified per #549 |
| 0.2 | 2026-06-17 | Extended canonical token set via Ted Greene's three-family taxonomy (Chord Chemistry Ch. 5–6); family-hierarchical matching for `quality_binding`; expanded alias table including symbols (`+`, `°`, `ø`, `Δ`). Ratified per #555. Strict additive over v0.1. |
