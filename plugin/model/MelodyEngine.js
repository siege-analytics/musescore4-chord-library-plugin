// MelodyEngine.js — Melody extraction, scoring, and voice leading logic
// Extracted from ChordLibrary.qml to support decomposition and Phase 1 features.
// All functions are pure (no UI state mutation) — they take inputs and return results.

.pragma library

// Interval name → semitone offset mapping (used for top note calculation)
var INTERVAL_SEMITONES = {
    "1": 0, "b2": 1, "2": 2, "b3": 3, "3": 4, "4": 5, "#4": 6,
    "b5": 6, "5": 7, "#5": 8, "6": 9, "b7": 10, "7": 11, "bb7": 9,
    "9": 2, "b9": 1, "#9": 3, "11": 5, "#11": 6, "13": 9, "b13": 8
}

// Note name display array (for melody display in walkthrough)
var NOTE_NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

// Get the top (highest-pitched) note of a voicing as a semitone class (0-11).
// Returns -1 if the voicing has no sounding notes.
//
// @param voicing    — voicing object with dots[], open[], intervals[]
// @param targetRoot — root note string (e.g. "F", "Bb") for transposition context
// @param semitoneMap — Transposer.SEMITONE_MAP lookup table
function voicingTopNoteSemitone(voicing, targetRoot, semitoneMap) {
    // Intervals array is ordered low-to-high pitch (string 6 first, string 1 last).
    // The last interval is always the top (highest-pitched) note.
    var intervals = voicing.intervals || []
    if (intervals.length === 0) return -1

    var iv = intervals[intervals.length - 1]
    var rootSemitone = semitoneMap[targetRoot] || 0
    var ivOffset = INTERVAL_SEMITONES[iv]
    if (ivOffset !== undefined) return (rootSemitone + ivOffset) % 12
    return -1
}

// Get the bass (lowest-pitched) note of a voicing as a semitone class (0-11).
// Mirror of voicingTopNoteSemitone but finds the HIGHEST string number (= lowest pitch).
//
// @param voicing    — voicing object with dots[], open[], intervals[]
// @param targetRoot — root note string (e.g. "F", "Bb") for transposition context
// @param semitoneMap — Transposer.SEMITONE_MAP lookup table
function voicingBassNoteSemitone(voicing, targetRoot, semitoneMap) {
    // Intervals array is ordered low-to-high pitch (string 6 first, string 1 last).
    // The first interval is always the bass (lowest-pitched) note.
    var intervals = voicing.intervals || []
    if (intervals.length === 0) return -1

    var iv = intervals[0]
    var rootSemitone = semitoneMap[targetRoot] || 0
    var ivOffset = INTERVAL_SEMITONES[iv]
    if (ivOffset !== undefined) return (rootSemitone + ivOffset) % 12
    return -1
}

// Suggest a bass note for a chord quality.
// Returns the chord root semitone by default.
//
// @param targetRoot — root note string
// @param quality    — chord quality string
// @param semitoneMap — Transposer.SEMITONE_MAP lookup table
function suggestBassNote(targetRoot, quality, semitoneMap) {
    var rootSemitone = semitoneMap[targetRoot]
    if (rootSemitone === undefined) return -1
    return rootSemitone
}

// Suggest smart bass notes considering voice leading context.
// Returns array of { semitone, name, reason } suggestions.
//
// @param targetRoot  — current chord root
// @param quality     — current chord quality
// @param prevRoot    — previous chord root (or null)
// @param nextRoot    — next chord root (or null)
// @param semitoneMap — Transposer.SEMITONE_MAP
function suggestBassNotes(targetRoot, quality, prevRoot, nextRoot, semitoneMap) {
    var suggestions = []
    var root = semitoneMap[targetRoot]
    if (root === undefined) return suggestions

    // 1. Root in bass (always the default)
    suggestions.push({ semitone: root, name: NOTE_NAMES[root], reason: "Root" })

    // 2. Third in bass (first inversion) — smooth for maj7, min7
    if (quality === "maj7" || quality === "min7" || quality === "dom7" || quality === "maj6") {
        var third = quality === "min7" ? (root + 3) % 12 : (root + 4) % 12
        suggestions.push({ semitone: third, name: NOTE_NAMES[third], reason: "3rd (1st inv)" })
    }

    // 3. Fifth in bass (second inversion)
    var fifth = (root + 7) % 12
    suggestions.push({ semitone: fifth, name: NOTE_NAMES[fifth], reason: "5th (2nd inv)" })

    // 4. Walking bass: chromatic approach to next chord root
    if (nextRoot) {
        var nextSemi = semitoneMap[nextRoot]
        if (nextSemi !== undefined) {
            var halfBelow = (nextSemi - 1 + 12) % 12
            var halfAbove = (nextSemi + 1) % 12
            if (halfBelow !== root) {
                suggestions.push({ semitone: halfBelow, name: NOTE_NAMES[halfBelow], reason: "Chromatic → " + nextRoot })
            }
            if (halfAbove !== root) {
                suggestions.push({ semitone: halfAbove, name: NOTE_NAMES[halfAbove], reason: "Chromatic ↗ " + nextRoot })
            }
        }
    }

    // 5. Stepwise from previous chord
    if (prevRoot) {
        var prevSemi = semitoneMap[prevRoot]
        if (prevSemi !== undefined) {
            var stepUp = (prevSemi + 2) % 12  // whole step up
            var stepDown = (prevSemi - 2 + 12) % 12  // whole step down
            if (stepUp !== root && suggestions.every(function(s) { return s.semitone !== stepUp })) {
                suggestions.push({ semitone: stepUp, name: NOTE_NAMES[stepUp], reason: "Step from " + prevRoot })
            }
        }
    }

    return suggestions
}

// Calculate "distance" between two voicings (lower = closer hand position).
// Used for voice leading — prefer smooth transitions between chord shapes.
//
// @param a — previous voicing
// @param b — candidate voicing
// @returns distance score (0 = identical position)
function voicingDistance(a, b) {
    if (!a || !b) return 999
    var fretDist = Math.abs((a.fret_number || 0) - (b.fret_number || 0))
    var dotDist = Math.abs((a.dots || []).length - (b.dots || []).length)
    return fretDist * 3 + dotDist
}

// Parse a melody override note name to a semitone class (0-11).
// Returns -1 if no valid override is set.
//
// @param noteText    — user-entered note name (e.g. "E", "Bb", "F#")
// @param semitoneMap — Transposer.SEMITONE_MAP lookup table
function parseNoteToSemitone(noteText, semitoneMap) {
    if (!noteText) return -1
    var note = noteText.trim()
    if (!note) return -1
    var midi = semitoneMap[note.charAt(0).toUpperCase() + note.substring(1)]
    return (midi !== undefined) ? midi : -1
}

// Extract the highest MIDI pitch from a MuseScore chord element.
// Returns -1 if no notes found.
//
// @param chordElement — MuseScore CHORD element with .notes array
function highestPitchInChord(chordElement) {
    if (!chordElement || !chordElement.notes) return -1
    var highest = -1
    for (var i = 0; i < chordElement.notes.length; i++) {
        if (chordElement.notes[i].pitch > highest)
            highest = chordElement.notes[i].pitch
    }
    return highest
}

// Extract melody note from a score segment by scanning all voices (0-3).
// Returns the highest MIDI pitch found, or -1 if none.
//
// @param segment — MuseScore segment object with elementAt(voice)
function extractMelodyFromSegment(segment) {
    if (!segment || !segment.elementAt) return -1
    var melodyMidi = -1
    for (var voice = 0; voice < 4 && melodyMidi < 0; voice++) {
        var el = segment.elementAt(voice)
        if (el && el.type === 91 /* Element.CHORD */ && el.notes) {
            for (var n = 0; n < el.notes.length; n++) {
                if (el.notes[n].pitch > melodyMidi)
                    melodyMidi = el.notes[n].pitch
            }
        }
    }
    return melodyMidi
}

// Score a voicing candidate for the findBestVoicing sorting comparator.
// Returns a numeric score (higher = better match).
//
// @param voicing       — candidate voicing object
// @param quality       — target chord quality string
// @param targetRoot    — target root note string
// @param melodyTarget  — melody semitone class (0-11) or -1 if none
// @param filterContext — current context filter or ""
// @param filterCategory — current category filter or ""
// @param refVoicing    — last inserted voicing (for voice leading) or null
// @param semitoneMap   — Transposer.SEMITONE_MAP lookup table
function scoreVoicing(voicing, quality, targetRoot, melodyTarget, filterContext, filterCategory, refVoicing, semitoneMap) {
    var score = 0

    // Exact quality match beats quartal
    if (voicing.chord_quality === quality) score += 20

    // Context and category bonuses
    if (filterContext && voicing.context === filterContext) score += 100
    if (filterCategory && voicing.category === filterCategory) score += 50

    // Category preference: shell > drop2 > others
    if (voicing.category === "shell") score += 10
    else if (voicing.category === "drop2") score += 5

    // Melody-on-top: big bonus if voicing's top note matches melody
    if (melodyTarget >= 0) {
        var topNote = voicingTopNoteSemitone(voicing, targetRoot, semitoneMap)
        if (topNote === melodyTarget) score += 200
    }

    // Voice leading: prefer voicings close to the last inserted one
    if (refVoicing) {
        score -= voicingDistance(refVoicing, voicing) * 2
    }

    return score
}

// Format a melody MIDI pitch for display in the walkthrough.
//
// @param melodyMidi — MIDI pitch (0-127)
// @returns note name string (e.g. "E", "Bb")
function melodyNoteName(melodyMidi) {
    if (melodyMidi < 0) return ""
    return NOTE_NAMES[melodyMidi % 12]
}

// Build a voice leading path visualization from batch chord data.
// Shows top note, bass note, and motion direction for each chord.
// Returns a formatted string for display in the walkthrough panel.
//
// @param batchChords — array of {text, root, voicing, melodyMidi, bassMidi}
// @param currentIndex — current step index (1-based, after increment)
// @param semitoneMap — Transposer.SEMITONE_MAP
function buildVoiceLeadingPath(batchChords, currentIndex, semitoneMap) {
    if (!batchChords || batchChords.length === 0) return ""

    var lines = []
    var prevTop = -1

    // Show a window of chords around the current position
    var windowStart = Math.max(0, currentIndex - 3)
    var windowEnd = Math.min(batchChords.length, currentIndex + 4)

    for (var i = windowStart; i < windowEnd; i++) {
        var item = batchChords[i]
        var topSemi = voicingTopNoteSemitone(item.voicing, item.root, semitoneMap)
        var topName = topSemi >= 0 ? NOTE_NAMES[topSemi] : "?"
        var bassSemi = voicingBassNoteSemitone(item.voicing, item.root, semitoneMap)
        var bassName = bassSemi >= 0 ? NOTE_NAMES[bassSemi] : "?"

        // Direction arrow from previous top note
        var arrow = ""
        if (prevTop >= 0 && topSemi >= 0) {
            var diff = topSemi - prevTop
            // Normalize to shortest distance (-6 to +5)
            if (diff > 6) diff -= 12
            if (diff < -6) diff += 12
            if (diff > 0) arrow = "↗"
            else if (diff < 0) arrow = "↘"
            else arrow = "→"
        }

        var marker = (i === currentIndex - 1) ? "▸ " : "  "
        var chordLabel = item.text
        // Pad to 6 chars for alignment
        while (chordLabel.length < 6) chordLabel += " "

        lines.push(marker + chordLabel + " " + arrow + " top:" + topName + "  bass:" + bassName)
        prevTop = topSemi
    }

    return lines.join("\n")
}
