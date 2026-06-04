# Voicing-tag review — what we're asking you to do

Thanks for helping. This is a small group of friends voting on guitar-voicing tags. Your judgment here directly improves the plugin's master-style recommender.

## What you're looking at

Each row is one **chord voicing** — a specific way to play a chord on the guitar. For example: a Caug7 drop-2 voicing fingered at the 5th fret with the b7 on top. The plugin's engine knows 820 of these.

Each row also has a set of **tags** that say two things about the voicing:

- **voicingStyle tags** — which master guitarist's vocabulary this voicing belongs to. Examples: `joe-pass`, `van-eps`, `dirk-laukens`, `jim-hall`, `peter-bernstein`, `ted-greene`, `chord-function-driven`, `quartal`, `shell`.
- **playStyle tags** — how the voicing is used in a tune. Examples: `block`, `chord-melody`, `walking-bass`, `altered-dominant`, `drop-2`, `drop-3`.

A first-pass automated tagger guessed these tags by reading each voicing's existing metadata (category, shape, chord quality) and matching against each master's declared style vocabulary. The guesses are educated, but the tagger has no ear and no taste. **That's where you come in.**

## How to read each row

The leftmost columns describe the voicing. The agent's columns show what the tagger proposed and why:

| Column | What it means |
|---|---|
| `agent_proposed_voicingStyle` | Tags the tagger thinks belong on this voicing |
| `agent_proposed_playStyle` | How the tagger thinks this voicing is played |
| `agent_confidence` | `HIGH` = the voicing's existing tags directly named a master tag; `MED` = derived from a coverage marker, master alias, or category rule; `NONE` = the tagger left it blank |
| `agent_reasoning` | One-line summary of why the tagger picked these tags |

Then there are columns for **each voter** (you):

| Column | What to put in it |
|---|---|
| `voter{N}_verdict` | `YES`, `NO`, or `REFINE` (blank = you skipped this row) |
| `voter{N}_override_reason` | Required if your verdict is not `YES`. Why are you disagreeing with the tagger? |
| `voter{N}_additions` | Tags you would add, comma-separated. Use names from the proposed columns above so they stay consistent across voicings. |
| `voter{N}_notes` | Any free-text comment |

## What we're asking — the three questions per row

For each row you choose to review:

1. **`verdict`** — does the agent's tag set belong on this voicing?
   - `YES` — yes, these are the right master(s) / play-style. Move on.
   - `NO` — these tags do not belong; the voicing is something else.
   - `REFINE` — some are right, some are wrong, or some are missing. Use `additions` to add what's missing.

2. **`override_reason`** — if your verdict is `NO` or `REFINE`, **briefly say why**. Examples:
   - "Caug7 doesn't fit Joe Pass's chord-melody vocabulary; this is more of a Bernstein dressing."
   - "Drop-3 m7 voicing on the lower strings — should also be tagged van-eps, not just pass."
   - "The shell here is sus2; Bernstein's R-3-7 shell principle doesn't apply."

   The override-reason column is important: it tells future-us (and the project owner) *why* the human disagreed with the tagger. Don't skip it on disagreements.

3. **`additions`** — tags you would add (comma-separated). Use the same kebab-case style you see in the proposed columns (`van-eps`, not `Van Eps`). If you don't know the exact name, write a free-form phrase in `notes` and the project owner will canonicalize it.

## What you do NOT have to do

- **You don't have to review all 820.** Skip rows you're unsure about. Quality of judgment beats coverage.
- **You don't have to review categories you don't play.** If quartal voicings aren't your thing, skip them.
- **You don't have to agree with the other voters.** This is a vote, not a consensus session.

## Why this matters

Today, selecting a master in the plugin's Library tab does nothing — there's no voicing-to-master link in the data. Once enough voicings carry approved tags, picking "Joe Pass" will visibly bias the voicing recommender toward Pass-shaped voicings; picking "Van Eps" toward triadic moving-voice voicings; "Bernstein" toward shell + dressing-the-notes; and so on. Your verdicts are the bridge between the master-side principles (already encoded) and the voicing-side library (currently untagged).

## Links (for the curious)

- Heuristic tagger source: **PR #390** (merged) — `scripts/voicing-tags/propose.py`
- Master-side vocabulary updates: **PR #392 (#391)** (merged)
- This crowdsource sheet: **#393**
- Engine path that consumes the approved tags: **#222 / #223**
- Umbrella ticket: **#222**

## Questions

If you hit a row where you genuinely can't decide — the chord is something you've never seen, the master attribution feels arbitrary, the confidence is `NONE` and you don't know what's right — **skip it**. We'd rather have a sparse, high-quality vote than a complete, low-confidence one.

Reach out if anything is confusing. You're helping shape what the plugin recommends to thousands of guitarists later.
