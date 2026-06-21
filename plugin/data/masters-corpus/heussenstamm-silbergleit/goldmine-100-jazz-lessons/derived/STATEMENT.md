---
run_id: 2026-05-28T15-05-20-heussenstamm-goldmine-100-jazz-lessons
stage: s4
source_pdf: Heussenstamm & Silbergleit - Goldmine 100 Jazz Lessons.pdf
model: claude-sonnet
extracted_at: 2026-06-02T04:19:14+00:00
schema_version: 0.1
---

# Goldmine 100 Jazz Lessons — Statement of Outputs

## Overview

*Goldmine 100 Jazz Lessons* by George Heussenstamm and Roni Silbergleit is a comprehensive jazz guitar method organized around a single governing premise: all jazz vocabulary—harmonic, melodic, rhythmic, and textural—radiates outward from one irreducible harmonic cell, the ii-V-I progression. The book builds a complete jazz language from the ground up, progressing through a deliberate one-way pedagogical gate: chord tones before scales, the cell before its substitutes, scale awareness before recognition of its limits. Even its earliest lessons are already pointing toward their own obsolescence—chord-tone-only improvisation is introduced as a stepping stone, not a destination; scales are introduced as liberation tools that become boxes if mistaken for complete systems.

The method's central harmonic teaching unfolds in layers. Chapter 2 fixes the chord-quality definitions and the voice-leading rule (the 7th of each chord resolves to the 3rd of the next) that underlies all subsequent motion. Chapter 3 introduces tritone substitution as the first structural escape from the cell—replacing the V7 with a chord rooted a tritone away, justified by the shared tones at the b5 pivot, producing chromatic rather than circle-of-fifths root motion. Chapters 6 and 11 deepen this with scale-degree equivalences (7sus4 equals minor-seventh-on-the-5th; super Locrian equals melodic minor a half-step above the altered dominant root) and a systematic taxonomy of the four tension tones (#5, b5, b9, #9) that mark the natural/altered boundary. By Chapter 10 the synthesis is explicit: pentatonic scales are hidden inside diatonic scales, chord shapes are melodic skeletons disguising scale patterns, and fretboard geometry, harmonic function, and rhythmic inflection are three descriptions of the same underlying jazz logic.

Rhythm and texture receive equal systematic treatment alongside harmony and melody. The book's first technical prescription—chord anticipation, placing voicings one eighth-note early—establishes that jazz rhythm is not a byproduct of note choice but a parallel technical language. Comping density (sparse guide tones through full voicings to complete silence) is named explicitly as the primary dynamic lever in musical conversation. Three named swing-feel techniques, a precise definition of ballad feel (even 8ths and triplets, arpeggiated attacks), and a stylistic boundary rule against blues bending in jazz contexts together confirm that the method treats feel as something to be learned with the same rigor as scales and voicings.

---

## Systems

### ii-V-I Harmonic Cell and Substitution System

The central system of the book treats the ii-V-I progression as an irreducible harmonic cell from which all jazz vocabulary radiates. The cell is not merely a chord sequence but a voice-leading organism: each chord's 7th resolves to the next chord's 3rd, and that motion is the engine of jazz harmonic gravity. The system extends through tritone substitution (replacing V7 with a chord rooted a tritone away, sharing shell tones in inverted form), whole ii-V tritone pairs, the natural-to-altered dominant shift device (Mixolydian to super Locrian immediately before resolution), and the minor-blues convention (bVI natural dominant leading to V altered dominant). The pedagogical architecture is a one-way gate: master the cell before its substitutes; master chord tones before scales.

**Members:**
- `ii — Minor Seventh` — minor-seventh quality; Dorian scale; half-diminished in minor contexts
- `V — Natural Dominant Seventh` — unaltered dominant; Mixolydian or Lydian dominant scale
- `V — Altered Dominant Seventh` — dominant with one or more of #5, b5, b9, #9; super Locrian
- `I — Major Seventh` — tonic resolution chord; major or Lydian scale
- `i — Minor Seventh (minor tonic)` — minor tonic in minor ii-V-i; Dorian scale
- `Tritone Substitute Dominant Seventh` — dominant rooted a tritone from original V7; 3rd and 7th shared in inverted form
- `V7sus4 — Suspended Dominant` — natural 4th replacing the 3rd; equivalent to minor seventh on the 5th; unresolved in jazz usage

**Traversal Rules:**

- **7th-to-3rd Guide-Tone Voice Leading** — `VoiceMotion` (direction: 7th\_resolves\_to\_3rd, applies\_to: ii-min7, v-dom7-natural, v-dom7-altered, i-maj7)
  The 7th of each chord leads directly (or via passing tone) to the 3rd of the next chord across the ii-V-I motion. (Chapter 2 summary: "tendency for the 7th of a chord to lead to the 3rd of the next one," p. 9; Chapter 3 summary: "fundamental move between Am7b5 and D7b9—the 7th of the first chord leading to the 3rd of the next," p. 22)

- **Natural-to-Altered Dominant Shift** — `VoiceMotion` (from: v-dom7-natural, to: v-dom7-altered, trigger: pre-resolution)
  A dominant seventh moves from natural (Mixolydian) to altered (super Locrian) immediately before V-I resolution to create urgency. (Chapter 4 summary: "dominant seven chord to change from natural to altered before it resolves in a V-I direction," p. 32; "first played from a corresponding Mixolydian scale and then switched to the super Locrian," p. 33)

- **Tritone Substitution — Chromatic Root Motion** — `SubstitutionExpand` (from: v-dom7-natural, to: tritone-sub-dom7, shared\_tones: 3rd + 7th, bass\_motion: chromatic)
  Replacing V7 with its tritone substitute converts circle-of-fifths root motion into chromatic (half-step) root motion to the I chord. (Chapter 3 summary: "replacement of a chord with another one of the same kind rooted a tritone away," p. 17; "chromatic root movement to get where we're going," p. 17)

- **ii-V-I Cell Replication via Tonicization** — `FamilyCoherence` (mechanism: tonicization, applies\_to: any\_non-tonic\_chord)
  Any chord in a progression may act as a temporary I, generating a local ii-V-I cell that redirects scale and chord-tone choices to the tonicized key. (Chapter 2 summary: "ii-V-I in F within the tune," p. 9)

- **Minor ii-V-i: Strong Preference for Altered Dominant** — `VoiceMotion` (preference: altered\_dominant, context: minor\_ii-V-i)
  In minor ii-V-i contexts the V chord is strongly expected to be altered rather than natural. (Chapter 4 summary: "for a minor ii-V-i, the tendency is strong for that V chord to be an altered dominant," p. 31)

**Modification Rules:**

- **Tritone Substitute Shares Inverted Shell Voicing** — `SubstitutionExpand` (shell\_inversion: true, interval: tritone)
  A dominant seventh and its tritone substitute share the same two-note shell (3rd + 7th), with those tones swapped in register. (Chapter 5 summary: "tritone substitutes of one another, and this is one place where they 'meet'," p. 49; Chapter 3 summary: "simple 7b5 chord is the place where a dominant chord and its tritone substitute meet," p. 17)

- **7sus4 = Minor Seventh on the 5th** — `SubstitutionExpand` (equivalence: sus4\_equals\_min7\_on\_5th)
  The 7sus4 chord is equivalent to a minor seventh chord built on the dominant's 5th; Dm7 voicings and melodic ideas substitute over G7sus4. (Chapter 6 summary: "7sus4 chord is very much like a minor seven chord built on its 5th," p. 66; "D minor seven ideas can typically fit hand-in-glove with G7sus4," p. 69)

- **Four Tension Tones Define Altered Dominant Boundary** — `ColorToneRequire` (tension\_tones: #5, b5, b9, #9, applies\_to: v-dom7-altered)
  Alterations to a dominant seventh are bounded to exactly four tension tones; adding any of these converts natural to altered status. (Chapter 11 summary: "four tension tones—b5, #5, b9, #9—and that's it," p. 145)

- **Jazz 101 — Same-Family Chord Substitution** — `SubstitutionExpand` (constraint: same\_family, families: major, minor, dominant)
  Any chord may be exchanged for another from the same family (major, minor, or dominant) to create embellishment without changing harmonic function. (Chapter 13 summary: "exchange, replace, or substitute any chord with another chord from the same family," p. 201; "three types of chords, or three chord families: major, minor, and dominant," p. 186)

- **bVI Natural Dominant → V Altered Dominant in Minor Blues** — `VoiceMotion` (from: bVI-natural-dom7, to: v-dom7-altered, context: minor\_blues)
  In minor blues, the bVI chord is a natural dominant and the V chord that follows is altered; the pair creates directed tension toward the minor tonic. (Chapter 3 summary: "normal pattern of a natural dominant for the bVI chord leading to an altered dominant for the V," p. 21)

---

### Scale-over-Chord Selection and Reduction System

This system governs which scale a player deploys over any given chord type. The dominant seventh chord is named explicitly as the "central battleground for scale choice in jazz," because the introduction of the b7th opens a spectrum of options—from the default Mixolydian through Lydian dominant, bebop dominant, diminished, and the altered super Locrian. The system's governing principle is strategic reduction: rather than switching scale per chord, the player groups chords by key region and applies one scale across the region, handling brief non-diatonic chords by either ignoring them or targeting their chord tones. The system carries its own explicit ceiling: scales are starting points that liberate initially but trap the player in boxes if mistaken for complete note-choice systems.

**Members:**
- `Dorian` — minor seventh / ii chord scale; natural minor with raised 6th
- `Mixolydian` — natural dominant scale; major with flat 7th
- `Lydian Dominant` — Mixolydian with raised 4th; accommodates #11, avoids natural-4th clash
- `Super Locrian / Altered Scale` — seventh mode of melodic minor; all four tension tones; enharmonically melodic minor a half-step above root
- `Diminished Scale (Half-Step / Whole-Step)` — octatonic; three-fret equivalence covers four keys per fingering
- `Bebop Dominant Scale` — Mixolydian plus natural major 7th passing tone; eight-note scale; Charlie Parker's tool
- `Harmonic Minor` — natural minor with raised 7th; applicable over diminished chords within it
- `Melodic Minor (Jazz)` — major with flat 3rd; parent of super Locrian, Lydian dominant, and multiple chord types
- `Minor Pentatonic / Pentatonic Mixing` — five-note subset; four pentatonics hidden within one major scale
- `Whole Tone Scale` — only two mutually exclusive scales cover the entire chromatic system; generates #5 dominant sounds
- `Locrian` — half-diminished / iim7b5 scale; minor ii-V-i contexts

**Traversal Rules:**

- **Group Chords by Key — Single-Scale Region Reduction** — `PositionContinuity` (mechanism: key\_region\_grouping)
  Analyze a tune to group chords into key regions; apply one scale across the entire region rather than switching scale per chord. (Chapter 10 summary: "we only need to apply one scale to groups of chords that are related to one key," p. 124)

- **Non-Diatonic Chord Two-Part Rule** — `NCTHarmonization` (options: ignore\_brief | emphasize\_chord\_tones)
  For briefly appearing non-diatonic chords, either ignore them and continue the key-region scale, or emphasize their chord tones as added color. (Chapter 10 summary: "outside-the-key chords come and go quickly, you can choose to not pay attention to them," p. 125)

- **Diminished Scale Three-Fret Equivalence** — `SymmetryMovement` (interval\_frets: 3, keys\_covered: 4)
  One diminished scale fingering pattern repeats every three frets and covers four keys simultaneously. (Chapter 11 summary: "same exact patterns and fingerings occur three frets above and below," p. 152)

- **Four Pentatonics Hidden Within One Major Scale** — `FamilyCoherence` (derived\_members: pentatonic-minor, count: 4)
  A single diatonic major scale contains up to four minor pentatonic scales usable simultaneously over related chords. (Chapter 10 summary: "C diatonic major scale contains three minor pentatonic scales within it," p. 126)

- **Super Locrian / Ab Melodic Minor Enharmonic Identity** — `SymmetryMovement` (equivalence: super\_locrian\_equals\_melodic\_minor\_up\_half\_step)
  G super Locrian and Ab melodic minor contain the same notes; practitioners use "melodic minor built a half step above the altered dominant root" as the practical mnemonic. (Chapter 11 summary: "Ab melodic minor scale contains the same notes as the G super Locrian scale," p. 160; Chapter 6 summary: "scalar common ground between these chords, as they are, is basically the Bb melodic minor scale," p. 62)

**Modification Rules:**

- **Lydian Dominant: Avoid Natural 4th Against Dominant 3rd** — `OmissionAllow` (omit\_tone: natural\_4th, replacement: raised\_4th, applies\_to: v-dom7-natural)
  Over natural dominant seventh chords, the natural 4th risks clashing with the chordal 3rd; Lydian dominant (raised 4th) eliminates this clash and adds #11. (Chapter 6 summary: "avoiding the natural 4th or chordal 11th, which could clash with the 3rd," p. 55; Chapter 8 summary: "avoids the potential clash of the natural 4th sustained against the chord," p. 93)

- **Scale-as-Method Ceiling: Scales Liberate Then Trap** — `DensityCeiling` (ceiling\_description: no single scale exhausts note choice over any chord or progression)
  Scales are a starting point for note choice, not a complete method; treating any single scale as a total how-to creates a box of limitations. (Chapter 8 summary: "scales do not tell the whole story when it comes to improvising—not even about note choice," p. 92)

- **Bebop Dominant and Diminished Scales: Mastery + Restraint** — `DensityCeiling` (ceiling\_description: resist\_overuse; specialty application only)
  Both scales must be mastered but resist overuse; they are high-demand specialty tools, not default choices. (Chapter 10 summary: "Don't overuse this scale, but you should definitely master it," p. 143; "natural or major 7th as well as the b7th and was a favorite of Charlie Parker," p. 142)

- **Chord-Tone-Only Improvisation as Developmental Floor** — `DensityFloor` (floor\_description: chord\_tones\_only; root\_3rd\_5th\_7th\_9th, pedagogical\_stage: prerequisite)
  Chord-tone-only lines (arpeggios through the 9th) form the minimum required competence before scale-based improvisation; they are a stepping stone, not an end goal. (Chapter 2 summary: "It is not an improvisational end-goal in itself," p. 15; "map out these chordal members on the fretboard and start to hear the chord changes," p. 14)

---

### Voicing Density and Comping Texture System

This system governs how chord voicings are constructed, selected, and texturally deployed in comping contexts. Its defining insight—stated explicitly in Chapter 8—is that comping density is the primary dynamic lever in musical conversation. The system ranges from complete silence (laying out) through sparse guide-tone pairs, rootless two-string shell voicings, quartal stacks, and rootless extended voicings, up to full closed positions. Every voicing type is learned in two forms (root on sixth string, root on fifth string) so that the next chord in any progression is always nearby. The system also encodes the physical grammar of the guitar: quartal voicings exploit the instrument's native perfect-4th string tuning; shell voicings exploit middle-string compactness when a bassist holds the root; Freddie Green straight-4 voicings are so minimal they are "felt more than heard."

**Members:**
- `Full Closed Voicing` — complete chord, root on sixth or fifth string; basis for movable-shape transposition
- `Shell Voicing — Rootless (3rd + 7th)` — two-string middle-string voicing; root omitted; designed for use alongside a bassist
- `Quartal Voicing` — stacked perfect 4ths; exploits native string tuning; enables outside patterns; requires finger-rolling
- `Rootless Extended Voicing` — familiar shape with low-string root omitted; increases mobility; bass covers root in ensemble
- `Sparse Guide-Tone Comping` — only 3rds and 7ths voiced; minimal density; maximum space for soloist
- `Laying Out` — complete silence; intentional texture choice in musical conversation
- `Straight-4 / Freddie Green Voicing` — quarter-note pulse, small root-3rd-7th shapes, precise release timing, low dynamic placement

**Traversal Rules:**

- **Dual Root-String Organizing Rule** — `PositionContinuity` (root\_strings: 6, 5; goal: minimize\_fretboard\_shift)
  Every chord is learned in two voicings—root on sixth string and root on fifth string—so the next chord in a progression is always nearby without large position shifts. (Chapter 13 summary: "you can always have the next chord coming up in a progression close by," p. 183)

- **Comping Density as Primary Dynamic Lever** — `TextureCycle` (levels: laying-out → guide-tone-sparse → shell-voicing-rootless → quartal-voicing → rootless-extended-voicing → full-closed-voicing)
  Move through voicing density levels as the primary means of shaping intensity through a tune. (Chapter 8 summary: "vary the density, and with it the intensity, of our comping to fit different musical situations," p. 94; "if we want to allow the texture to be on the thin side, we could go as far as to lay out entirely," p. 94)

- **Movable Shape Transposition Across 12 Keys** — `PositionContinuity` (mechanism: fret\_shift\_transposition)
  Any non-open-string voicing is moved fret by fret to transpose to other keys, exactly as barre chords are shifted. (Chapter 13 summary: "all chord shapes are movable when you're not using open-string voicings," p. 183)

**Modification Rules:**

- **Formula-Based Chord Modification Within and Across Families** — `SubstitutionExpand` (base\_formula: 1-3-5-b7; operations: raise\_5th, lower\_5th, raise\_9th, lower\_9th, flatten\_3rd, raise\_7th)
  Starting from the dominant seventh formula (1-3-5-b7), raise or lower the 5th or 9th to alter; flatten the 3rd to shift to minor; raise the 7th to shift to major. (Chapter 13 summary: "If we study the A7 chord and its formula, we can change it and create other chords," p. 184; "raise or lower the 5th or the 9th note by a half step," p. 188)

- **Shell Voicing: Root Omission for Compactness** — `OmissionAllow` (omit\_tone: root, result: shell-voicing-rootless, condition: bassist\_present)
  Full chord voicings are reduced to 3rd + 7th by removing the root, producing compact two-string middle-string shapes suitable for use over a walking bass. (Chapter 5 summary: "leaving off the root, to boot … very compact, easy-to-play, and flexible little two-string voicings," p. 48)

- **Chord Melody: Melody Always on Top** — `ColorToneRequire` (required\_position: highest\_voice, applies\_to: chord-melody)
  In chord-melody playing the melody note must always be the highest-pitched note in the voicing. (Chapter 13 summary: "always have the melody of the tune or song on top of the chords as the highest sounding pitch," p. 196)

- **Straight-4 (Freddie Green) Voicing Density Constraints** — `DensityCeiling` (max\_notes: 3, release\_timing: swung\_quarter\_gap, dynamic: felt\_more\_than\_heard)
  Straight-4 comping requires minimal voicing size (root-3rd-7th or smaller), precise short release between quarter notes, and volume kept low. (Chapter 5 summary: "moderate or minimal in size, and some small root-3rd-and-7th kind of chord shapes," p. 46; "'Felt more than heard' is the classic description of its role in the swing-era big band," p. 47)

- **Partial Voicings and Rootless Extended Chords** — `OmissionAllow` (omit\_tone: root, also\_allows: omit\_any\_non\_guide\_tone)
  Not all chord tones need be present; rootless voicings are encouraged in ensemble contexts where the bass covers the root. (Chapter 13 summary: "You don't always have to have the root or all the notes of the chord present," p. 184; Chapter 8 summary: "leaving them off is often a good way to vary the texture," p. 90)

---

## Provenance Notes

All three systems are drawn directly from the book-level distillation (aggregated across Chapters 1–13) and the thirteen per-chapter summaries produced at stage s3. Specific traversal and modification rules are backed by verbatim quote excerpts from the referenced chapter files (ch01.md through ch13.md) as recorded in the systems-draft JSON.

**Chapters contributing primarily to identified systems:**
- **Chapter 1** (Comping Fundamentals and Turnarounds): upbeat emphasis and chord anticipation doctrine contributed to the Voicing/Comping Texture system; turnaround and altered scale vocabulary contributed to the ii-V-I Harmonic Cell system.
- **Chapters 2, 3, 4, 6, 11, 13**: primary sources for both the ii-V-I Harmonic Cell system and the Scale-over-Chord Selection system.
- **Chapters 5, 8, 13**: primary sources for the Voicing Density and Comping Texture system.
- **Chapters 7, 9, 10, 12**: these chapters contain important melodic and technical material—hemiola, sequential practice patterns, string-group arpeggio systems, neighbor notes, enclosure targeting, interval jumping, one-string permutation drills, and pentatonic mixing—that informs the Scale-over-Chord system (particularly Chapter 10's pentatonic-within-diatonic rule and strategic key-reduction method) but did not independently yield a fourth system in this draft. Their melodic construction techniques (Constant Phrase Shape, Changing Rhythmic Shape, Pattern 1 and 2, the Lick, enclosure) represent a melodic construction domain that could be formalized as a separate system in a subsequent revision but is not yet modeled here.

No chapters were left without contribution; every chapter supplied at least one rule or member cited in one of the three systems above.
