.pragma library

// ExclusionEngine.js — per-tuning-per-mode voicing exclusion with user
// overrides (#210 Stage 2).
//
// Given a voicing + tolerances + user overrides, returns either null
// (voicing is visible) or {dimension, message} naming the first failing
// dimension. Ordering chosen for UX meaningfulness — the most actionable
// reason wins so the user sees something useful in the "Hidden (N)" UI.
//
// Tolerances shape (per-tuning-per-mode, with mode-level fallback):
//   {
//     maxFret:             int (e.g. 12),
//     maxStretch:          int (e.g. 5),                  // absolute fret span
//     maxMutedStrings:     int (e.g. 3),
//     minSoundingNotes:    int (e.g. 3),
//     requireRootInBass:   bool,
//     allowOpenStrings:    bool,
//     maxDifficultyTier:   "standard" | "advanced" | "expert",
//     excludedCategories:  [string, ...]                  // category names to exclude
//   }
//
// User overrides shape: { "<signatureKey>": "include" | "exclude" }
//
// Opts shape:
//   {
//     signatureKeyFn: function(voicing) -> string,   // typically ChordSelector.signatureKey
//     difficultyFn:   function(voicing) -> { tier: "..." }  // typically FingeringEngine.computeDifficulty
//   }

// Dimension priority — first failure wins. User override > category >
// difficulty > mute-count > stretch > maxFret > min-notes > root-in-bass
// > open-strings. Ordering picks the most user-meaningful reason first
// (a category exclusion is a clearer story than "9th finger barre too hard").
var DIMENSION_ORDER = [
    "userOverride",
    "excludedCategories",
    "maxDifficultyTier",
    "maxMutedStrings",
    "maxStretch",
    "maxFret",
    "minSoundingNotes",
    "requireRootInBass",
    "allowOpenStrings"
]

var TIER_RANK = { "standard": 0, "advanced": 1, "expert": 2 }

function _absoluteFrets(voicing) {
    var fretNumber = voicing.fret_number || 0
    var dots = voicing.dots || []
    var fretted = []
    for (var i = 0; i < dots.length; i++) {
        var f = fretNumber + (dots[i].fret - 1)
        if (f > 0) fretted.push(f)
    }
    return fretted
}

function _bassInterval(voicing) {
    // Bass = highest-numbered string that is sounding (fretted or open).
    var mutes = voicing.mutes || []
    var dots = voicing.dots || []
    var opens = voicing.open || []
    var intervals = voicing.intervals || []
    var bassStr = 0
    var bassIdx = -1
    for (var d = 0; d < dots.length; d++) {
        if (mutes.indexOf(dots[d].string) >= 0) continue
        if (dots[d].string > bassStr) { bassStr = dots[d].string; bassIdx = d }
    }
    // Open strings can also be the bass when lower-numbered than fretted notes
    // BUT open strings are usually fretted-equivalent at the same string; only
    // count opens that aren't muted.
    for (var o = 0; o < opens.length; o++) {
        if (mutes.indexOf(opens[o]) >= 0) continue
        if (opens[o] > bassStr) {
            bassStr = opens[o]
            // Open strings don't always have a parallel intervals entry — assume root
            // if no specific record. This is a known approximation: voicings.json
            // open-string voicings carry intervals in alphabetical/index order so
            // we can't index parallel here. Caller should not enable requireRootInBass
            // on voicings where opens are present without a richer schema.
            bassIdx = -1
            // Try to find a matching open interval. Some voicings tag opens'
            // intervals at the end of the intervals array; we don't reliably know.
            // For Stage 2, treat unknown-bass-from-open as "passes" (no exclude).
        }
    }
    if (bassIdx >= 0 && bassIdx < intervals.length) return intervals[bassIdx]
    return null  // unknown / no information — caller treats as passing
}

// Returns null if voicing is visible; otherwise { dimension, message }.
function evaluateExclusion(voicing, tolerances, userOverrides, opts) {
    if (!voicing) return null
    opts = opts || {}

    // --- userOverride (highest priority) ---
    if (userOverrides && opts.signatureKeyFn) {
        var sig = opts.signatureKeyFn(voicing)
        if (sig && userOverrides[sig] === "exclude") {
            return { dimension: "userOverride", message: "user-excluded" }
        }
        if (sig && userOverrides[sig] === "include") {
            return null  // allowlist wins over all subsequent checks
        }
    }

    if (!tolerances) return null

    // --- excludedCategories ---
    if (tolerances.excludedCategories && voicing.category) {
        for (var ec = 0; ec < tolerances.excludedCategories.length; ec++) {
            if (tolerances.excludedCategories[ec] === voicing.category) {
                return {
                    dimension: "excludedCategories",
                    message: "category: " + voicing.category + " excluded by mode"
                }
            }
        }
    }

    // --- maxDifficultyTier ---
    if (tolerances.maxDifficultyTier && opts.difficultyFn) {
        var diff = opts.difficultyFn(voicing)
        var voicingTier = (diff && diff.tier) || "standard"
        var maxRank = TIER_RANK[tolerances.maxDifficultyTier]
        var voicingRank = TIER_RANK[voicingTier]
        if (maxRank !== undefined && voicingRank !== undefined && voicingRank > maxRank) {
            return {
                dimension: "maxDifficultyTier",
                message: "difficulty: " + voicingTier + " (mode max: " + tolerances.maxDifficultyTier + ")"
            }
        }
    }

    // --- maxMutedStrings ---
    if (tolerances.maxMutedStrings !== undefined) {
        var muteCount = (voicing.mutes || []).length
        if (muteCount > tolerances.maxMutedStrings) {
            return {
                dimension: "maxMutedStrings",
                message: "mutes: " + muteCount + " > max " + tolerances.maxMutedStrings
            }
        }
    }

    // --- maxStretch ---
    if (tolerances.maxStretch !== undefined) {
        var fretted = _absoluteFrets(voicing)
        if (fretted.length >= 2) {
            var minF = Math.min.apply(null, fretted)
            var maxF = Math.max.apply(null, fretted)
            var span = maxF - minF + 1  // span in frets, inclusive
            if (span > tolerances.maxStretch) {
                return {
                    dimension: "maxStretch",
                    message: "stretch: " + span + " > max " + tolerances.maxStretch
                }
            }
        }
    }

    // --- maxFret ---
    if (tolerances.maxFret !== undefined) {
        var fretted2 = _absoluteFrets(voicing)
        if (fretted2.length > 0) {
            var maxF2 = Math.max.apply(null, fretted2)
            if (maxF2 > tolerances.maxFret) {
                return {
                    dimension: "maxFret",
                    message: "fret: " + maxF2 + " > max " + tolerances.maxFret
                }
            }
        }
    }

    // --- minSoundingNotes ---
    if (tolerances.minSoundingNotes !== undefined) {
        var sounding = ((voicing.dots || []).length) + ((voicing.open || []).length)
        if (sounding < tolerances.minSoundingNotes) {
            return {
                dimension: "minSoundingNotes",
                message: "sounding: " + sounding + " < min " + tolerances.minSoundingNotes
            }
        }
    }

    // --- requireRootInBass ---
    if (tolerances.requireRootInBass === true) {
        var bassInt = _bassInterval(voicing)
        // bassInt === null means unknown (opens-only voicings without parallel
        // intervals data); treat as passing rather than excluding mysteriously.
        if (bassInt !== null && bassInt !== "1") {
            return {
                dimension: "requireRootInBass",
                message: "bass interval: " + bassInt + " (mode requires root in bass)"
            }
        }
    }

    // --- allowOpenStrings ---
    if (tolerances.allowOpenStrings === false) {
        if (voicing.open && voicing.open.length > 0) {
            return {
                dimension: "allowOpenStrings",
                message: "open strings used (mode disallows)"
            }
        }
    }

    return null
}

// Resolve the effective tolerances for (tuning, mode) given a sparse override
// map. Per-tuning-per-mode entries override per-mode entries, which override
// the empty-object default.
//
// toleranceMap shape:
//   {
//     modes: { "chord-melody": {...}, "comping": {...}, ... },
//     tunings: {
//       "baritone": { "chord-melody": {...} },
//       ...
//     }
//   }
function resolveTolerances(toleranceMap, tuningSlug, modeId) {
    var base = {}
    if (!toleranceMap) return base
    // Mode-level defaults.
    if (toleranceMap.modes && toleranceMap.modes[modeId]) {
        var m = toleranceMap.modes[modeId]
        for (var k1 in m) base[k1] = m[k1]
    }
    // Per-tuning-per-mode overrides.
    if (toleranceMap.tunings
            && toleranceMap.tunings[tuningSlug]
            && toleranceMap.tunings[tuningSlug][modeId]) {
        var t = toleranceMap.tunings[tuningSlug][modeId]
        for (var k2 in t) base[k2] = t[k2]
    }
    return base
}
