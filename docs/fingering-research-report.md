# Guitar Chord Fingering: Comprehensive Research Report

**Date:** 2026-04-10
**Purpose:** Inform the design of a physically-aware fingering validation system for the ChordLibrary MuseScore plugin, including partial/diagonal barre support (an open problem in the literature).

---

## 1. Ted Greene's Fingering System

### Notation
- **1** = Index, **2** = Middle, **3** = Ring, **4** = Pinky, **T** = Thumb, **0** = Open
- Fingering numbers appear below chord diagrams
- Shape symbols (dot -> X -> square -> triangle) show melodic movement within chords

### V-System
- 14 voicing groups (V-1 through V-14) organized by voice spacing (Bass-Tenor-Alto-Soprano)
- 43 distinct four-note chord qualities
- Three recognition methods (third left unfinished by Greene)
- **Not a difficulty classification** — classifies by spacing/voicing group

### Physical Approach
- **Ted Greene had small hands** — his entire system was designed around this constraint
- Favored shell voicings (2-note bass + melody) because full close-position voicings were often too wide
- **Tip barring**: fingertip pressing two adjacent lower strings (distinct from flat barre)
- **Thumb (T)**: wrapping over neck for bass on strings 5-6, freeing other fingers
- **Note omission**: any voicing that's too difficult can drop a note
- **Hinge barre**: finger flat on some strings, curled away from others

### Key Resources
- Paul Vachon: "How to Read Ted Greene Chord Diagrams" — https://tedgreene.com/images/lessons/students/PaulVachon/HowToReadTedGreeneChordDiagrams.pdf
- V-System materials (29+ PDFs) — https://www.tedgreene.com/teaching/v_system.asp
- Chords & Chord Melody archive — https://tedgreene.com/teaching/chords.asp
- James Hober: "The V-System Introduction" — https://tedgreene.com/images/lessons/v_system/02_V-System_Introduction.pdf
- V-System Chord Tone Gap Method — https://www.tedgreene.com/images/lessons/v_system/V-System_Chord_Tone_Gap_Method.pdf
- Forestail Ted Greene Chord Diagram Generator — https://forestail.com/en/ted-greene-chord-diagram-generator/
- Ted Greene Forums — https://forums.tedgreene.com/

### Digitized Data
- **fusionprogguy/Fretboard** (Python, ~300 chords with V-System classification in CSV) — https://github.com/fusionprogguy/Fretboard
- Ted Greene's *Chord Chemistry* (1971, Alfred Publishing) — no machine-readable extraction exists publicly

---

## 2. Academic Literature

### Foundational Papers

| Authors | Title | Year | Venue | Approach | URL |
|---------|-------|------|-------|----------|-----|
| Sayegh | "Fingering for String Instruments with the Optimum Path Paradigm" | 1989 | Computer Music Journal 13(6) | Viterbi network / shortest path | Seminal paper; cited via Semantic Scholar |
| Radicioni, Anselma & Lombardo | "An Algorithm to Compute Fingering for String Instruments" | 2004 | AISC 2004 | CSP formulation | http://pgp.di.unito.it/~anselma/pdf/AISC04.pdf |
| Radicioni, Anselma & Lombardo | "A CSP Approach for Modeling the Hand Gestures of a Virtual Guitarist" | 2005 | Springer LNCS | CSP + physical model | https://link.springer.com/chapter/10.1007/11558590_47 |
| Radicioni, Anselma & Lombardo | "A Constraint-based Approach for Annotating Music Scores with Gestural Information" | 2007 | Constraints (Springer) | CSP, validated vs human expert | https://link.springer.com/article/10.1007/s10601-007-9015-y |
| Radicioni & Lombardo | "Guitar Fingering for Music Performance" | — | ResearchGate | CSP overview | https://www.researchgate.net/publication/238543175 |

### KTH Degree Projects (2013)

| Authors | Title | Approach | URL |
|---------|-------|----------|-----|
| Norman & Grozman | "An Algorithm for Optimal Guitar Fingering" | Layered graph, exhaustive search, reach tables | http://www.diva-portal.org/smash/get/diva2:668903/FULLTEXT01.pdf |
| Norman & Grozman | (KTH report) | Same | https://www.csc.kth.se/utbildning/kth/kurser/DD143X/dkand13/Group7Anders/final/Vladimir.Grozman.Christopher.Norman.report.pdf |
| Ilczuk & Skold | "Putting a Finger on Guitars and Algorithms" | Weighted graph, difficulty costs | https://www.csc.kth.se/utbildning/kandidatexjobb/medieteknik/2013/rapport/ilczuk_konrad_OCH_skold_philip_K13018.pdf |

### Dynamic Programming / Machine Learning

| Authors | Title | Year | Venue | Approach | URL |
|---------|-------|------|-------|----------|-----|
| Radisavljevic & Driessen | "Path Difference Learning for Guitar Fingering Problem" | 2004 | ICMC | DP + gradient descent | https://www.mistic.ece.uvic.ca/publications/2004_icmc_pdl.pdf |
| Hori & Sagayama | "Input-Output HMM Applied to Automatic Arrangement for Guitars" | 2013 | J. Information Processing | HMM | https://www.jstage.jst.go.jp/article/ipsjjip/21/2/21_264/_article |
| Hori & Sagayama | "Minimax Viterbi Algorithm for HMM-Based Guitar Fingering Decision" | 2016 | ISMIR | Minimax Viterbi | http://m.mr-pc.org/ismir16/website/articles/285_Paper.pdf |
| Tuohy & Potter | "A Genetic Algorithm for the Automatic Generation of Playable Guitar Tablature" | 2005 | U. Georgia | Distributed GA + neural net | https://www.ai.uga.edu/sites/default/files/inline-files/tuohy_daniel.pdf |
| — | "A Differential Evolution Algorithm Assisted by ANFIS for Music Fingering" | — | Springer LNCS | ANFIS learns from fingered scores | https://link.springer.com/chapter/10.1007/978-3-642-29353-5_6 |

### Japanese Research

| Authors | Title | Year | Venue | URL |
|---------|-------|------|-------|-----|
| Isato et al. | "Optimization for Guitar Fingering on Single Notes" | 2004 | IEICE Transactions | https://www.jstage.jst.go.jp/article/ieejeiss/124/7/124_7_1396/_article/-char/en |
| Miura & Hori | "Constructing a System for Finger-Position Determination and Tablature Generation" | 2004 | Systems & Computers in Japan | https://onlinelibrary.wiley.com/doi/abs/10.1002/scj.10609 |

### Recent ML/Transformer Approaches (2024-2025)

| Authors | Title | Year | Venue | Approach | URL |
|---------|-------|------|-------|----------|-----|
| Riley et al. | "MIDI-to-Tab: Guitar Tablature Inference via Masked Language Modeling" | 2024 | ISMIR | T5 transformer | https://qmro.qmul.ac.uk/xmlui/bitstream/handle/123456789/97939/Riley%20GAPS%20A%20Large%202024%20Accepted.pdf |
| — | "A Machine Learning Approach for MIDI to Guitar Tablature Conversion" | 2025 | arXiv | DNN + search | https://arxiv.org/abs/2510.10619 |
| — | "Fingering Prediction for Classical Guitar: Dataset Creation and Model Development" | 2025 | Springer | Ensemble (0.903 accuracy) | https://link.springer.com/chapter/10.1007/978-981-96-2074-6_14 |

### Chord-Specific Difficulty Research

| Authors | Title | Year | Venue | URL |
|---------|-------|------|-------|-----|
| — | "Quantifying the Ease of Playing Song Chords on the Guitar" | 2023 | ISMIR | https://archives.ismir.net/ismir2023/paper/000086.pdf |
| — | "A Customizable Mathematical Model for Determining the Difficulty of Guitar Triad Chords" | 2022 | ICCIS (Springer) | https://link.springer.com/chapter/10.1007/978-981-99-2322-9_51 |

### CombinoChord (Most Relevant Physical Model)

| Author | Title | Year | Venue | URL |
|--------|-------|------|-------|-----|
| Smith | CombinoChord (IEEE paper) | 2021 | IEEE | https://ieeexplore.ieee.org/document/9376001/ |
| Smith | CombinoChord blog post | 2016 | Blog | https://nicholastsmith.wordpress.com/2016/04/05/combinochord-a-guitar-chord-generator-app/ |

---

## 3. The CombinoChord Physical Model

Inter-finger distance constraints in millimeters:

| Finger Pair | Min (mm) | Max (mm) |
|-------------|----------|----------|
| 1-2 (index-middle) | 5.0 | 80.0 |
| 1-3 (index-ring) | 15.0 | 95.0 |
| 1-4 (index-pinky) | 25.0 | 110.0 |
| 2-3 (middle-ring) | 6.0 | 52.0 |
| 2-4 (middle-pinky) | 12.0 | 69.0 |
| 3-4 (ring-pinky) | 8.5 | 47.0 |

Penalty function: `SF(x, a, b) = 1 + (x - 0.99a)^3` when `x < a`; otherwise `1 - ((x - 0.99a) / (1.01b - 0.99a))^2`

Fret geometry (Mersenne's Law): `width(n) = gamma / 2^((n-1)/12)` where gamma = first fret width (~36mm on a standard guitar).

---

## 4. Existing Databases with Finger Assignments

| Source | Size | Fingers | License | Format | URL |
|--------|------|---------|---------|--------|-----|
| szaza/guitar-chords-db-json | 99,230 chords | Yes | MIT | JSON | https://github.com/szaza/guitar-chords-db-json |
| tombatossals/chords-db | Moderate | Yes (+ barres) | MIT | JSON / npm | https://github.com/tombatossals/chords-db |
| UCI/Kaggle Guitar Chords | 2,633 chords | Yes | CC BY 4.0 | CSV | https://archive.ics.uci.edu/dataset/575/guitar+chords+finger+positions |
| Uberchord API | Large | Yes | Free API | JSON (REST) | https://api.uberchord.com/ |
| fusionprogguy/Fretboard | ~300 | Yes (V-System) | GitHub | CSV | https://github.com/fusionprogguy/Fretboard |
| T-vK/chord-collection | Large | Yes | GitHub | JS/JSON | https://github.com/T-vK/chord-collection |

### Data Format Examples

**tombatossals/chords-db:**
```json
{
  "key": "D", "suffix": "sus2",
  "positions": [{
    "frets": [0, 3, 2, 0, -1, -1],
    "fingers": [0, 3, 1, 0, 0, 0],
    "barres": [],
    "capo": false
  }]
}
```

**Uberchord API:**
```json
{
  "strings": "1 X 2 2 1 0",
  "fingering": "1 X 3 4 2 X",
  "chordName": "F,maj,7,"
}
```

**UCI/Kaggle:** CSV with columns for root, type, intervals, and 6 finger-position columns (x=muted, 0=open, 1-4=fingers).

---

## 5. Standard Data Formats with Fingering Support

| Format | Fingering Field | Standard |
|--------|----------------|----------|
| MusicXML 4.0 | `<fingering>` inside `<frame-note>` | W3C |
| ChordPro | `fingers` param in `{define}` directive | Open |
| Guitar Pro (GP3-GP5) | Signed byte per note (0=T, 1-4) | Proprietary |

**MusicXML example:** https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/fingering-element-frame/

**ChordPro example:**
```
{define: Bes base-fret 1 frets 1 1 3 3 3 1 fingers 1 1 2 3 4 1}
```

**Guitar Pro:** PyGuitarPro can read/write — https://github.com/Perlence/PyGuitarPro

---

## 6. Open-Source Implementations

### Static Chord Fingering

| Repo | Language | Approach | URL |
|------|----------|----------|-----|
| pcorey/chord | Elixir | Recursive sieve, 4 constraint rules, barre detection | https://github.com/pcorey/chord |
| hyvyys/chord-fingering | JavaScript | Generates fingerings, difficulty score, barre detection | https://github.com/hyvyys/chord-fingering |
| RidwanSharkar/Fretboard-Explorer | React/JS | Backtracking, 5-fret max | https://github.com/RidwanSharkar/Fretboard-Explorer |
| jonthysell/Chordious | C# (.NET) | Fretboard diagram generator (MIT) | https://github.com/jonthysell/Chordious |
| rlk/picker | JavaScript | Calculates and renders fingerings | https://github.com/rlk/picker |
| hybridpicker/fretboard-position-finder | Python/Django | Position finder for scales/arpeggios/chords | https://github.com/hybridpicker/fretboard-position-finder |

### Melody Fingering (Sequential)

| Repo | Language | Approach | URL |
|------|----------|----------|-----|
| natecdr/tuttut | Python (PyPI) | HMM + Viterbi | https://github.com/natecdr/tuttut |
| senshu/TablaZinc | MiniZinc + JS | Constraint solver (Gecode) | https://github.com/senshu/TablaZinc |
| burksbuilds/guitar-robot | Python | A* search | https://github.com/burksbuilds/guitar-robot |
| srviest/SoloLa | Python | Guitar solo transcription | https://github.com/srviest/SoloLa |

### MuseScore Landscape
- **No existing MuseScore plugin performs automatic left-hand fingering assignment for guitar.**
- MuseScore's linked tablature assigns fret/string numbers but NOT finger numbers.
- Manual fingering uses 0-4 (T for thumb); right hand uses p, i, m, a, c.

---

## 7. Commercial Apps with Fingering Data

| App | Fingering? | Platform | Notes |
|-----|-----------|----------|-------|
| Chord! (Robotic Ears) | Yes (computed, all possible) | iOS/Android | Most algorithmically sophisticated |
| ChordBank | Yes (14,000+ voicings) | iOS/Web | https://chordbank.com/ |
| Yousician | Yes (color-coded) | iOS/Android/Web | |
| Fender Play | Yes | iOS/Android/Web | |
| iReal Pro | Yes (interactive, swipeable) | iOS/Android | Cannot add custom voicings |
| all-guitar-chords.com | Yes (2,700+, with audio) | Web | https://www.all-guitar-chords.com/ |
| chord-c.com | Yes (with barre indicators) | Web | https://chord-c.com/ |
| JGuitar.com | Yes (any tuning) | Web | https://jguitar.com/ |
| Oolimo.com | Yes (curated + algorithmic) | Web/iOS/Android | https://www.oolimo.com/ |

---

## 8. Open Problems (No Published Solutions)

1. **Partial barres** — most systems treat barres as all-or-nothing across contiguous strings. Diagonal/partial barres (Van Eps technique) are unmodeled.
2. **Thumb-over-neck** — absent from academic literature entirely (classical guitar bias).
3. **Hand size variation** — CombinoChord's table is one-size-fits-all.
4. **Tip barring** (Ted Greene) — fingertip pressing two adjacent lower strings; not formalized in any algorithm.
5. **Hinge barres** — finger flat on some strings, curled away from others; no published model.

---

## 9. Guitar Pedagogy Conventions

### Standard Fingering Notation
- **Left hand:** 1=index, 2=middle, 3=ring, 4=pinky, T=thumb
- **Right hand (classical):** p=pulgar (thumb), i=indice (index), m=medio (middle), a=anular (ring)
- Left-hand numbers appear to the left of noteheads in classical notation

### CAGED System
- Maps 5 open chord shapes (C, A, G, E, D) up the neck with canonical fingerings
- De facto standard for teaching open and barre chords
- Reference: https://www.jazz-guitar-licks.com/blog/guest-posts/why-jazz-guitarists-should-study-the-caged-method.html

### Joe Pass's Approach
- Reduced chord thinking to three simple shapes
- Emphasis on economy — minimal finger movement between voicings
- Reference: https://www.guitarworld.com/lessons/jazz-guitar-corner-learn-fretboard-joe-pass

### Classical Guitar Conventions
- Most rigorous fingering rules: position shifts, guide fingers, string crossing
- Reference: https://www.thisisclassicalguitar.com/finger-names-for-classical-guitar/
- Reference: https://www.classicalguitarcorner.com/guitar-finger-numbers/

---

## 10. Recommended Implementation Approach

### Phase 1: Fingering Validation in VoicingCalculator
- Run `suggestFingering()` on each candidate voicing during generation
- Reject voicings that fail fingering assignment
- Use CombinoChord distance table as physical model

### Phase 2: Partial/Diagonal Barre Support (Novel Contribution)
- Model each finger with barre capabilities (full, partial, hinge, diagonal, tip)
- Use Mersenne's Law to determine where diagonal barres become physically possible
- Difficulty tiers: standard (simple barre) -> advanced (partial) -> expert (Van Eps)

### Phase 3: Validation Against Real-World Data
- Cross-reference generated fingerings against szaza/tombatossals databases (99K+ chords)
- Compare with Uberchord API results
- Flag disagreements for manual review

### Phase 4: Difficulty Scoring
- Combine: finger span penalty, finger count, barre type, fret position
- Informed by ISMIR 2023 criteria and CombinoChord penalty function
- Expose as user-facing difficulty rating per voicing

---

## Credits & Acknowledgments

This research synthesizes work from the following individuals and projects:

### Researchers
- **Siamak Sayegh** — foundational Optimum Path Paradigm (1989)
- **Daniele P. Radicioni, Luca Anselma & Vincenzo Lombardo** — CSP formulation for guitar fingering
- **Christopher Norman & Vladimir Grozman** — optimal guitar fingering algorithm (KTH, 2013)
- **Konrad Ilczuk & Philip Skold** — fingering algorithm evaluation (KTH, 2013)
- **Aleksander Radisavljevic & Peter F. Driessen** — path difference learning (ICMC, 2004)
- **Gen Hori & Shigeki Sagayama** — HMM-based guitar arrangement / Minimax Viterbi
- **Daniel R. Tuohy & W.D. Potter** — genetic algorithm for tablature (U. Georgia)
- **Nicholas T. Smith** — CombinoChord physical model and genetic algorithm (IEEE, 2021)
- **Isato et al.** — guitar fingering optimization for robots
- **Miura & Hori** — finger-position determination system
- **Riley et al.** — MIDI-to-Tab transformer (Queen Mary U. London, 2024)

### Pedagogues & Musicians
- **Ted Greene** (1946-2005) — V-System, Chord Chemistry, tip barring technique
- **George Van Eps** (1913-1998) — 7-string guitar pioneer, diagonal barre technique
- **Joe Pass** (1929-1994) — economical chord voicing approach
- **Paul Vachon** — Ted Greene diagram notation guide
- **James Hober** — V-System mathematical formalization
- **Marten Falk** — guitar teacher, fingering rules for Norman & Grozman

### Open-Source Projects
- **tombatossals/chords-db** — MIT license chord database with fingerings
- **szaza/guitar-chords-db-json** — MIT license, 99,230 chords with fingerings
- **T-vK/chord-collection** — source data for szaza's collection
- **pcorey/chord** — Elixir chord fingering with constraint sieve (Pete Corey)
- **hyvyys/chord-fingering** — JavaScript fingering generator with difficulty scoring
- **senshu/TablaZinc** — MiniZinc constraint solver for tablature
- **natecdr/tuttut** — Python HMM+Viterbi fingering
- **burksbuilds/guitar-robot** — A* search fingering for robot guitar (Andrew Burks)
- **fusionprogguy/Fretboard** — Python V-System implementation
- **RidwanSharkar/Fretboard-Explorer** — React backtracking chord explorer
- **jonthysell/Chordious** — .NET fretboard diagram generator
- **rlk/picker** — JavaScript fingering calculator
- **hybridpicker/fretboard-position-finder** — Django position finder
- **Perlence/PyGuitarPro** — Python Guitar Pro file reader
- **Giancarlo Facoetti / fachords.com** — UCI/Kaggle guitar chords dataset (CC BY 4.0)

### Data Sources
- **UCI Machine Learning Repository** — Guitar Chords Finger Positions dataset
- **Kaggle** — Guitar Chords Finger Positions (yamqwe)
- **Uberchord API** — free REST API with fingering data
- **tedgreene.com** — archived lesson materials
- **W3C** — MusicXML 4.0 specification
- **ChordPro** — chord notation format specification
