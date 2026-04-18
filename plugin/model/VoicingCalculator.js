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

    // Find bass strings that can produce the root.
    // Search ALL practical bass strings (bottom half of the instrument),
    // not just the lowest one. This ensures 7-string players get all
    // 6-string voicing shapes (bass on string 6, 5, 4) plus string-7
    // shapes. The maxMutedStrings constraint naturally limits how many
    // strings below the bass get muted.
    var bassCandidates = []
    var maxBassStrings = Math.ceil(numStrings / 2)  // bottom half: strings 7,6,5,4 on 7-str; 6,5,4 on 6-str
    var bassStringsSearched = 0
    for (var bi = 0; bi < stringsLowToHigh.length && bassStringsSearched < maxBassStrings; bi++) {
        var bs = stringsLowToHigh[bi]
        var bOpts = stringOptions[bs]
        for (var bo = 0; bo < bOpts.length; bo++) {
            if (bOpts[bo][0] >= 0 && bOpts[bo][1] === rootPc) {
                bassCandidates.push([bs, bOpts[bo][0]])
            }
        }
        bassStringsSearched++
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

        // T-020: Fret-dependent stretch limits.
        // Lower frets are physically wider, so maxStretch is harder to achieve.
        // Scale: frets 1-3 reduce by 1, frets 4-6 nominal, frets 7+ add 1.
        var effectiveStretch = cfg.maxStretch
        if (bassFret >= 1 && bassFret <= 3) effectiveStretch = Math.max(2, cfg.maxStretch - 1)
        else if (bassFret >= 7) effectiveStretch = cfg.maxStretch + 1

        // Fret range based on bass position
        var fretMin, fretMax
        if (bassFret > 0) {
            fretMin = Math.max(0, bassFret - effectiveStretch)
            fretMax = bassFret + effectiveStretch
        } else {
            fretMin = 0
            fretMax = effectiveStretch + 1
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

            // Check stretch and fingering feasibility
            if (fretted.length > 0) {
                var minF = fretted[0], maxF = fretted[0]
                for (var fi2 = 1; fi2 < fretted.length; fi2++) {
                    if (fretted[fi2] < minF) minF = fretted[fi2]
                    if (fretted[fi2] > maxF) maxF = fretted[fi2]
                }
                if (maxF - minF > effectiveStretch) continue

                // Fingering feasibility: you have 4 fretting fingers.
                // A barre covers one fret across multiple strings = 1 finger.
                // So distinct non-zero fret positions must be ≤ 4.
                var distinctFrets = {}
                for (var df = 0; df < fretted.length; df++) {
                    distinctFrets[fretted[df]] = true
                }
                var numDistinct = 0
                for (var dfk in distinctFrets) numDistinct++
                if (numDistinct > 4) continue
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

            // Fingering feasibility: check that 4 fingers (+ optional thumb)
            // can cover all fretted notes, accounting for barres.
            if (dots.length > 0 && !_isFingeringFeasible(dots, fn, numStrings, mutes)) continue

            // Top note interval for naming
            var topInterval = intervals.length > 0 ? intervals[intervals.length - 1] : "?"

            // Classify category by interval voicing structure
            var sounding = allNotes.length
            var isAltered = qualityId.indexOf("sharp") >= 0 || qualityId.indexOf("b9") >= 0
                || qualityId.indexOf("b13") >= 0 || qualityId.indexOf("b5") >= 0

            var cat = "shell"  // default: 3 notes or fewer
            if (isAltered) {
                cat = "altered"
            } else if (sounding >= 5) {
                cat = "extended"
            } else if (sounding === 4) {
                // Classify drop2 vs drop3 vs close by analyzing voice spacing.
                // Sort sounding notes by MIDI pitch (low to high).
                var midiNotes = []
                for (var mn = 0; mn < allNotes.length; mn++) {
                    midiNotes.push(tuningMidi[String(allNotes[mn][0])] + allNotes[mn][1])
                }
                midiNotes.sort(function(a, b) { return a - b })
                // Intervals between adjacent voices (in semitones)
                var gaps = []
                for (var gi = 1; gi < midiNotes.length; gi++) {
                    gaps.push(midiNotes[gi] - midiNotes[gi - 1])
                }
                // Drop 2: widest gap is between voices 2 and 3 (from top) → gaps[0] is largest
                // Drop 3: widest gap is between voices 3 and 4 (from top) → gaps[1] is largest (when sorted bottom-up, gaps[0])
                var maxGap = Math.max.apply(null, gaps)
                var maxGapIdx = gaps.indexOf(maxGap)
                if (maxGap >= 7 && maxGapIdx === gaps.length - 2) {
                    cat = "drop2"
                } else if (maxGap >= 7 && maxGapIdx <= gaps.length - 3) {
                    cat = "drop3"
                } else if (maxGap <= 5) {
                    cat = "close"
                } else {
                    cat = "spread"
                }
            }

            // Assign contexts: chord melody (CM) for 4+ notes, comping (CV) for 3+
            // String count determines suffix (4, 5, 6, 7)
            var strSuffix = String(numStrings)
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
// @param tuningMidi   — string→MIDI map (e.g. {"1": 57, "2": 52, ...})
// @param constraints  — optional override constraints
// @param progressFn   — optional callback(current, total, phase) for UI progress
function generateAll(tuningMidi, constraints, progressFn) {
    var allVoicings = []
    var defaultQualities = []
    for (var qid in CHORD_QUALITIES) {
        defaultQualities.push(qid)
    }

    // capPerRoot budget: user-specified cap, or 120 default (~10 per root).
    // capPerRoot always runs to ensure top-note diversity and even root distribution.
    var cfg = {}
    for (var cdk in DEFAULT_CONSTRAINTS) cfg[cdk] = DEFAULT_CONSTRAINTS[cdk]
    if (constraints) { for (var cck in constraints) cfg[cck] = constraints[cck] }
    // maxPerQuality: 0 = unlimited (Ted Greene mode), positive = cap, undefined/null = default 120
    var maxPerQ = (typeof cfg.maxPerQuality === "number") ? cfg.maxPerQuality : 120

    var totalQualities = defaultQualities.length

    // Pass 1: root-in-bass voicings
    for (var i = 0; i < defaultQualities.length; i++) {
        if (progressFn) progressFn(i, totalQualities, "root-position")
        var voicings = calculateForQuality(tuningMidi, defaultQualities[i], constraints)
        voicings = capPerRoot(voicings, maxPerQ)
        for (var j = 0; j < voicings.length; j++) {
            allVoicings.push(voicings[j])
        }
    }

    // Pass 2: inversions (non-root bass) for all qualities
    var invConstraints = {}
    for (var dk in DEFAULT_CONSTRAINTS) invConstraints[dk] = DEFAULT_CONSTRAINTS[dk]
    if (constraints) { for (var ck in constraints) invConstraints[ck] = constraints[ck] }
    invConstraints.requireRootInBass = false
    for (var ii = 0; ii < defaultQualities.length; ii++) {
        if (progressFn) progressFn(ii, totalQualities, "inversions")
        var invVoicings = calculateForQuality(tuningMidi, defaultQualities[ii], invConstraints)
        invVoicings = capPerRoot(invVoicings, maxPerQ)
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
    if (progressFn) progressFn(0, 3, "quartal")
    for (var qid in QUARTAL_QUALITIES) {
        var qVoicings = calculateForQuality(tuningMidi, qid, quartalConstraints)
        qVoicings = capPerRoot(qVoicings, maxPerQ)
        for (var qi2 = 0; qi2 < qVoicings.length; qi2++) {
            qVoicings[qi2].category = "quartal"
            qVoicings[qi2].chord_quality = "quartal"
            allVoicings.push(qVoicings[qi2])
        }
    }

    if (progressFn) progressFn(1, 1, "complete")

    // Clean up internal scores
    for (var ci = 0; ci < allVoicings.length; ci++) {
        delete allVoicings[ci]._score
    }

    return allVoicings
}

// Cap voicings per root with diversity across three dimensions:
// 1. Top note — so melody matching works for every possible melody note
// 2. Sounding note count — so shells, drop2s, and extended voicings all appear
// 3. Category — so different voicing types (shell, drop2, close, etc.) are represented
// Without this diversity, voicings using all strings (0 mutes, lowest score)
// crowd out smaller shapes that are often more musical.
function capPerRoot(voicings, maxPerQ) {
    // Group by root
    var byRoot = {}
    for (var i = 0; i < voicings.length; i++) {
        var r = voicings[i].root || "C"
        if (!byRoot[r]) byRoot[r] = []
        byRoot[r].push(voicings[i])
    }
    var rootKeys = Object.keys(byRoot)
    // maxPerQ === 0 means unlimited — return everything. The 20-per-root floor
    // below exists so the diversity phases always have room; it intentionally
    // lifts very small user-supplied caps.
    var perRoot = (maxPerQ === 0)
        ? Infinity
        : Math.max(20, Math.ceil(maxPerQ / Math.max(rootKeys.length, 1)))

    var result = []
    for (var ri = 0; ri < rootKeys.length; ri++) {
        var rootVoicings = byRoot[rootKeys[ri]]
        rootVoicings.sort(function(a, b) { return (a._score || 0) - (b._score || 0) })

        var pickedSet = {}
        var picked = []

        function tryPick(v) {
            if (pickedSet[v.id]) return false
            pickedSet[v.id] = true
            picked.push(v)
            return true
        }

        // Phase 1: one voicing per distinct top note (melody diversity)
        var seenTopNotes = {}
        for (var ti = 0; ti < rootVoicings.length; ti++) {
            var notes = rootVoicings[ti].notes || []
            var topNote = notes.length > 0 ? notes[notes.length - 1] : "?"
            if (!seenTopNotes[topNote]) {
                seenTopNotes[topNote] = true
                tryPick(rootVoicings[ti])
            }
        }

        // Phase 2: one voicing per distinct sounding-note count (3, 4, 5, 6, 7)
        // This ensures shells (3-note), drop2 (4-note), and extended (5+) all appear
        var seenCounts = {}
        for (var ci = 0; ci < rootVoicings.length; ci++) {
            var noteCount = (rootVoicings[ci].notes || []).length
            if (!seenCounts[noteCount]) {
                seenCounts[noteCount] = true
                tryPick(rootVoicings[ci])
            }
        }

        // Phase 3: one voicing per distinct category
        var seenCats = {}
        for (var cai = 0; cai < rootVoicings.length; cai++) {
            var cat = rootVoicings[cai].category || "other"
            if (!seenCats[cat]) {
                seenCats[cat] = true
                tryPick(rootVoicings[cai])
            }
        }

        // Phase 4: fill remaining slots with best-scoring voicings
        for (var fi = 0; fi < rootVoicings.length && picked.length < perRoot; fi++) {
            tryPick(rootVoicings[fi])
        }

        for (var ki = 0; ki < picked.length; ki++) {
            result.push(picked[ki])
        }
    }
    return result
}

// Fingering feasibility check — can 4 fingers (+ optional thumb) cover
// all fretted notes? Uses barre-aware slot counting:
// 1. Group notes by absolute fret
// 2. At the lowest fret, notes on non-adjacent strings that span the full
//    barre range (with intermediate strings at higher frets) count as ONE
//    finger (barre). Other same-fret groups also count as one finger each.
// 3. Above the barre, adjacent strings at the same fret share one finger.
// 4. Total finger slots must be ≤ 4 (or ≤ 5 with thumb on bass string 5+).
// 5. Stretch between lowest and highest fret must not exceed position limits.
//
// This mirrors FingeringEngine.suggestFingering() logic but is a quick
// boolean check without building full assignments.
function _isFingeringFeasible(dots, fretNumber, numStrings, mutes) {
    // Compute absolute frets
    var fretted = []
    for (var i = 0; i < dots.length; i++) {
        var af = fretNumber + (dots[i].fret - 1)
        if (af > 0) fretted.push({ string: dots[i].string, fret: af })
    }
    if (fretted.length === 0) return true

    var minFret = fretted[0].fret
    var maxFret = fretted[0].fret
    for (var m = 1; m < fretted.length; m++) {
        if (fretted[m].fret < minFret) minFret = fretted[m].fret
        if (fretted[m].fret > maxFret) maxFret = fretted[m].fret
    }

    // Stretch check — use Mersenne's Law for mm-based physical limits.
    // Max reach for fingers 1-4 is ~110mm (CombinoChord, Smith 2021).
    var MAX_REACH_MM = 110.0
    var GAMMA = 36.0  // first fret width in mm (25.5" scale)
    var spanMm = 0
    for (var sf = minFret; sf < maxFret; sf++) {
        spanMm += GAMMA / Math.pow(2, (sf - 1) / 12)
    }
    if (spanMm > MAX_REACH_MM) return false

    // Count strings at min fret
    var stringsAtMin = []
    for (var sm = 0; sm < fretted.length; sm++) {
        if (fretted[sm].fret === minFret) stringsAtMin.push(fretted[sm].string)
    }

    // Barre: if ≥2 notes at min fret, they can share finger 1 (barre covers
    // the range from min to max string, with intermediate strings overridden
    // by higher-fret fingers or muted)
    var useBarre = stringsAtMin.length >= 2
    var fingerSlots = 0

    if (useBarre) {
        fingerSlots = 1 // barre = 1 finger
    } else {
        fingerSlots = 1 // single note at min fret = 1 finger
    }

    // Count above-barre slots: group by fret, split non-adjacent strings
    var aboveByFret = {}
    for (var af2 = 0; af2 < fretted.length; af2++) {
        if (fretted[af2].fret > minFret) {
            var fr = fretted[af2].fret
            if (!aboveByFret[fr]) aboveByFret[fr] = []
            aboveByFret[fr].push(fretted[af2].string)
        }
    }
    for (var fk in aboveByFret) {
        var strs = aboveByFret[fk].sort(function(a, b) { return a - b })
        // Count groups of adjacent strings
        var groups = 1
        for (var g = 1; g < strs.length; g++) {
            if (strs[g] - strs[g - 1] > 1) groups++
        }
        fingerSlots += groups
    }

    // Check if we have enough fingers (4, or 5 with thumb)
    if (fingerSlots <= 4) return true

    // Try thumb: if bass-most note is on string 5+ and isolated,
    // removing it might bring slots to ≤ 4
    if (numStrings >= 6) {
        var bassString = 0
        for (var bn = 0; bn < fretted.length; bn++) {
            if (fretted[bn].string > bassString) bassString = fretted[bn].string
        }
        if (bassString >= 5) {
            // Recount without bass note
            var remaining = []
            for (var rn = 0; rn < fretted.length; rn++) {
                if (fretted[rn].string !== bassString) remaining.push(fretted[rn])
            }
            if (remaining.length === 0) return true

            var minF2 = remaining[0].fret
            for (var m2 = 1; m2 < remaining.length; m2++) {
                if (remaining[m2].fret < minF2) minF2 = remaining[m2].fret
            }
            var atMin2 = 0
            for (var am2 = 0; am2 < remaining.length; am2++) {
                if (remaining[am2].fret === minF2) atMin2++
            }
            var slots2 = atMin2 >= 2 ? 1 : 1 // barre or single
            var above2 = {}
            for (var a2 = 0; a2 < remaining.length; a2++) {
                if (remaining[a2].fret > minF2) {
                    var f2 = remaining[a2].fret
                    if (!above2[f2]) above2[f2] = []
                    above2[f2].push(remaining[a2].string)
                }
            }
            for (var fk2 in above2) {
                var strs2 = above2[fk2].sort(function(a, b) { return a - b })
                var grp2 = 1
                for (var g2 = 1; g2 < strs2.length; g2++) {
                    if (strs2[g2] - strs2[g2 - 1] > 1) grp2++
                }
                slots2 += grp2
            }
            if (slots2 <= 4) return true
        }
    }

    return false
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
