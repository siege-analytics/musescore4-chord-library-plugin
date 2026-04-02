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

// Keys that use flats in their key signature (and their chord symbols)
// Sharp keys: C, G, D, A, E, B, F#/Gb (we treat F# as sharp, Gb as flat)
// Flat keys: F, Bb, Eb, Ab, Db, Gb
var FLAT_KEYS = { "F": true, "Bb": true, "Eb": true, "Ab": true, "Db": true, "Gb": true }

// Determine whether a target root prefers flats or sharps
function prefersFlats(targetRoot) {
    return FLAT_KEYS[targetRoot] === true
}

// Transpose a note name to a target key with correct enharmonic spelling.
// E.g., transposeNoteToKey("E", "C", "F") → "A" (not "A", but correct)
//       transposeNoteToKey("Bb", "C", "F#") → "E" (sharp key, no flats)
function transposeNoteToKey(noteName, sourceRoot, targetRoot) {
    var offset = semitoneOffset(sourceRoot, targetRoot)
    return transposeNote(noteName, offset, prefersFlats(targetRoot))
}

// Transpose a voicing name from its stored root (C) to a target root.
// E.g., "Cmaj7 — A shape — Shell" with targetRoot "G" → "Gmaj7 — A shape — Shell"
// Quartal voicings drop the root prefix entirely since they're quality-agnostic.
function transposeName(name, sourceRoot, targetRoot) {
    if (!name) return name
    // Quartal voicings: strip the root prefix (e.g., "Cquartal" → "Quartal")
    var quartalPattern = new RegExp("^" + sourceRoot + "quartal")
    if (quartalPattern.test(name)) {
        return name.replace(quartalPattern, "Quartal")
    }
    if (sourceRoot === targetRoot) return name
    var pattern = new RegExp("^" + sourceRoot + "(?=[^a-z]|maj|min|dim|aug|sus|m[^a-z]|$)")
    return name.replace(pattern, targetRoot)
}

// Transpose an entire voicing's notes and name to a target key.
// Returns { name, notes, fret_number } with respelled values.
function transposeVoicing(voicing, targetRoot) {
    var offset = semitoneOffset(voicing.root, targetRoot)
    var useFlats = prefersFlats(targetRoot)

    var newNotes = []
    for (var i = 0; i < voicing.notes.length; i++) {
        newNotes.push(transposeNote(voicing.notes[i], offset, useFlats))
    }

    // Respell the chord name: replace leading root with target root
    // Quartal voicings drop the root prefix since they're quality-agnostic
    var newName = voicing.name
    if (newName && newName.indexOf(voicing.root + "quartal") === 0) {
        newName = newName.replace(voicing.root + "quartal", "Quartal")
    } else if (targetRoot !== voicing.root) {
        newName = newName.replace(/^C(?=[^a-z]|maj|min|dim|aug|sus|m[^a-z]|$)/, targetRoot)
    }

    return {
        name: newName,
        notes: newNotes,
        fret_number: voicing.fret_number + offset
    }
}
