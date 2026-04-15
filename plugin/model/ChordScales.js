// ChordScales.js — Chord-scale association for jazz guitar voicings.
// Maps chord qualities to compatible scales for improvisation context.
// Used to tag voicings and provide scale suggestions in the walkthrough.

.pragma library

// Scale definitions: name → interval pattern (semitones from root)
var SCALES = {
    "Ionian":        [0, 2, 4, 5, 7, 9, 11],
    "Dorian":        [0, 2, 3, 5, 7, 9, 10],
    "Phrygian":      [0, 1, 3, 5, 7, 8, 10],
    "Lydian":        [0, 2, 4, 6, 7, 9, 11],
    "Mixolydian":    [0, 2, 4, 5, 7, 9, 10],
    "Aeolian":       [0, 2, 3, 5, 7, 8, 10],
    "Locrian":       [0, 1, 3, 5, 6, 8, 10],
    "Melodic Minor": [0, 2, 3, 5, 7, 9, 11],
    "Harmonic Minor":[0, 2, 3, 5, 7, 8, 11],
    "Lydian b7":     [0, 2, 4, 6, 7, 9, 10],
    "Altered":       [0, 1, 3, 4, 6, 8, 10],
    "Half-Whole Dim":[0, 1, 3, 4, 6, 7, 9, 10],
    "Whole-Half Dim":[0, 2, 3, 5, 6, 8, 9, 11],
    "Whole Tone":    [0, 2, 4, 6, 8, 10],
    "Blues":          [0, 3, 5, 6, 7, 10],
    "Bebop Dom":     [0, 2, 4, 5, 7, 9, 10, 11],
    "Pentatonic Maj":[0, 2, 4, 7, 9],
    "Pentatonic Min":[0, 3, 5, 7, 10],
}

// Chord quality → array of compatible scale names (ordered by preference)
var CHORD_SCALE_MAP = {
    // Major family
    "maj7":       ["Ionian", "Lydian"],
    "maj6":       ["Ionian", "Lydian", "Pentatonic Maj"],
    "maj9":       ["Ionian", "Lydian"],
    "maj":        ["Ionian", "Lydian", "Pentatonic Maj"],

    // Dominant family
    "dom7":       ["Mixolydian", "Lydian b7", "Bebop Dom", "Blues"],
    "dom9":       ["Mixolydian", "Lydian b7", "Bebop Dom"],
    "dom13":      ["Mixolydian", "Lydian b7"],
    "dom7b9":     ["Half-Whole Dim", "Altered", "Phrygian"],
    "dom7sharp9": ["Altered", "Half-Whole Dim", "Blues"],
    "dom7sharp11":["Lydian b7"],
    "dom7b13":    ["Altered", "Whole Tone"],
    "dom7sharp5": ["Whole Tone", "Altered"],

    // Minor family
    "min7":       ["Dorian", "Aeolian", "Pentatonic Min"],
    "min9":       ["Dorian", "Aeolian"],
    "min6":       ["Dorian", "Melodic Minor"],
    "min-maj7":   ["Melodic Minor", "Harmonic Minor"],
    "min7b5":     ["Locrian", "Locrian"],

    // Diminished family
    "dim7":       ["Whole-Half Dim"],
    "dim":        ["Whole-Half Dim"],

    // Augmented
    "aug":        ["Whole Tone"],

    // Suspended
    "sus4":       ["Mixolydian", "Dorian"],
    "sus2":       ["Mixolydian", "Ionian"],

    // Quartal (quality-agnostic — works over many harmonies)
    "quartal":    ["Dorian", "Mixolydian", "Pentatonic Maj"],
}

// Get compatible scales for a chord quality.
// Returns array of { name: string, intervals: [int] }
function getScalesForQuality(quality) {
    var scaleNames = CHORD_SCALE_MAP[quality] || CHORD_SCALE_MAP["dom7"]  // fallback to dominant
    var result = []
    for (var i = 0; i < scaleNames.length; i++) {
        var name = scaleNames[i]
        if (SCALES[name]) {
            result.push({ name: name, intervals: SCALES[name] })
        }
    }
    return result
}

// Get scale names as a simple string array for tagging/display
function getScaleNames(quality) {
    var scaleNames = CHORD_SCALE_MAP[quality]
    if (!scaleNames) return []
    return scaleNames.slice()
}

// Check if a voicing's intervals are all contained within a given scale.
// voicingIntervals: array of semitone values (0-11)
// scaleIntervals: array of semitone values from SCALES
function voicingFitsScale(voicingIntervals, scaleIntervals) {
    for (var i = 0; i < voicingIntervals.length; i++) {
        var found = false
        for (var j = 0; j < scaleIntervals.length; j++) {
            if (voicingIntervals[i] === scaleIntervals[j]) {
                found = true
                break
            }
        }
        if (!found) return false
    }
    return true
}

// Get all scales that contain all notes of a voicing.
// voicingSemitones: array of semitone values (0-11) from the voicing's intervals
function matchingScales(voicingSemitones) {
    var matches = []
    for (var name in SCALES) {
        if (voicingFitsScale(voicingSemitones, SCALES[name])) {
            matches.push(name)
        }
    }
    return matches
}

// Note names for display (sharps for sharp keys, flats for flat keys)
var NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
var SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
var SHARP_ROOTS = {"C#":1, "D":1, "E":1, "F#":1, "G":1, "A":1, "B":1}

// Semitone offset for a root note
var ROOT_SEMITONES = {"C":0,"C#":1,"Db":1,"D":2,"D#":3,"Eb":3,"E":4,"F":5,"F#":6,"Gb":6,"G":7,"G#":8,"Ab":8,"A":9,"A#":10,"Bb":10,"B":11}

// Get the notes of a scale transposed to a given root.
// Returns { notes: ["F", "G", "A", "Bb", "C", "D", "Eb"], intervals: ["1", "2", "3", "4", "5", "6", "b7"] }
function getScaleNotes(scaleName, root) {
    var intervals = SCALES[scaleName]
    if (!intervals) return { notes: [], intervals: [] }
    var rootSemi = ROOT_SEMITONES[root] || 0
    var useSharp = SHARP_ROOTS[root]
    var names = useSharp ? SHARP_NAMES : NOTE_NAMES

    var INTERVAL_LABELS = {0:"1",1:"b2",2:"2",3:"b3",4:"3",5:"4",6:"b5",7:"5",8:"b6",9:"6",10:"b7",11:"7"}

    var notes = []
    var ivLabels = []
    for (var i = 0; i < intervals.length; i++) {
        var semi = (rootSemi + intervals[i]) % 12
        notes.push(names[semi])
        ivLabels.push(INTERVAL_LABELS[intervals[i]] || String(intervals[i]))
    }
    return { notes: notes, intervals: ivLabels }
}

// Format scale suggestion as a display string.
// E.g., "Cmaj7 → Ionian, Lydian"
function formatScaleSuggestion(root, quality) {
    var names = getScaleNames(quality)
    if (names.length === 0) return ""
    return root + " " + names.join(", ")
}
