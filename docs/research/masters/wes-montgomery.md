# Wes Montgomery — research notes

**Primary source type:** web research (no in-repo corpus; estate-managed
free archive doesn't exist for Wes the way it does for Greene).
**Last research pass:** 2026-05-21 (#226 + revision in this PR).
**Principle entries:** 5 in `masters.json`.

## Research method

WebSearch + WebFetch from the running session. Sites consulted:

| URL | Status | Used for |
|---|---|---|
| <https://en.wikipedia.org/wiki/Wes_Montgomery> | accessible | thumb-attack origin, three-tier arc (attributes to Wolf Marshall), superimposed triads quote |
| <https://www.voicelidjazzguitar.com/jazz-guitar-blog/jazz-guitar-upper-structures-wes-montgomery-drop-2> | accessible | upper-structure triad substitution, drop-2 vehicle |
| <https://www.fundamental-changes.com/wes-montgomery-video-lesson/> | accessible | three-tier arc, thumb "brush the strings" detail, tune list (Satin Doll, Four on Six) |
| <http://jazzbluesabstracttruth.blogspot.com/2013/02/wes-montgomery-jazz-guitar-method.html> | accessible (via search indexing) | octave fingering: first finger lower note + deadens intermediate string; 3rd/4th finger upper octave |
| <https://www.jazzguitar.be/blog/wes-montgomery-jazz-guitar-licks/> | **403 blocked** | indexed in search results; not directly readable |
| <https://www.jazzguitar.be/blog/wes-montgomery-chord-solo/> | **403 blocked** | indexed only |
| Jens Larsen drop-2 series | accessible via search indexing | drop-2 background; not Wes-specific in the extracts we saw |

## Sources per principle

### 1. `three-tier-chorus-development`

> Single notes → octaves → block chords, each tier melodically motivated.

**Wikipedia** attributes this to Wolf Marshall's pedagogy: Wes
"typically would start a solo single notes, then break into octaves
for a chorus or two, and finally finish his solo with a chorus or
two using chordal melodies." Marshall is the canonical citation
for this arc.

**Fundamental Changes** restates it: "He would start off with single
note lines, move onto octaves and finish with chords... to create
solos with a bit of variation."

**Recorded exemplar:** Fundamental Changes recommends "Four On Six"
from *Smokin' at the Half Note* (1965).

### 2. `octave-passage-construction`

> First finger on lower note + dampens intermediate string;
> 3rd or 4th finger on upper octave; string pairs 6&4, 5&3, 4&2, 3&1.

**Jazz Blues Abstract Truth blog** documents Jesse Gress's
description of the fingering mechanism (first finger lower / damp
middle / upper-fingers octave above). The same blog mentions:

- Gress's advice: focus on one note of the octave; let the other
  shadow naturally
- Wes practiced octaves on standards including "Sunny" and
  "Tear It Down" (from his Hal Leonard method book)

**Wikipedia** also notes Wes developed octaves partly to keep
volume down when practicing late at night (avoid waking his kids).
That biographical motivation isn't encoded in the principle — it's
context.

### 3. `block-chord-drop-2-predominance`

> Drop-2 voicings as the primary block-chord vehicle.

**Voicelid Jazz Guitar** documents drop-2 as "the vehicle for these
ideas." Indexed search hit on jazzguitar.be (blocked from direct
fetch) reinforces: Wes "stuck with chords played mainly on adjacent
strings and drop 2 chord shapes."

**Recorded exemplar:** *The Incredible Jazz Guitar of Wes Montgomery*
(1960) — "D-Natural Blues" block-chord chorus.

### 4. `thumb-attack-articulation`

> Thumb-only right hand; downstroke for singles; brush/rake for chords.

**Wikipedia** documents the origin: Wes adopted thumb-only technique
after marriage when he had to practice quietly (didn't want to wake
neighbors / wife). The technique stuck.

**Fundamental Changes** describes the mechanics: "use the underside
of his thumb, and he'd brush the strings."

**Adrian Ingram's biographical study (Centerstream, 2008)** is the
canonical book reference but we don't have it on disk — citation is
secondary.

### 5. `upper-structure-triad-substitution`

> DbMaj7 over Bbm7-Eb7 as a unified "Db major field."

**Voicelid Jazz Guitar** documents the strategy with the specific
example:

> "Over a Bbm7 chord: Stacking the 9th (C) while omitting the root
> creates a DbMaj7 sound, which could then be repositioned over the
> following Eb7."
>
> "Db becomes the b7. F becomes the 9. Ab becomes the 11 (sus4).
> C becomes the 13."

And:

> "He would 'substitute a Gm7b5 shape over an Eb7' to outline
> extensions without the root note present."

**Wikipedia** complements with the general claim: Wes used
"superimposed triads and arpeggios as the main source for his
soloing ideas."

## What was REMOVED from the previous Wes entry

The earlier entry shipped a principle `blues-vocabulary-in-jazz-context`
("altered-dominant voicings at blues-line destinations"). After
research, this couldn't be sourced specifically — Wes's blues
phrasing is documented in general, but the specific encoded claim
about altered-dominant voicings at blues-line destinations was an
inference I made, not a documented principle. Removed.

Replaced with `upper-structure-triad-substitution`, which IS
well-sourced.

The earlier `block-chord-to-octave-parallelism` principle was also
trimmed: my claim about "top voice continuity from the preceding
octave passage" was an inference. The revised version focuses on
the documented drop-2 predominance.

## Followups

- **Direct citation from Ingram's *Wes Montgomery*** (Centerstream
  biographical study) for thumb mechanics.
- **Unblock or replace jazzguitar.be sources** — the 403s blocked
  detail extraction; we cited via search-result indexing only.
- **Recording-based annotation pass** for specific transcribed
  block-chord choruses (D-Natural Blues, Four on Six).

## Bibliography

- *Wes Montgomery* — Wikipedia.
  <https://en.wikipedia.org/wiki/Wes_Montgomery>
- *Wes Montgomery's Drop-2 + Upper Structures* — Voicelid Jazz Guitar.
  <https://www.voicelidjazzguitar.com/jazz-guitar-blog/jazz-guitar-upper-structures-wes-montgomery-drop-2>
- *Play Guitar Like Wes Montgomery* — Fundamental Changes.
  <https://www.fundamental-changes.com/wes-montgomery-video-lesson/>
- *Wes Montgomery Jazz Guitar Method: Octaves* — Jazz Blues Abstract
  Truth (Gress excerpt).
  <http://jazzbluesabstracttruth.blogspot.com/2013/02/wes-montgomery-jazz-guitar-method.html>
- Ingram, Adrian. *Wes Montgomery*. Centerstream Publications, 2008.
- Marshall, Wolf. Various pedagogical writings on Wes Montgomery
  (cited via Wikipedia).
- Montgomery, Wes. *Wes Montgomery Guitar Folio*. Hal Leonard
  (posthumous transcriptions).
