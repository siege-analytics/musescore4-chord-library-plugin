---
run_id: 2026-05-28T15-05-20-fisher-jazz-guitar-method-vol-3
stage: s4
source_pdf: Fisher, Jody - Jazz Guitar Method, Vol 3 (Mastering Chord Melody).pdf
model: claude-sonnet
extracted_at: 2026-05-29T06:17:58+00:00
schema_version: 0.1
---

# Jazz Guitar Method, Vol. 3: Mastering Chord Melody — Statement of Outputs

## Overview

*Jazz Guitar Method, Vol. 3: Mastering Chord Melody* by Jody Fisher is a guitar pedagogy work that systematically teaches the art of fingerstyle chord-melody arrangement. Beginning with right-hand technique (Chapter 1) and progressing through harmonic arrangement, voice-leading, bass-line composition, and voicing exploration (Chapters 2–6), the book constructs a coherent method for making a single guitarist sound like an ensemble. Its core subject is not repertoire but **method**: how to analyze, voice, enrich, and arrange any melody with harmonic backing in real time.

The book's organizing philosophy is **flexibility over specialization**. This principle is established on the very first pages (Chapter 1: "best to learn every technique instead of relying on just one or two") and recurs throughout: Chapter 2 urges learning voicings in multiple keys and treating arrangements as skeletal frameworks rather than fixed compositions; Chapter 5 systematizes voicing and bass-line approaches across all twelve keys to enable real-time improvisation; Chapter 6 emphasizes discovering new possibilities within known shapes through octave transposition and symmetrical movement. The book is not a catalog of tricks to master but a scaffold for developing a personal, responsive approach.

The book's terminal move, stated explicitly in Chapter 6, reframes all preceding instruction: **"how you use what you know, rather than how much you know, that counts."** While mastery of voicings and techniques brings flexibility, artistic voice and expressive musicianship are the ultimate measure. This frames the book's entire preceding technical program—technique, harmony, voice-leading, arrangement—as tools in service of a musical personality, not ends in themselves.

---

## Systems

### System 1: Right-Hand Technique System

This system governs the three primary right-hand techniques available to the chord-melody guitarist: pure fingerstyle, hybrid pick-with-fingers, and single-note alternating patterns. In fingerstyle, the thumb (p) controls the sixth and fifth strings while fingers (i, m, a, c) each govern one string, enabling selective chord voicing and simultaneous multi-voice harmony impossible with a pick alone. The hybrid technique holds a pick between thumb and index finger while remaining fingers manage higher strings, offering easy switching between techniques but limiting harmonic density to four-note chords. For melodic single-note playing, jazz guitarists typically alternate either i-m or p-m. The overarching rule is that **all three techniques must be mastered**—not one or two—so the player is prepared for any musical situation.

**Members:**
- Fingerstyle Technique
- Hybrid Pick-with-Fingers Technique
- Single-Note Alternating Patterns

**Traversal Rules:**
- **Master All Techniques for Flexibility** — Develop proficiency in all techniques rather than specializing. Engine payload kind: `_pending:technique-cycling`. *(Chapter 1 summary; p. 8)*

**Modification Rules:**
- **Fingerstyle Selective Voicing Control** — Pluck only the desired tones, avoiding muting and barring. Engine payload kind: `OmissionAllow`. *(Chapter 1 summary; p. 7)*
- **Fingerstyle Simultaneous Voice Sounding** — Fingerstyle uniquely enables all chord notes to sound simultaneously like a keyboard. Engine payload kind: `_pending:simultaneous-voicing`. *(Chapter 1 summary; p. 7)*
- **Hybrid Technique Four-Note Voicing Limit** — Hybrid pick-with-fingers limits harmonic density to four-note chords maximum. Engine payload kind: `DensityCeiling`. *(Chapter 1 summary; p. 7)*

*(Backed by Chapter 1 summary, pages 7–8.)*

---

### System 2: Harmonic Arrangement and Voice-Leading System

This is the book's core methodological system, covering chord-melody arrangement from first principles. It begins with melody study (single notes in all octaves), proceeds through key selection for fingerboard playability, chord voicing with melody on top, and layered harmonic enrichment through passing chords, substitutions, and alterations. The anchor principle is that **the 3rd and 7th degrees define chord quality** and must be treated as the load-bearing tones of any voicing or voice-leading decision. Smooth, stepwise motion between voices is the governing aesthetic; enrichment is always guided by context and taste rather than applied mechanically.

**Members:**
- Melody in Single Notes
- Chord Families
- Voicing Positions
- Non-Chord Tones
- Voice-Leading Anchor Tones (3rds and 7ths)

**Traversal Rules:**
- **Melody-Driven Voicing Selection** — Find chord voicings that place melody notes on top. Engine payload kind: `_pending:melody-on-top`. *(Chapter 2 summary; p. 9)*
- **Melody Study Across All Octaves** — Learn melody in single notes across every octave before harmonization. Engine payload kind: `PositionContinuity`. *(Chapter 2 summary; p. 11)*
- **Key Selection for Playability and Character** — Explore different keys to improve fingerboard playability and exploit open strings. Engine payload kind: `_pending:key-selection`. *(Chapter 2 summary; p. 11)*
- **Stepwise Voice Motion** — Arrange voicings so voices travel in whole and half steps between changes. Engine payload kind: `VoiceMotion`. *(Chapter 3 summary; p. 21)*
- **Passing Chord Smooth Transition** — Insert passing chords between two primary chords to smooth voice-leading. Engine payload kind: `VoiceMotion`. *(Chapter 3 summary; p. 23)*
- **Secondary Dominants as V7-I Generalization** — Treat any chord as a temporary tonic and precede with its V7. Engine payload kind: `FamilyCoherence`. *(Chapter 4 summary; p. 39)*
- **ii-V7-I Progression for Key Definition** — Use ii-V7-I to define a key via characteristic root, 3rd, and 7th motion. Engine payload kind: `FamilyCoherence`. *(Chapter 4 summary; p. 40)*

**Modification Rules:**
- **Octave Adjustment for Harmonic Expansion** — Raise the melody an octave to enable larger voicings. Engine payload kind: `_pending:octave-adjustment`. *(Chapter 2 summary; p. 9)*
- **Chord Enhancement Through Extension and Alteration** — Add extensions or alterations while maintaining family identity. Engine payload kind: `DensityFloor`. *(Chapter 2 summary; p. 12)*
- **Chord Family Interchangeability** — Within a chord family, members are functionally interchangeable. Engine payload kind: `FamilyCoherence`. *(Chapter 2 summary; p. 12)*
- **Context and Taste as Enhancement Guide** — Musical context and taste determine when and how much to enhance. Engine payload kind: `_pending:aesthetic-judgment`. *(Chapter 2 summary; p. 12)*
- **Diads for Two-Note Harmonization** — Harmonize both chord and non-chord tones with diads (3rds and 6ths). Engine payload kind: `_pending:diad-harmonization`. *(Chapter 3 summary; p. 18)*
- **Non-Chord Tone Integration as Chord Extension** — Add melody-derived non-chord tones to the chord as extensions or alterations. Engine payload kind: `NCTHarmonization`. *(Chapter 3 summary; p. 19)*
- **3rd and 7th as Voice-Leading Anchors** — Prioritize preservation of 3rds and 7ths; they define chord quality. Engine payload kind: `VoiceMotion`. *(Chapter 3 summary; p. 22)*
- **Half-Step Dominant Passing Chords** — Use a dominant chord a half step above or below to smooth transitions. Engine payload kind: `SubstitutionExpand`. *(Chapter 3 summary; p. 23)*
- **Diminished Chord as V7 Substitute** — Substitute a diminished chord a half step below the target for V7. Engine payload kind: `SubstitutionExpand`. *(Chapter 3 summary; p. 30)*
- **Quartal Harmony Construction** — Build chords by stacking 4ths to create alternative harmonic color. Engine payload kind: `_pending:quartal-stacking`. *(Chapter 3 summary; p. 33)*
- **Octave Doubling for Melodic Emphasis** — Double melody in octaves for stronger emphasis (as used by Wes Montgomery and George Benson). Engine payload kind: `DensityFloor`. *(Chapter 3 summary; p. 36)*
- **Backcycling as ii-V7-I Extension** — Extend ii-V7-I by repeating fourth-movement through the cycle. Engine payload kind: `FamilyCoherence`. *(Chapter 4 summary; p. 44)*
- **Tritone Substitution for Dominant Chords** — Replace V7 with a dominant chord whose root is a tritone (diminished 5th) away. Engine payload kind: `SubstitutionExpand`. *(Chapter 4 summary; p. 45)*

*(Backed by Chapter 2 summary, pages 9–17; Chapter 3 summary, pages 18–37; Chapter 4 summary, pages 38–47.)*

---

### System 3: Bass Line and Two-Instrument Arrangement System

This system addresses the specific challenge of making one guitarist sound like two instruments—a walking bassist and a chord-playing guitarist performing together. Voicings are learned systematically in all twelve keys using the minimum number of fretting fingers, freeing the left hand for melodic flexibility. The thumb handles all bass notes while the index and middle fingers voice the triad above. Scale tones and half-step approach notes connect chord voicings into a convincing walking bass; overlapping sustain of triad notes and rhythmic separation (bass on the downbeat, chord fractionally after) create the acoustic illusion of ensemble depth.

**Members:**
- Bass Note Anchor
- Triad Voicing
- Scale-Tone Connection
- Half-Step Approach Note

**Traversal Rules:**
- **Learn Voicings Systematically in All Twelve Keys** — Master voicings in all twelve keys before applying bass-line approaches. Engine payload kind: `PositionContinuity`. *(Chapter 5 summary; p. 50)*
- **Bass Line Connection via Scale Tones** — Use chord-scale tones to connect triad voicings. Engine payload kind: `VoiceMotion`. *(Chapter 5 summary; p. 51)*
- **Half-Step Chord Approaches** — Approach chords from a half step above or below the lowest triad voice. Engine payload kind: `VoiceMotion`. *(Chapter 5 summary; p. 53)*

**Modification Rules:**
- **Minimal-Finger Voicing for Melody Freedom** — Use as few fingers as possible (often two) to free fingers for melody and improvisation. Engine payload kind: `OmissionAllow`. *(Chapter 5 summary; p. 50)*
- **Right-Hand Thumb-Index-Middle Finger Assignment** — Thumb plays bass; index and middle voice the triad. Engine payload kind: `_pending:right-hand-role-split`. *(Chapter 5 summary; p. 51)*
- **Tritone Substitution by Root Distance** — Approach any chord via a substitute chord whose root is a tritone from the destination root. Engine payload kind: `SubstitutionExpand`. *(Chapter 5 summary; p. 48)*
- **Bass Every Beat with Chords as Accents** — Bass on every beat as anchor; chords as punches/accents with realistic dynamic balance. Engine payload kind: `TextureCycle`. *(Chapter 5 summary; p. 51)*
- **Rhythmic Separation via Bass-Chord Delay** — Bass on downbeat, chord slightly after, within the same beat. Engine payload kind: `TextureCycle`. *(Chapter 5 summary; p. 54)*
- **Sustaining Overlapping Triad Notes** — Let two notes of the triad ring while hitting the next bass note for harmonic continuity. Engine payload kind: `VoiceMotion`. *(Chapter 5 summary; p. 55)*

*(Backed by Chapter 5 summary, pages 48–57.)*

---

### System 4: Voicing Symmetry and Octave Transposition System

This system teaches how to expand the voicing palette without learning entirely new shapes, by moving familiar chord forms through octaves and applying symmetrical transposition. The key insight is that **certain shapes retain their harmonic function under consistent intervallic movement**: specifically, dominant voicings containing 9ths and altered 5ths remain functional dominant chords when transposed by whole steps. This frees the player from rote memorization and directs attention toward what familiar shapes can become when repositioned. The system also encompasses ensemble techniques (trading fours) and the method of reharmonization via bass-line composition, where composing a new bass line drives the harmonic choices across an entire section. The governing ethical principle of this system—and of the book as a whole—is that **artistic voice and expressive musicianship matter more than the accumulation of theoretical knowledge**.

**Members:**
- Voicing Octave Position
- Symmetrical Transposition Interval
- Reharmonization Bass Line

**Traversal Rules:**
- **Octave Exploration of Familiar Shapes** — Discover new voicings by moving voices of known shapes to higher or lower octaves. Engine payload kind: `SymmetryMovement`. *(Chapter 6 summary; p. 60)*
- **Symmetrical Transposition with Function Retention** — Move chord shapes by symmetrical intervals while retaining harmonic function. Engine payload kind: `SymmetryMovement`. *(Chapter 6 summary; p. 60)*
- **Whole-Step Transposition for Dominant Alterations** — Dominant voicings with 9ths and altered 5ths transpose by whole steps while retaining function. Engine payload kind: `SymmetryMovement`. *(Chapter 6 summary; p. 60)*
- **Reharmonization via Bass Line Composition** — Compose a new bass line across a section to drive and guide harmonic choices. Engine payload kind: `_pending:bassline-led-reharm`. *(Chapter 6 summary; p. 62)*

**Modification Rules:**
- **Artistic Voice Over Theoretical Accumulation** — Prioritize artistic voice and expressive usage over the accumulation of voicings; how you use what you know counts more than how much you know. Engine payload kind: `_pending:expressive-priority`. *(Chapter 6 summary; p. 63)*

*(Backed by Chapter 6 summary, pages 58–63.)*

---

## Pending Work

The following `_pending:<kebab>` engine payload kinds appear in the systems-draft and represent engine behaviors not yet formally specified. Each signals a concept identified in the source text that requires a concrete engine rule definition before the system can be fully operationalized:

| Kind | System | What It Signals |
|---|---|---|
| `_pending:technique-cycling` | Right-Hand Technique | A rule governing how and when the player cycles between fingerstyle, hybrid, and alternating techniques depending on musical context. |
| `_pending:simultaneous-voicing` | Right-Hand Technique | A rule capturing the fingerstyle-specific capability to sound all chord voices simultaneously (as opposed to arpeggiated or selective). |
| `_pending:melody-on-top` | Harmonic Arrangement & Voice-Leading | A constraint enforcing that the melody note must be the highest voice in any chord voicing selected for chord-melody arrangement. |
| `_pending:key-selection` | Harmonic Arrangement & Voice-Leading | A rule for evaluating and selecting a key based on fingerboard playability, open-string availability, and melodic character. |
| `_pending:octave-adjustment` | Harmonic Arrangement & Voice-Leading | A transformation rule for raising (or lowering) the melody by one octave when the target voicing shape requires it. |
| `_pending:aesthetic-judgment` | Harmonic Arrangement & Voice-Leading | A meta-rule encoding the principle that musical context and taste govern the degree and type of harmonic enrichment applied—not a mechanical selection. |
| `_pending:diad-harmonization` | Harmonic Arrangement & Voice-Leading | A rule for constructing two-note harmonizations (3rds and 6ths) for both chord tones and non-chord tones in the melody. |
| `_pending:quartal-stacking` | Harmonic Arrangement & Voice-Leading | A rule for constructing chords by stacking perfect 4ths as an alternative to tertian (3rd-based) voicing. |
| `_pending:right-hand-role-split` | Bass Line & Two-Instrument Arrangement | A rule specifying that the right-hand thumb (p) takes bass notes while index (i) and middle (m) fingers voice the upper triad in two-part arrangement. |
| `_pending:bassline-led-reharm` | Voicing Symmetry & Octave Transposition | A rule for the process of reharmonizing a section by first composing a bass line, then deriving chord choices from that bass line. |
| `_pending:expressive-priority` | Voicing Symmetry & Octave Transposition | A meta-rule asserting that artistic voice and expressive musicianship take precedence over theoretical accumulation; encodes the book's closing evaluative principle. |

---

## Provenance Notes

**What this statement draws from:**
- The book-level distillation (run_id `2026-05-28T15-05-20-fisher-jazz-guitar-method-vol-3`, extracted 2026-05-29), which itself aggregates all chapter summaries.
- Six chapter-level summaries (Chapters 1–6), each backed by individual chapter source files (`ch01.md` through `ch06.md`), covering source pages 7–63 of the PDF.
- The systems-draft JSON derived in the S3 stage, which directly maps systems, members, traversal rules, and modification rules to chapter-level evidence with page citations and quote excerpts.

**Chapter coverage and system yield:**
- **Chapter 1 (pp. 7–8):** Yielded System 1 (Right-Hand Technique) in its entirety.
- **Chapter 2 (pp. 9–17):** Yielded the foundational traversal rules and several modification rules for System 2 (Harmonic Arrangement and Voice-Leading), including melody study, key selection, octave adjustment, chord families, chord enhancement, and the context-and-taste principle.
- **Chapter 3 (pp. 18–37):** Yielded the voice-leading, diad, non-chord-tone, diminished-substitute, quartal, and octave-doubling modification rules for System 2. The diminished-chord fingerboard geometry (repeats every three frets) is embedded in the diminished-as-V7-substitute rule rather than as a standalone system.
- **Chapter 4 (pp. 38–47):** Yielded the secondary-dominant, ii-V7-I, backcycling, and tritone-substitution rules for System 2, and contributed the tritone-substitution-by-root-distance rule shared with System 3.
- **Chapter 5 (pp. 48–57):** Yielded System 3 (Bass Line and Two-Instrument Arrangement) in its entirety, including all traversal and modification rules governing the walking-bass and two-part arrangement technique.
- **Chapter 6 (pp. 58–63):** Yielded System 4 (Voicing Symmetry and Octave Transposition) in its entirety, including the symmetrical-transposition rules, reharmonization-via-bassline rule, and the book's closing expressive-priority principle.

**No chapters went without system yield.** Every chapter contributed at least one system or a substantial group of rules to an existing system. The minimalist single-note-with-chords-at-changes alternative mentioned in Chapter 3 is represented as a modification option within System 2 rather than as a separate system, as it is framed in the source as an option for players who prefer that texture rather than a distinct methodological branch.
