// FingeringEngine.js — Left-hand fingering generation from voicing geometry.
// Extracted from ChordLibrary.qml (Phase 2 decomposition).

// Generate fingering assignments for a voicing.
// Returns array of { string, finger } objects.
// Uses heuristic: lowest fretted note → index finger (1),
// ascending frets → middle (2), ring (3), pinky (4).
// Barre detection: all notes on same fret → all finger 1.
function suggestFingering(voicing) {
    if (!voicing || !voicing.dots || voicing.dots.length === 0) return []

    var fretted = []
    for (var i = 0; i < voicing.dots.length; i++) {
        var d = voicing.dots[i]
        var absFret = voicing.fret_number + (d.fret - 1)
        if (absFret > 0) {
            fretted.push({ string: d.string, fret: absFret, relFret: d.fret })
        }
    }
    fretted.sort(function(a, b) {
        if (a.fret !== b.fret) return a.fret - b.fret
        return b.string - a.string
    })

    // Barre: all notes on same fret
    var allSameFret = fretted.length > 0
    for (var j = 1; j < fretted.length; j++) {
        if (fretted[j].fret !== fretted[0].fret) { allSameFret = false; break }
    }
    if (allSameFret) {
        var barreResult = []
        for (var b = 0; b < fretted.length; b++) {
            barreResult.push({ string: fretted[b].string, finger: 1 })
        }
        return barreResult
    }

    var fretToFinger = {}
    var fingerNum = 1
    var lastFret = -1
    for (var k = 0; k < fretted.length; k++) {
        if (fretted[k].fret !== lastFret) {
            if (fingerNum <= 4) {
                fretToFinger[fretted[k].fret] = fingerNum
                fingerNum++
                lastFret = fretted[k].fret
            }
        }
    }

    var result = []
    for (var m = 0; m < fretted.length; m++) {
        result.push({
            string: fretted[m].string,
            finger: fretToFinger[fretted[m].fret] || 4
        })
    }
    return result
}

// Build a per-string fingering display string like "1-X-1-2-X-X".
// Returns empty string if no dots.
function computeFingeringString(voicing) {
    var dots = voicing.dots || []
    var mutes = voicing.mutes || []
    var opens = voicing.open || []
    var numStrings = voicing.strings || 6
    var fretNumber = voicing.fret_number || 1

    if (dots.length === 0) return ""

    var fretted = []
    for (var d = 0; d < dots.length; d++) {
        fretted.push({
            string: dots[d].string,
            absFret: fretNumber + (dots[d].fret - 1),
        })
    }
    fretted.sort(function(a, b) { return a.absFret - b.absFret })

    var fretGroups = {}
    for (var i = 0; i < fretted.length; i++) {
        if (!fretGroups[fretted[i].absFret])
            fretGroups[fretted[i].absFret] = []
        fretGroups[fretted[i].absFret].push(fretted[i].string)
    }

    var uniqueFrets = Object.keys(fretGroups).sort(function(a, b) { return a - b })
    var fretToFinger = {}
    var fingers = [1, 2, 3, 4]
    for (var f = 0; f < uniqueFrets.length && f < 4; f++) {
        fretToFinger[uniqueFrets[f]] = fingers[f]
    }

    var result = {}
    for (var j = 0; j < fretted.length; j++) {
        result[fretted[j].string] = fretToFinger[fretted[j].absFret] || 1
    }

    var parts = []
    for (var s = numStrings; s >= 1; s--) {
        if (result[s] !== undefined)
            parts.push(String(result[s]))
        else if (mutes.indexOf(s) >= 0)
            parts.push("X")
        else if (opens.indexOf(s) >= 0)
            parts.push("O")
        else
            parts.push("·")
    }
    return parts.join(" ")
}
