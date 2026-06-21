---
run_id: 2026-05-28T15-05-20-laukens-jazz-guitar-patterns-vol-1
stage: s4
source_pdf: Laukens, Dirk - Jazz Guitar Patterns, Vol 1.pdf
model: claude-sonnet
extracted_at: 2026-05-31T16:44:49+00:00
schema_version: 0.1
---

# Jazz Guitar Patterns, Vol. 1 (Dirk Laukens) — Statement of Outputs

## Overview

*Jazz Guitar Patterns, Vol. 1* by Dirk Laukens advances a single sustained argument: jazz guitar improvisation is a learnable craft of substitution, and every technique in the book is a specific, reusable rule for swapping one harmonic object for another at a precisely defined entry point. As the book-level distillation summarizes, the pedagogical structure is consistent across all eight Studies — each chapter applies a growing vocabulary to a named standard, so that patterns are never drilled in a void but always tested against real chord changes moving through real harmonic time. Chapters 1 and 2 establish the template without prose commentary; from Chapter 3 onward, the prose unpacks the logic and the remaining studies layer concept upon concept while returning to the same substitution framework each time.

The book's foundational unit is the melodic pattern anchored to a specific chord tone and approached through enclosure, formalized in Chapter 3 as *diatonic enclosure*. From that kernel, the method builds outward: reusable rhythmic-harmonic cells (the 3157 motif, the 1235 Coltrane pattern), complementary approach moves (the Honeysuckle Rose motif, chromatic approach from below), four precisely constructed bebop scale variants, and a comprehensive upper-structure substitution lattice that maps specific arpeggios and triads — each entered from a named scale degree — onto every chord quality the guitarist encounters. The book's deepest structural assumption is that *harmonic color is determined by which shape you borrow and from which scale degree you enter it*, not by running a parent scale from root to octave.

The book's single universal practice prescription, introduced in Chapter 3 and applied implicitly across all eight Studies, is to begin each phrase with the pattern over a backing track and then cycle all fingering positions through the circle of fifths. This ensures the student is always working vocabulary in a musical context and always rotating systematically through all keys rather than habituating a single fingering. The eight Studies themselves are the macro-level application of that protocol — each standard (*Blues for Alice*, *The Days of Wine and Roses*, *There Will Never Be Another You*, *All the Things You Are* (twice), *Solar*, *Autumn Leaves*, *Groovin' High*) is a new harmonic environment that forces the same substitution vocabulary to adapt its entry points, fingerings, and phrase lengths to different ii–V–I configurations, key centers, and formal structures.

---

## Systems

### System 1: Upper-Structure Substitution Lattice

The Substitution Lattice is the book's central organizing system. Rather than deriving melodic lines from root-position chord tones, the method teaches the guitarist to identify which arpeggio or triad — rooted on a specific named interval of the underlying chord — will produce the desired harmonic color, and to play that shape instead. The substitution choice, not the root-position arpeggio, determines the sound. The system maps precisely defined upper-structure objects onto five chord-quality targets, each with its own family of available substitutions.

**Members:**
- **Major 7 chord** — Cmaj7-type targets; substitutions include a minor triad on the 3rd (Em over Cmaj7) and the relative minor arpeggio.
- **Minor 7 chord** — Dm7-type targets; substitutions include Fmaj7 from the b3, a minor triad on the 5th, and an augmented triad on the b3.
- **Dominant 7 chord** — G7-type targets; substitutions include a half-diminished arpeggio from the 3rd, diminished arpeggios from b9/3/5/b7, minor triads on the 5th or b9, and the tritone-substitute arpeggio.
- **Half-diminished chord** — Bm7b5-type targets; substitutions include maj7 from the b5 and m(add9) from the b3.
- **Altered dominant** — G7alt-type targets; substitutions include Gaug7, Bmaj7#5, and Abm/maj7 arpeggios extracted from the altered scale, and m(add9) from the b9.

**Modification Rules:**

*Minor triad on the 3rd of a major chord* — Place a minor triad rooted on the 3rd of any major chord (Em over Cmaj7). `SubstitutionExpand` (Chapter 8 summary)

*Minor triad on the 5th of a minor chord* — Place a minor triad rooted on the 5th of any minor chord (Am over Dm7). `SubstitutionExpand` (Chapter 8 summary)

*Minor triad on the 5th of a dominant chord* — Place a minor triad rooted on the 5th of any dominant chord (Dm over G7); this is the signature Wes Montgomery move. `SubstitutionExpand` (Chapter 8 summary; Chapter 3 summary — "Dm over G7 is a technique Wes Montgomery")

*Minor triad on the b9 of an altered dominant* — Place a minor triad rooted on the b9 (Abm over G7alt) for altered color. `SubstitutionExpand` (Chapter 8 summary)

*Half-diminished arpeggio from the 3rd of a dominant* — Play Bm7b5 over G7 to bring out the 9 sound; the paradigm case of harmonic substitution over a dominant chord in this method. `SubstitutionExpand` (Chapter 3 summary; Chapter 6 summary)

*Diminished arpeggio from b9/3/5/b7 of a dominant* — Play a diminished arpeggio rooted on any of the four points (Abdim7 over G7) for the 7b9 coloration. Because diminished chords are built in stacked minor thirds, all four inversions are fingered identically on the fretboard. `SubstitutionExpand` (Chapter 5 summary; Chapter 6 summary)

*Maj7 arpeggio from b3 of minor7 (relative-major sub)* — Play Fmaj7 over Dm7 by rooting the maj7 on the b3; attributed to Wes Montgomery and described as creating a minor-major color. `SubstitutionExpand` (Chapter 4 summary; Chapter 8 summary — "Wes Montgomery phrase that uses an Fmaj7 arpeggio over Dm7")

*Maj7 arpeggio from b5 of half-diminished* — Play Fmaj7 over Bm7b5 for the #11 tension color. `SubstitutionExpand` (Chapter 3 summary — "maj7 chord over a half-diminished chord, starting on the b5")

*Augmented triad/maj7#5 from b3 of minor* — Play an augmented triad or maj7#5 arpeggio rooted on the b3 of a minor chord (Gaug over Em7) for the minor/major-7 sound. `SubstitutionExpand` (Chapter 4 summary; Chapter 7 summary)

*Augmented arpeggio over altered dominant* — An augmented 7th arpeggio or triad brings out the altered sound on a dominant chord; for tritone-sub #11 dominants, build augmented from the original V7alt root. `SubstitutionExpand` (Chapter 3 summary; Chapter 4 summary — "Db7#11 is a substitution for G7alt, you can use a G augmented triad")

*m(add9) arpeggio from b9 of altered dominant* — Play an m(add9) arpeggio rooted on the b9 of an altered dominant (Fm(add9) over E7#9). `SubstitutionExpand` (Chapter 4 summary)

*m(add9) arpeggio from b3 of half-diminished* — Play an m(add9) arpeggio rooted on the b3 of a half-diminished (Dm(add9) over Bm7b5). `SubstitutionExpand` (Chapter 4 summary)

*Tritone-substitute dominant arpeggio* — Replace a dominant chord with the arpeggio of its tritone substitute (Bb7 arpeggio over E7) to generate the full altered sound through chromatic voice-leading. `SubstitutionExpand` (Chapter 8 summary)

*Harmonic minor / Phrygian dominant over V7 of minor ii-V* — Over the V7 of a minor ii–V–I, play the tonic harmonic minor scale (or equivalently Phrygian dominant from V's root) for the 7b9/b13 color. The book treats these as two names for the same fretboard move. `SubstitutionExpand` (Chapter 3 summary; Chapter 5 summary; Chapter 7 summary)

---

### System 2: Bebop Scale Family with Metric Guarantee

The Bebop Scale Family defines four eight-note scales, each constructed by inserting exactly one chromatic passing tone into a seven-note parent modal scale. The system's load-bearing rule is not about pitch content alone: starting any bebop scale run on a downbeat and on a chord tone produces a *metric guarantee* — all subsequent chord tones in the descending run will fall on downbeats, and all passing tones will fall on upbeats. This makes the bebop scale a precise rhythmic framework for jazz phrasing, not merely a pitch set. The book also specifies the guitar-idiomatic execution mechanism: slides are the correct mechanical solution to fingering the inserted chromatic passing tone in descending lines.

**Members:**
- **Dominant bebop scale** — Mixolydian + natural 7 chromatic passing tone.
- **Major bebop scale** — Major scale + b6 chromatic passing tone.
- **Minor bebop scale** — Dorian + natural 7 chromatic passing tone.
- **Bebop melodic minor scale** — Melodic minor + b6 chromatic passing tone.

**Modification Rules:**

*Bebop scale construction (mode + chromatic passing tone)* — Construct any bebop scale by adding exactly one chromatic passing tone to a seven-note parent mode; each of the four variants has a specific parent mode and a specific added pitch. `_pending:bebop-scale-construction` (Chapter 6 summary; Chapter 7 summary — dominant, minor, major, and melodic minor formulas)

**Traversal Rules:**

*Downbeat-chord-tone entry rule (metric guarantee)* — Enter a bebop scale run on a downbeat AND on a chord tone (1, 3, 5, or b7); all subsequent chord tones then fall on downbeats and all passing tones on upbeats. This is described as the scale's single most powerful rule. `_pending:metric-guarantee-entry` (Chapter 6 summary — "as long as you start the bebop scale on a downbeat and on a chord note"; Chapter 7 summary)

*Slide-based fingering for the chromatic passing tone* — On guitar, descending bebop-scale lines use slides to reposition the fretting hand across the inserted chromatic note rather than fingering each pitch as a discrete stopped note. `_pending:slide-fingering` (Chapter 7 summary — "play the bebop scale on guitar (descending). It involves some slides"; Chapter 8 summary)

---

### System 3: Approach and Enclosure Vocabulary

The Approach and Enclosure Vocabulary is a set of four melodic devices for targeting chord tones and scale degrees. Three are approach mechanisms — diatonic enclosure (two-note surround then resolution), chromatic approach from below (one semitone), and arpeggio-from-below (the Honeysuckle Rose motif, which targets a scale degree by playing a triad ascending into it) — and one is an ornamental technique, Pat Metheny's doubling-notes move, which applies universally to any scale, arpeggio, or pattern. These devices are the book's foundational entry-point vocabulary: the upper-structure substitution lattice and the bebop scales provide *what* to play; the approach vocabulary provides *how to arrive* at the first note. Chapter 3 also houses the system's sole practice prescription: cycle every pattern through the circle of fifths over a backing track.

**Members:**
- **Diatonic enclosure** — Three-note approach: scale-step above the target, scale-step below the target, target.
- **Chromatic approach from below** — Single semitone below the target chord tone; used heavily in gypsy jazz.
- **Arpeggio-from-below (Honeysuckle Rose motif)** — Target a scale degree by playing an ascending triad into it from below.
- **Doubling notes (Metheny)** — Repeat selected notes within a scale, arpeggio, or pattern as an ornament; universally applicable.

**Modification Rules:**

*Diatonic enclosure targets a chord tone* — Apply diatonic enclosure to a chord-tone target — the 9 above, the 7 below, then the 1 — as the foundational bebop entry pattern. `NCTHarmonization` (Chapter 3 summary — "one note above (the 9), then one note below (the 7), and finally your target")

*Chromatic approach below each triad tone* — Approach each note of a target triad from one chromatic semitone below; this is the gypsy-jazz fingering idiom. `NCTHarmonization` (Chapter 4 summary — "Each note of the F triad ... approached from a chromatic note below")

*Arpeggio-from-below targets any scale tone* — Target any scale degree by playing an ascending triad into it from below; generalized from the Honeysuckle Rose motif to any major-scale degree. `NCTHarmonization` (Chapter 5 summary — "the 3rd note of the scale (2) is targeted by a triad from below"; "targeting scale notes with an arpeggio from below")

*Doubling-notes ornament (universal)* — Apply the doubling-notes ornament to any scale, arpeggio, or pattern — a Pat Metheny-derived universal coloration. `_pending:doubling-ornament` (Chapter 3 summary — "doubling notes ... applied to every scale, arpeggio, or pattern")

**Preferences:**

*Practice every pattern through the circle of fifths* — The book's universal practice prescription: drill any pattern through all twelve keys via the circle of fifths to acquire every fingering position, always over a backing track. `_pending:circle-of-fifths-drill` (Chapter 3 summary — "playing it through the circle of fifths"; "Put on a backing track and start improvising")

---

## Pending Work

The following `_pending:<kebab>` engine payload kinds appear in the systems draft. Each signals a rule or preference whose *content* is fully described in the book but whose representation as a formal engine operation has not yet been finalized:

- **`_pending:bebop-scale-construction`** — Signals that the four bebop scale construction formulas (parent mode + specific chromatic passing tone) need a formalized scale-construction operation type rather than being handled as raw pitch-set data. The four formulas are fully specified in the source (Chapters 6 and 7); the engine kind is the open item.

- **`_pending:metric-guarantee-entry`** — Signals that the downbeat-chord-tone entry rule — which enforces the metric guarantee that chord tones land on downbeats — requires a rhythmic-placement operation type not yet defined in the engine. The rule itself is precisely stated in Chapter 6.

- **`_pending:slide-fingering`** — Signals that the guitar-specific slide technique for navigating bebop-scale chromatic passing tones in descending lines needs a guitar-execution operation type. The technique is described in Chapters 7 and 8; the engine kind is the open item.

- **`_pending:doubling-ornament`** — Signals that Pat Metheny's doubling-notes ornament — repeating selected notes within any scale, arpeggio, or pattern — requires an ornament-application operation type. The technique is introduced in Chapter 3 and described as universally applicable.

- **`_pending:circle-of-fifths-drill`** — Signals that the book's universal practice prescription — cycling all fingering positions through the circle of fifths over a backing track — requires a practice-protocol operation type. The prescription is stated in Chapter 3 and implied throughout all eight Studies.

---

## Provenance Notes

**What is drawn from what.** The three systems are derived from the book-level distillation (which aggregates the per-chapter summaries) and the chapter summaries themselves (Chapters 3-8). All modification and traversal rules cite chapter summaries as authority; quote excerpts in the systems-draft JSON are drawn from those summaries' paraphrase of the source PDF.

**Chapters 1 and 2 yielded no systems and no quotable prose.** Both chapters are notation-only worked etudes — Chapter 1 over *Blues for Alice* (pages 8-9) and Chapter 2 over *The Days of Wine and Roses* (pages 10-12). Their chapter summaries confirm explicitly that neither contains load-bearing prose passages. They demonstrate the pedagogical template in practice but introduce no named techniques, substitution rules, or scale definitions that are not subsequently named and explained in Chapters 3-8. Their contribution to the statement is structural and contextual: they establish the etude format that all later Studies follow.

**The altered scale** is not its own system in the draft because the book treats it as a *reservoir of superimposable shapes* rather than a traversable scale system. Its members (Gaug7, Bmaj7#5, Abm/maj7, and the full altered-tone inventory) are absorbed into the Upper-Structure Substitution Lattice under the altered-dominant member. (Chapter 6 summary; book-level distillation, "The Altered Scale and Its Extractions")

**Long-range chromatic voice-leading** (descending from the high E string across phrase spans, demonstrated in Chapter 5) and the **rhythmic-placement / voice-leading target** principle (chromatic descent from the 7 to the 5, stated explicitly in Chapter 8) are documented in the book-level distillation under "Guitar-Specific Execution and Voice-Leading" but do not appear as formal system members in the systems draft. Both are execution principles that operate at the phrase-architecture level; they are candidates for a future Guitar Execution system if the draft is extended.
