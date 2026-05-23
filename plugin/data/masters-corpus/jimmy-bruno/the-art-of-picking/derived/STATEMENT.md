---
run_id: 2026-05-23T22-12-11-bruno-art-of-picking
stage: s4
source_pdf: Jimmy-Bruno-The-Art-Of-Picking.pdf
model: claude-sonnet
extracted_at: 2026-05-23T22:30:48+00:00
schema_version: 0.1
---

---
run_id: 2026-05-23T22-12-11-bruno-art-of-picking
stage: s4
source_pdf: Jimmy-Bruno-The-Art-Of-Picking.pdf
model: claude-sonnet
extracted_at: 2026-05-23T22:30:00+00:00
schema_version: 0.1
---

# The Art of Picking — Statement of Outputs

## Overview

Jimmy Bruno's *The Art of Picking* (2002) is a compact picking-hand method built around a three-rule directional system: down-stroke when crossing to a higher string, up-stroke when crossing to a lower string, and alternate strokes when staying on one string. The justification given in Chapter 1 is economy of motion — the pick is always positioned where it next needs to be — and Bruno frames adoption of the system as a deliberate break from the entrenched strict-alternate-picking habit, warning the student that the new motion will feel awkward before paying off. The mechanical preconditions are treated as equally load-bearing: a relaxed wrist with motion driven from the elbow, and a strict no-anchor right hand whose fingers must not touch the strings, pick guard, or any other part of the guitar (Chapters 1–2).

The book proceeds in a deliberately sequential pedagogical arc that Bruno forbids the student from skipping. Chapter 1 states the rules and the practice conventions (MM 60–120, every exercise drilled starting with both a down-stroke and an up-stroke). Chapter 2 isolates the three stroke types — down-up, up-down, and the difficult in-between stroke — on every string and on adjacent-string double-stops. Chapter 3 adds consecutive same-direction strokes as core jazz vocabulary under a strict no-ringing/muting requirement and a precision-over-speed mandate. Chapters 4–6 generalize the rule to larger textures: the six basic major-scale fingerings (4), arpeggios (5), and string skipping (6). Chapters 7–8 turn the mechanism toward musical material — typical bebop phrases (7) and articulations (8). Chapter 9 explicitly licenses rule-breaking under stylistic and rhythmic conditions, and Chapter 10 closes with the meta-rule that picking is habit-formation, prescribing repetition over analysis.

Three organizing systems carry the method: a Directional Picking system that holds the central rule, its stroke vocabulary, and every sanctioned exception; a Right-Hand Mechanics system that specifies the physical preconditions (elbow-driven motion, no-anchor fingers, relaxed posture); and a Six Essential Major-Scale Fingerings system that supplies the V/H taxonomy (6V2, 5V2, 6V4, 5V4, 6H2, 5H2) anchored to Bruno's companion book *Six Essential Fingerings for the Jazz Guitarist*. The aesthetic axiom that ties them together appears in Chapter 5: music drives picking, not the fretboard — the picking mechanism serves musical intent, and fingerboard convenience must never dictate the line.

## Systems

### Directional Picking

Bruno's central system enumerates the stroke-type vocabulary as members and codifies both the core directional rules and an unusually explicit catalog of sanctioned exceptions. The three core rules — down to higher string, up to lower string, alternate on same string — are applied uniformly across single-string drilling, scales, arpeggios, string skipping, and bebop phrases; the same rule extends without modification to non-adjacent strings. A second-tier principle states that fingerboard position dictates picking pattern: relocating an identical phrase to a different position changes which notes land on which strings, and the pick sequence must be redrawn accordingly. Modification rules cover the triplet drill exception (three consecutive downs then three consecutive ups, confined to drill and not to real phrases), rest-start stroke freedom, big-band consecutive-down accents (with slurs offered as an equivalent), rhythmic-break consecutive downs, the bebop preference for slurred over picked triplets, and a notable master-override in Chapter 6 where Bruno himself prefers strict alternate down-up for the hardest skip+accent+in-between combination. Preferences codify the practice discipline (both starting strokes, precision over speed, articulation over speed in arpeggios, fingering-enables-speed, music-drives-picking, no ringing, MM 60–120, sequential study, repetition over analysis).

Members: Down-up stroke; Up-down stroke; Mixed strokes; In-between stroke; Consecutive down-stroke; Consecutive up-stroke; Same-string sixteenth reversal.

Traversal rules:
- Down-stroke when crossing to a higher string — `_pending:directional-stroke-higher` (Chapter 1 summary; ch01.md "When going to a higher string, use a down-stroke").
- Up-stroke when crossing to a lower string — `_pending:directional-stroke-lower` (Chapter 1 summary; ch01.md "When going to a lower string, use an up-stroke").
- Alternate strokes on the same string — `_pending:same-string-alternation` (Chapter 1 summary; ch01.md "When playing on one string, use alternate strokes").
- Economy of motion governs traversal — `_pending:economy-of-motion` (Chapter 1 summary; ch01.md "one concept or rule that causes the pick to travel the least amount of distance").
- String-skip directional rule — `_pending:string-skip-directional` (Chapter 6 summary; ch06.md "When skipping strings the same rule applies").
- Directional rule applies across all six major-scale fingerings — `_pending:scale-traversal-uniform` (Chapter 4 summary; ch04.md "six basic fingerings for the major scales").
- Arpeggio traversal is the same directional rule — `_pending:arpeggio-directional` (Chapter 5 summary; ch05.md "Higher string = down stroke Lower string = up stroke").
- Fingerboard position dictates picking pattern — `_pending:position-dictates-picking` (Chapter 7 summary; ch07.md "same phrase in the 7th position. This changes the picking considerably").

Modification rules:
- Triplet exception: three down then three up — `_pending:triplet-consecutive-exception` (Chapter 3 summary; ch03.md "three down-strokes followed by three up-strokes").
- Triplet exception confined to drill, not real phrases — `_pending:exception-scoped-to-drill` (Chapter 3 summary; ch03.md "if I had to play a triplet phrase in the context of a line... I would adhere to the rule").
- Phrase after rest may start with either stroke — `_pending:rest-start-stroke-freedom` (Chapter 5 summary; ch05.md "when there is a rest between phrases, it is possible to break the rule").
- Consecutive down-strokes for big-band accent — `_pending:big-band-consecutive-downs` (Chapter 9 summary; ch09.md "consecutive down strokes to emphsis certain notes... big band type phrase").
- Slurs as substitute for consecutive downs — `_pending:slur-substitute-for-consecutive-down` (Chapter 9 summary; ch09.md "same type phrase with slurs").
- Rhythmic break licenses two down-strokes — `_pending:rhythmic-break-consecutive-downs` (Chapter 9 summary; ch09.md "rhythmic break between notes, you may want to use to down strokes").
- Hard skip+accent override to alternate picking — `_pending:master-override-alternate` (Chapter 6 summary; ch06.md "easier to play them with alternating down - up strokes").
- Prefer slurred triplets over picked triplets in bebop — `_pending:slurred-triplet-preference` (Chapter 7 summary; ch07.md "I prefer the 2nd example; it sounds more horn-like").
- Slurring substitutes pick strokes with hammer/pull — `_pending:slur-substitution` (Chapter 8 summary; ch08.md "Pick one note and play two notes").
- Slurs require notes on the same string — `_pending:same-string-slur-constraint` (Chapter 8 summary; ch08.md "moving the slur over any two notes that are on the same string").
- Long-short ending articulation — `_pending:long-short-cadence` (Chapter 8 summary; ch08.md "play these last two notes, long, short").

Preference rules:
- Practice every exercise starting with both strokes — `_pending:bidirectional-practice` (Chapter 1, 5, 6 summaries; ch01.md, ch05.md, ch06.md).
- Precision over speed — `_pending:precision-over-speed` (Chapter 3 summary; ch03.md "precision of the 8th notes is more important than speed").
- Articulation over speed in arpeggios — `_pending:articulation-over-speed` (Chapter 5 summary; ch05.md "Articulatioin is more important han speed").
- Fingering, not picking aggression, enables speed — `_pending:fingering-enables-speed` (Chapter 5 summary; ch05.md "the fingering makes the speed possible").
- Music drives picking, not the fretboard — `_pending:music-drives-picking` (Chapter 5 summary; ch05.md "NOT let the fingerboard make the music").
- Notes must not ring into each other — `_pending:no-ringing-mute-requirement` (Chapters 2 and 3 summaries; ch02.md, ch03.md "Do not let notes ring!").
- Practice tempo MM 60–120 — `_pending:tempo-prescription` (Chapter 1 summary; ch01.md "practice these exercise at MM 60 to 120").
- Sequential study order; no skipping — `_pending:sequential-study-order` (Chapter 1 summary; ch01.md "not a good idea to skip around in this book").
- Repetition over analysis — `_pending:repetition-over-analysis` (Chapter 10 summary; ch10.md "key is repetition. Do not overanalyze your right hand movements").

### Right-Hand Mechanics

The Right-Hand Mechanics system specifies the physical preconditions for the directional picking rule. Motion is generated at the elbow with a still, untilted wrist; the right-hand fingers must not contact the strings, bridge, pick guard, or any other part of the guitar; and the entire right hand, wrist, and elbow must remain relaxed rather than tense. This no-anchor posture is the load-bearing physical complement to economy of motion: a free-floating hand can travel the minimum distance dictated by the directional rule, while an anchored hand cannot. The palm may rest lightly on the strings (for muting), but the fingers may not.

Members: Wrist; Elbow; Right-hand fingers; Palm.

Traversal rules:
- Motion comes from the elbow — `_pending:elbow-driven-motion` (Chapters 1 and 2 summaries; ch01.md "The movement should come from the elbow"; ch02.md "the movement is from the elbow").

Modification rules:
- Right-hand fingers must not touch the guitar — `_pending:no-anchor-fingers` (Chapters 1 and 2 summaries; ch01.md "Do not touch the strings, bridge or any other part of the guitar"; ch02.md "Do not touch the guitar with the fingers of the right hand").
- No pick-guard contact — `_pending:no-pick-guard-contact` (Chapter 2 summary; ch02.md "Do not touch the pick guard or strings").
- Relaxed right hand, wrist, and elbow — `_pending:relaxed-hand` (Chapter 1 summary; ch01.md "always be relaxed and never tense or tight").

### Six Essential Major-Scale Fingerings

Chapter 4 anchors the scale work to Bruno's companion volume *Six Essential Fingerings for the Jazz Guitarist*, supplying the substrate on which the directional rule is applied. The six fingerings are labeled with a V/H taxonomy keyed to the root string: V denotes two-notes-per-string verticals (6V2, 5V2, 6V4, 5V4) and H denotes position-shift horizontals (6H2, 5H2), the numeral indexing the root string. A string-crossing notation — asterisks above the exercise marking moves to higher vs. lower strings — layers onto each fingering so the down-on-higher / up-on-lower rule is visible at every transition. The chapter is essentially a uniform application of the directional rule across all six core shapes rather than new technique; the system's role in the book is to bind the picking method to Bruno's broader scale framework.

Members: 6V2 fingering; 5V2 fingering; 6V4 fingering; 5V4 fingering; 6H2 fingering; 5H2 fingering.

Traversal rules:
- String-crossing notation marks where the directional rule applies — `_pending:string-crossing-notation` (Chapter 4 summary; ch04.md "** = moving to HIGHER STRING", "* = moving to LOWER STRING").

Modification rules:
- Anchored to Six Essential Fingerings system — `_pending:six-fingerings-anchor` (Chapter 4 summary; ch04.md "see my book Six Essential Fingerings for the Jazz Guitarist").

## Pending Work

All engine_payload kinds in the systems-draft are currently `_pending:` markers, signaling that no engine-layer kind for picking-hand motion yet exists in the masters.json schema (which to date has been chord-and-voicing-shaped, e.g. `VoiceMotion`, `FamilyCoherence`, `ColorToneRequire`, `OmissionAllow`). They cluster into seven families that need engine kinds defined before promotion:

- Directional stroke selection by string-crossing direction — `_pending:directional-stroke-higher`, `_pending:directional-stroke-lower`, `_pending:same-string-alternation`, `_pending:string-skip-directional`, `_pending:scale-traversal-uniform`, `_pending:arpeggio-directional`. Together these signal a need for a picking-hand stroke-selection kind keyed to the geometry of the next note (higher / lower / same string), generalizable across textures.
- Motion-economy justification — `_pending:economy-of-motion`. Signals the meta-rule that justifies stroke selection (minimize pick travel), distinct from any single stroke-selection rule.
- Position-dependent re-picking — `_pending:position-dictates-picking`. Signals that the same pitch sequence in different fretboard positions yields different stroke sequences; the kind must consume a fingering and emit a stroke pattern.
- Sanctioned exceptions to alternation — `_pending:triplet-consecutive-exception`, `_pending:exception-scoped-to-drill`, `_pending:rest-start-stroke-freedom`, `_pending:big-band-consecutive-downs`, `_pending:rhythmic-break-consecutive-downs`, `_pending:master-override-alternate`. Signals presence-negative or override constraints on the directional rule, scoped by context (drill vs. real phrase, rhythmic gap, stylistic accent, master experience).
- Slur-as-articulation mechanics — `_pending:slur-substitute-for-consecutive-down`, `_pending:slurred-triplet-preference`, `_pending:slur-substitution`, `_pending:same-string-slur-constraint`, `_pending:long-short-cadence`. Signals an articulation layer that swaps pick strokes for hammer/pull and a same-string geometric constraint on where slurs are legal.
- Right-hand posture preconditions — `_pending:elbow-driven-motion`, `_pending:no-anchor-fingers`, `_pending:no-pick-guard-contact`, `_pending:relaxed-hand`. Signals a physical-precondition kind orthogonal to stroke selection (the system requires these to be true before any stroke rule applies).
- Practice-discipline preferences — `_pending:bidirectional-practice`, `_pending:precision-over-speed`, `_pending:articulation-over-speed`, `_pending:fingering-enables-speed`, `_pending:music-drives-picking`, `_pending:no-ringing-mute-requirement`, `_pending:tempo-prescription`, `_pending:sequential-study-order`, `_pending:repetition-over-analysis`. Signals practice-protocol rules that surround the engine rather than functioning as voicing/stroke-selection rules themselves; these may resolve to a single practice-prescription kind or be folded into system-level prose.
- Fingering substrate anchor — `_pending:six-fingerings-anchor`, `_pending:string-crossing-notation`. Signals cross-work references (to *Six Essential Fingerings for the Jazz Guitarist*) and notation-layer conventions for visualizing where the directional rule applies.

The density of `_pending:` markers reflects that *The Art of Picking* is the corpus's first picking-hand work; the engine kinds developed for chord-construction works (Benson Vol. 1) do not yet cover stroke-direction selection, picking-hand posture, or slur articulation.

## Provenance Notes

All system blocks, rules, and quote excerpts are drawn from the book-level distillation and the ten per-chapter summaries (ch01–ch10.md), with each rule's `references[]` pointing back to a specific chapter and topic in the summaries. The chapter quote files (`chapters/ch01.md` through `chapters/ch10.md`) supply the verbatim excerpts.

No chapter failed to yield a system contribution: Chapters 1–2 ground the Directional Picking and Right-Hand Mechanics systems; Chapter 3 supplies the consecutive-stroke vocabulary, the triplet exception, and the precision-over-speed and no-ringing preferences; Chapter 4 supplies the Six Essential Major-Scale Fingerings system; Chapter 5 supplies the arpeggio-traversal rule, the rest-start exception, and the aesthetic axioms (articulation over speed, fingering enables speed, music drives picking); Chapter 6 supplies the string-skip directional rule and the master-override exception; Chapters 7–8 supply the position-dictates-picking rule, the slurred-triplet preference, and the slur-articulation mechanics; Chapter 9 supplies the big-band and rhythmic-break exceptions and the slur-as-substitute equivalence; Chapter 10 supplies the repetition-over-analysis closing preference.

Two characteristic Bruno moves surface in the systems-draft as load-bearing in their own right: the anti-sweep-picking polemic of Chapter 5 (reframing sweep picking as nothing more than the directional rule applied to arpeggios, captured by the arpeggio-traversal-unified rule) and the master-override moment in Chapter 6 (where Bruno prefers strict alternate down-up over his own framework for the hardest skip+accent+in-between combination, captured by the hard-skip-accent-override rule). The horn-line aesthetic that runs through Chapters 5, 7, and 9 — saxophone-like slurred triplets, horn-section big-band accents, and saxophone/piano arpeggio phrasing as justification — surfaces in the slurred-triplet-bebop-preference and big-band-consecutive-downs modification rules rather than as a standalone system, since it is a stylistic justification consumed by the picking system rather than a separable mechanism.
