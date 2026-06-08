# Voicing data dictionary

A guide for the #395 voicing-tag review. Defines the **voicing categories**, **master tags**, and **principle tags** you'll see on the form. Generated from `plugin/data/voicings.json` + `plugin/data/masters.json` + the #389 proposer output — keep in sync via `scripts/voicing-tags/build-data-dictionary.py`.

## A. Voicing categories

Each voicing has one `category` — its broad shape family.

### `drop2` — Drop-2

**What it is:** A 4-note voicing built by taking a close-position chord and dropping the second-highest note an octave.

**What it sounds like:** The bread-and-butter chord-melody and comping shape — clean, balanced, easy to voice-lead. Most jazz chord-solo arrangements live here.

**Example:** The Cm7 shape you'd play across strings 6–3 or 5–2 with the b7 on top — the same shapes Joe Pass plays through Autumn Leaves.

### `drop3` — Drop-3

**What it is:** Like drop-2, but the THIRD-highest voice is dropped an octave — producing a wider, more open spread across the strings.

**What it sounds like:** Bigger sound, more piano-like. Common when you want a bass note to ring under a chord-melody phrase.

**Example:** The Cm7 voicing with root on the 6th string, skipping the 5th string, and the rest of the chord on strings 4–2.

### `shell` — Shell voicing

**What it is:** A skeleton voicing — usually just the root, third, and seventh (R-3-7) — with no fifth or extensions.

**What it sounds like:** Minimal, dry, leaves space. Common in bebop comping and as a starting point that you 'dress' with extensions and tensions.

**Example:** Peter Bernstein's go-to comping shape: R-3-7 on strings 6, 4, 3 or 5, 3, 2 — under a melody on the top strings.

### `quartal` — Quartal voicing

**What it is:** A voicing built by stacking perfect-fourths rather than thirds.

**What it sounds like:** Open, ambiguous, modern. Doesn't commit to a single tonality — perfect for modal contexts and McCoy Tyner / Jim Hall sounds.

**Example:** Three fourths stacked on the middle strings — works equally well as Dm7, G7sus, or Cmaj9 depending on the bass.

### `extended` — Extended voicing

**What it is:** A voicing that includes upper-structure extensions: 9th, 11th, 13th.

**What it sounds like:** Rich, modern, harmonically saturated. Sounds 'jazzy' on a Cmaj7 vamp; sounds 'wrong' on a country progression.

**Example:** Cmaj9 with the 9 on top instead of the root — turns a static chord into a color.

### `altered` — Altered voicing

**What it is:** A dominant-7 voicing with one or more altered tensions: b5, #5, b9, #9, #11, b13.

**What it sounds like:** Tense, leaning hard toward resolution. The Tristano / Coltrane language.

**Example:** G7#9 with the #9 on top, used as the V chord into Cm in a minor ii-V-i.

## B. Master tags

Master tags (`joe-pass`, `van-eps`, `dirk-laukens`, …) mean "voicings in this master's tradition." One line per master, drawn from each master's primary principle in `masters.json`.

- **`alan-de-mause`** — The book's operative procedure throughout: convert a lead sheet (single-note melody + chord symbols) into a complete solo fingerstyle guitar arrangement.
- **`barry-galbraith`** — Galbraith's *Jazz Solo Guitar* anthology teaches by demonstration rather than by prose.
- **`benson`** — (no summary in masters.json)
- **`brent-vaartstra`** — Vaartstra's procedural method for learning any standard.
- **`dirk-laukens`** — Laukens organizes his entire pedagogy — across the beginner method, the chord dictionary, the pattern volume, and the lick anthology — around moveable physical shapes.
- **`gene-bertoncini`** — Bertoncini's *Arrangements for Solo Guitar* teaches by demonstration.
- **`greg-orourke`** — O'Rourke's central operating system. Step 1: pick a suitable tune (ballad-not-bebop selection rule — slower tempos with longer-held melody notes are practically easier).
- **`heussenstamm-silbergleit`** — The book's foundational organizing claim: the ii-V-I progression is not just one progression among many but the IRREDUCIBLE harmonic cell from which all jazz vocabulary — harmonic, melodic, rhythmic, textural — radiates.
- **`jamey-aebersold`** — Aebersold's foundational innovation: a recorded rhythm section supplies tempo, harmony, and feel while the student practices scales, chord-tones, patterns, and improvisation over the same progressions.
- **`jens-larsen`** — The improviser does not arpeggiate the root chord; instead they select the substitute arpeggio whose notes maximally overlap the underlying chord's guide tones (3rd and 7th) and color tones (9, 11, 13, altered extensions).
- **`jerry-bergonzi`** — A fixed group of consecutive notes (2-7 eighth notes, or their triplet/16th equivalents) is shifted systematically across all eight metrical entry points in a 4/4 bar.
- **`jerry-coker`** — Coker's foundational thesis (Elements Ch1): the great jazz improvisors share roughly 18 common 'devices' that account for nearly all the language they speak.
- **`jim-hall`** — Hall's comping foundation: 3rd and 7th of the chord on the middle strings, often as two-note voicings or grace-noted into fuller shapes.
- **`jimmy-bruno`** — Bruno's central system. Three rules govern every pick stroke: down-stroke when crossing to a higher string, up-stroke when crossing to a lower string, alternate strokes when staying on one string.
- **`jody-fisher`** — Fisher categorizes voicings systematically for teaching: drop-2 (drop the second-from-top from a close-position stack), drop-3 (drop the third-from-top), abbreviated voicings, extended-harmony voicings (9ths/11ths/13ths), altered-chord for…
- **`joe-pass`** — Bass walks on every beat (chord tones, passing notes between chord tones, chord-extension notes, tritone approaches to the root); chord 'stabs' land on off-beats with 2-3 note voicings rather than full block chords.
- **`johnny-smith`** — Closely-voiced chord-melody — all four voices within an octave, often within a 4-fret span. Produces a unified vertical sound rather than a wide-spread texture.
- **`lenny-breau`** — Bass, chord, and melody played simultaneously via fingerstyle, with right-hand finger independence treating each voice on its own timeline.
- **`martin-taylor`** — The right-hand thumb alternates between the 6th and 5th strings (or 6th/4th depending on chord) to maintain continuous bass support without interrupting melodic flow.
- **`matt-warnock`** — Warnock's *Beginner's Guide* organizes its complete curriculum — chord vocabulary, comping rhythms, picking technique, chromatic harmony, scale shapes, ornaments, and mixed solo texture — around ONE harmonic vehicle: the Dm7-G7-Cmaj7 ii V…
- **`mickey-baker`** — Baker prunes the guitar's chord universe to 26 essential shapes (Chapter 1), later extended to 30 (Chapter 5), and references every voicing by number rather than by Roman-numeral function.
- **`nelson-faria`** — Faria's load-bearing technical architecture across all five Brazilian styles.
- **`pat-martino`** — The single governing principle of Linear Expressions. Improvisation is not free melodic invention; the chord encountered selects the line form played. Every melodic decision in the system is downstream of harmonic identification.
- **`peter-bernstein`** — Bernstein's load-bearing conceptual frame: improvisation is language use, not scale deployment.
- **`randy-felts`** — Felts's foundational organizing move: every chord is assigned to one of three functional families — tonic (I, III, VI), subdominant (II, IV, V7sus4), or dominant (V7, VII-7b5) — and every substitution operates within or between these famil…
- **`ted-dunbar`** — The founding axiom of Dunbar's method, named explicitly in Chapter 1. Every pitch in the chromatic scale exerts a cadential pull toward any active tonal center.
- **`ted-greene`** — Four-note voicings are classified into 14 groups (V-1 through V-14) ordered from most compact to most spread: V-1 is the closest cluster, V-14 the widest, with V-13/V-14 less spread than V-11/V-12.
- **`van-eps`** — Every chord-quality category in Van Eps's method begins by harmonizing the corresponding scale in triads. Major chords (Ex. 1-25) start with the harmonized major scale in triads; minor chords (Ex.
- **`wes-montgomery`** — A solo arcs through three distinct textural tiers: single-note lines (statement), parallel octaves (intensification), block-chord harmonization (climax).

## C. Principle tags

Principle tags describe a specific way of organizing voicings. Pulled from the source principle's `summary` field in `masters.json` — only tags the #389 proposer actually emits are listed.

### `chord-function-driven` (from `dirk-laukens/function-assigned-vocabulary`)

Across Laukens's catalog every melodic-vocabulary unit (scale, arpeggio, pattern, lick) is assigned to a chord function rather than to a chord-name-in-a-key.

### `dirk-laukens` (from `dirk-laukens/moveable-shape-as-organizing-principle`)

Laukens organizes his entire pedagogy — across the beginner method, the chord dictionary, the pattern volume, and the lick anthology — around moveable physical shapes.

### `drop-3` (from `joe-pass/drop-2-and-drop-3-chord-melody`)

Pass's typical chord-melody technique harmonizes the melody with drop-2 and drop-3 voicings. Drop-2 keeps melody on top of a 4-note voicing on adjacent strings; drop-3 spreads the voicing wider with a 'skip' in the middle.

### `function-assigned` (from `dirk-laukens/function-assigned-vocabulary`)

Across Laukens's catalog every melodic-vocabulary unit (scale, arpeggio, pattern, lick) is assigned to a chord function rather than to a chord-name-in-a-key.

### `quartal` (from `jim-hall/fourth-stacks-and-open-voicings`)

Hall's signature 'fourths' sound: voicings built from stacked perfect fourths rather than triadic thirds — beautiful and harmonically ambiguous, doesn't commit to a single tonality. Often complemented with bass notes for grounding and counter-melodies on top.

### `shell` (from `peter-bernstein/dressing-the-notes-comping-aesthetic`)

The melody-first hierarchy applied to accompaniment: comping's job is to give each melody note the right outfit so it feels important.

### `substitution-derivation` (from `dirk-laukens/substitution-as-derivable-not-memorized`)

Laukens treats substitutions as derivable from a small set of named relations rather than as a memorized catalog.

### `van-eps` (from `van-eps/harmonized-scale-foundation`)

Every chord-quality category in Van Eps's method begins by harmonizing the corresponding scale in triads. Major chords (Ex. 1-25) start with the harmonized major scale in triads; minor chords (Ex. 26-32) with the harmonized minor; 7th chords (Ex.

## D. Confidence levels

Each row on the form shows an `agent_confidence` of `HIGH`, `MED`, or `NONE`.

- **`HIGH`** — The voicing's existing tags directly named a master tag, so the automated tagger is reasonably sure the attribution is right.
- **`MED`** — The tag was derived: from a 'coverage' marker on the voicing, from a master-id alias in the voicing's tags, or from a category rule (e.g. category=quartal → quartal + jim-hall). The tagger thinks this fits but it's less certain.
- **`NONE`** — The tagger couldn't attribute this voicing to any master with confidence and left the voicingStyle blank. These are exactly the rows your judgment helps most.

