---
run_id: 2026-05-29T06-51-17-vaartstra-jazz-standards-playbook
stage: s4
source_pdf: Greenan, Brent - The Jazz Standards Playbook.pdf
model: claude-sonnet
extracted_at: 2026-05-31T01:10:26+00:00
schema_version: 0.1
---

# The Jazz Standards Playbook — Statement of Outputs

## Overview

*The Jazz Standards Playbook* by Brent Vaartstra teaches jazz improvisation through sequential study of ten carefully chosen jazz standards. The book's architecture is explicitly cumulative: each standard serves as a vehicle for introducing harmonic, melodic, and practice principles that compound across chapters, with no chapter operating in isolation from the ones before it. The defining characteristic of Vaartstra's method is an ear-first orientation — he positions sheet music as a verification tool rather than a primary source and treats effortful aural retrieval as the engine of durable musical memory. This orientation, established in Chapter 1 and sustained through Chapter 12, shapes every subsequent technical instruction.

The method rests on four interlocking systems: a procedural acquisition protocol (the LIST process), a functional harmony navigation system built from the ii-V-I progression outward, a modal harmony system anchored in Dorian mode and the Miles Davis aesthetic model, and a concrete improvisation practice toolkit. These systems are not presented as abstract theory; each is grounded in specific tunes and practice exercises before any principle is generalized. The progression from Autumn Leaves through Stella by Starlight is the scaffolding, not the product — the product is a transferable improvisational grammar.

Vaartstra's characteristic analytical moves include attaching memorable labels to complex harmonic phenomena (backdoor dominant, tritone substitution, hybrid ii-V-I), emphasizing relational rather than absolute chord analysis, and repeatedly returning to the question of what intervals define a chord's identity — particularly the 3rds and 7ths — as the practical decision-making tool available in real time. Chapter 12 frames the entire book's ten standards not as endpoints but as gateways to hundreds of other tunes, and characterizes music study as perpetual exploration rather than mastery achieved.

---

## Core Systems

### brent-vaartstra:jazz-standards-playbook:ear-first-acquisition

**Ear-First Acquisition System (LIST Process)**

This system defines the procedural method by which a jazz musician must approach learning any standard. Its four sequential stages — Listen, Internalize, Sing, Transfer — function as ordered prerequisites: the instrument stays away during Listen, undivided attention governs Internalize, the ability to sing the melody alone serves as the pass/fail gate before Transfer, and within Transfer, melody is learned before chords. Chapter 1 establishes the entire system, declaring sheet music's proper role as a checking mechanism rather than a learning source and positioning the Sing stage as proof of internalization rather than a performance goal.

The traversal rules enforce strict sequencing. `PositionContinuity` governs all three sequential ordering rules: LIST stages must proceed in order (Chapter 1), melody must precede chords within Transfer (Chapter 1), and root identification must precede quality determination when learning chords by ear (Chapter 1). These are not suggestions — the chapter's framing presents the order as the mechanism that produces durable retention rather than notation-dependent dependency.

Modification rules specify enrichment within stages. Including vocal recordings and learning lyrics deepens melodic memory (Chapter 1); using Frank Sinatra as the unembellished melody reference establishes a reliable baseline before studying ornamented versions (Chapter 1); extending the Sing stage to include bass notes trains harmonic ear in parallel with melodic memory (Chapter 1). The sheet-music-as-verification rule (`OmissionAllow`) permits notation use only after the ear has already acquired the material.

---

### brent-vaartstra:jazz-standards-playbook:functional-harmony-navigation

**Functional Harmony Navigation System**

This system governs melodic and harmonic movement through functional jazz progressions built from the Major and Minor Diatonic Series of 7th Chords. Its six member categories — Major 7, Dominant 7, Minor 7, Half-Diminished, Diminished 7, and the ii-V-I Progression Unit — are organized by their Roman numeral functions and chord formulas. Chapter 2 establishes the foundational architecture, declaring the ii-V-I the "cornerstone" of jazz harmony, defining guide tones (3rds and 7ths) as the melodic spine of improvisation, and naming voice leading as the governing principle for melodic connection. Every subsequent chapter applies and extends this framework.

Five traversal rules govern movement through the system. Guide-tone voice leading (`VoiceMotion`) specifies that the 7th of each chord resolves by step to the 3rd of the next, producing smooth melodic connection across ii-V-I and cycle-of-fourths progressions — established in Chapter 2 and reinforced in Chapter 7. Arpeggio connection via nearest chord tone (`VoiceMotion`) extends this principle: when moving between chord arpeggios, entry on the closest chord tone rather than the root is preferred — Chapter 4 states this for functional arpeggios, Chapter 7 applies it to modal arpeggios. Cycle-of-fourths harmonic movement (`PositionContinuity`) governs the default direction of jazz harmony — descending fifths / ascending fourths — with Chapter 10 providing the definitive study through *All the Things You Are*. Stepwise connection at key-center boundaries (`VoiceMotion`) governs the specific challenge of rapid modulations such as the cycle of major thirds in Chapter 9. Relational chord function analysis (`FamilyCoherence`), introduced in Chapter 4 and elaborated in Chapter 5, establishes that a chord's function is determined by the chords before and after it, never in isolation — the foundational analytical stance of the entire system.

Eight modification rules describe how members of the system may be altered or substituted. Diatonic minor to dominant 7 conversion (`SubstitutionExpand`) is identified in Chapter 2 and confirmed in Chapter 6 as standard jazz practice. Tritone substitution (`SubstitutionExpand`), introduced in Chapter 8, replaces a dominant 7 chord with the dominant built on the root a tritone away, sharing the original's guide tones. Backdoor dominant substitution (`SubstitutionExpand`) — bVII7 replacing V7 by whole-step approach — appears with its extended form (backdoor ii-V) in Chapter 11. Diminished 7 as rootless dominant b9 substitute (`SubstitutionExpand`) is established in Chapter 9, where F#dim7 functions as a rootless D7(b9). Secondary dominant tonicization (`SubstitutionExpand`) — any diatonic chord preceded by its V7 or full ii-V pair — is introduced in Chapter 4 and elaborated in Chapter 5. The hybrid ii-V-I (`SubstitutionExpand`), introduced in Chapter 11, borrows the ii and V from the parallel minor while resolving to a major I chord. Minimal-change voice leading (`VoiceMotion`) — adjusting only the 3rds and 7ths that carry chord quality while holding other tones constant — is the governing simplicity principle for harmonically dense passages, prescribed in Chapter 8. Extension layer permission (`ColorToneRequire`) grants explicit access to 9ths, 11ths, and 13ths as available color tones over any 7th chord, introduced in Chapter 8. Chromatic passing tone insertion (`NCTHarmonization`), first named in Chapter 4 and formalized in Chapter 8, permits non-diatonic half-step connectors between diatonic notes as non-structural melodic events.

---

### brent-vaartstra:jazz-standards-playbook:modal-harmony-system

**Modal Harmony Improvisation System**

This system governs improvisation in modal harmonic contexts where chord movement is minimal or static and modes function as pitch collections rather than as functional progressions. Its eight members are the seven modes of the major scale plus the Whole-Half Diminished Scale. Chapter 7 establishes the system through *So What*, introducing D Dorian (built from C major) as the primary modal vehicle and teaching that guide tones are unnecessary in modal contexts — the mode as pitch collection replaces the guide-tone framework that governs functional harmony. Chapter 6 prepares this shift by introducing the Mixolydian scale (major with b7, formula 1-2-3-4-5-6-b7) and reframing scales as "pitch collections" rather than linear drills. Chapter 9 adds the Whole-Half Diminished Scale (W-H-W-H-W-H-W) as the note-choice resource for diminished 7 and dominant b9 chords.

Three traversal rules govern modal movement. Modal arpeggio connection via nearest chord tone (`VoiceMotion`) — entering each new arpeggio on whichever chord tone is closest to the last note played — is taught in Chapter 7 as the substitute for root-centric arpeggio practice. Modal pattern exercise in 3rds with half/whole-step mode links (`StringSetTransition`) internalizes mode relationships by connecting adjacent modes through 3rd-based patterns that transition by half or whole step, established in Chapter 7. Space-and-expand phrasing (`TextureCycle`) models Miles Davis's approach to *So What*: play a phrase, leave space, then expand — avoiding continuous note-running in favor of sparse, intentional melodic statements. Chapter 7 presents this as the aesthetic standard for modal playing, not merely a stylistic preference.

Three modification rules govern the modal system's constraints and permissions. Guide tone omission in modal contexts (`OmissionAllow`) — established in Chapter 7 — removes the 3rd/7th resolution requirement that governs functional harmony, authorizing the mode itself as sufficient harmonic structure. Scales as pitch collections (`ColorToneRequire`) — introduced in Chapter 6 and reinforced in Chapter 7 — prohibits treating modes as linear scales to run and instead positions them as non-ordered sets of available note choices. Chromatic approach notes in modal playing (`NCTHarmonization`) — modeled through Miles Davis's Dorian practice in Chapter 7 — permits occasional chromatic approach notes as expressive exceptions that do not disrupt modal identity.

---

### brent-vaartstra:jazz-standards-playbook:improvisation-practice-toolkit

**Improvisation Practice Toolkit System**

This system organizes the concrete improvisation practice methods taught across all chapters into a structured toolkit of seven named tools: guide tones, melody reference, chord tones/arpeggios, contrafact composition, motif development, transcribed licks, and composed solos. Chapter 10 consolidates all six core tools explicitly (excluding composed solos, which Chapter 10 adds as its distinctive contribution), but individual tools are introduced throughout the book — guide tones in Chapter 2, three-chorus melody escalation in Chapter 3, contrafact composition in Chapter 5, motif development named in Chapter 8, and transcribed licks as a 12-keys practice mandate in Chapter 6.

Four traversal rules govern how practitioners sequence and escalate across tools. Three-chorus melody escalation (`TextureCycle`) — introduced in Chapter 3 through *Blue Bossa* — scaffolds from straight melody in chorus one, to melody as embellished guideline in chorus two, to free improvisation with melodic fragments referenced in chorus three. All licks and patterns through all 12 keys (`SymmetryMovement`) — prescribed explicitly in Chapter 6 and applied throughout — requires every learned lick, pattern, or harmonic concept to be internalized across all 12 keys. Density reduction for harmonically dense passages (`DensityFloor`) — prescribed in Chapter 8 — mandates reducing note density to as few as a single note over an entire sequence to isolate chord-tone hearing before complexity is reintroduced. Quarter-note solo rhythmic reduction (`DensityFloor`) — introduced in Chapter 11 — removes rhythmic complexity from improvisation practice by restricting note values to quarter notes, isolating harmonic navigation as the sole cognitive task.

Five modification rules govern the individual tools' constraints and combinations. Contrafact singability and simplicity (`DensityCeiling`) — established in Chapter 5 — requires student contrafacts to be simple enough to sing and to outline chord changes through chord tones. Bebop contrafact mandatory structure (`DensityCeiling`) — also from Chapter 5 — requires that even a dense bebop-style contrafact contain repeated sections, rhythmic clones, and deliberate structure. Thematic repetition with variation (`TextureCycle`) — from Chapter 5 — establishes space and recurring melodic/rhythmic themes as hallmarks of strong improvisation. Strong melody licensing harmonic freedom (`ColorToneRequire`) — established in Chapter 3 — permits any degree of outside playing provided the improvised line is melodically strong and resolves with intention. Note-mapping for dense harmonic passages (`_pending:note-map-scaffold`) — introduced in Chapter 11 — scaffolds complex changes by mapping all available scale and chord tones before building melodic lines.

---

## Pending Work

- **`_pending:aural-enrichment-protocol`** (used by three modification rules in the Ear-First Acquisition System: `include-vocal-versions`, `sinatra-reference-for-straight-melody`, `sing-bass-notes-for-harmony`): These three rules describe enrichment behaviors within the Listen and Sing stages of the LIST process. They share a common operational shape — identifying a supplementary input source or extending a stage's scope — that does not map cleanly to any existing engine payload kind. The encoder must design an `aural-enrichment-protocol` engine kind that represents stage-specific input-source constraints and scope extensions without conflating them with traversal order rules.

- **`_pending:note-map-scaffold`** (used by `note-mapping-for-dense-harmony` in the Improvisation Practice Toolkit System): This rule describes a pre-compositional scaffolding operation — mapping all available pitch choices over complex changes before constructing melodic lines. It is distinct from density reduction rules (which govern note count during playing) and from voice-leading rules (which govern interval motion). The encoder must design a `note-map-scaffold` engine kind that represents pre-pass pitch inventory operations as a precondition to melodic construction.

---

## Provenance Notes

- **Chapter 1** fully yielded the Ear-First Acquisition System (LIST Process). All four LIST stages and all modification enrichments trace to this chapter.

- **Chapter 2** is the primary source for the Functional Harmony Navigation System's foundational architecture: guide tones, voice leading, the ii-V-I cornerstone, the diatonic minor-to-dominant conversion, and the guide-tone practice method. It also contributes to the Improvisation Practice Toolkit (guide tones tool).

- **Chapter 3** contributes the three-chorus melody escalation traversal rule and the strong-melody-licenses-outside-playing modification rule to the Improvisation Practice Toolkit. It did not yield an independent system; its contribution is instrumental practice protocol rather than harmonic vocabulary.

- **Chapter 4** contributes secondary dominant tonicization, arpeggio-nearest-chord-tone, relational chord function analysis, and chromatic approach notes to the Functional Harmony Navigation System. It did not yield an independent system.

- **Chapter 5** contributes target chord analysis and contrafact composition tools (both simple/singable and bebop forms) to the Improvisation Practice Toolkit, and the relational analysis principle to the Functional Harmony Navigation System. It did not yield an independent system; its harmonic content (ii-V expansion, dual analysis readings) feeds the Functional Harmony Navigation System as elaboration rather than new architecture.

- **Chapter 6** contributes the Mixolydian scale and scales-as-pitch-collections to the Modal Harmony System, the diatonic-minor-to-dominant conversion confirmation to the Functional Harmony Navigation System, and the all-12-keys internalization mandate to the Improvisation Practice Toolkit. It did not yield an independent system.

- **Chapter 7** is the primary source for the Modal Harmony Improvisation System: Dorian mode, guide-tone omission, modal arpeggio traversal, modal patterns in thirds, and the Miles Davis space-and-expand phrasing model all originate here.

- **Chapter 8** is a dense contributor to both the Functional Harmony Navigation System (tritone substitution, chromatic passing tones, minimal-change voice leading, extensions permission) and the Improvisation Practice Toolkit (density reduction, motif development, defining-notes analytical question). It did not yield an independent system; its content is application of the substitution and voice-leading grammar.

- **Chapter 9** contributes the Whole-Half Diminished Scale and diminished-7-as-rootless-dominant-b9 to the Functional Harmony Navigation and Modal Harmony Systems, and the stepwise key-center connection traversal rule. The cycle of major thirds is introduced as an analytical device but is subsumed within the Functional Harmony Navigation System's relational analysis framework rather than forming a separate system.

- **Chapter 10** consolidates six core improvisation tools (guide tones, melody, chord tones, contrafacts, motifs, transcribed licks) and adds composed solos to the Improvisation Practice Toolkit. Its harmonic content (cycling 4ths, passing diminished chords, V-as-key-transposition weapon) feeds the Functional Harmony Navigation System. It did not yield a system distinct from the existing four.

- **Chapter 11** contributes backdoor dominant substitution, hybrid ii-V-I, and the backdoor ii-V to the Functional Harmony Navigation System, and the quarter-note solo and note-mapping tools to the Improvisation Practice Toolkit. It did not yield an independent system.

- **Chapter 12** contributed no systems. Its content is explicitly meta-pedagogical: the framing of standards as vehicles, the characterization of music as lifetime study without final arrival, and the principle of harmonic and rhythmic transferability. These are orientation statements, not operational rules or system members. They inform the Overview but do not encode as traversal or modification rules.
