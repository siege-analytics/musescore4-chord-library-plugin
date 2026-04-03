// VoicingCalculator.js — Runtime chord voicing generator for any tuning.
// Ported from scripts/chord_calculator.py. Computes geometrically correct
// voicings from actual string MIDI values, fret positions, and playability
// constraints. All voicings are normalized to root C for the plugin's
// transposition pipeline.

.pragma library

var CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

var INTERVAL_LABELS = {
    0: "1", 1: "b9", 2: "9", 3: "b3", 4: "3", 5: "4",
    6: "b5", 7: "5", 8: "#5", 9: "6", 10: "b7", 11: "7"
}

// Chord quality definitions: id → { intervals: [semitones], display: string, minNotes: int }
var CHORD_QUALITIES = {
    // Triads
    "maj":        { intervals: [0, 4, 7], display: "maj", minNotes: 3 },
    "min":        { intervals: [0, 3, 7], display: "min", minNotes: 3 },
    "aug":        { intervals: [0, 4, 8], display: "aug", minNotes: 3 },
    "dim":        { intervals: [0, 3, 6], display: "dim", minNotes: 3 },
    "sus4":       { intervals: [0, 5, 7], display: "sus4", minNotes: 3 },
    "sus2":       { intervals: [0, 2, 7], display: "sus2", minNotes: 3 },
    // 7th chords
    "dom7":       { intervals: [0, 4, 7, 10], display: "7", minNotes: 3 },
    "maj7":       { intervals: [0, 4, 7, 11], display: "maj7", minNotes: 3 },
    "min7":       { intervals: [0, 3, 7, 10], display: "m7", minNotes: 3 },
    "min7b5":     { intervals: [0, 3, 6, 10], display: "m7b5", minNotes: 3 },
    "dim7":       { intervals: [0, 3, 6, 9], display: "dim7", minNotes: 3 },
    "min-maj7":   { intervals: [0, 3, 7, 11], display: "m(maj7)", minNotes: 3 },
    // 6th chords
    "maj6":       { intervals: [0, 4, 7, 9], display: "6", minNotes: 3 },
    "min6":       { intervals: [0, 3, 7, 9], display: "m6", minNotes: 3 },
    // Extended
    "dom9":       { intervals: [0, 2, 4, 10], display: "9", minNotes: 4 },
    "maj9":       { intervals: [0, 2, 4, 11], display: "maj9", minNotes: 4 },
    "min9":       { intervals: [0, 2, 3, 10], display: "m9", minNotes: 4 },
    "dom13":      { intervals: [0, 4, 9, 10], display: "13", minNotes: 4 },
    // Altered dominants
    "dom7b9":     { intervals: [0, 1, 4, 10], display: "7b9", minNotes: 4 },
    "dom7sharp9": { intervals: [0, 3, 4, 10], display: "7#9", minNotes: 4 },
    "dom7sharp11":{ intervals: [0, 4, 6, 10], display: "7#11", minNotes: 4 },
    "dom7b13":    { intervals: [0, 4, 8, 10], display: "7b13", minNotes: 4 },
}

// Quartal voicings — stacked perfect 4ths, defined as pitch class sets.
// These are chord-quality-agnostic: they work over any harmony.
// Multiple sizes: 3-note, 4-note, 5-note quartal stacks.
var QUARTAL_QUALITIES = {
    "quartal3": { intervals: [0, 5, 10], display: "quartal", minNotes: 3 },        // C-F-Bb
    "quartal4": { intervals: [0, 5, 10, 3], display: "quartal", minNotes: 4 },     // C-F-Bb-Eb
    "quartal5": { intervals: [0, 5, 10, 3, 8], display: "quartal", minNotes: 5 },  // C-F-Bb-Eb-Ab
}

// Default calculation constraints
var DEFAULT_CONSTRAINTS = {
    maxFret: 12,
    maxStretch: 4,
    allowOpenStrings: true,
    requireRootInBass: true,
    minSoundingNotes: 3,
    maxMutedStrings: 3,
}

// Calculate voicings for a single chord quality and root, given tuning + constraints.
// Returns array of voicing objects in plugin-compatible format (root C normalized).
//
// @param tuningMidi      — object mapping string number → MIDI value (e.g. {"1": 57, "2": 52, ...})
// @param qualityId       — chord quality ID (e.g. "dom7", "maj7")
// @param constraints     — override object (merged with DEFAULT_CONSTRAINTS)
// @returns array of voicing objects
function calculateForQuality(tuningMidi, qualityId, constraints) {
    var quality = CHORD_QUALITIES[qualityId] || QUARTAL_QUALITIES[qualityId]
    if (!quality) return []

    var cfg = {}
    for (var dk in DEFAULT_CONSTRAINTS) cfg[dk] = DEFAULT_CONSTRAINTS[dk]
    if (constraints) {
        for (var ck in constraints) cfg[ck] = constraints[ck]
    }

    var strings = []
    for (var sk in tuningMidi) strings.push(parseInt(sk))
    strings.sort(function(a, b) { return a - b })  // 1=highest, 6=lowest
    var stringsLowToHigh = strings.slice().reverse()  // 6,5,4,3,2,1
    var numStrings = strings.length

    var results = []
    var bestVoicings = {}  // dedup key → voicing

    // Calculate for all 12 roots — open strings are root-specific
    // and can't be transposed. Each voicing stores its actual root.
    var rootsToCalc = cfg.allowOpenStrings ? [0,1,2,3,4,5,6,7,8,9,10,11] : [0]

  for (var rci = 0; rci < rootsToCalc.length; rci++) {
    var rootPc = rootsToCalc[rci]
    var requiredIntervals = quality.intervals
    var targetPcs = {}
    for (var ri = 0; ri < requiredIntervals.length; ri++) {
        targetPcs[(rootPc + requiredIntervals[ri]) % 12] = true
    }

    // Find which fret positions on each string produce target pitch classes
    var stringOptions = {}
    for (var si = 0; si < strings.length; si++) {
        var s = strings[si]
        var opts = []
        var openPc = tuningMidi[String(s)] % 12
        if (cfg.allowOpenStrings && targetPcs[openPc]) {
            opts.push([0, openPc])
        }
        for (var f = 1; f <= cfg.maxFret; f++) {
            var fretPc = (tuningMidi[String(s)] + f) % 12
            if (targetPcs[fretPc]) {
                opts.push([f, fretPc])
            }
        }
        opts.push([-1, -1])  // muted option
        stringOptions[s] = opts
    }

    // Find bass strings that can produce the root
    var bassCandidates = []
    for (var bi = 0; bi < stringsLowToHigh.length; bi++) {
        var bs = stringsLowToHigh[bi]
        var bOpts = stringOptions[bs]
        for (var bo = 0; bo < bOpts.length; bo++) {
            if (bOpts[bo][0] >= 0 && bOpts[bo][1] === rootPc) {
                bassCandidates.push([bs, bOpts[bo][0]])
            }
        }
        if (bassCandidates.length > 0) break  // only lowest string
    }

    if (!cfg.requireRootInBass) {
        // If root in bass not required, allow any string as bass
        // (for slash chords, inversions)
        if (bassCandidates.length === 0) {
            for (var bi2 = 0; bi2 < stringsLowToHigh.length; bi2++) {
                var bs2 = stringsLowToHigh[bi2]
                var bOpts2 = stringOptions[bs2]
                for (var bo2 = 0; bo2 < bOpts2.length; bo2++) {
                    if (bOpts2[bo2][0] >= 0) {
                        bassCandidates.push([bs2, bOpts2[bo2][0]])
                    }
                }
                if (bassCandidates.length > 0) break
            }
        }
    }

    if (bassCandidates.length === 0) return []

    for (var bci = 0; bci < bassCandidates.length; bci++) {
        var bassString = bassCandidates[bci][0]
        var bassFret = bassCandidates[bci][1]

        // Strings higher-pitched than bass (lower string numbers)
        var remaining = []
        var mutedBelow = []
        for (var rs = 0; rs < strings.length; rs++) {
            if (strings[rs] < bassString) remaining.push(strings[rs])
            else if (strings[rs] > bassString) mutedBelow.push(strings[rs])
        }

        // Fret range based on bass position
        var fretMin, fretMax
        if (bassFret > 0) {
            fretMin = Math.max(0, bassFret - cfg.maxStretch)
            fretMax = bassFret + cfg.maxStretch
        } else {
            fretMin = 0
            fretMax = cfg.maxStretch + 1
        }

        // Filter options for remaining strings
        var filteredOptions = []
        for (var fi = 0; fi < remaining.length; fi++) {
            var fs = remaining[fi]
            var fopts = []
            var rawOpts = stringOptions[fs]
            for (var fo = 0; fo < rawOpts.length; fo++) {
                var fret = rawOpts[fo][0]
                var fpc = rawOpts[fo][1]
                if (fret === -1) { fopts.push([-1, -1]) }
                else if (fret === 0 && cfg.allowOpenStrings) { fopts.push([0, fpc]) }
                else if (fret >= fretMin && fret <= fretMax) { fopts.push([fret, fpc]) }
            }
            if (fopts.length === 0) fopts.push([-1, -1])
            filteredOptions.push({ string: fs, options: fopts })
        }

        // Enumerate combinations (itertools.product equivalent)
        var combos = enumerateCombos(filteredOptions)

        for (var ci = 0; ci < combos.length; ci++) {
            var combo = combos[ci]
            var allNotes = [[bassString, bassFret, rootPc]]
            var fretted = bassFret > 0 ? [bassFret] : []

            for (var ni = 0; ni < combo.length; ni++) {
                var cFret = combo[ni][0]
                var cPc = combo[ni][1]
                var cStr = filteredOptions[ni].string
                if (cFret >= 0) {
                    allNotes.push([cStr, cFret, cPc])
                    if (cFret > 0) fretted.push(cFret)
                }
            }

            // Check minimum sounding notes
            if (allNotes.length < Math.max(cfg.minSoundingNotes, quality.minNotes)) continue

            // Check max muted
            var nMuted = 0
            for (var mi = 0; mi < combo.length; mi++) {
                if (combo[mi][0] === -1) nMuted++
            }
            nMuted += mutedBelow.length
            if (nMuted > cfg.maxMutedStrings) continue

            // Check stretch
            if (fretted.length > 0) {
                var minF = fretted[0], maxF = fretted[0]
                for (var fi2 = 1; fi2 < fretted.length; fi2++) {
                    if (fretted[fi2] < minF) minF = fretted[fi2]
                    if (fretted[fi2] > maxF) maxF = fretted[fi2]
                }
                if (maxF - minF > cfg.maxStretch) continue
            }

            // Check required pitch classes present
            var soundingPcs = {}
            for (var pi = 0; pi < allNotes.length; pi++) {
                soundingPcs[allNotes[pi][2]] = true
            }
            var hasAll = true
            for (var qi = 0; qi < requiredIntervals.length; qi++) {
                if (!soundingPcs[(rootPc + requiredIntervals[qi]) % 12]) {
                    hasAll = false; break
                }
            }
            if (!hasAll) continue

            // Verify root is lowest sounding note (if required)
            if (cfg.requireRootInBass) {
                var bassMidi = tuningMidi[String(bassString)] + bassFret
                var isLowest = true
                for (var li = 1; li < allNotes.length; li++) {
                    var noteMidi = tuningMidi[String(allNotes[li][0])] + allNotes[li][1]
                    if (noteMidi < bassMidi) { isLowest = false; break }
                }
                if (!isLowest) continue
            }

            // Deduplicate by the actual physical shape on the fretboard:
            // quality + which strings are fretted/open/muted + relative fret positions
            // This avoids near-duplicates while keeping genuinely different shapes
            var shapeFingerprint = []
            for (var si2 = 0; si2 < allNotes.length; si2++) {
                shapeFingerprint.push(allNotes[si2][0] + ":" + allNotes[si2][1])
            }
            var dedupKey = qualityId + "|" + shapeFingerprint.sort().join(",")

            var stretch = 0
            if (fretted.length > 0) stretch = maxF - minF
            var score = nMuted * 10 + stretch

            // Skip worse versions of the same shape (check any context variant)
            var anyExists = bestVoicings[dedupKey + "|CV" + (numStrings >= 7 ? "7" : "6")]
            if (anyExists && anyExists._score <= score) continue

            // Build voicing in plugin format
            var fn = (fretted.length > 0) ? minF : 1
            var dots = []
            var notes = []
            var intervals = []
            var mutes = mutedBelow.slice()
            var opens = []

            // Sort allNotes by string number descending (low pitch first)
            allNotes.sort(function(a, b) { return b[0] - a[0] })
            for (var vi = 0; vi < allNotes.length; vi++) {
                var vStr = allNotes[vi][0]
                var vFret = allNotes[vi][1]
                var vPc = allNotes[vi][2]
                notes.push(CHROMATIC[(tuningMidi[String(vStr)] + vFret) % 12])
                intervals.push(INTERVAL_LABELS[(vPc - rootPc + 12) % 12] || "?")
                if (vFret === 0) opens.push(vStr)
                else if (vFret > 0) dots.push({ string: vStr, fret: vFret - fn + 1 })
            }

            for (var mi2 = 0; mi2 < combo.length; mi2++) {
                if (combo[mi2][0] === -1) {
                    var ms = filteredOptions[mi2].string
                    if (mutes.indexOf(ms) < 0) mutes.push(ms)
                }
            }
            mutes.sort(function(a, b) { return a - b })

            // Top note interval for naming
            var topInterval = intervals.length > 0 ? intervals[intervals.length - 1] : "?"

            // Classify category by voicing shape and chord quality
            var sounding = allNotes.length
            var isAltered = qualityId.indexOf("sharp") >= 0 || qualityId.indexOf("b9") >= 0
                || qualityId.indexOf("b13") >= 0 || qualityId.indexOf("b5") >= 0
            var cat = "shell"  // default: 3 notes
            if (isAltered) cat = "altered"
            else if (sounding >= 5) cat = "extended"
            else if (sounding === 4 && stretch <= 3) cat = "drop2"
            else if (sounding === 4) cat = "drop3"

            // Assign contexts: chord melody (CM) for 4+ notes, comping (CV) for 3+
            // String count determines 6 vs 7
            var strSuffix = numStrings >= 7 ? "7" : "6"
            var contexts = []
            if (sounding >= 4) contexts.push("CM" + strSuffix)
            contexts.push("CV" + strSuffix)

            // Emit one voicing per context so it appears in all relevant filters
            for (var ci2 = 0; ci2 < contexts.length; ci2++) {
            var ctx = contexts[ci2]

            var rootName = CHROMATIC[rootPc]
            var voicing = {
                id: "calc-" + qualityId + "-" + rootName + "-f" + fn + "-" + numStrings + "str-" + ctx + "-" + dedupKey.replace(/[,:]/g, ""),
                name: rootName + quality.display + " — Fret " + fn + " — " + cat.charAt(0).toUpperCase() + cat.slice(1) + " (" + topInterval + " on top)",
                chord_quality: qualityId,
                root: rootName,
                category: cat,
                context: ctx,
                strings: numStrings,
                fret_number: fn,
                visible_frets: Math.max(4, dots.length > 0 ? Math.max.apply(null, dots.map(function(d) { return d.fret })) : 4),
                dots: dots,
                mutes: mutes,
                open: opens,
                notes: notes,
                intervals: intervals,
                tags: ["calculated"],
                _score: score
            }
            bestVoicings[dedupKey + "|" + ctx] = voicing
            } // end contexts loop
        }
    }
  } // end roots loop

    // Collect results (keep _score for caller sorting — cleaned up in generateAll)
    for (var key in bestVoicings) {
        results.push(bestVoicings[key])
    }
    return results
}

// Generate voicings for ALL chord qualities the plugin uses.
// Returns a flat array of voicing objects, all root C.
//
// @param tuningMidi  — string→MIDI map (e.g. {"1": 57, "2": 52, ...})
// @param constraints — optional override constraints
function generateAll(tuningMidi, constraints) {
    var allVoicings = []
    var defaultQualities = []
    for (var qid in CHORD_QUALITIES) {
        defaultQualities.push(qid)
    }

    // Pass 1: root-in-bass voicings — uncapped (digital Ted Greene mode)
    for (var i = 0; i < defaultQualities.length; i++) {
        var voicings = calculateForQuality(tuningMidi, defaultQualities[i], constraints)
        for (var j = 0; j < voicings.length; j++) {
            allVoicings.push(voicings[j])
        }
    }

    // Pass 2: inversions (non-root bass) for all qualities — uncapped
    var invConstraints = {}
    for (var dk in DEFAULT_CONSTRAINTS) invConstraints[dk] = DEFAULT_CONSTRAINTS[dk]
    if (constraints) { for (var ck in constraints) invConstraints[ck] = constraints[ck] }
    invConstraints.requireRootInBass = false
    for (var ii = 0; ii < defaultQualities.length; ii++) {
        var invVoicings = calculateForQuality(tuningMidi, defaultQualities[ii], invConstraints)
        for (var ij = 0; ij < invVoicings.length; ij++) {
            allVoicings.push(invVoicings[ij])
        }
    }

    // Pass 3: quartal voicings — use the same geometry engine with quartal pitch classes.
    // Root-in-bass relaxed for quartals since they're not root-oriented.
    var quartalConstraints = {}
    for (var qdk in DEFAULT_CONSTRAINTS) quartalConstraints[qdk] = DEFAULT_CONSTRAINTS[qdk]
    if (constraints) { for (var qck in constraints) quartalConstraints[qck] = constraints[qck] }
    quartalConstraints.requireRootInBass = false
    for (var qid in QUARTAL_QUALITIES) {
        var qVoicings = calculateForQuality(tuningMidi, qid, quartalConstraints)
        // Cap quartal voicings to top 10 per size
        qVoicings.sort(function(a, b) { return (a._score || 0) - (b._score || 0) })
        var qKept = 0
        for (var qi2 = 0; qi2 < qVoicings.length && qKept < 10; qi2++) {
            // Override the category and chord_quality for quartal voicings
            qVoicings[qi2].category = "quartal"
            qVoicings[qi2].chord_quality = "quartal"
            allVoicings.push(qVoicings[qi2])
            qKept++
        }
    }

    // Clean up internal scores
    for (var ci = 0; ci < allVoicings.length; ci++) {
        delete allVoicings[ci]._score
    }

    return allVoicings
}

// Cartesian product of filtered options (replaces itertools.product)
function enumerateCombos(filteredOptions) {
    if (filteredOptions.length === 0) return [[]]
    var results = []
    var maxCombos = 5000  // safety limit

    function recurse(depth, current) {
        if (results.length >= maxCombos) return
        if (depth >= filteredOptions.length) {
            results.push(current.slice())
            return
        }
        var opts = filteredOptions[depth].options
        for (var i = 0; i < opts.length; i++) {
            current.push(opts[i])
            recurse(depth + 1, current)
            current.pop()
        }
    }
    recurse(0, [])
    return results
}
