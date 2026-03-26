// Transposer.js — Semitone offset calculator for voicing transposition
// All voicings stored with root C. This module calculates fret adjustments
// to transpose to any target root.

.pragma library

var SEMITONE_MAP = {
    "C": 0, "B#": 0,
    "C#": 1, "Db": 1,
    "D": 2,
    "D#": 3, "Eb": 3,
    "E": 4, "Fb": 4,
    "F": 5, "E#": 5,
    "F#": 6, "Gb": 6,
    "G": 7,
    "G#": 8, "Ab": 8,
    "A": 9,
    "A#": 10, "Bb": 10,
    "B": 11, "Cb": 11
}

// Calculate semitone distance from sourceRoot to targetRoot
function semitoneOffset(sourceRoot, targetRoot) {
    var src = SEMITONE_MAP[sourceRoot]
    var tgt = SEMITONE_MAP[targetRoot]
    if (src === undefined || tgt === undefined) {
        console.error("Unknown root note: " + sourceRoot + " or " + targetRoot)
        return 0
    }
    return (tgt - src + 12) % 12
}

// Transpose a voicing's fret number from its stored root to a target root
function transposeFret(fretNumber, sourceRoot, targetRoot) {
    var offset = semitoneOffset(sourceRoot, targetRoot)
    return fretNumber + offset
}

// Extract root note from a chord symbol string
// e.g., "Fm7" → "F", "Bbmaj7" → "Bb", "F#7" → "F#", "C#m7b5" → "C#"
function extractRoot(chordSymbol) {
    if (!chordSymbol || chordSymbol.length === 0) return null

    var first = chordSymbol[0].toUpperCase()
    if (first < "A" || first > "G") return null

    if (chordSymbol.length > 1) {
        var second = chordSymbol[1]
        if (second === "#" || second === "b") {
            return first + second
        }
    }
    return first
}

// Transpose all note names in a voicing by the given semitone offset
// Returns an array of transposed note names
var NOTE_NAMES_SHARP = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
var NOTE_NAMES_FLAT = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

function transposeNote(noteName, offset, preferFlats) {
    var semitone = SEMITONE_MAP[noteName]
    if (semitone === undefined) return noteName
    var newSemitone = (semitone + offset) % 12
    return preferFlats ? NOTE_NAMES_FLAT[newSemitone] : NOTE_NAMES_SHARP[newSemitone]
}
