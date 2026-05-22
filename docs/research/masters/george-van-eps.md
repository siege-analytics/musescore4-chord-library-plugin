# George Van Eps — research notes

**Primary source type:** primary-source PDF of the 1939-era Van Eps
Method for Guitar (Epiphone Inc., NY) consulted in-session via the
project owner's attached copy. NOT committed to repo — the underlying
publication's copyright status differs from the Greene corpus (which
is openly distributed by the estate).
**Last research pass:** 2026-05-21 (this PR, after a web-source-only
first pass).
**Principle entries:** 7 in `masters.json` (was 5 after the web pass;
all rewritten against the primary source).

## What changed and why

The first research pass (#228) relied on secondary web sources —
Rob MacKillop's analysis at robmackillop.net, the
jazzguitarlessons.net profile, the Guitar Player feature.
That pass introduced two specific claims I now have to correct:

1. **"Banjo-derived arpeggio picking"** — MacKillop's
   interpretation. Van Eps's own text in the 1939 Method (page 3,
   "Pick and Wrist Action" + Ex. 2 instructions) describes the
   technique as **pulsation picking** with wrist axis over the top
   note for dynamic predominance. No mention of banjo origin in the
   primary source. Replaced with `pulsation-picking-top-voice-emphasis`.

2. **"Rootless voicings → ii-V-I cadence (F triad implies Dm7)"** —
   also MacKillop's analytical gloss. Ex. 1's own instructions
   describe it as "a harmonized major scale in triads" — diatonic
   triads. The "F triad is rootless Dm7" reading isn't in Van Eps's
   own text. Removed; replaced with `harmonized-scale-foundation`
   which describes what Ex. 1 actually is.

## Source identification

The PDF consulted is the 1939-era Epiphone Inc. publication. The
title page identifies it as **The George Van Eps Method for Guitar**
($2.50 cover price, Epiphone Inc., New York), distributed via
DjangoBooks.com with a Glenn Thompson watermark. The Foreword refers
to "succeeding volumes in preparation for publication in the near
future," confirming this is volume 1 of an intended multi-volume
series; the later 3-volume *Harmonic Mechanisms for Guitar* (Mel Bay,
1980-1982) is the mature realization of that series.

Important: **this is a 6-string method**. The 7-string (low A) work
is in Harmonic Mechanisms and on the 7-string recordings (Mellow
Guitar, 1956 and after). All 7 principles below are tagged
`applies_to_tunings: ["standard"]` — they're documented for the
6-string. 7-string-specific principles will need a separate research
pass against Harmonic Mechanisms.

## Sources per principle

### 1. `harmonized-scale-foundation`

Direct from the Foreword + every chord-quality section's first
exercise. The method's organizing principle is harmonizing the
relevant scale in triads:
- Ex. 1 (Major chords): harmonized major scale in triads
- Ex. 26 (Minor chords): harmonized minor scale in triads
- Ex. 33 (Seventh chords): built on the seventh arpeggio
- Ex. 48 (Diminished chords): harmonized diminished

Van Eps's solfeggio quote from the Foreword:
> "Think of the tonic of every key as 'do'; this is called the
> Solfeggio system. Therefore if you are in E flat, consider the E
> flat as 'do'. Through this system all keys are equal and therefore
> you will not favor any particular key or keys."

### 2. `six-fingering-string-sets`

The "Explanation of the String Chart" page (p. 6) introduces the
formal notation: sets of 3 (1|3, 2|3, 3|3, 4|3), sets of 4 (1|4,
2|4, 3|4), broken sets (1|B3, 2|B3, 3|B3, broken 1st of 3 = B1|3,
B2|3, B3|3), broken sets of 4 (1|B4, 2|B4), broken sets of 2
(1|B2, 2|B2, 3|B2, 4|B2), and the A-prefixed broken sets (A|1,
A|2, A|3).

Ex. 1's instructions document the six-form structure of the
harmonized major scale:
> "1st form — from C up to F"
> "2nd form — from C up to C sharp (D if possible)"
> "3rd form — from C up to F"
> "4th form — from A flat up to D flat (D if possible)"
> "5th form — from A flat up to E"
> "6th form — from F sharp up to C sharp"

The legato principle: "in making these quick shifts, do not rush
the tempo. Plant your fingers solidly and firmly on the fingerboard.
After releasing the pressure on a formation get used to forming the
next position while the hand is in motion."

### 3. `outer-voice-anchor-inner-motion`

The "hold outer voices while inner moves" device appears across
many exercises. Direct quotes from the primary source:

**Ex. 14 (Three forms):**
> "The upper (melodic) line is in half notes while the two lower
> voices are in whole notes. Make sure they sustain their full
> value. Practice all three forms equally as the purpose throughout
> this method is balanced technique."

**Ex. 20:**
> "A variation of the major scale with the top voice in quarter
> notes and the bottom voices in whole notes."

**Ex. 57:**
> "The top line is in quarter notes and the harmonic structure is
> in whole notes. Make sure the whole notes are held for their
> full value."

**Ex. 60 (Two forms):**
> "The moving voice is in the middle of the structure, which
> presents a difficulty as the up-stroke must pick the middle note
> while the two outside notes are sounding. Make sure you do not
> deaden either of the sustaining voices with the up-stroke."

**Ex. 82:**
> "Individual control of the fingers is developed in this exercise.
> In the first measure the third and fourth fingers play the two
> upper voices in quarter notes while the first and second fingers
> sustain the lower voices in whole notes."

This is the seed of what later (in Harmonic Mechanisms, 1980s)
became known as the "lap piano" style — but the device is
documented decades earlier in this 1939 method.

### 4. `chromatic-tenths-with-middle-voice`

Direct quote from Ex. 37 instructions (the first of a series of
stretching exercises):
> "You will notice that the middle note remains the same while the
> other two voices move around the middle voice in chromatic tenths.
> This is the first exercise using a broken set of three strings.
> (See page 6.) Pay close attention to the set markings under the
> staff in all these exercises. Practice in all keys in straight
> down strokes, then with arpeggio picking. Be careful in the latter
> as you have to jump over a string with the pick."

The chromatic 10ths principle was correctly captured in the
web-sourced first pass via jazzguitarlessons.net's gloss, but now
we have it from the source itself.

### 5. `pulsation-picking-top-voice-emphasis`

From "The Pick and Wrist Action" (p. 3) of the primary source:
> "In a complete wrist action the wrist imitates a twisting motion
> with each stroke, very much like flicking something off your hand.
> See that you use a quick and accurate stroke, eliminating all
> excess movement because you want the notes to sound simultaneously,
> not one by one. When playing on inside strings use the next
> highest string as a pick-stop. The axis of your wrist should be
> directly over the highest note as the top note should predominate.
> In other words if you are picking the B, D, and G strings as a
> triad, the axis should be over the B string with the result that
> the D string will sound softly, the G string a little louder, and
> the B string will be the loudest, which is dynamically correct."

And from Ex. 2 (which introduces "arpeggio picking" as Van Eps's
term):
> "The pick passes over each string and accents it with a slight
> kick, which is more of a pulsation... using the pulsation
> principle you will be able to maintain a steady tempo and you
> will not strike two strings at once."

### 6. `finger-flattening-fifth-finger`

Direct quote from Ex. 16 (Three forms):
> "This exercise must be practiced very carefully as we introduce
> a new principle in the first two forms which is the 'breaking'
> (or flattening from an arched position) of the first joint of
> the fingers. In the first form at the second and third measures,
> you flatten the first joint of the second finger to produce the
> added note, which brings this principle into the classification
> of a fifth finger. It is a very difficult maneuver because the
> finger that is doing the flattening must sustain another note
> during the process... This flattening principle must be practiced
> methodically as it must be reliable rhythmically and should be
> done with a snap."

Van Eps's own term is "fifth finger" — MacKillop's "mini barre"
description is functionally equivalent but Van Eps's own naming
is more specific (it's an added-note technique, not a barre proper).

### 7. `string-deadening-for-open-voicings`

Direct quote from Ex. 58 (Two forms) and its footnote:
> "This is the first diminished chord exercise in open voicing. It
> is necessary to 'deaden' a string. This is taken care of by the
> fingering. For instance, in the first form the D string (IV) is
> stopped from vibrating with the second finger while that finger
> is used for the note on the A (V) string. Practice slowly and
> observe all markings.
>
> *i.e. The pick strikes that string, but the left hand finger
> does not let it sound clearly."

A specific Van Eps mechanic for executing open voicings (skipping
intermediate strings) with a sweep-friendly pick motion.

## What was REMOVED

- `lap-piano-polyphonic-style` (web-sourced) — kept the IDEA but
  re-attributed via `outer-voice-anchor-inner-motion` to the actual
  exercises that document it in 1939. The "lap piano" term itself
  appears to be from later interviews/profiles, not the primary
  text.
- `independent-bass-counterpoint` (web-sourced, 7-string-specific) —
  REMOVED from this pass. Will be re-added when 7-string Harmonic
  Mechanisms is researched. The 1939 method is 6-string.
- `10th-interval-anchor` (web-sourced) — REPLACED with the more
  precise `chromatic-tenths-with-middle-voice` which has direct
  primary-source citation from Ex. 37.
- `rootless-voicings-for-cadences` (MacKillop's gloss) — REMOVED.
  Ex. 1 is harmonized-scale-in-triads, not a rootless-ii-V-I
  pedagogy in Van Eps's own framing.
- `banjo-derived-arpeggio-picking` (MacKillop's claim) — REPLACED
  with `pulsation-picking-top-voice-emphasis`, which is what
  Van Eps actually documents.

## Followups

- **7-string Harmonic Mechanisms (3 vols, Mel Bay, 1980-1982)** —
  the canonical 7-string method. Will need a separate research pass
  to add:
  - Independent low-A bass voice principles
  - The mature "lap piano" framing
  - Whatever inner-voice / counterpoint principles are introduced
    that weren't already in the 1939 method
- **Mellow Guitar (1956)** + later 7-string recordings as
  example-voicing references.
- **Howard Alden interviews** — Alden was Van Eps's most direct
  inheritor; his published commentary may add nuance.
- **Etude Study from p. 40** — Van Eps's pedagogy for composing
  one's own etudes; not encoded as a principle (it's a meta-practice
  rule) but worth noting in the research file.

## Bibliography

- **Van Eps, George.** *The George Van Eps Method for Guitar*.
  Epiphone Inc., New York, ca. 1939. Primary source consulted via
  PDF (Glenn Thompson copy, DjangoBooks.com distribution). Not in
  the repo corpus.
- Van Eps, George. *Harmonic Mechanisms for Guitar*, vols 1-3. Mel
  Bay Publications, 1980-1982. Cited; not yet directly consulted.
- *George Van Eps (1913-1998)* — jazzguitarlessons.net.
  <https://www.jazzguitarlessons.net/blog/george-van-eps>
- *George Van Eps Method for Guitar* — Rob MacKillop, musician.
  <https://robmackillop.net/george-van-eps-method-for-guitar/>
  (Secondary source; corrected against the primary in this pass.)
- *The seven-string guitars and smooth "lap-piano" style of George
  Van Eps* — Guitar Player.
  <https://www.guitarplayer.com/players/george-van-eps-my-guitar>
- *George Van Eps* — Grokipedia.
  <https://grokipedia.com/page/George_Van_Eps>
