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

// Compute a voicing's root-relative fingering signature (#194).
// Matches the shape produced by scripts/derive_curated_shapes.py so the
// curated-shapes.json lookup at scoring time is symmetric.
//
// Returns a string key suitable for object lookup. Format:
//   "<strings>|m:<sorted-mutes>|o:<sorted-opens>|p:<sorted (string,interval) pairs>"
//
// Two voicings with the same root-relative shape produce the same key
// regardless of which root they're transposed to.
function signatureKey(voicing) {
    if (!voicing) return ""
    var strings = voicing.strings || 6
    var mutes = (voicing.mutes || []).slice().sort(function(a, b) { return a - b })
    var opens = (voicing.open || []).slice().sort(function(a, b) { return a - b })
    var dots = voicing.dots || []
    var intervals = voicing.intervals || []
    var pairs = []
    for (var i = 0; i < dots.length; i++) {
        if (i >= intervals.length) continue
        pairs.push([dots[i].string, intervals[i]])
    }
    pairs.sort(function(a, b) {
        if (a[0] !== b[0]) return a[0] - b[0]
        if (a[1] < b[1]) return -1
        if (a[1] > b[1]) return 1
        return 0
    })
    var pairStr = ""
    for (var pi = 0; pi < pairs.length; pi++) {
        if (pi > 0) pairStr += ","
        pairStr += pairs[pi][0] + ":" + pairs[pi][1]
    }
    return strings + "|m:" + mutes.join(",") + "|o:" + opens.join(",") + "|p:" + pairStr
}

// Build a lookup map from a curated-shapes.json payload (#194).
// Returns { signatureKey -> { boost, name, traditions, … } }.
function buildCuratedLookup(curatedPayload) {
    var lookup = {}
    if (!curatedPayload || !curatedPayload.shapes) return lookup
    for (var i = 0; i < curatedPayload.shapes.length; i++) {
        var shape = curatedPayload.shapes[i]
        var sig = shape.signature || {}
        // Reconstruct the same key format signatureKey() produces.
        var strings = sig.strings || 6
        var mutes = (sig.mutes || []).slice().sort(function(a, b) { return a - b })
        var opens = (sig.opens || []).slice().sort(function(a, b) { return a - b })
        var pairs = (sig.pairs || []).slice()
        pairs.sort(function(a, b) {
            if (a[0] !== b[0]) return a[0] - b[0]
            if (a[1] < b[1]) return -1
            if (a[1] > b[1]) return 1
            return 0
        })
        var pairStr = ""
        for (var pi = 0; pi < pairs.length; pi++) {
            if (pi > 0) pairStr += ","
            pairStr += pairs[pi][0] + ":" + pairs[pi][1]
        }
        var key = strings + "|m:" + mutes.join(",") + "|o:" + opens.join(",") + "|p:" + pairStr
        lookup[key] = shape
    }
    return lookup
}

// Union two voicing arrays, deduping by (signatureKey, chord_quality) (#209).
// Curated entries (the first array) win on collision so their hand-curated
// metadata (name, category, traditions, voicingStyle, playStyle) is preserved
// over the calculator's generic equivalents.
//
// Both arrays may contain voicings normalized to C-root (the convention for
// both `voicings.json` and `VoicingCalculator.generateAll` output), so the
// signatureKey is comparable across sources.
function unionVoicings(curated, calculated) {
    var seen = {}
    var out = []
    function addAll(arr) {
        if (!arr) return
        for (var i = 0; i < arr.length; i++) {
            var v = arr[i]
            if (!v) continue
            var key = signatureKey(v) + "|" + (v.chord_quality || "")
            if (seen[key]) continue
            seen[key] = true
            out.push(v)
        }
    }
    addAll(curated)    // first wins on collision — curated metadata preserved
    addAll(calculated)
    return out
}

// Compute a scoring delta from the active mode config (#161).
// Mode config shape (from plugin/config/modes.json):
//   { categoryDeltas, rangeFretMin, rangeFretMax, rangeFretBonus,
//     mutePenaltyPerString, modeMatchBonus, modeMismatchPenalty }
// Caller supplies modeId (the key into the modes map) so we can check
// voicing.suitableModes membership. If modeConfig is null/undefined,
// returns 0 (no effect).
function computeModeDelta(voicing, modeConfig, modeId) {
    if (!modeConfig) return 0
    var delta = 0
    var cd = modeConfig.categoryDeltas || {}
    if (voicing.category && cd[voicing.category] !== undefined) {
        delta += cd[voicing.category]
    }
    var fret = voicing.fret_number || 0
    if (modeConfig.rangeFretMin !== undefined && modeConfig.rangeFretMax !== undefined
        && fret >= modeConfig.rangeFretMin && fret <= modeConfig.rangeFretMax) {
        delta += (modeConfig.rangeFretBonus || 0)
    }
    if (modeConfig.mutePenaltyPerString) {
        var muteCount = voicing.mutes ? voicing.mutes.length : 0
        delta -= muteCount * modeConfig.mutePenaltyPerString
    }
    if (modeId && voicing.suitableModes && voicing.suitableModes.length > 0) {
        if (voicing.suitableModes.indexOf(modeId) >= 0) {
            delta += (modeConfig.modeMatchBonus || 0)
        } else {
            delta += (modeConfig.modeMismatchPenalty || 0)
        }
    }
    return delta
}

// Difficulty memo (#178). FingeringEngine.computeDifficulty is a pure function of
// dots+mutes+open+strings+fret_number, and we call it O(N) times per sort in the
// hot path. Memoize on the voicing's stable identity. Cleared per scoring pass
// to avoid unbounded growth in long-running sessions.
var _difficultyMemo = {}
function _resetDifficultyMemo() { _difficultyMemo = {} }
function _difficultyFor(v, fn) {
    if (!fn) return null
    // Prefer voicing.id when available (curated voicings); fall back to a derived
    // signature for calculator-generated voicings that may have transient ids.
    var key = v.id
    if (!key) {
        var dots = v.dots || []
        var sig = (v.strings || 6) + "|" + (v.fret_number || 0) + "|"
        for (var i = 0; i < dots.length; i++) sig += dots[i].string + ":" + dots[i].fret + ","
        sig += "m:" + (v.mutes || []).join(",") + "|o:" + (v.open || []).join(",")
        key = sig
    }
    if (_difficultyMemo[key] === undefined) {
        _difficultyMemo[key] = fn(v)
    }
    return _difficultyMemo[key]
}

// Score a single voicing candidate against a query context (#164).
// Centralizes the scoring rubric so findBestVoicing and findAllVoicings stay
// in sync. Returns a numeric score (higher = better).
//
// opts carries the full call context: see findBestVoicing for the shape.
function _scoreCandidate(v, targetRoot, quality, melodyTarget, bassTarget, ref, opts) {
    var score = 0

    if (v.chord_quality === quality) score += 20

    // Legacy context scoring boost retired (#174 Stage 1). filterContext still
    // operates as a filter upstream; mode (chord-melody / comping / …) drives
    // the playing-role scoring via modeConfig below.
    if (opts.filterCategory && v.category === opts.filterCategory) score += 50

    if (v.category === "shell") score += 10
    else if (v.category === "drop2") score += 5

    var melMul = (opts.modeConfig && opts.modeConfig.melodyBonusMultiplier !== undefined)
        ? opts.modeConfig.melodyBonusMultiplier : 1.0
    var bassMul = (opts.modeConfig && opts.modeConfig.bassBonusMultiplier !== undefined)
        ? opts.modeConfig.bassBonusMultiplier : 1.0

    if (melodyTarget >= 0 && opts.topNoteFn) {
        var melodyBonus = (opts.melodyLocked ? 500 : 200) * melMul
        if (opts.topNoteFn(v, targetRoot, opts.semitoneMap) === melodyTarget) score += melodyBonus
    }
    if (bassTarget >= 0 && opts.bassNoteFn) {
        var bassBonus = (opts.bassLocked ? 500 : 250) * bassMul
        if (opts.bassNoteFn(v, targetRoot, opts.semitoneMap) === bassTarget) score += bassBonus
    }
    if (ref && opts.distanceFn) {
        score -= opts.distanceFn(ref, v) * 2
        if (ref.category === v.category && ref.fret_number === v.fret_number) score -= 15
    }
    score -= (v.mutes ? v.mutes.length : 0) * 5
    var fret = v.fret_number || 0
    if (fret >= 3 && fret <= 7) score += 5
    if (opts.difficultyFn) {
        // Memoized via _difficultyFor (#178). Same voicing in repeated sort passes
        // (walkthrough re-sort on every step) reuses the prior result instead of
        // re-running suggestFingering's constraint solver.
        var d = _difficultyFor(v, opts.difficultyFn)
        if (d && d.tier === "expert") score -= 30
        else if (d && d.tier === "advanced") score -= 10
    }
    if (opts.profileCategoryWeightFn) score += opts.profileCategoryWeightFn(v.category)
    if (opts.profileQualityBoostFn) score += opts.profileQualityBoostFn(v.chord_quality)
    if (opts.modeConfig) score += computeModeDelta(v, opts.modeConfig, opts.modeId)
    // Curated shape boost (#194 Phase 2a). When a candidate's root-relative
    // fingering signature matches a curated entry, apply the entry's boost.
    // Lookup is built once at startup from curated-shapes.json.
    if (opts.curatedLookup) {
        var entry = opts.curatedLookup[signatureKey(v)]
        if (entry && entry.boost) score += entry.boost
    }
    return score
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

    // Precompute scores once per candidate (#178). Previously the comparator
    // called _scoreCandidate twice per comparison, multiplying difficultyFn
    // and inner callback invocations by N×log(N)×2.
    _resetDifficultyMemo()
    var ranked = new Array(candidates.length)
    for (var k = 0; k < candidates.length; k++) {
        ranked[k] = {
            v: candidates[k],
            s: _scoreCandidate(candidates[k], targetRoot, quality, melodyTarget, bassTarget, ref, opts)
        }
    }
    ranked.sort(function(a, b) { return b.s - a.s })
    return ranked[0].v
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
    var seenShapes = {}  // deduplicate same shape from different contexts
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        if ((v.strings || 6) > maxStrings) continue
        if (v.root !== "C" && v.root !== targetRoot) continue
        if (v.chord_quality === quality || v.category === "quartal") {
            if (opts.filterCategory && v.category !== opts.filterCategory && v.chord_quality === quality) continue
            // Deduplicate by shape
            var dk = ""
            var dots = v.dots || []
            for (var di = 0; di < dots.length; di++) dk += dots[di].string + ":" + dots[di].fret + ","
            var sk = v.chord_quality + "|" + (v.fret_number || 0) + "|" + dk
            if (seenShapes[sk]) continue
            seenShapes[sk] = true
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

    // Precompute scores once per candidate (#178).
    _resetDifficultyMemo()
    var ranked = new Array(candidates.length)
    for (var k = 0; k < candidates.length; k++) {
        ranked[k] = {
            v: candidates[k],
            s: _scoreCandidate(candidates[k], targetRoot, quality, melodyTarget, bassTarget, ref, opts)
        }
    }
    ranked.sort(function(a, b) { return b.s - a.s })
    var out = new Array(ranked.length)
    for (var oi = 0; oi < ranked.length; oi++) out[oi] = ranked[oi].v
    return out
}

// Build bass-string groups from a list of alternative voicings.
// Returns { groups: { stringNum: [voicings] }, list: [sortedStringNums] }
function buildBassStringGroups(altVoicings) {
    var groups = {}
    var list = []
    for (var i = 0; i < altVoicings.length; i++) {
        var v = altVoicings[i]
        var mutes = v.mutes || []
        var bassStr = 0
        // Bass = highest-numbered SOUNDING string (fretted or open, not muted)
        var dots = v.dots || []
        for (var d = 0; d < dots.length; d++) {
            if (dots[d].string > bassStr && mutes.indexOf(dots[d].string) < 0)
                bassStr = dots[d].string
        }
        var opens = v.open || []
        for (var o = 0; o < opens.length; o++) {
            if (opens[o] > bassStr && mutes.indexOf(opens[o]) < 0)
                bassStr = opens[o]
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
