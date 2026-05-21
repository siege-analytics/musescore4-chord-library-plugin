# Walkthrough performance profile (v2.4)

**Ticket:** #199
**Bench harness:** `tests/perf/walkthrough_bench.js`
**Run:** `node tests/perf/walkthrough_bench.js`

## Scenario

32-bar Au Privave-shaped progression (F major; ii-V dense) on Standard 6-String + Chord Melody + Default style.

```
F7  F7  Cm7 F7  Bb7 Bb7 F7  F7    (A)
Gm7 C7  F7  D7  Gm7 C7  F7  F7    (A)
F7  F7  Cm7 F7  Bb7 Bb7 F7  F7    (A)
Gm7 C7  F7  D7  Gm7 C7  F7  F7    (B->A')
```

## Results

| Scenario | Voicings pool | Median ms | Per-chord ms |
|---|---|---|---|
| **A** — current production (Standard 6, default constraints) | 820 | 10.76 | 0.34 |
| **B** — 10x voicing pool (simulates worst-case non-standard tuning at high `maxPerQuality`) | 8 200 | 20.24 | 0.63 |

Scenario A: well within budget. Users won't perceive any latency for the selection path.

Scenario B: ratio is 1.9x slower despite 10x pool size — the early-rejection filters (`v.root !== "C" && v.root !== targetRoot`, `v.strings > maxStrings`) strip most of the 10x duplicates before the expensive sort step. Sort-time work grows much slower than pool size.

## Callback counts (per 32-chord walkthrough, scenario A)

| Callback | Avg invocations | Per chord |
|---|---|---|
| `topNoteFn` (MelodyEngine.voicingTopNoteSemitone) | 0 | 0 |
| `bassNoteFn` (MelodyEngine.voicingBassNoteSemitone) | 0 | 0 |
| `distanceFn` (MelodyEngine.voicingDistance) | 1 618 | ~51 |
| `difficultyFn` (FingeringEngine.computeDifficulty) | 1 670 | ~52 |

`topNoteFn` / `bassNoteFn` are zero because the bench doesn't pass `melodyMidi` / `bassMidi`. A real walkthrough with melody-lock or bass-lock would invoke them; expected count ≈ 52 per chord (once per candidate).

`difficultyFn` at 52 invocations per chord matches the candidate count post-filter. The memoization from #178 already caches within a single `findBestVoicing` call.

## Conclusion: no fix warranted at current data scales

The user-visible "stall" the v2.2/v2.3 code review flagged was about **generation** — specifically `VoicingCalculator.generateAll` on Baritone B with `maxPerQuality: 0` producing 94 000 voicings. That path is separate from selection.

Selection at all measured scales finishes well under typical UI-responsiveness budgets (50ms is generous). Fixing it further would be premature optimization.

## What this profile did NOT measure

- **`VoicingCalculator.generateAll` runtime** — the generation-side hot path. Should be measured separately if the 94k-voicing stall returns as a real user report.
- **QML rendering overhead** — the bench runs in Node.js, not in MuseScore. The user-visible "this feels slow" experience includes diagram drawing, ComboBox rebuilds, etc., that this harness can't see.
- **Cold-start cost** — first-time tuning switch loads + caches voicings. A separate concern.
- **Melody/bass-lock path** — the `topNoteFn` / `bassNoteFn` branches aren't exercised here.

## Follow-up tickets to file (if/when warranted)

- **perf: VoicingCalculator.generateAll on uncapped non-standard tunings (the actual 94k-voicing stall).** Profile separately; likely needs lazy generation or worker offload.
- **perf: Bench melody-lock and bass-lock paths.** Probably fine; worth measuring.
- **perf: Cold-start tuning load + cache write.** Probably fine; users hit this rarely.

## How to re-run

```
node tests/perf/walkthrough_bench.js                    # default 30 iters
node tests/perf/walkthrough_bench.js --iterations 100   # tighter confidence intervals
node tests/perf/walkthrough_bench.js --json             # machine-readable
```

Use the JSON output to track regressions: a future PR that changes scoring should re-run and compare median to the baseline numbers above (10.76 ms scenario A, 20.24 ms scenario B).
