# Payload-Kind Glossary

`engine_payload.kind` is the dimension a rule is classified along — what the rule tells the engine to do, in 12 named buckets plus a `_pending:<kebab>` escape. This doc defines each name so authors can pick the right one without coercing rules into wrong buckets.

**Provenance.** These 12 names trace to predecessor session `260521-aware-nebula`'s `plans/schema-systems-model.md` lines 121-134 (post-#295 rollback). The definitions below are derived from how those same plans use the names against real rules in `plans/*-system-rebuild.md`. When a kind has no concrete rule-usage citation, the definition is conservative and the **Boundary notes** flag the gap.

**Tickets.** #298 (this doc), #297 (the master-distillation pipeline whose Stage 4 fills these kinds), #277-#285 (per-master migration into masters.json that consumes them).

---

## How to use this doc

When writing a rule, ask the two questions in order:

1. **Does the rule act on a single voicing in isolation, or on the relationship between two consecutive voicings?**
   - Single voicing (modification): `SubstitutionExpand`, `DensityFloor`, `DensityCeiling`, `OmissionAllow`, `ColorToneRequire`, `NCTHarmonization`, `TextureCycle`.
   - Consecutive voicings (traversal): `PositionContinuity`, `VoiceMotion`, `StringSetTransition`, `SymmetryMovement`, `FamilyCoherence`.

2. **Within that group, which dimension does the rule constrain?** See per-kind sections below. If the rule doesn't match cleanly, use `_pending:<short-kebab-slug>` — do NOT stretch a name. Stretches are the failure mode this glossary exists to prevent.

When in doubt: `_pending:`. Three of Benson Vol 1's rules in `derived/systems-draft.json` were filed under wrong names that this glossary surfaces (see the Audit section at the end).

**Note on field names.** The example payload field names below (`system_ref`, `same_region_threshold_frets`, `preferred_order`, `min_sounding_notes`, etc.) are **illustrative**, drawn from the predecessor's `schema-systems-model.md` examples. They are not normative until engine code consumes them. A future PR that wires up engine implementation may rename or restructure these fields; the glossary's field listings should be updated then. What's authoritative today is only `kind` (the enum value) and `_pending:<kebab>` (the escape).

---

## Traversal kinds

These act on the relationship between consecutive voicings.

### `PositionContinuity`

**Semantic.** Prefer the next voicing to stay within the same fingerboard region as the current voicing. The "region" is defined by an underlying system's spatial taxonomy — e.g., Pass's Six Chord Forms partition the fretboard into six ~5-6-fret regions, each anchored on a chord shape.

**Required/optional fields beyond `kind`.**
- `system_ref` — the taxonomy this rule consults (e.g. `pass:six-chord-forms`).
- `same_region_threshold_frets` — how wide the region is (e.g. `6`).
- `bonus`/`penalty` — score adjustment when next voicing is/isn't in the same region.

**Worked example.** Pass R1.2 (`pass:six-chord-forms`): "While the musical context permits, stay in one Form across consecutive voicings." Encoded as `{ kind: "PositionContinuity", system_ref: "pass:six-chord-forms", same_region_threshold_frets: 6, bonus: 15 }`. Source: `plans/schema-systems-model.md` lines 139-148.

**Boundary notes.** This is NOT "prefer the same string set" (that's `StringSetTransition`). NOT "prefer common-tone voicing motion" (that's `VoiceMotion`). NOT "stay in the same key" or "stay in the same harmonic field" (no kind covers that yet; would be `_pending:key-continuity` if it ever surfaces). The "region" is a spatial concept on the fingerboard, defined by the referenced system's taxonomy.

### `VoiceMotion`

**Semantic.** Constrain how the voices in a chord move between consecutive voicings. Expresses preferences over a motion-type taxonomy (common-tone, stepwise-inner, leap, parallel) with a ranked order.

**Required/optional fields beyond `kind`.**
- `preferred_order` — ordered array of motion types, best-first (e.g. `["common-tone", "stepwise-inner", "leap", "parallel"]`).
- `bonus_per_position` — score adjustment per rank (e.g. `[20, 10, 0, -5]`).

**Worked example.** Pass R3.1/R3.2 (`pass:voicing-density-and-voice-leading`): "voicings should lead into one another or have a common tone connecting them." Encoded as `{ kind: "VoiceMotion", preferred_order: [...], bonus_per_position: [...] }`. Source: `plans/schema-systems-model.md` lines 150-157. Reused by Wes R3.2 and Greene R4.1/R4.3 per their rebuild docs.

**Boundary notes.** This is **per-pair** (current voicing, next voicing). Multi-voice tracking across N positions — e.g. Greene's inner-voice counterpoint requiring continuous voices across an entire sequence — is **`_pending:inner-voice-counterpoint`** (filed because the per-pair `VoiceMotion` is structurally insufficient for it). NOT a rule about a single voicing's interval content (that's `DensityFloor`/`DensityCeiling`/`OmissionAllow`/`ColorToneRequire`). NOT a rule about forbidden intervals between bass and top of a single voicing — that's also a single-voicing rule and currently has no kind (would be `_pending:forbidden-vertical-interval`).

### `StringSetTransition`

**Semantic.** Constrain how a chord shape moves between string sets (e.g. 6-5-4-3 to 5-4-3-2). Typically requires a specific fingering move (pivot-finger, slide, position shift).

**Required/optional fields beyond `kind`.**
- `pivot_finger` — required finger for the transition (e.g. `1`, `4`).
- `transition_type` — `"pivot"`, `"slide"`, `"shift"`.
- `bonus`/`penalty`.

**Worked example.** Pass R1.1 (`pass:six-chord-forms`): "use the 1st or 4th finger to play two consecutive notes; the second note lands the hand in the next Form." Source: `plans/pass-system-rebuild.md`. Van Eps R1.1 harmonized-scale traversal also flagged as using this kind (per `plans/vaneps-system-rebuild.md` line 41).

**Boundary notes.** This is about the MECHANICAL move between string sets. Greene's `_pending:string-transference` is a stricter variant — moving a voicing while preserving relative chord position — which the existing kind doesn't capture. NOT about the spatial region (that's `PositionContinuity`). NOT about the voicing's note content.

### `SymmetryMovement`

**Semantic.** Prefer/require movement along a symmetric musical interval pattern — whole-tone, minor-third, diminished-cycle, etc.

**Required/optional fields beyond `kind`.**
- `interval` — `"whole-tone"`, `"minor-third"`, `"major-third"`, `"tritone"`, etc.
- `cycle_length` — `2`, `3`, `4`, `6`.
- `bonus`/`penalty`.

**Worked example.** Greene's symmetric-movement system uses this kind per `plans/greene-system-rebuild.md` line 134, citing "existing `SymmetryMovement` (per #249's v1 payload kinds list)."

**Boundary notes.** This is about INTERVAL symmetry of the motion between voicings (or chord roots), not about the chord quality being symmetric (e.g. diminished 7th chords are quality-symmetric — that's `OmissionAllow` for "no inversions for symmetric chords" if anything). NOT about modal symmetry in scales.

### `FamilyCoherence`

**Semantic.** Prefer the next voicing to share a harmonic family with the current voicing. "Family" is defined by an underlying taxonomy system — typically major/minor/dominant per Pass's Three Harmonic Families.

**Required/optional fields beyond `kind`.**
- `system_ref` — the family taxonomy (e.g. `pass:three-harmonic-families`).
- `bonus`/`penalty`.

**Worked example.** Pass R2.1 (`pass:three-harmonic-families`): "When traversing a chord progression, voicings drawn from the same family share recognition cues for the listener." Source: `plans/pass-system-rebuild.md` (R2.1 section).

**Boundary notes.** The family taxonomy is the referenced system's job. NOT about staying in the same key or harmonic field. NOT about substitution within a family — that's `SubstitutionExpand`.

---

## Modification kinds

These act on a single voicing in isolation, before or independent of consecutive-voicing comparison.

### `SubstitutionExpand`

**Semantic.** Expand the candidate pool of voicings for a given chord by substituting other chord qualities or types. The substitute set is enumerable and finite.

**Required/optional fields beyond `kind`.**
- `target_quality` — the chord being substituted (e.g. `"dom7"`).
- `expansion_set` — array of replacement qualities (e.g. `["dom7", "dom9", "dom13", "dom7b9", ...]`).
- `applies_to_contexts` — array of contexts where this substitution is licensed.

**Worked example.** Pass R5.3 (`pass:dominant-substitution-lattice`): expanding `dom7` into the altered family. Encoded as `{ kind: "SubstitutionExpand", target_quality: "dom7", expansion_set: [...], applies_to_contexts: ["comping", "chord-melody"] }`. Source: `plans/schema-systems-model.md` lines 159-168. Reused by Van Eps R1.3 chord-scale-equivalence and Greene's cycle-of-fourths substitution per their rebuild docs.

**Boundary notes.** This is about EXPANDING the candidate pool with related-quality substitutes. NOT about modifying a single voicing's interval content (that's `OmissionAllow` / `DensityFloor` / `DensityCeiling`). NOT about substituting one chord for another in the progression (that's reharm Phase B, currently handled by a higher-level mechanism, not this kind). Wes's upper-structure-triad substitution is `_pending:upper-structure-triad` because the substitute is structurally different (a triad positioned over an implied root, not a substitute chord quality).

### `DensityFloor`

**Semantic.** Require at least N sounding notes in the voicing. Below the floor, the voicing is rejected or penalized.

**Required/optional fields beyond `kind`.**
- `min_sounding_notes` — integer.
- `context_filter` — optional, e.g. `"solo"`, `"comping"`.

**Worked example.** Pass R3.4 (`pass:voicing-density-and-voice-leading`): solo-guitar contexts require at least 3 sounding notes. Encoded as `{ kind: "DensityFloor", min_sounding_notes: 3, context_filter: "solo" }`. Source: `plans/schema-systems-model.md` lines 170-178. Breau's bass-melody system also uses `DensityFloor: 2` per `plans/breau-system-rebuild.md` line 30.

**Boundary notes.** This is a hard or soft NOTE-COUNT floor. NOT about which intervals are present (that's `ColorToneRequire`). NOT about which intervals are forbidden between voices (no kind exists for that — would be `_pending:forbidden-vertical-interval`). Pairs with `DensityCeiling`; together they define a sounding-note band.

### `DensityCeiling`

**Semantic.** Require at most N sounding notes in the voicing. Above the ceiling, the voicing is rejected or penalized.

**Required/optional fields beyond `kind`.**
- `max_sounding_notes` — integer.
- `context_filter` — optional.

**Worked example.** Hall's guide-tone system (`hall:guide-tone-comping`): comping context uses 2-note voicings only. Encoded as `{ kind: "DensityCeiling", max_sounding_notes: 2, context_filter: "comping" }`. Source: `plans/hall-system-rebuild.md` line 17. Breau bass-melody system uses `DensityCeiling: 2` for implied-harmony texture (line 30).

**Boundary notes.** This is a NOTE-COUNT ceiling — about how MANY notes sound. **NOT about forbidden vertical intervals.** A rule like "no flat-9 between bass and top of major/minor chords" is structurally a forbidden-interval rule, not a density-ceiling rule, and currently has no kind — should be `_pending:forbidden-vertical-interval`. The Benson Vol 1 Stage 4 output filed exactly this rule as `DensityCeiling`; that's the canonical example of a stretch this glossary catches (see Audit section).

### `OmissionAllow`

**Semantic.** Permit specific chord tones to be omitted from the voicing. Used both for guitar-idiomatic edits (the 5th in 13ths is conventionally omitted) and for context-specific licenses (omit the root in piano-trio comping where the bass player has it).

**Required/optional fields beyond `kind`.**
- `omissible_degrees` — array of chord degrees (e.g. `["5"]`, `["1", "5"]`).
- `applies_to_chord_types` — array of chord qualities or families.
- `applies_to_contexts` — optional.

**Worked example.** "The 5th is almost always omitted in 13th chords" — encoded as `{ kind: "OmissionAllow", omissible_degrees: ["5"], applies_to_chord_types: ["dom13", "maj13", "min13"] }`. Sources: this example is plausible but not a verbatim rebuild-doc citation; `plans/schema-systems-model.md` line 278 mentions the `tolerance_hints.minSoundingNotes` migration path (related but not exactly this rule), and `plans/vaneps-system-rebuild.md` line 156 cites `OmissionAllow` as partial coverage of Van Eps's R4.2. **TODO**: replace this constructed example with a verbatim rebuild-doc citation once a master's rebuild explicitly encodes omission-allow against a specific degree.

**Boundary notes.** This is about which tones MAY be omitted, not which must be. NOT about which tones must be present (that's `ColorToneRequire`). NOT about avoid notes in melodic context (that's `NCTHarmonization`'s territory). Van Eps R4.1 note-addition-by-flattening goes the OTHER way (adding a note), which existing `OmissionAllow` doesn't cover — that's `_pending:flattened-finger-extension`.

### `ColorToneRequire`

**Semantic.** Require or bonus voicings that expose specific "color tones" — typically extensions (9, 11, 13) or mode-characteristic notes that give the chord its harmonic identity beyond chord-tones-only.

**Required/optional fields beyond `kind`.**
- `required_degrees` — array of chord degrees (e.g. `["#11"]`, `["b6"]`).
- `bonus`/`penalty`.
- `applies_to_chord_types` — optional.

**Worked example.** **TODO**: write when the first rule explicitly using `ColorToneRequire` against specific named degrees lands in a rebuild doc. Today the kind exists only as the predecessor's one-line comment in `plans/schema-systems-model.md` line 132 ("voicings exposing color tones rank higher"). The Phrygian "characteristic note: b2" pattern in Benson Vol 1's Stage 4 is the closest concrete usage, but it was filed by Stage 4 against this kind without prior rebuild-doc precedent — so citing it would be self-referential.

**Boundary notes.** This is a SINGLE-VOICING content rule about which tones must/should appear. NOT about how to handle non-chord tones in a melodic line (that's `NCTHarmonization`). NOT about "avoid notes" — those are tones to AVOID exposing, which is the inverse and currently has no kind (Benson Vol 1's "Avoid Note Suppression" was filed under `NCTHarmonization` and arguably belongs under `_pending:avoid-note-suppression` — see Audit).

### `NCTHarmonization`

**Semantic.** Control how the engine treats non-chord tones (NCTs) in the melody when generating voicings beneath them. "Appetite N" controls how aggressively NCTs get harmonized vs. left as bare melody notes.

**Required/optional fields beyond `kind`.**
- `appetite` — `0` (never harmonize NCT) through `1.0` (always harmonize).
- `nct_treatment_per_type` — optional map `{passing: 0.3, neighbor: 0.5, suspension: 0.8, ...}`.

**Worked example.** **TODO**: write when the first rule explicitly using `NCTHarmonization` against a melodic NCT context lands in a rebuild doc. Today the kind exists only as the predecessor's one-line comment in `plans/schema-systems-model.md` line 133 ("harmonize/skip non-chord tones with appetite N"). No rebuild-doc cites it against a specific rule.

**Boundary notes.** **This is about MELODY-DRIVEN harmonization** — given a non-chord tone in the melody, do you find a voicing that includes it (harmonize) or leave it bare? **It is NOT about "avoid notes" in the modal-harmony sense.** Avoid notes are mode-degree-specific notes that the modal taxonomy says should not be ended on or sustained over the underlying chord; that is a different concept and currently has no dedicated kind. Benson Vol 1's "Avoid Note Suppression" was filed here in the systems-draft and is one of the three audit findings below.

### `TextureCycle`

**Semantic.** Cycle the active texture (bass / chord / melody) across beats or beat-groups, producing a self-accompanied feel. Used by chord-melody and walking-bass styles.

**Required/optional fields beyond `kind`.**
- `texture_sequence` — ordered array (e.g. `["bass", "chord", "bass", "chord"]` for a typical chord-melody rhythm).
- `beat_pattern` — optional grouping (e.g. `[1, 2, 3, 4]`).
- `applies_to_contexts` — optional.

**Worked example.** **TODO**: write when the first rule explicitly using `TextureCycle` against a beat-pattern texture-cycling rule lands in a rebuild doc. The natural candidate (Pass's solo-guitar walking-bass-plus-chord-stab texture) is mentioned in `plans/pass-system-rebuild.md` but not bound to this kind there. Today the kind exists only as the predecessor's one-line comment in `plans/schema-systems-model.md` line 134.

**Boundary notes.** This is a STRUCTURAL rule about which voices sound when. NOT about chord density per voicing (that's `DensityFloor` / `DensityCeiling`). NOT about voicing transitions (those are traversal kinds). Benson Vol 1's Stage 4 used this kind for the "Study Devices Protocol" rule which is arguably a stretch — the Study Devices Protocol is a practice prescription, not a beat-level texture-cycling rule (see Audit).

---

## When no kind fits: `_pending:<kebab>`

If no name above matches what your rule does, use `_pending:<short-kebab-slug>`. The schema accepts it. Existing `_pending:` placeholders that have surfaced from the rebuild work:

| Slug | Why | First citation |
|---|---|---|
| `_pending:inner-voice-counterpoint` | N-voice tracking across N positions; `VoiceMotion` is per-pair only | Greene R4.2, R4.5; Van Eps R2.1-R2.5 |
| `_pending:string-transference` | Stricter than `StringSetTransition`: preserve relative chord position | Greene system; Van Eps R1.1 |
| `_pending:chord-scale-equivalence` | Greene's chord-scale substitution mechanism distinct from `SubstitutionExpand` | Greene rebuild |
| `_pending:flattened-finger-extension` | Adding a sounding note via finger flattening; `OmissionAllow` is omission only | Van Eps R4.1 |
| `_pending:upper-structure-triad` | Substitute is a triad above implied root, not a chord-quality substitution | Wes upper-structure system |
| `_pending:voicing-respacing` | Drop-2 / Drop-3 / drop-2+4 close-to-open transforms | Benson Vol 1 ch4 |

These are candidate names for future kind-additions, each warranting its own ticket per #256's `_pending:` workflow.

When you add a new `_pending:<slug>`, prefer slugs that describe the MECHANIC (what the rule does to candidates) rather than the EFFECT (musical outcome). `_pending:voicing-respacing` is good; `_pending:open-voicing-preference` is worse because it describes the effect.

---

## Audit: Benson Vol 1 stretches

Three rules in `plugin/data/masters-corpus/benson/method-vol-1-chord-construction/derived/systems-draft.json` were filed under named kinds that this glossary makes visible as stretches. Recording them as the first audited cases:

### 1. `No b9 Above Bass` was filed as `DensityCeiling`

Source: `chord-families` system in `derived/systems-draft.json`. The rule says: on major/minor chords, the interval between bass note and top note must not be a b9.

**Why it's a stretch.** `DensityCeiling` is a NOTE-COUNT ceiling. The b9-above-bass rule is a forbidden-vertical-interval constraint, structurally different. A voicing with 4 notes can satisfy `DensityCeiling: 4` and still violate the b9-above-bass rule.

**Correct kind.** `_pending:forbidden-vertical-interval`. New `_pending:` slug. Should be added to the table above when a follow-up ticket files it.

### 2. `Avoid Note Suppression` was filed as `NCTHarmonization`

Source: `harmonic-fields` system in `derived/systems-draft.json`. The rule says: don't end phrases on or sustain a mode's avoid notes over the underlying chord.

**Why it's a stretch.** `NCTHarmonization` is about HARMONIZING melody-driven non-chord tones. The avoid-note rule is the OPPOSITE: don't FEATURE these tones, leave them as passing only. Same direction (melody-driven), opposite handling.

**Correct kind.** `_pending:avoid-note-suppression`. New `_pending:` slug; same follow-up ticket as above could cover both new kinds.

### 3. `Study Devices Protocol` was filed as `TextureCycle`

Source: `harmonic-fields` system in `derived/systems-draft.json`. The rule encodes Benson/Farrell's four-rule practice protocol: one key at a time, with a groove, mastery before key change, 6th/5th-string voicings before 4th-string.

**Why it's a stretch.** `TextureCycle` is a structural rule about which voices sound when across beats. The Study Devices Protocol is a PRACTICE-PRESCRIPTION rule about how a student should sequence study — meta to the voicing engine, not a voicing engine rule at all.

**Correct kind.** Arguably no engine_payload kind fits because this rule does not constrain candidate voicings; it constrains the PRACTICE WORKFLOW. Options: `_pending:practice-prescription` (if we want to encode such rules at all), OR drop the rule from `systems-draft.json` and capture it instead as `system.summary` prose. The latter is cleaner.

---

## Maintenance

- This glossary lives at `docs/payload-kinds.md` and is linked from `schema/masters.schema.json`'s `engine_payload` description and from `CLAUDE.md`'s "Masters schema" section.
- When a `_pending:<slug>` graduates to a named kind, add a new section above and update the table in the "When no kind fits" section.
- When a stretch is caught during a per-master PR review, add it to the Audit section as a precedent.
- When the predecessor session's `plans/*-system-rebuild.md` corpus changes (e.g. when the master-distillation pipeline produces new rebuild docs for other masters), re-grep for kind usages and update the **Worked example** of each kind if a sharper one emerges.

**Source materials grep-verified to exist at the time of this writing:**
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/schema-systems-model.md`
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/pass-system-rebuild.md`
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/vaneps-system-rebuild.md`
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/greene-system-rebuild.md`
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/hall-system-rebuild.md`
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/wes-system-rebuild.md`
- `/Users/dheerajchand/.craft-agent/workspaces/my-workspace/sessions/260521-aware-nebula/plans/breau-system-rebuild.md`
