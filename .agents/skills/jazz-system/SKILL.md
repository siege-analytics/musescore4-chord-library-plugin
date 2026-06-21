---
name: "Jazz System (project framing)"
description: "Project-identity skill: musescore4-chord-library-plugin is a jazz arrangement system, not a chord bank. Consult before making scope or design decisions on this repo."
---

# Jazz System — project framing

This repository's git name (`musescore4-chord-library-plugin`) and its original CLAUDE.md framing as a "chord voicing management" tool reflect the project's **origin story**, not its current shape. As of 2026-05-22 (session 260521-aware-nebula), the project's actual identity is:

> **A jazz arrangement system that helps a user harmonize songs section-by-section, with composable Master × Style × Tuning × Mode × Context assignments per section or per stretch.**

The chord-voicing layer is a supporting subsystem, not the headline.

## Why this matters for any new work

Scope decisions for this repo should NOT be made against the chord-library framing. If the only reason to defer something is "this is too ambitious for a chord library," that reasoning **does not apply**. Ask instead:

> "Is this a thing a jazz player thinks about when arranging a song?"

If yes, it's in scope — even if implementation is deferred to a later milestone.

## Structural backbone

The system's architecture is anchored in the **Fisher Framework** (a synthesis of five pedagogy books: Fisher's three-volume *Jazz Guitar Method*, jazzguitar.be's *Beginner's Guide to Jazz Guitar*, and jazzguitar.be's *Complete Chord Melody*). The framework is structured as:

**8 phases × 34+ questions**, where the questions are the workflow of arranging a song, and each master provides their distinctive answers.

Source of truth: `plans/framework-fisher-questions.md` (currently in session 260521-aware-nebula plans dir; will be promoted to repo `docs/` once stabilized).

### Phase summary
- **A. Preparation** — tune / key / section structure / texture / right-hand
- **B. Reharmonization** — rewrite the written changes per master appetite (#241)
- **C. Melody recognition** — chord tone vs non-chord tone
- **D. Voicing selection** — family, extensions, shape, density, string set, position, omissions
- **E. Voice leading** — relational rules between successive voicings
- **F. Bass line + rhythm** — texture-dependent
- **G. Substitution / approach** — inserted chords between written ones
- **H. Completion** — playability, form (opening/body/conclusion), ending

A parallel **Phase D' / E' / F' lane** for `accompanied-lead` texture (single-line over rhythm section) was carved out in #248.

## Composability model

Every section (or stretch within a section) carries a tuple:

```
(master, style, tuning, mode, context)
```

- **Master** = the *how* — which Fisher question gets which kind of answer (Pass's how, Greene's how, Van Eps's how)
- **Style** = the *what vocabulary* — which scales / qualities / categories are in the candidate pool (Bebop, Manouche, Bossa, etc.)
- **Tuning** = stringing (standard, Van Eps 7-string, all-fourths, etc.)
- **Mode** = solo / accompanied-lead / ensemble-chord-melody (#240)
- **Context** = section role within the arrangement (intro / head / solo-chorus-N / out-head / tag)

**Cross-pollination is supported**: "Van Eps applied to Manouche" means Van Eps's question-answering machinery with Manouche's candidate pool. Composition semantics (who wins on knob conflicts) is open design — see #244.

## Open architecture tickets (consult before making changes touching these areas)

| # | Title |
|---|---|
| #240 | Section-tuple carries 'context' / 'texture' dimension |
| #241 | Master-driven reharmonization as explicit Step-0 |
| #242 | 'derivation' field on master principles (primary-source vs transcription-inference vs synthesized) |
| #243 | UX: section-aware lead-sheet workspace |
| #244 | Composition semantics for master × style |
| #245 | Separate 'general rules' from 'specific arrangement choices' in extraction |
| #246 | Per-stretch styling within a section |
| #247 | Phase H form (opening/body/conclusion) per master |
| #248 | Accompanied-lead lane (parallel Phase D'/E'/F' for soloing line) |

These are not ranked or scheduled — they are the design surface. New work should reference or update them rather than rediscovering their questions.

## What was true before this reframe (still operative)

- Self-contained plugin in `plugin/`, installable to MuseScore Plugins directory
- Django-style separation: `plugin/model/*.js` business logic, `plugin/ui/*.qml` visual, `plugin/ChordLibrary.qml` router
- Properties-in / signals-out decomposition pattern (#75 Phases A/B/C complete)
- 290 tests passing (`tests/test_js_modules.py` + `tests/test_core.py`)
- `develop` branch is the work branch; `main` is the release branch
- Master bookshelf data: `plugin/data/masters.json` (9 masters, growing under the new framework)
- Pedagogical-source PDFs live at `~/Desktop/parse_these/` — 16 PDFs, all primary sources

## Working rhythm preferences (per Dheeraj 2026-05-22)

- **Think gate is mandatory** — read `~/.craft-agent/workspaces/my-workspace/skills/thinking/think/SKILL.md` before any non-trivial work. The gate has produced the right outcomes here; do not bypass.
- **File tickets eagerly** — every non-trivial observation, design direction, or banked decision gets a GitHub issue. Tickets are mutable; eagerness over precision.
- **Push back honestly** — when a user proposal might be wrong or has a downside they haven't surfaced, name it before going along. Don't only present tradeoffs symmetrically when one direction is clearly better.
- **Pilot before sweep** — when a new methodology is being introduced, validate on one master (Pass is the current control) before sweeping all 11 PDFs.

## Concrete entry points for new sessions

1. Read this skill in full
2. Read `CLAUDE.md` (project-level conventions — but note the chord-library framing is partially outdated; this skill supersedes scope language)
3. Read `plans/framework-fisher-questions.md` in the active session (or the promoted location in `docs/` if it has moved)
4. Read `plans/think-rule-extraction-and-classification.md` and `plans/amendment-scope-discipline.md` for the methodology shift history
5. List open issues filtered to the bookshelf / jazz-system thread (#240-#248 plus newer)
