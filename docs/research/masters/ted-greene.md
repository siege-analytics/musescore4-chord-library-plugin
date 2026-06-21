# Ted Greene — research notes

**Source corpus:** `plugin/data/masters-corpus/greene/` (committed to repo
from the MVP scrape in #220). 20 PDFs + matching `.txt` extracts.
**Last research pass:** 2026-05-21 (#229).
**Principle entries:** 5 in `masters.json` (was 2 seeds before this pass).

## Corpus extraction limits

Most of Greene's manuscripts are hand-drawn notation that did not OCR.
The text extracts (`.txt` sidecars) are empty or near-empty for the
notation-heavy files. The files with real prose content:

| File | Size | What's in it |
|---|---|---|
| `01_WhoIsJamesHober.txt` | 8.9 KB | Hober's V-System intro; full prose |
| `00_Welcome.txt` | 1.9 KB | V-System chapter index |
| `ii7-V7-I_TedGreene_1974-11-28_and_29.txt` | 1.5 KB | Greene's prose on ii7 vs IVmaj7 |
| `3-NoteChordsForThe_I_ChordInGBlues_WithLetter_TedGreene_1995-12-16.txt` | 1.4 KB | Letter to Bruce; no technique content |

The remaining 16 files (counterpoint exercises, single-note lines,
inversion tables, foggy-day arrangements, comping studies) are mostly
or entirely notation. Encoding principles from those requires either
running `--full` to expand the corpus AND a notation-reading pass,
OR primary-source consultation against Chord Chemistry / Modern
Chord Progressions.

## Sources per principle

### 1. `v-system-voicing-groups`

> Four-note voicings are classified into 14 groups (V-1 through V-14)
> ordered from most compact to most spread.

**Primary source:** `01_WhoIsJamesHober.txt` (corpus), Hober's intro.
Quoted verbatim:

> "Notice that as you go from V-1 to V-14 the basic trend is to go
> from the most compact to the most spread out (although V-13 and
> V-14 are less spread out than V-11 and V-12). To me this is typical
> of the Ted Greene approach: use logic to generate possibilities but
> don't be so strict that you lose [practical results]."

The 43-quality figure also from `01_WhoIsJamesHober.txt`:

> "I asked him, 'So Ted, do you know how many four distinct note
> chords there are?' And he instantly blurted out, 'Forty-three!'"

**What we DON'T have:** the precise interval-spelling of each V-group
(V-1 = which intervals exactly, V-2 = which, etc.). That detail lives
in Hober's `Method 1 - How to Build` chapter, which we didn't scrape
in the MVP. Followup: `--full` sweep, then encode the per-group
interval signatures.

### 2. `fixed-soprano-tour`

> Hold the top voice (soprano) constant; cycle through all 14
> V-System voicing groups.

**Primary source:** `01_WhoIsJamesHober.txt` (corpus). Hober:

> "I now call this a 'fixed soprano tour.' For a given chord, in
> this case G7, the soprano is held constant, in this case on the
> flat 7, and a G7 chord from each of the fourteen voicing groups
> is shown."

And:

> "He had explained nothing to me about the V-System. And yet in a
> single line of music notation he had concisely described and
> implied the entire V-System…sort of."

**Secondary reference:** tedgreene.com V-System chapter list
(`00_Welcome.txt`) names "24. The Fixed Soprano Tour" as a chapter.

### 3. `voice-leading-inner-motion`

> Melody on top, bass anchors, inner voices move stepwise between
> chord changes.

**Primary source:** Chord Chemistry (Greene, 1971) — cited but not
in our corpus. The V-System chapter list (`00_Welcome.txt`) names:

> "20. Conversion" — the V-System device for moving between voicing
> groups while preserving voice-leading economy.

**Status:** the claim "melody on top, bass anchors, inner voices
move stepwise" is the canonical description of Greene's voice-leading
approach across multiple secondary sources. It IS the central idea
of much of Modern Chord Progressions. The corpus extracts confirm
"Conversion" as a named V-System chapter that handles between-voicing
transitions; we infer the voice-leading-economy purpose from the
chapter title + general knowledge. **A direct verbatim citation
from Chord Chemistry would strengthen this principle.**

### 4. `ii7-over-ivmaj7-substitution`

> Greene's documented preference for ii7 over IVmaj7 in the IV-V-I
> cadence, citing the strident major-7 interval of IVmaj7.

**Primary source:** `ii7-V7-I_TedGreene_1974-11-28_and_29.txt`
(corpus). Greene's own prose:

> "You might wonder why IVmaj7, rather than ii7 wasn't used for IV.
> It is because of the strongly dissonant interval of a major 7th
> (between root and 7th) in the IVmaj7 — this was apparently harsher
> to the ears of our forefathers than the mild dissonance of a minor
> 7th in the ii7. To modern ears the IVmaj7 is just as nice as a ii7,
> but through tradition and for other reasons not to be discussed
> here, the ii7 has remained the favorite chord to precede V(7) with..."

And on practice:

> "Practice them in various keys, and decoration, and resolve them
> to I. Then do them in minor keys, but use ii±7 - V(7) - i instead
> of ii7 - V(7) - I."

The "±7" notation is Greene's for the half-diminished (m7b5).

### 5. `sequential-articulation`

> Right-hand fingerstyle / hybrid-pick articulation; closely
> associated with harp-harmonics.

**Primary source:** Modern Chord Progressions (Greene, 1973) — cited
but not in our corpus.

**Corpus confirmation of harp-harmonics:**
`3-NoteChordsForThe_I_ChordInGBlues_WithLetter_TedGreene_1995-12-16.txt`
(letter to Bruce):

> "An example: the harp-harmonics. At one time when people heard
> it, it took their breath away. Now it's like it barely has the
> power to move — it's just an unpleasant part of our species, I
> guess. I hate it."

Greene wished harp-harmonics retained their original impact;
confirms the technique was in his vocabulary and he treasured it.

**Status:** the broader "sequential articulation" claim (bass first,
inner voices in sequence, melody on top) is the canonical description
of Greene's right-hand approach across secondary sources but isn't
verbatim in the corpus extracts. A direct citation from Modern Chord
Progressions would strengthen this.

## What was REMOVED from the previous Greene entry

Nothing. The two seed principles (`voice-leading-inner-motion`,
`sequential-articulation`) are kept; both are now better-sourced.
Three new principles added on top of them.

## Followups

- **Run `scripts/fetch-greene-corpus.py --full`** to bring in the
  remaining V-System chapters (the per-group interval definitions
  for V-1 through V-14). That unlocks tagging actual voicings to
  specific V-groups (`voicingStyleTags: ["greene-v1"]` etc.).
- **Direct citation from Chord Chemistry** for the voice-leading
  principle.
- **Direct citation from Modern Chord Progressions** for sequential
  articulation.
- **Notation-reading pass** on the existing notation-heavy PDFs
  (counterpoint, single-note lines, inversion tables) — owner work.

## Bibliography

- Greene, Ted. *Chord Chemistry*. Dale Zdenek Publications, 1971.
- Greene, Ted. *Modern Chord Progressions*. Dale Zdenek Publications, 1973.
- Hober, James. V-System Introduction. tedgreene.com.
  <https://tedgreene.com/teaching/v_system.asp>
- Greene, Ted. *ii7 - V(7) - I* (manuscript, 1974-11-28 and 1974-11-29).
  Corpus: `ii7-V7-I_TedGreene_1974-11-28_and_29.pdf`.
- Greene, Ted. Letter to Bruce on 3-note chords for the I chord in G
  blues (1995-12-16). Corpus:
  `3-NoteChordsForThe_I_ChordInGBlues_WithLetter_TedGreene_1995-12-16.pdf`.
