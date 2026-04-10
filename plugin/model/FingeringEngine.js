.pragma library
// FingeringEngine.js — Left-hand fingering generation from voicing geometry.
// Extracted from ChordLibrary.qml (Phase 2 decomposition).
//
// Constraint-based algorithm that respects physical guitar limitations:
// - Full barre detection at lowest fret (covers all intermediate strings)
// - Adjacent-string mini-barres at higher frets
// - Stretch limits by fret position
// - Thumb (T/0) for bass notes when fingers are exhausted
// - Finger ordering: lower fret → lower finger number

// === Physical Hand Model ===
// Based on CombinoChord (Smith 2021, IEEE) inter-finger distance constraints.
// Fret widths computed via Mersenne's Law: width(n) = GAMMA / 2^((n-1)/12)
// where GAMMA is the first fret width (~36mm on a standard 25.5" scale guitar).

var GAMMA = 36.0  // first fret width in mm (standard 25.5" / 648mm scale)

// Fret width in mm at a given fret position (Mersenne's Law).
function fretWidthMm(fret) {
    if (fret <= 0) return GAMMA
    return GAMMA / Math.pow(2, (fret - 1) / 12)
}

// Distance in mm between two frets (sum of fret widths in the span).
function fretDistanceMm(fretLow, fretHigh) {
    if (fretLow >= fretHigh) return 0
    var dist = 0
    for (var f = fretLow; f < fretHigh; f++) {
        dist += fretWidthMm(f)
    }
    return dist
}

// CombinoChord inter-finger distance constraints (mm).
// Source: Smith 2021, IEEE — Table 1.
// Each entry: [minMm, maxMm]
var FINGER_DISTANCE = {
    "1-2": [5.0,  80.0],
    "1-3": [15.0, 95.0],
    "1-4": [25.0, 110.0],
    "2-3": [6.0,  52.0],
    "2-4": [12.0, 69.0],
    "3-4": [8.5,  47.0]
}

// Check whether two fingers at given frets are within physical reach.
// fingerLow/fingerHigh are finger numbers (1-4), fretLow/fretHigh are fret positions.
function isFingerReachValid(fingerLow, fingerHigh, fretLow, fretHigh) {
    if (fingerLow === fingerHigh) return fretLow === fretHigh  // same finger = same fret (barre)
    var key = fingerLow + "-" + fingerHigh
    var limits = FINGER_DISTANCE[key]
    if (!limits) return true  // no constraint data, allow
    var dist = fretDistanceMm(fretLow, fretHigh)
    return dist >= limits[0] && dist <= limits[1]
}

// Maximum stretch in frets between finger 1 and finger 4 at a given fret position,
// derived from the CombinoChord mm model.
function maxStretchAt(fret) {
    var maxMm = FINGER_DISTANCE["1-4"][1]  // 110mm max reach
    var stretch = 0
    var dist = 0
    for (var f = fret; f < fret + 8; f++) {  // try up to 8 frets
        dist += fretWidthMm(f)
        if (dist > maxMm) break
        stretch++
    }
    return stretch
}

// === Barre Type Detection ===
//
// Barre types (from standard to expert):
//   "full"     — flat finger across contiguous strings at one fret
//   "hinge"    — flat on some strings, curled away from others (partial coverage)
//   "tip"      — fingertip presses 2 adjacent lower strings (Ted Greene technique)
//   "diagonal" — angled finger spans 2 adjacent frets on adjacent strings
//                (possible where fret width < ~20mm, i.e., fret 10+)
//
// Each barre has a difficulty weight used in scoring (Phase 4).
var BARRE_DIFFICULTY = {
    "none": 0,
    "full": 1,
    "tip": 2,
    "hinge": 3,
    "diagonal": 4
}

// Average finger width in mm (index finger pad).
// Used to determine if a diagonal barre is physically possible.
var FINGER_WIDTH_MM = 18.0

// Can a diagonal barre work at this fret position?
// Requires fret width ≤ finger width (so the finger can span two frets).
function canDiagonalBarreAt(fret) {
    return fretWidthMm(fret) <= FINGER_WIDTH_MM
}

// Barre capability per finger.
// maxStrings: maximum strings a full barre can cover.
// canHinge: can this finger do a hinge barre (partial, curled on some strings)?
// canTip: can this finger tip-barre 2 adjacent strings?
// canDiagonal: can this finger do a diagonal barre (at narrow enough frets)?
var FINGER_BARRE_CAPS = {
    1: { maxStrings: 6, canHinge: true,  canTip: true,  canDiagonal: true  },
    2: { maxStrings: 3, canHinge: true,  canTip: true,  canDiagonal: true  },
    3: { maxStrings: 3, canHinge: true,  canTip: true,  canDiagonal: false },
    4: { maxStrings: 2, canHinge: false, canTip: false, canDiagonal: false }
}

// Detect the barre type for a finger assignment covering multiple strings/frets.
// Returns { type: "full"|"hinge"|"tip"|"diagonal"|"none", strings: [], frets: [] }
function detectBarreType(finger, stringFretPairs) {
    if (stringFretPairs.length <= 1) return { type: "none", strings: [], frets: [] }

    var caps = FINGER_BARRE_CAPS[finger]
    if (!caps) return { type: "none", strings: [], frets: [] }

    var strings = stringFretPairs.map(function(p) { return p.string })
    var frets = stringFretPairs.map(function(p) { return p.fret })

    // All same fret?
    var allSameFret = true
    for (var i = 1; i < frets.length; i++) {
        if (frets[i] !== frets[0]) { allSameFret = false; break }
    }

    if (allSameFret) {
        // Check adjacency
        var sortedStr = strings.slice().sort(function(a, b) { return a - b })
        var contiguous = true
        for (var j = 1; j < sortedStr.length; j++) {
            if (sortedStr[j] - sortedStr[j - 1] !== 1) { contiguous = false; break }
        }
        if (contiguous && strings.length <= caps.maxStrings) {
            return { type: "full", strings: strings, frets: [frets[0]] }
        }
        if (caps.canHinge) {
            return { type: "hinge", strings: strings, frets: [frets[0]] }
        }
        if (strings.length === 2 && caps.canTip) {
            return { type: "tip", strings: strings, frets: [frets[0]] }
        }
    }

    // Different frets — check for diagonal barre (2 strings, 2 adjacent frets)
    if (stringFretPairs.length === 2 && caps.canDiagonal) {
        var sorted = stringFretPairs.slice().sort(function(a, b) { return a.fret - b.fret })
        var fretDiff = sorted[1].fret - sorted[0].fret
        var strDiff = Math.abs(sorted[1].string - sorted[0].string)
        if (fretDiff === 1 && strDiff === 1 && canDiagonalBarreAt(sorted[0].fret)) {
            return { type: "diagonal", strings: strings, frets: frets }
        }
    }

    return { type: "none", strings: [], frets: [] }
}

// Check whether a set of strings forms a contiguous (adjacent) group.
function stringsAreAdjacent(strings) {
    if (strings.length <= 1) return true
    var sorted = strings.slice().sort(function(a, b) { return a - b })
    for (var i = 1; i < sorted.length; i++) {
        if (sorted[i] - sorted[i - 1] !== 1) return false
    }
    return true
}

// Split a set of strings into groups of adjacent strings.
// e.g. [3,4,6] → [[3,4],[6]]
function splitIntoAdjacentGroups(strings) {
    if (strings.length === 0) return []
    var sorted = strings.slice().sort(function(a, b) { return a - b })
    var groups = [[sorted[0]]]
    for (var i = 1; i < sorted.length; i++) {
        if (sorted[i] - sorted[i - 1] === 1) {
            groups[groups.length - 1].push(sorted[i])
        } else {
            groups.push([sorted[i]])
        }
    }
    return groups
}

// Generate fingering assignments for a voicing.
// Returns array of { string, finger } objects.
// finger: 0 = thumb (T), 1 = index, 2 = middle, 3 = ring, 4 = pinky.
function suggestFingering(voicing) {
    if (!voicing || !voicing.dots || voicing.dots.length === 0) return []

    var numStrings = voicing.strings || 6
    var fretNumber = voicing.fret_number || 1

    // Collect fretted notes with absolute fret positions
    var fretted = []
    for (var i = 0; i < voicing.dots.length; i++) {
        var d = voicing.dots[i]
        var absFret = fretNumber + (d.fret - 1)
        if (absFret > 0) {
            fretted.push({ string: d.string, fret: absFret })
        }
    }
    if (fretted.length === 0) return []

    // Find minimum and maximum fret
    var minFret = fretted[0].fret
    for (var mf = 1; mf < fretted.length; mf++) {
        if (fretted[mf].fret < minFret) minFret = fretted[mf].fret
    }

    // Collect strings at the minimum fret
    var stringsAtMinFret = []
    for (var sm = 0; sm < fretted.length; sm++) {
        if (fretted[sm].fret === minFret) stringsAtMinFret.push(fretted[sm].string)
    }

    // Barre detection: if ≥2 notes at the minimum fret, use a barre.
    // The barre covers ALL strings from min to max string number at that fret,
    // regardless of gaps — intermediate strings are covered by the barre but
    // overridden by higher-fret fingers.
    var useBarre = stringsAtMinFret.length >= 2
    var barreStrings = [] // strings that the barre actually sounds (no higher-fret override)

    if (useBarre) {
        var barreMinStr = Math.min.apply(null, stringsAtMinFret)
        var barreMaxStr = Math.max.apply(null, stringsAtMinFret)

        // The barre covers barreMinStr to barreMaxStr.
        // A string within that range that's fretted at a higher fret is
        // overridden — the barre is underneath but another finger presses harder.
        // A muted string within the barre is dampened (still part of the barre gesture).
        var mutes = voicing.mutes || []
        for (var bs = barreMinStr; bs <= barreMaxStr; bs++) {
            // Is this string fretted at a higher fret?
            var higherFret = false
            for (var hf = 0; hf < fretted.length; hf++) {
                if (fretted[hf].string === bs && fretted[hf].fret > minFret) {
                    higherFret = true
                    break
                }
            }
            // Is this string muted?
            var isMuted = false
            for (var mu = 0; mu < mutes.length; mu++) {
                if (mutes[mu] === bs) { isMuted = true; break }
            }
            // Barre sounds on this string only if it's at the barre fret
            if (!higherFret && !isMuted) {
                barreStrings.push(bs)
            }
        }
    }

    // Collect "above-barre" notes: notes at frets higher than minFret
    var aboveNotes = []
    for (var an = 0; an < fretted.length; an++) {
        if (fretted[an].fret > minFret) {
            aboveNotes.push(fretted[an])
        }
    }

    // If no barre, also include the single note at minFret
    if (!useBarre) {
        // Single note at minFret gets finger 1
        // Above-barre notes get fingers 2+
    }

    // Group above-barre notes by fret, then split into adjacent-string groups
    var aboveByFret = {}
    var aboveFretOrder = []
    for (var af = 0; af < aboveNotes.length; af++) {
        var fr = aboveNotes[af].fret
        if (!aboveByFret[fr]) {
            aboveByFret[fr] = []
            aboveFretOrder.push(fr)
        }
        aboveByFret[fr].push(aboveNotes[af].string)
    }
    aboveFretOrder.sort(function(a, b) { return a - b })

    // Build above-barre slots: each group of adjacent strings at a fret = 1 finger
    var aboveSlots = []
    for (var afi = 0; afi < aboveFretOrder.length; afi++) {
        var aboveFret = aboveFretOrder[afi]
        var groups = splitIntoAdjacentGroups(aboveByFret[aboveFret])
        for (var g = 0; g < groups.length; g++) {
            aboveSlots.push({ fret: aboveFret, strings: groups[g] })
        }
    }

    // Sort above slots: ascending fret, then descending max-string (bass first)
    aboveSlots.sort(function(a, b) {
        if (a.fret !== b.fret) return a.fret - b.fret
        return Math.max.apply(null, b.strings) - Math.max.apply(null, a.strings)
    })

    // Assign fingers
    var result = []
    var nextFinger = 1

    if (useBarre) {
        // Finger 1 = barre
        for (var brs = 0; brs < barreStrings.length; brs++) {
            result.push({ string: barreStrings[brs], finger: 1 })
        }
        nextFinger = 2
    } else {
        // Finger 1 = single note at minFret
        result.push({ string: stringsAtMinFret[0], finger: 1 })
        nextFinger = 2
    }

    // Check if we have enough fingers for above-barre slots
    var fingersNeeded = aboveSlots.length
    var fingersAvailable = 4 - nextFinger + 1 // fingers 2,3,4 = 3 available

    if (fingersNeeded <= fingersAvailable) {
        // Straightforward assignment
        for (var si = 0; si < aboveSlots.length; si++) {
            var slot = aboveSlots[si]
            for (var ss = 0; ss < slot.strings.length; ss++) {
                result.push({ string: slot.strings[ss], finger: nextFinger })
            }
            nextFinger++
        }
    } else {
        // Not enough fingers — try thumb for the bass-most note,
        // then reassign remaining fingers.
        var canUseThumb = false
        var thumbIdx = -1

        // Find the bass-most fretted note (highest string number)
        var bassString = -1
        var bassFret = -1
        for (var bn = 0; bn < fretted.length; bn++) {
            if (fretted[bn].string > bassString) {
                bassString = fretted[bn].string
                bassFret = fretted[bn].fret
            }
        }

        // Thumb is viable if the bass note is on string 5+ (wrap-around)
        // and is somewhat isolated from the rest of the voicing
        if (bassString >= 5) {
            canUseThumb = true
        }

        if (canUseThumb) {
            // Reassign from scratch with thumb on bass note
            return _assignWithThumb(fretted, voicing, bassString, bassFret)
        }

        // Last resort: consolidate same-fret non-adjacent into one finger
        // (the player will use a flat finger or partial barre)
        var consolidated = _consolidateAboveSlots(aboveSlots)
        for (var ci = 0; ci < consolidated.length; ci++) {
            var cSlot = consolidated[ci]
            var finger = nextFinger <= 4 ? nextFinger : 4
            for (var cs = 0; cs < cSlot.strings.length; cs++) {
                result.push({ string: cSlot.strings[cs], finger: finger })
            }
            if (nextFinger <= 4) nextFinger++
        }
    }

    // Detect and annotate barre types on the result
    _annotateBarreTypes(result, fretted)

    // Validate finger-pair distances against CombinoChord model
    _validateFingerReach(result, fretted, minFret)

    // Add stretch warning if overall span exceeds physical limits
    _addStretchWarnings(result, fretted, minFret)

    return result
}

// Reassign fingering with thumb (finger 0) on the specified bass note.
function _assignWithThumb(fretted, voicing, thumbString, thumbFret) {
    var remaining = []
    for (var i = 0; i < fretted.length; i++) {
        if (fretted[i].string === thumbString && fretted[i].fret === thumbFret) continue
        remaining.push(fretted[i])
    }

    var result = [{ string: thumbString, finger: 0 }]

    if (remaining.length === 0) return result

    // Find min fret among remaining
    var minFret = remaining[0].fret
    for (var m = 1; m < remaining.length; m++) {
        if (remaining[m].fret < minFret) minFret = remaining[m].fret
    }

    // Strings at min fret
    var atMin = []
    var aboveMin = []
    for (var r = 0; r < remaining.length; r++) {
        if (remaining[r].fret === minFret) atMin.push(remaining[r])
        else aboveMin.push(remaining[r])
    }

    // Barre or single for finger 1
    if (atMin.length >= 2) {
        var barreMinStr = atMin[0].string
        var barreMaxStr = atMin[0].string
        for (var b = 1; b < atMin.length; b++) {
            if (atMin[b].string < barreMinStr) barreMinStr = atMin[b].string
            if (atMin[b].string > barreMaxStr) barreMaxStr = atMin[b].string
        }
        var mutes = voicing.mutes || []
        for (var bs = barreMinStr; bs <= barreMaxStr; bs++) {
            var overridden = false
            for (var o = 0; o < aboveMin.length; o++) {
                if (aboveMin[o].string === bs) { overridden = true; break }
            }
            var isMuted = false
            for (var mu = 0; mu < mutes.length; mu++) {
                if (mutes[mu] === bs) { isMuted = true; break }
            }
            if (!overridden && !isMuted) {
                result.push({ string: bs, finger: 1 })
            }
        }
    } else {
        result.push({ string: atMin[0].string, finger: 1 })
    }

    // Above-min notes: group by fret, split adjacent
    var byFret = {}
    var fretOrder = []
    for (var af = 0; af < aboveMin.length; af++) {
        var fr = aboveMin[af].fret
        if (!byFret[fr]) { byFret[fr] = []; fretOrder.push(fr) }
        byFret[fr].push(aboveMin[af].string)
    }
    fretOrder.sort(function(a, b) { return a - b })

    var finger = 2
    for (var fi = 0; fi < fretOrder.length; fi++) {
        var groups = splitIntoAdjacentGroups(byFret[fretOrder[fi]])
        for (var g = 0; g < groups.length; g++) {
            var f = finger <= 4 ? finger : 4
            for (var s = 0; s < groups[g].length; s++) {
                result.push({ string: groups[g][s], finger: f })
            }
            if (finger <= 4) finger++
        }
    }

    return result
}

// Merge same-fret slots to reduce total count.
function _consolidateAboveSlots(slots) {
    var byFret = {}
    var fretOrder = []
    for (var i = 0; i < slots.length; i++) {
        var f = slots[i].fret
        if (!byFret[f]) { byFret[f] = []; fretOrder.push(f) }
        for (var s = 0; s < slots[i].strings.length; s++) {
            byFret[f].push(slots[i].strings[s])
        }
    }
    var merged = []
    for (var fi = 0; fi < fretOrder.length; fi++) {
        merged.push({ fret: fretOrder[fi], strings: byFret[fretOrder[fi]] })
    }
    return merged
}

// Annotate barre types on fingering results.
// Groups result entries by finger number, detects barre type for each
// multi-string finger, and adds barreType field to those entries.
function _annotateBarreTypes(result, fretted) {
    // Group by finger
    var byFinger = {}
    for (var i = 0; i < result.length; i++) {
        var f = result[i].finger
        if (f <= 0) continue  // skip thumb
        if (!byFinger[f]) byFinger[f] = []
        // Find absolute fret for this string
        var af = 0
        for (var j = 0; j < fretted.length; j++) {
            if (fretted[j].string === result[i].string) {
                af = fretted[j].fret
                break
            }
        }
        byFinger[f].push({ string: result[i].string, fret: af, resultIdx: i })
    }

    for (var finger in byFinger) {
        var entries = byFinger[finger]
        if (entries.length <= 1) continue

        var pairs = entries.map(function(e) { return { string: e.string, fret: e.fret } })
        var bt = detectBarreType(parseInt(finger), pairs)

        if (bt.type !== "none") {
            for (var k = 0; k < entries.length; k++) {
                result[entries[k].resultIdx].barreType = bt.type
            }
        }
    }
}

// Validate finger-pair distances using the CombinoChord mm model.
// Adds reachWarning flag to result entries where a finger pair exceeds
// its physical distance limits.
function _validateFingerReach(result, fretted, minFret) {
    // Build finger → fret mapping (use the lowest fret for barred fingers)
    var fingerFrets = {}
    for (var i = 0; i < result.length; i++) {
        var f = result[i].finger
        if (f <= 0) continue  // skip thumb
        // Find the absolute fret for this string
        var absFret = -1
        for (var j = 0; j < fretted.length; j++) {
            if (fretted[j].string === result[i].string) {
                absFret = fretted[j].fret
                break
            }
        }
        if (absFret < 0) continue
        if (fingerFrets[f] === undefined || absFret < fingerFrets[f]) {
            fingerFrets[f] = absFret
        }
    }

    // Check each finger pair
    var fingers = Object.keys(fingerFrets).sort(function(a, b) { return a - b })
    for (var fi = 0; fi < fingers.length; fi++) {
        for (var fj = fi + 1; fj < fingers.length; fj++) {
            var fLow = parseInt(fingers[fi])
            var fHigh = parseInt(fingers[fj])
            var fretLow = fingerFrets[fLow]
            var fretHigh = fingerFrets[fHigh]
            if (fretLow > fretHigh) {
                var tmp = fretLow; fretLow = fretHigh; fretHigh = tmp
            }
            if (!isFingerReachValid(fLow, fHigh, fretLow, fretHigh)) {
                // Flag all entries as having a reach issue
                for (var w = 0; w < result.length; w++) {
                    result[w].stretchWarning = true
                }
                return
            }
        }
    }
}

// Add stretchWarning flag to results when span exceeds physical limits.
function _addStretchWarnings(result, fretted, minFret) {
    var maxFret = minFret
    for (var i = 0; i < fretted.length; i++) {
        if (fretted[i].fret > maxFret) maxFret = fretted[i].fret
    }
    var span = maxFret - minFret
    var limit = maxStretchAt(minFret)
    if (span > limit) {
        for (var w = 0; w < result.length; w++) {
            result[w].stretchWarning = true
        }
    }
}

// Build a per-string fingering display string like "1 X 1 2 X X".
// Uses suggestFingering internally for consistency.
// finger 0 (thumb) displays as "T".
// Returns empty string if no dots.
function computeFingeringString(voicing) {
    var dots = voicing.dots || []
    var mutes = voicing.mutes || []
    var opens = voicing.open || []
    var numStrings = voicing.strings || 6

    if (dots.length === 0) return ""

    var assignments = suggestFingering(voicing)

    // Build a map: string → finger label
    var fingerByString = {}
    for (var a = 0; a < assignments.length; a++) {
        var finger = assignments[a].finger
        fingerByString[assignments[a].string] = finger === 0 ? "T" : String(finger)
    }

    var parts = []
    for (var s = numStrings; s >= 1; s--) {
        if (fingerByString[s] !== undefined)
            parts.push(fingerByString[s])
        else if (mutes.indexOf(s) >= 0)
            parts.push("X")
        else if (opens.indexOf(s) >= 0)
            parts.push("O")
        else
            parts.push("·")
    }
    return parts.join(" ")
}
