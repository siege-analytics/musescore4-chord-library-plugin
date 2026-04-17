// ChordScales.js — Chord-scale association for jazz guitar voicings.
// Maps chord qualities to compatible scales for improvisation context.
// Used to tag voicings and provide scale suggestions in the walkthrough.
// Extended with CRUD operations and JSON persistence (#142).

.pragma library

// === Default (hardcoded) scale definitions — used as fallback ===
var DEFAULT_SCALES = {
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

var DEFAULT_CHORD_SCALE_MAP = {
    "maj7":       ["Ionian", "Lydian"],
    "maj6":       ["Ionian", "Lydian", "Pentatonic Maj"],
    "maj9":       ["Ionian", "Lydian"],
    "maj":        ["Ionian", "Lydian", "Pentatonic Maj"],
    "dom7":       ["Mixolydian", "Lydian b7", "Bebop Dom", "Blues"],
    "dom9":       ["Mixolydian", "Lydian b7", "Bebop Dom"],
    "dom13":      ["Mixolydian", "Lydian b7"],
    "dom7b9":     ["Half-Whole Dim", "Altered", "Phrygian"],
    "dom7sharp9": ["Altered", "Half-Whole Dim", "Blues"],
    "dom7sharp11":["Lydian b7"],
    "dom7b13":    ["Altered", "Whole Tone"],
    "dom7sharp5": ["Whole Tone", "Altered"],
    "min7":       ["Dorian", "Aeolian", "Pentatonic Min"],
    "min9":       ["Dorian", "Aeolian"],
    "min6":       ["Dorian", "Melodic Minor"],
    "min-maj7":   ["Melodic Minor", "Harmonic Minor"],
    "min7b5":     ["Locrian", "Locrian"],
    "dim7":       ["Whole-Half Dim"],
    "dim":        ["Whole-Half Dim"],
    "aug":        ["Whole Tone"],
    "sus4":       ["Mixolydian", "Dorian"],
    "sus2":       ["Mixolydian", "Ionian"],
    "quartal":    ["Dorian", "Mixolydian", "Pentatonic Maj"],
    "aug7":       ["Whole Tone", "Altered"],
    "augMaj7":    ["Lydian", "Ionian"],
    "dom7alt":    ["Altered", "Half-Whole Dim"],
    "dom7flat5":  ["Whole Tone", "Altered", "Lydian b7"],
    "maj13":      ["Ionian", "Lydian"],
    "maj69":      ["Ionian", "Lydian", "Pentatonic Maj"],
    "maj7sharp11":["Lydian"],
    "maj7sharp5": ["Lydian", "Whole Tone"],
    "min-maj9":   ["Melodic Minor", "Harmonic Minor"],
    "min11":      ["Dorian", "Aeolian"],
    "13b9":       ["Half-Whole Dim", "Altered", "Phrygian"],
    "13sharp9":   ["Altered", "Half-Whole Dim", "Blues"],
    "13sus4":     ["Mixolydian", "Dorian"],
    "7b5b9":      ["Altered", "Whole Tone"],
    "7b5sharp9":  ["Altered", "Half-Whole Dim"],
    "7b9sus4":    ["Half-Whole Dim", "Phrygian"],
    "7sharp5b9":  ["Altered", "Half-Whole Dim"],
    "7sharp5sharp9": ["Altered", "Half-Whole Dim"],
    "9sus4":      ["Mixolydian", "Dorian"],
}

// === Live state (populated from JSON or defaults) ===

// Scale definitions: name -> interval pattern (semitones from root)
var SCALES = {}

// Chord quality -> array of compatible scale names (ordered by preference)
var CHORD_SCALE_MAP = {}

// Scale metadata: id -> { id, name, aliases, intervals, category, builtin }
var _scaleRegistry = {}

// Custom chord qualities added by user
var _customQualities = []

// Track whether loadScales() has been called
var _loaded = false

// === Initialization ===

// Initialize SCALES and CHORD_SCALE_MAP from defaults (called on first use if not loaded)
function _ensureLoaded() {
    if (_loaded) return
    // Copy defaults into live state
    for (var name in DEFAULT_SCALES) {
        SCALES[name] = DEFAULT_SCALES[name].slice()
    }
    for (var quality in DEFAULT_CHORD_SCALE_MAP) {
        CHORD_SCALE_MAP[quality] = DEFAULT_CHORD_SCALE_MAP[quality].slice()
    }
    _loaded = true
}

// Load scales from parsed JSON data (called by ChordLibrary.qml on startup).
// jsonData: parsed object from scales.json with { scales, chordScaleMap, customQualities }
// Returns true on success, false on error.
function loadScales(jsonData) {
    if (!jsonData || !jsonData.scales || !jsonData.chordScaleMap) {
        _ensureLoaded()
        return false
    }

    // Reset live state
    SCALES = {}
    CHORD_SCALE_MAP = {}
    _scaleRegistry = {}
    _customQualities = (jsonData.customQualities || []).slice()

    // Load scale definitions from JSON array
    var scales = jsonData.scales
    for (var i = 0; i < scales.length; i++) {
        var s = scales[i]
        if (!s.id || !s.name || !s.intervals || s.intervals.length < 3) continue
        SCALES[s.name] = s.intervals.slice()
        _scaleRegistry[s.id] = {
            id: s.id,
            name: s.name,
            aliases: (s.aliases || []).slice(),
            intervals: s.intervals.slice(),
            category: s.category || "custom",
            builtin: s.builtin === true
        }
    }

    // Load chord-scale mappings (JSON uses scale IDs, convert to names)
    var csMap = jsonData.chordScaleMap
    for (var quality in csMap) {
        var scaleIds = csMap[quality]
        var names = []
        for (var j = 0; j < scaleIds.length; j++) {
            var reg = _scaleRegistry[scaleIds[j]]
            if (reg) names.push(reg.name)
        }
        CHORD_SCALE_MAP[quality] = names
    }

    _loaded = true
    return true
}

// Serialize current state back to JSON object for persistence.
// Returns object matching scales.json schema.
function saveScales() {
    _ensureLoaded()
    var scales = []
    for (var id in _scaleRegistry) {
        var r = _scaleRegistry[id]
        scales.push({
            id: r.id,
            name: r.name,
            aliases: r.aliases.slice(),
            intervals: r.intervals.slice(),
            category: r.category,
            builtin: r.builtin
        })
    }

    // Convert CHORD_SCALE_MAP (uses names) back to IDs for JSON
    var csMap = {}
    for (var quality in CHORD_SCALE_MAP) {
        var names = CHORD_SCALE_MAP[quality]
        var ids = []
        for (var i = 0; i < names.length; i++) {
            var scaleId = _nameToId(names[i])
            if (scaleId) ids.push(scaleId)
        }
        csMap[quality] = ids
    }

    return {
        scales: scales,
        chordScaleMap: csMap,
        customQualities: _customQualities.slice()
    }
}

// === Scale CRUD ===

// Add a new custom scale. Returns the new scale's id, or "" on validation failure.
// name: display name (must be unique)
// intervals: array of semitone values (0-11), must start with 0, minimum 3
// category: string category (default "custom")
// aliases: optional array of alternate names
function addScale(name, intervals, category, aliases) {
    _ensureLoaded()
    if (!name || !intervals || intervals.length < 3) return ""
    if (intervals[0] !== 0) return ""
    if (SCALES[name]) return ""  // name already exists

    // Validate intervals: all 0-11, sorted, no duplicates
    if (!_validateIntervals(intervals)) return ""

    var id = _slugify(name)
    if (_scaleRegistry[id]) return ""  // id collision

    SCALES[name] = intervals.slice()
    _scaleRegistry[id] = {
        id: id,
        name: name,
        aliases: (aliases || []).slice(),
        intervals: intervals.slice(),
        category: category || "custom",
        builtin: false
    }
    return id
}

// Update an existing scale. Returns true on success.
// Only custom scales (builtin: false) can have their intervals changed.
// Name, aliases, and category can be changed on any scale.
function updateScale(scaleId, name, intervals, category, aliases) {
    _ensureLoaded()
    var reg = _scaleRegistry[scaleId]
    if (!reg) return false

    // Validate intervals if changing them
    if (intervals && intervals.length >= 3) {
        if (reg.builtin) return false  // can't change built-in intervals
        if (intervals[0] !== 0) return false
        if (!_validateIntervals(intervals)) return false
    }

    // If renaming, update SCALES key and CHORD_SCALE_MAP references
    var oldName = reg.name
    var newName = name || oldName

    if (newName !== oldName) {
        if (SCALES[newName]) return false  // name collision
        // Move intervals under new name
        SCALES[newName] = SCALES[oldName]
        delete SCALES[oldName]
        // Update chord-scale map references
        for (var quality in CHORD_SCALE_MAP) {
            var arr = CHORD_SCALE_MAP[quality]
            for (var i = 0; i < arr.length; i++) {
                if (arr[i] === oldName) arr[i] = newName
            }
        }
        reg.name = newName
    }

    if (intervals && intervals.length >= 3 && !reg.builtin) {
        reg.intervals = intervals.slice()
        SCALES[newName] = intervals.slice()
    }
    if (category) reg.category = category
    if (aliases) reg.aliases = aliases.slice()

    return true
}

// Delete a scale. Returns true on success.
// Built-in scales cannot be deleted.
function deleteScale(scaleId) {
    _ensureLoaded()
    var reg = _scaleRegistry[scaleId]
    if (!reg) return false
    if (reg.builtin) return false

    var name = reg.name
    delete SCALES[name]
    delete _scaleRegistry[scaleId]

    // Remove from chord-scale mappings
    for (var quality in CHORD_SCALE_MAP) {
        var arr = CHORD_SCALE_MAP[quality]
        var filtered = []
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] !== name) filtered.push(arr[i])
        }
        CHORD_SCALE_MAP[quality] = filtered
    }
    return true
}

// Get the full scale registry as an array (for UI display).
function getScaleList() {
    _ensureLoaded()
    var result = []
    for (var id in _scaleRegistry) {
        var r = _scaleRegistry[id]
        result.push({
            id: r.id,
            name: r.name,
            aliases: r.aliases.slice(),
            intervals: r.intervals.slice(),
            category: r.category,
            builtin: r.builtin
        })
    }
    // Sort: built-in first, then by name
    result.sort(function(a, b) {
        if (a.builtin !== b.builtin) return a.builtin ? -1 : 1
        return a.name.localeCompare(b.name)
    })
    return result
}

// Get a single scale by ID. Returns null if not found.
function getScaleById(scaleId) {
    _ensureLoaded()
    var r = _scaleRegistry[scaleId]
    if (!r) return null
    return {
        id: r.id,
        name: r.name,
        aliases: r.aliases.slice(),
        intervals: r.intervals.slice(),
        category: r.category,
        builtin: r.builtin
    }
}

// === Chord-Scale Mapping CRUD ===

// Set the scale mapping for a chord quality.
// scaleNames: array of scale names in preference order.
function setChordScaleMapping(quality, scaleNames) {
    _ensureLoaded()
    if (!quality || !scaleNames) return false
    // Validate all scale names exist
    for (var i = 0; i < scaleNames.length; i++) {
        if (!SCALES[scaleNames[i]]) return false
    }
    CHORD_SCALE_MAP[quality] = scaleNames.slice()
    return true
}

// Remove a chord-scale mapping entirely.
function removeChordScaleMapping(quality) {
    _ensureLoaded()
    if (!CHORD_SCALE_MAP[quality]) return false
    delete CHORD_SCALE_MAP[quality]
    return true
}

// === Custom Quality CRUD ===

// Add a custom chord quality name. Returns true on success.
function addCustomQuality(qualityName) {
    _ensureLoaded()
    if (!qualityName) return false
    for (var i = 0; i < _customQualities.length; i++) {
        if (_customQualities[i] === qualityName) return false  // already exists
    }
    _customQualities.push(qualityName)
    // Initialize empty mapping if not present
    if (!CHORD_SCALE_MAP[qualityName]) {
        CHORD_SCALE_MAP[qualityName] = []
    }
    return true
}

// Remove a custom chord quality. Returns true on success.
function removeCustomQuality(qualityName) {
    _ensureLoaded()
    var idx = -1
    for (var i = 0; i < _customQualities.length; i++) {
        if (_customQualities[i] === qualityName) { idx = i; break }
    }
    if (idx < 0) return false
    _customQualities.splice(idx, 1)
    delete CHORD_SCALE_MAP[qualityName]
    return true
}

// Get the list of custom qualities.
function getCustomQualities() {
    _ensureLoaded()
    return _customQualities.slice()
}

// === Internal helpers ===

// Convert a scale name to its registry ID. Returns "" if not found.
function _nameToId(name) {
    for (var id in _scaleRegistry) {
        if (_scaleRegistry[id].name === name) return id
    }
    return ""
}

// Generate a slug ID from a name.
function _slugify(name) {
    return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
}

// Validate an intervals array: all integers 0-11, sorted ascending, no duplicates.
function _validateIntervals(intervals) {
    for (var i = 0; i < intervals.length; i++) {
        var v = intervals[i]
        if (typeof v !== "number" || v < 0 || v > 11 || v !== Math.floor(v)) return false
        if (i > 0 && v <= intervals[i - 1]) return false  // must be sorted, no dups
    }
    return true
}

// === Existing public API (unchanged signatures) ===

// Note names for display (sharps for sharp keys, flats for flat keys)
var NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
var SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
var SHARP_ROOTS = {"C#":1, "D":1, "E":1, "F#":1, "G":1, "A":1, "B":1}

// Semitone offset for a root note
var ROOT_SEMITONES = {"C":0,"C#":1,"Db":1,"D":2,"D#":3,"Eb":3,"E":4,"F":5,"F#":6,"Gb":6,"G":7,"G#":8,"Ab":8,"A":9,"A#":10,"Bb":10,"B":11}

// Get compatible scales for a chord quality.
// Returns array of { name: string, intervals: [int] }
function getScalesForQuality(quality) {
    _ensureLoaded()
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
    _ensureLoaded()
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
    _ensureLoaded()
    var matches = []
    for (var name in SCALES) {
        if (voicingFitsScale(voicingSemitones, SCALES[name])) {
            matches.push(name)
        }
    }
    return matches
}

// Get the notes of a scale transposed to a given root.
// Returns { notes: ["F", "G", "A", "Bb", "C", "D", "Eb"], intervals: ["1", "2", "3", "4", "5", "6", "b7"] }
function getScaleNotes(scaleName, root) {
    _ensureLoaded()
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
// E.g., "Cmaj7 -> Ionian, Lydian"
function formatScaleSuggestion(root, quality) {
    _ensureLoaded()
    var names = getScaleNames(quality)
    if (names.length === 0) return ""
    return root + " " + names.join(", ")
}
