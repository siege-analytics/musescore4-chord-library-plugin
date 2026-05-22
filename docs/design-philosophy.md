# Design Philosophy — Jazz System

This document records the load-bearing design principles for the project as it evolves from a chord-voicing library into a jazz arrangement system. These are not implementation details — they are decisions about *what the system is for* and *what it refuses to do*.

If you're a user wondering "why does the system behave this way" or a contributor wondering "what's the right scope for this PR," this is the document that answers.

---

## 1. The project is a Jazz System, not a chord bank

The git repository's name (`musescore4-chord-library-plugin`) and its initial CLAUDE.md framing reflect the project's **origin story**, not its current shape.

The project began as: *"I hate making chord diagrams by hand. Voice this beat for me."* A per-beat chord-voicing tool.

It has grown into: **a section-by-section jazz arrangement system, where the user can assign a composable `(master, style, tuning, mode, context)` tuple per section (or per stretch within a section), and the engine produces voicings, voice-leading, bass lines, and reharmonization choices that reflect that assignment.**

Scope decisions should be made against the Jazz System framing, not the chord-library framing. If the only reason to defer something is "this is too ambitious for a chord library," that reasoning does not apply. Ask instead: *"Is this a thing a jazz player thinks about when arranging a song?"* If yes, it's in scope.

**Tracking:** see [`.agents/skills/jazz-system/SKILL.md`](../.agents/skills/jazz-system/SKILL.md) for the full project framing.

---

## 2. The framework — 8 phases, 34+ questions

Arrangement decisions are organized into eight phases:

| Phase | What | Examples |
|---|---|---|
| **A. Preparation** | tune, key, sections, texture, right-hand | "What key? What sections? Solo or accompanied?" |
| **B. Reharmonization** | rewrite the written changes per active master's appetite | Pass: high. Van Eps: low. |
| **C. Melody recognition** | chord-tone vs non-chord-tone classification | Mostly theory, not opinion |
| **D. Voicing selection** | family, extensions, shape, density, string set, position, omissions | "Drop-2 or shell? Six strings or four?" |
| **E. Voice leading** | how successive voicings connect (relational territory) | "Common tone? Stepwise inner motion?" |
| **F. Bass line + rhythm** | self-played bass, walking style, rhythmic interlock | "Walking bass? Pompe? Bossa pattern?" |
| **G. Substitution / approach** | inserted chords between written ones | Passing diminished, tritone approach |
| **H. Completion** | playability, form (opening / body / conclusion), ending | Arrangement-level form decisions |

A parallel **Phase D' / E' / F'** lane covers `accompanied-lead` texture (single-line over rhythm section) — line generation, line-to-chord coordination, band-pocket placement.

Sources for the framework: Jody Fisher's three-volume *Jazz Guitar Method* (Alfred), jazzguitar.be's *Beginner's Guide to Jazz Guitar*, and jazzguitar.be's *Complete Chord Melody*. Other framework sources (Salvador, Leavitt, Russell) get incorporated as the project matures.

---

## 3. The systems-with-three-layers model

Each master in the bookshelf is **not** a flat list of preferences. Each master owns one or more **systems**, where each system has three layers:

1. **Taxonomy** — labels / tag sets (Pass's Six Chord Forms; Greene's V-System; Van Eps's string-set classifications).
2. **Traversal rules** — how objects relate, how you move between them (pivot-finger shifts; voice-leading preferences).
3. **Modification rules** — transformations on objects (substitution lattices; voicing-density reductions; NCT-harmonization choices).

Plus the master carries **preferences** — ranked queries against their own systems.

A single physical voicing on the fingerboard can be described concurrently by **multiple masters' systems** — Pass calls a shape "C Form, drop-2"; Greene calls the same shape "V-1.3"; Wayne calls it "Position II." The voicing is the invariant; the *naming systems* are per-master.

This dissolves the master × style composition problem: each master's systems are independent rule sets, the engine consults both and intersects their outputs, no precedence rule is needed because there's no shared state to fight over.

**Tracking:** schema details in [#249](https://github.com/siege-analytics/musescore4-chord-library-plugin/issues/249). Pass rebuild as the canonical example in session 260521-aware-nebula plans.

---

## 4. The base case is a codified consensus — named "Berklee"

Every system for talking about chords commits to a **base case** — a theology that defines the canonical objects (what a chord is, what a voicing is, what an interval is). The choice of base case is itself a partisan commitment, not a neutral foundation.

The base case for this project is a **codified consensus** drawn from decades of pedagogical synthesis: Salvador → Leavitt → Berklee curriculum + George Russell's *Lydian Chromatic Concept* + jazzguitar.be + Fisher + ambient teacher consensus. It contains internal contradictions:

- Chord-scale theory and functional harmony are taught with equal verbal emphasis without acknowledging they're different frames.
- Modes are taught both as parallel scales and as derivative-from-major.
- Shell voicings and drop-2 voicings are both presented as "foundational."
- The notation (mixed-case Roman numerals) quietly assumes functional harmony as the frame, even when chord-scale theory is being taught.

**These contradictions are not bugs to fix.** They are how the consensus actually exists in the field. Most contemporary jazz-guitar students and teachers operate within this consensus without acknowledging the contradictions.

### Why the consensus stays as it is — Esperanto vs English

A rationally cleaner system (pure chord-scale theory; pure functional harmony; all-uppercase Roman numerals) would be cleaner *and useless*. **English succeeds because it's what people speak. Esperanto failed because it was designed for cleanliness, optimizing the wrong thing.** A jazz musician who adopts a private Esperanto loses the ability to read a chart, talk to a sideman, or follow standard pedagogy.

The base case lives in the schema as a **pseudo-master** (`kind: "pseudo-master"`, `id: "berklee"`) — distinct from real opinionated individual masters. Salvador, Leavitt, and Russell are eventually their own *real* masters with discrete systems; their commitments are partially upstream of the pseudo-master but they're not equated to it.

**Tracking:** [#251](https://github.com/siege-analytics/musescore4-chord-library-plugin/issues/251).

---

## 5. The engine refuses MTD-jazz fallbacks

**The engine has opinions because the masters had opinions. There is no neutral default.**

When the engine evaluates a candidate under an active master's preferences and the master has no opinion (no descriptor for the queried system, or no rule covers the case):

| Behavior | Status |
|---|---|
| Mark master as silent; don't adjust score for this preference | ✅ Required |
| Apply "general jazz theory" / chord-scale-theory as a fallback | ❌ Forbidden — that's MTD-jazz in disguise |
| Apply "what most jazz arrangements do" as a fallback | ❌ Forbidden — pure MTD-jazz |
| Apply the active style's preference IF explicitly labeled as such | ⚠️ Acceptable with labeling |

The Berklee pseudo-master (the codified consensus) is the lingua franca — OK as a user-facing starting state. **NOT** OK as a silent fallback when an active master is silent. The user opts into the consensus for communication; they do not get the consensus ventriloquized into a master's silences.

**The reconciliation rule:** *the consensus is what you speak; a master is how you choose to speak it differently.* When a master is silent, the consensus does not speak for them.

This is named *Moralistic Therapeutic Deism* (MTD) jazz, after Christian Smith's sociology-of-religion term. MTD-jazz is the contemporary cultural pull toward "all masters are great, no one is wrong, refusing to commit to which approach is better is the polite move." Strong-opinion masters (Wynton Marsalis being the canonical example) get framed as "dicks" for refusing the MTD-jazz consensus. The project rejects this consensus.

**Tracking:** [#250](https://github.com/siege-analytics/musescore4-chord-library-plugin/issues/250).

---

## 6. Composition is three explicit layers

Per section (or per stretch within a section), the user can compose three layers, all explicitly active:

| Layer | Examples | Commitment |
|---|---|---|
| **Base case** (pseudo-master) | `berklee` | Highest — defines the ontology |
| **Style** | `manouche`, `bebop`, `bossa`, `bossa-nova-jobim` | Moderate — idiomatic vocabulary |
| **Master** | `joe-pass`, `ted-greene`, `van-eps` | Per-section, swappable |

Cross-pollination is supported: "Van Eps applied to Manouche on top of Berklee" produces an arrangement that's distinctively *not* Van Eps, *not* Manouche, *not* generic — a hybrid that preserves the edges of all three layers rather than sanding them down into a polite synthesis.

A user wanting a more conservative experience can stay with `master: berklee, style: bebop` and get vanilla bebop. A user wanting something specific picks a master. A user wanting cross-pollination experiments with master × style combinations the masters themselves never tried.

---

## 7. Documentation discipline

Project-defining decisions land in **three places, not one**:

- **Memory** (agent-internal context) — for future agent sessions to inherit the principles
- **Tickets** (GitHub issues) — project-visible record, feeds release notes, lets users see what was decided
- **Docs** (this file, `CLAUDE.md`, `.agents/skills/`) — user-facing explanation that survives outside the GitHub UI

If a decision is load-bearing enough to outlive the conversation that produced it, it goes to all three. Memory alone is invisible. Tickets alone get lost in backlog. Docs alone don't carry the historical "why we decided this" context.

---

## 8. Where this design lives in the codebase

| Concept | File |
|---|---|
| Project framing for AI agents | [`.agents/skills/jazz-system/SKILL.md`](../.agents/skills/jazz-system/SKILL.md) |
| Project conventions (existing) | [`CLAUDE.md`](../CLAUDE.md) |
| Master schema (planned) | `schema/masters.schema.json` (rewrite per #249) |
| Voicing descriptor schema (planned) | `schema/voicings.schema.json` (extend per #249's voicing-descriptor pairing) |
| Base-case content (planned) | `docs/base-case-berklee-content.md` (to be written) |
| Open architecture tickets | #240, #241, #242, #243, #244, #245, #246, #247, #248, #249, #250, #251 |

---

*Last updated: 2026-05-22 (session 260521-aware-nebula). This document is curated as the project evolves; major principles get added or refined as design discussions warrant.*
