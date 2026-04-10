// ChordSelector.js — Chord symbol parsing and voicing selection logic.
// Extracted from ChordLibrary.qml (Phase 1 decomposition).
// All functions are pure — they take inputs and return results.

// NOT .pragma library — receives topNoteFn/bassNoteFn/distanceFn callbacks.

// Quality string normalisation table.
// Maps common chord symbol suffixes to canonical quality IDs.
var qualityMap = {
    "7": "dom7", "maj7": "maj7", "Maj7": "maj7", "M7": "maj7",
    "m7": "min7", "min7": "min7", "-7": "min7",
    "m7b5": "min7b5", "-7b5": "min7b5", "ø7": "min7b5",
    "dim7": "dim7", "o7": "dim7",
    "6": "maj6", "m6": "min6", "-6": "min6",
    "9": "dom9", "maj9": "maj9", "m9": "min9",
    "13": "dom13",
    "7b9": "dom7b9", "7#5": "dom7sharp5", "7b5": "dom7flat5",
    "7alt": "dom7alt", "alt": "dom7alt",
    "sus4": "sus4", "sus2": "sus2",
    "aug7": "aug7", "+7": "aug7",
    "mMaj7": "min-maj7", "m(maj7)": "min-maj7",
    "": "dom7"  // bare "C" = major, but with 7th context we default to dom7
}

// Extract the root note from a chord symbol string.
// Returns null if no valid root found.
// Local copy of Transposer.extractRoot to avoid cross-module dependency.
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

// Parse a chord symbol like "Fmaj7", "Bb7", "D-7b5", "C/E" into
// { root, quality, slashBass?, ambiguous? }.
// Returns null if the input can't be parsed.
function parseChordSymbol(text) {
    if (!text || text.length === 0) return null

    // Check for slash chord notation (e.g. "Cmaj7/E", "F/A")
    var slashBass = null
    var chordPart = text
    var slashIdx = text.lastIndexOf("/")
    if (slashIdx > 0) {
        var afterSlash = text.substring(slashIdx + 1)
        var bassRoot = extractRoot(afterSlash)
        if (bassRoot && afterSlash.trim().length <= 2) {
            slashBass = bassRoot
            chordPart = text.substring(0, slashIdx)
        }
    }

    var root = extractRoot(chordPart)
    if (!root) return null
    var suffix = chordPart.substring(root.length)
    suffix = suffix.replace(/^\s*/, "").replace("Δ", "maj").replace("△", "maj")
        .replace("°", "dim").replace("ø", "m7b5").replace("+", "aug")
        .replace("−", "-")
    var quality = qualityMap[suffix] || null
    if (!quality) {
        if (suffix.indexOf("maj7") >= 0) quality = "maj7"
        else if (suffix.indexOf("m7b5") >= 0 || suffix.indexOf("-7b5") >= 0) quality = "min7b5"
        else if (suffix.indexOf("m7") >= 0 || suffix.indexOf("-7") >= 0) quality = "min7"
        else if (suffix.indexOf("dim") >= 0) quality = "dim7"
        else if (suffix.indexOf("7") >= 0) quality = "dom7"
        else if (suffix.indexOf("m") >= 0 || suffix.indexOf("-") >= 0) quality = "min7"
        else {
            quality = "dom7"
            var result2 = { root: root, quality: quality, ambiguous: true }
            if (slashBass) result2.slashBass = slashBass
            return result2
        }
    }
    var result = { root: root, quality: quality }
    if (slashBass) result.slashBass = slashBass
    return result
}

// Find the best matching voicing for a chord.
//
// @param voicingsData — array of voicing objects
// @param targetRoot   — root note string (e.g. "F", "Bb")
// @param quality      — canonical quality ID (e.g. "dom7", "min7")
// @param opts         — {
//   maxStrings, filterContext, contextStringCounts, filterCategory,
//   melodyMidi, bassMidi, melodyLocked, bassLocked, lastInsertedVoicing,
//   topNoteFn(voicing, root), bassNoteFn(voicing, root), distanceFn(a, b)
// }
function findBestVoicing(voicingsData, targetRoot, quality, opts) {
    var maxStrings = opts.maxStrings || 7
    if (opts.filterContext && opts.contextStringCounts
        && opts.contextStringCounts[opts.filterContext] !== undefined) {
        var contextMax = opts.contextStringCounts[opts.filterContext]
        if (contextMax < maxStrings) maxStrings = contextMax
    }
    var candidates = []
    var quartalCandidates = []
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        if ((v.strings || 6) > maxStrings) continue
        if (v.root !== "C" && v.root !== targetRoot) continue
        if (v.chord_quality === quality) {
            if (opts.filterCategory && v.category !== opts.filterCategory) continue
            candidates.push(v)
        } else if (v.category === "quartal") {
            quartalCandidates.push(v)
        }
    }
    if (candidates.length === 0 && opts.filterCategory) {
        for (var j = 0; j < voicingsData.length; j++) {
            var v2 = voicingsData[j]
            if (v2.chord_quality !== quality) continue
            if (v2.root !== "C" && v2.root !== targetRoot) continue
            if ((v2.strings || 6) > maxStrings) continue
            candidates.push(v2)
        }
    }
    for (var q = 0; q < quartalCandidates.length; q++) {
        candidates.push(quartalCandidates[q])
    }
    if (candidates.length === 0) {
        if (quality !== "dom7") return findBestVoicing(voicingsData, targetRoot, "dom7", opts)
        return null
    }

    var melodyMidi = opts.melodyMidi
    var bassMidi = opts.bassMidi
    var melodyTarget = (melodyMidi !== undefined && melodyMidi >= 0) ? melodyMidi % 12 : -1
    var bassTarget = (bassMidi !== undefined && bassMidi >= 0) ? bassMidi % 12 : -1
    var ref = opts.lastInsertedVoicing

    candidates.sort(function(a, b) {
        var scoreA = 0, scoreB = 0
        if (a.chord_quality === quality) scoreA += 20
        if (b.chord_quality === quality) scoreB += 20
        if (opts.filterContext && a.context === opts.filterContext) scoreA += 100
        if (opts.filterContext && b.context === opts.filterContext) scoreB += 100
        if (opts.filterCategory && a.category === opts.filterCategory) scoreA += 50
        if (opts.filterCategory && b.category === opts.filterCategory) scoreB += 50
        if (a.category === "shell") scoreA += 10
        else if (a.category === "drop2") scoreA += 5
        if (b.category === "shell") scoreB += 10
        else if (b.category === "drop2") scoreB += 5
        if (melodyTarget >= 0 && opts.topNoteFn) {
            var melodyBonus = opts.melodyLocked ? 500 : 200
            if (opts.topNoteFn(a, targetRoot, opts.semitoneMap) === melodyTarget) scoreA += melodyBonus
            if (opts.topNoteFn(b, targetRoot, opts.semitoneMap) === melodyTarget) scoreB += melodyBonus
        }
        if (bassTarget >= 0 && opts.bassNoteFn) {
            var bassBonus = opts.bassLocked ? 500 : 250
            if (opts.bassNoteFn(a, targetRoot, opts.semitoneMap) === bassTarget) scoreA += bassBonus
            if (opts.bassNoteFn(b, targetRoot, opts.semitoneMap) === bassTarget) scoreB += bassBonus
        }
        if (ref && opts.distanceFn) {
            scoreA -= opts.distanceFn(ref, a) * 2
            scoreB -= opts.distanceFn(ref, b) * 2
            // T-022: Penalize consecutive same-shape voicings (same category + fret)
            if (ref.category === a.category && ref.fret_number === a.fret_number) scoreA -= 15
            if (ref.category === b.category && ref.fret_number === b.fret_number) scoreB -= 15
        }
        // T-022: Penalize excessive mutes (prefer fuller voicings)
        scoreA -= (a.mutes ? a.mutes.length : 0) * 5
        scoreB -= (b.mutes ? b.mutes.length : 0) * 5
        // T-022: Register preference — prefer mid-register voicings (frets 3-7)
        var fretA = a.fret_number || 0
        var fretB = b.fret_number || 0
        if (fretA >= 3 && fretA <= 7) scoreA += 5
        if (fretB >= 3 && fretB <= 7) scoreB += 5
        return scoreB - scoreA
    })
    return candidates[0]
}

// Return ALL matching voicings for a chord, sorted by score (best first).
// Same parameter contract as findBestVoicing.
function findAllVoicings(voicingsData, targetRoot, quality, opts) {
    var maxStrings = opts.maxStrings || 7
    if (opts.filterContext && opts.contextStringCounts
        && opts.contextStringCounts[opts.filterContext] !== undefined) {
        var contextMax = opts.contextStringCounts[opts.filterContext]
        if (contextMax < maxStrings) maxStrings = contextMax
    }
    var candidates = []
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        if ((v.strings || 6) > maxStrings) continue
        if (v.root !== "C" && v.root !== targetRoot) continue
        if (v.chord_quality === quality || v.category === "quartal") {
            if (opts.filterCategory && v.category !== opts.filterCategory && v.chord_quality === quality) continue
            candidates.push(v)
        }
    }
    if (candidates.length === 0 && opts.filterCategory) {
        for (var j = 0; j < voicingsData.length; j++) {
            var v2 = voicingsData[j]
            if (v2.chord_quality !== quality && v2.category !== "quartal") continue
            if (v2.root !== "C" && v2.root !== targetRoot) continue
            if ((v2.strings || 6) > maxStrings) continue
            candidates.push(v2)
        }
    }

    var melodyMidi = opts.melodyMidi
    var bassMidi = opts.bassMidi
    var melodyTarget = (melodyMidi !== undefined && melodyMidi >= 0) ? melodyMidi % 12 : -1
    var bassTarget = (bassMidi !== undefined && bassMidi >= 0) ? bassMidi % 12 : -1
    var ref = opts.lastInsertedVoicing

    candidates.sort(function(a, b) {
        var scoreA = 0, scoreB = 0
        if (a.chord_quality === quality) scoreA += 20
        if (b.chord_quality === quality) scoreB += 20
        if (opts.filterContext && a.context === opts.filterContext) scoreA += 100
        if (opts.filterContext && b.context === opts.filterContext) scoreB += 100
        if (opts.filterCategory && a.category === opts.filterCategory) scoreA += 50
        if (opts.filterCategory && b.category === opts.filterCategory) scoreB += 50
        if (a.category === "shell") scoreA += 10
        else if (a.category === "drop2") scoreA += 5
        if (b.category === "shell") scoreB += 10
        else if (b.category === "drop2") scoreB += 5
        if (melodyTarget >= 0 && opts.topNoteFn) {
            var melodyBonus = opts.melodyLocked ? 500 : 200
            if (opts.topNoteFn(a, targetRoot, opts.semitoneMap) === melodyTarget) scoreA += melodyBonus
            if (opts.topNoteFn(b, targetRoot, opts.semitoneMap) === melodyTarget) scoreB += melodyBonus
        }
        if (bassTarget >= 0 && opts.bassNoteFn) {
            var bassBonus = opts.bassLocked ? 500 : 250
            if (opts.bassNoteFn(a, targetRoot, opts.semitoneMap) === bassTarget) scoreA += bassBonus
            if (opts.bassNoteFn(b, targetRoot, opts.semitoneMap) === bassTarget) scoreB += bassBonus
        }
        if (ref && opts.distanceFn) {
            scoreA -= opts.distanceFn(ref, a) * 2
            scoreB -= opts.distanceFn(ref, b) * 2
            if (ref.category === a.category && ref.fret_number === a.fret_number) scoreA -= 15
            if (ref.category === b.category && ref.fret_number === b.fret_number) scoreB -= 15
        }
        scoreA -= (a.mutes ? a.mutes.length : 0) * 5
        scoreB -= (b.mutes ? b.mutes.length : 0) * 5
        var fretA = a.fret_number || 0
        var fretB = b.fret_number || 0
        if (fretA >= 3 && fretA <= 7) scoreA += 5
        if (fretB >= 3 && fretB <= 7) scoreB += 5
        return scoreB - scoreA
    })
    return candidates
}

// Build bass-string groups from a list of alternative voicings.
// Returns { groups: { stringNum: [voicings] }, list: [sortedStringNums] }
function buildBassStringGroups(altVoicings) {
    var groups = {}
    var list = []
    for (var i = 0; i < altVoicings.length; i++) {
        var v = altVoicings[i]
        var bassStr = 0
        var dots = v.dots || []
        for (var d = 0; d < dots.length; d++) {
            if (dots[d].string > bassStr) bassStr = dots[d].string
        }
        var opens = v.open || []
        for (var o = 0; o < opens.length; o++) {
            if (opens[o] > bassStr) bassStr = opens[o]
        }
        if (bassStr === 0) bassStr = v.strings || 6
        if (!groups[bassStr]) {
            groups[bassStr] = []
            list.push(bassStr)
        }
        groups[bassStr].push(v)
    }
    list.sort(function(a, b) { return b - a })
    return { groups: groups, list: list }
}
