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
    var dots = voicing.dots || []
    var opens = voicing.open || []
    if (dots.length === 0 && opens.length === 0) return -1

    // Find the lowest string number (= highest pitch on guitar)
    var minStr = 99
    var topDotIdx = -1
    for (var i = 0; i < dots.length; i++) {
        if (dots[i].string < minStr) { minStr = dots[i].string; topDotIdx = i }
    }
    for (var j = 0; j < opens.length; j++) {
        if (opens[j] < minStr) { minStr = opens[j]; topDotIdx = -2 }
    }

    // Use intervals array to get the interval, then compute semitone
    var intervals = voicing.intervals || []
    if (topDotIdx >= 0 && topDotIdx < intervals.length) {
        var iv = intervals[topDotIdx]
        var rootSemitone = semitoneMap[targetRoot] || 0
        var ivOffset = INTERVAL_SEMITONES[iv]
        if (ivOffset !== undefined) return (rootSemitone + ivOffset) % 12
    }
    return -1
}

// Get the bass (lowest-pitched) note of a voicing as a semitone class (0-11).
// Mirror of voicingTopNoteSemitone but finds the HIGHEST string number (= lowest pitch).
//
// @param voicing    — voicing object with dots[], open[], intervals[]
// @param targetRoot — root note string (e.g. "F", "Bb") for transposition context
// @param semitoneMap — Transposer.SEMITONE_MAP lookup table
function voicingBassNoteSemitone(voicing, targetRoot, semitoneMap) {
    var dots = voicing.dots || []
    var opens = voicing.open || []
    if (dots.length === 0 && opens.length === 0) return -1

    // Find the highest string number (= lowest pitch on guitar)
    var maxStr = 0
    var bassDotIdx = -1
    for (var i = 0; i < dots.length; i++) {
        if (dots[i].string > maxStr) { maxStr = dots[i].string; bassDotIdx = i }
    }
    for (var j = 0; j < opens.length; j++) {
        if (opens[j] > maxStr) { maxStr = opens[j]; bassDotIdx = -2 }
    }

    // Use intervals array to get the interval, then compute semitone
    var intervals = voicing.intervals || []
    if (bassDotIdx >= 0 && bassDotIdx < intervals.length) {
        var iv = intervals[bassDotIdx]
        var rootSemitone = semitoneMap[targetRoot] || 0
        var ivOffset = INTERVAL_SEMITONES[iv]
        if (ivOffset !== undefined) return (rootSemitone + ivOffset) % 12
    }
    // For open strings as bass: the last interval corresponds to the bass
    // (intervals are ordered high-to-low in the voicing data)
    if (bassDotIdx === -2 && intervals.length > 0) {
        var bassIv = intervals[intervals.length - 1]
        var rootSemi = semitoneMap[targetRoot] || 0
        var bassOffset = INTERVAL_SEMITONES[bassIv]
        if (bassOffset !== undefined) return (rootSemi + bassOffset) % 12
    }
    return -1
}

// Suggest a bass note for a chord quality.
// Returns the chord root semitone by default (root in bass is standard).
// For slash chords or inversions, this could be extended.
//
// @param targetRoot — root note string
// @param quality    — chord quality string
// @param semitoneMap — Transposer.SEMITONE_MAP lookup table
function suggestBassNote(targetRoot, quality, semitoneMap) {
    var rootSemitone = semitoneMap[targetRoot]
    if (rootSemitone === undefined) return -1
    // Default: root in bass
    return rootSemitone
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
