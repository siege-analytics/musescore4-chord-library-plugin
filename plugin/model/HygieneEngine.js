// HygieneEngine.js — Library hygiene audit: duplicate detection,
// enharmonic equivalents, cross-context shape matching.
// Extracted from ChordLibrary.qml (Phase 2 decomposition).

// Check if a finding key is in the ignore list.
function isIgnored(key, ignoreList) {
    for (var i = 0; i < ignoreList.length; i++) {
        if (ignoreList[i].key === key) return true
    }
    return false
}

// Build a fingerprint string for a voicing (for exact duplicate detection).
function buildFingerprint(v) {
    var dots = []
    for (var d = 0; d < v.dots.length; d++)
        dots.push(v.dots[d].string + ":" + v.dots[d].fret)
    dots.sort()
    return v.strings + "|" + v.fret_number + "|" + dots.join(",") + "|" + v.context + "|" + v.chord_quality
}

// Run the full hygiene audit.
// Returns { results: string[], duplicates: int, enharmonic: int, crossCtx: int, dismissed: int }
function runAudit(voicingsData, tuningMidi, ignoreList) {
    var results = []
    var duplicates = 0
    var enharmonic = 0
    var crossCtx = 0
    var dismissed = 0

    // 1. Exact duplicates: same dots + fret + strings + context + quality
    var fpMap = {}
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        var fp = buildFingerprint(v)
        if (fpMap[fp]) {
            var dupKey = "DUP:" + v.id + "=" + fpMap[fp]
            if (isIgnored(dupKey, ignoreList)) { dismissed++ } else {
                results.push("DUP: " + v.id + " = " + fpMap[fp])
                duplicates++
            }
        } else {
            fpMap[fp] = v.id
        }
    }

    // 2. Enharmonic equivalents: same pitch class set, different quality
    var pcsMap = {}
    for (var j = 0; j < voicingsData.length; j++) {
        var vv = voicingsData[j]
        var pcs = []
        for (var dd = 0; dd < vv.dots.length; dd++) {
            var strNum = vv.dots[dd].string
            var strMidi = tuningMidi[String(strNum)]
            if (strMidi !== undefined) {
                var absFret = vv.fret_number + (vv.dots[dd].fret - 1)
                pcs.push((strMidi + absFret) % 12)
            }
        }
        for (var oo = 0; oo < (vv.open || []).length; oo++) {
            var openMidi = tuningMidi[String(vv.open[oo])]
            if (openMidi !== undefined) pcs.push(openMidi % 12)
        }
        pcs.sort()
        var pcsKey = pcs.join(",")
        if (!pcsMap[pcsKey]) pcsMap[pcsKey] = []
        pcsMap[pcsKey].push({ id: vv.id, quality: vv.chord_quality })
    }
    for (var pk in pcsMap) {
        var group = pcsMap[pk]
        if (group.length > 1) {
            var quals = {}
            for (var g = 0; g < group.length; g++) quals[group[g].quality] = true
            if (Object.keys(quals).length > 1) {
                var ids = group.map(function(x) { return x.id + "(" + x.quality + ")" })
                var enhKey = "ENH:" + pk
                if (isIgnored(enhKey, ignoreList)) { dismissed++ } else {
                    results.push("ENHARMONIC: " + ids.join(" = "))
                    enharmonic++
                }
            }
        }
    }

    // 3. Cross-context: same shape in different contexts
    var shapeMap = {}
    for (var k = 0; k < voicingsData.length; k++) {
        var vvv = voicingsData[k]
        var sdots = []
        for (var sd = 0; sd < vvv.dots.length; sd++)
            sdots.push(vvv.dots[sd].string + ":" + vvv.dots[sd].fret)
        sdots.sort()
        var shapeFp = vvv.strings + "|" + sdots.join(",")
        if (!shapeMap[shapeFp]) shapeMap[shapeFp] = []
        shapeMap[shapeFp].push({ id: vvv.id, context: vvv.context })
    }
    for (var sk in shapeMap) {
        var sgroup = shapeMap[sk]
        if (sgroup.length > 1) {
            var ctxs = {}
            for (var sg = 0; sg < sgroup.length; sg++) ctxs[sgroup[sg].context] = true
            if (Object.keys(ctxs).length > 1) {
                var sids = sgroup.map(function(x) { return x.id + "(" + x.context + ")" })
                var ctxKey = "CTX:" + sk
                if (isIgnored(ctxKey, ignoreList)) { dismissed++ } else {
                    results.push("CROSS-CTX: " + sids.join(" | "))
                    crossCtx++
                }
            }
        }
    }

    return { results: results, duplicates: duplicates, enharmonic: enharmonic, crossCtx: crossCtx, dismissed: dismissed }
}

// Remove exact duplicates. Returns { cleaned: voicing[], removed: int }.
function dedup(voicingsData) {
    var seen = {}
    var removed = 0
    var cleaned = []
    for (var i = 0; i < voicingsData.length; i++) {
        var fp = buildFingerprint(voicingsData[i])
        if (seen[fp]) {
            removed++
        } else {
            seen[fp] = voicingsData[i].id
            cleaned.push(voicingsData[i])
        }
    }
    return { cleaned: cleaned, removed: removed }
}

// Build the text audit report. Returns the report string.
function buildReport(voicingsData, tuningLabel, ignoreCount, lastResults) {
    var report = "CHORD LIBRARY AUDIT REPORT\n"
        + "=".repeat(60) + "\n"
        + "Date:     " + new Date().toISOString().split("T")[0] + "\n"
        + "Voicings: " + voicingsData.length + "\n"
        + "Tuning:   " + tuningLabel + "\n"
        + "Dismissed: " + ignoreCount + " findings suppressed\n"
        + "=".repeat(60) + "\n\n"

    var dups = [], enhs = [], ctxs = []
    for (var i = 0; i < lastResults.length; i++) {
        var r = lastResults[i]
        if (r.indexOf("DUP:") === 0) dups.push(r)
        else if (r.indexOf("ENHARMONIC:") === 0) enhs.push(r)
        else if (r.indexOf("CROSS-CTX:") === 0) ctxs.push(r)
    }

    if (dups.length > 0) {
        report += "EXACT DUPLICATES (" + dups.length + ")\n"
            + "-".repeat(40) + "\n"
            + "Same dots + fret + context + quality. Click 'Fix Duplicates' in the\n"
            + "plugin to remove these automatically.\n\n"
        for (var d = 0; d < dups.length; d++) {
            var dupKey = "DUP:" + dups[d].substring(5).replace(/ /g, "")
            report += "  " + dups[d] + "\n"
            report += "    DISMISS KEY: " + dupKey + "\n\n"
        }
    }

    if (enhs.length > 0) {
        report += "ENHARMONIC EQUIVALENTS (" + enhs.length + ")\n"
            + "-".repeat(40) + "\n"
            + "Same pitch classes, different chord quality name.\n"
            + "Usually legitimate (e.g., C6 and Am7 share the same notes).\n"
            + "If both names make sense, dismiss the finding.\n\n"
        for (var e = 0; e < enhs.length; e++) {
            var enhKey = "ENH:" + enhs[e].substring(12, 30).replace(/ /g, "")
            report += "  " + enhs[e] + "\n"
            report += "    DISMISS KEY: " + enhKey + "\n\n"
        }
    }

    if (ctxs.length > 0) {
        report += "CROSS-CONTEXT MATCHES (" + ctxs.length + ")\n"
            + "-".repeat(40) + "\n"
            + "Same shape in different contexts (CM6 vs CV6). Expected — same shape,\n"
            + "different musical purpose. Informational only.\n\n"
        for (var c = 0; c < ctxs.length; c++) {
            var ctxKey = "CTX:" + ctxs[c].substring(11, 30).replace(/ /g, "")
            report += "  " + ctxs[c] + "\n"
            report += "    DISMISS KEY: " + ctxKey + "\n\n"
        }
    }

    if (lastResults.length === 0) {
        report += "No issues found. Library is clean.\n"
    }

    report += "\n" + "=".repeat(60) + "\n"
        + "HOW TO ACT ON FINDINGS\n"
        + "-".repeat(40) + "\n"
        + "DUPLICATES: Click 'Fix Duplicates' in the plugin to auto-remove.\n"
        + "DISMISS:    Copy a DISMISS KEY from above, paste it into the\n"
        + "            'Dismiss' field in Settings > Library Health, click Dismiss.\n"
        + "RESET:      Click 'Reset All Dismissed' to un-suppress everything.\n"

    return report
}
