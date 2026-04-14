// FilterEngine.js — Voicing filtering, search, and filter list management.
// Extracted from ChordLibrary.qml (Phase 1 decomposition).
// All functions are pure — they take inputs and return results.

// NOT .pragma library — receives distanceFn callback in applyFilters().

// Rebuild the dynamic filter lists from the current voicing data.
// Returns { contextList, categoryList, qualityList } with "All ..." sentinels.
function rebuildFilterLists(voicingsData) {
    var contexts = {}, categories = {}, qualities = {}
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        if (v.context) contexts[v.context] = true
        if (v.category) categories[v.category] = true
        if (v.chord_quality) qualities[v.chord_quality] = true
    }
    return {
        contextList: ["All Contexts"].concat(Object.keys(contexts).sort()),
        categoryList: ["All Types"].concat(Object.keys(categories).sort()),
        qualityList: ["All Qualities"].concat(Object.keys(qualities).sort())
    }
}

// Apply filters to voicing data and return the filtered array.
//
// @param voicingsData — full voicing array
// @param opts         — {
//   filterContext, filterCategory, filterQuality, searchText,
//   maxStrings, contextStringCounts,
//   sortByProximity, lastInsertedVoicing, distanceFn(a, b)
// }
function applyFilters(voicingsData, opts) {
    var maxStrings = opts.maxStrings || 7
    if (opts.filterContext && opts.contextStringCounts
        && opts.contextStringCounts[opts.filterContext] !== undefined) {
        var contextMax = opts.contextStringCounts[opts.filterContext]
        if (contextMax < maxStrings) maxStrings = contextMax
    }

    // Context matching: CM7 also includes CM6, CM5, CM4 (a 4-string drop2
    // is valid on a 7-string guitar). Extract the context type prefix (CM/CV)
    // and match any context with the same prefix and <= string count.
    var ctxPrefix = ""
    var ctxStrings = 0
    if (opts.filterContext && opts.contextStringCounts) {
        // Extract prefix: "CM7" → "CM", "CV6" → "CV"
        ctxPrefix = opts.filterContext.replace(/[0-9]+$/, "")
        ctxStrings = opts.contextStringCounts[opts.filterContext] || 99
    }

    var result = []
    var seenShapes = {}  // deduplicate by shape (same dots+fret+quality from different contexts)
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        if (opts.filterContext) {
            if (ctxPrefix) {
                // Match same context type with <= string count
                var vPrefix = (v.context || "").replace(/[0-9]+$/, "")
                var vStrings = opts.contextStringCounts[v.context] || 99
                if (vPrefix !== ctxPrefix || vStrings > ctxStrings) continue
            } else {
                if (v.context !== opts.filterContext) continue
            }
        }
        if (opts.filterCategory && v.category !== opts.filterCategory) continue
        if (opts.filterQuality && v.chord_quality !== opts.filterQuality
            && v.chord_quality !== "quartal") continue
        var voicingStrings = v.strings || 6
        if (voicingStrings > maxStrings) continue
        if (opts.searchText) {
            var q = opts.searchText.toLowerCase()
            var match = v.name.toLowerCase().indexOf(q) >= 0
                || v.chord_quality.toLowerCase().indexOf(q) >= 0
                || (v.tags && v.tags.join(" ").toLowerCase().indexOf(q) >= 0)
            if (!match) continue
        }
        // Deduplicate: same shape from different contexts should appear once.
        // Build a shape key from quality + fret + dot positions.
        var dotsKey = ""
        var dots = v.dots || []
        for (var dk = 0; dk < dots.length; dk++) {
            dotsKey += dots[dk].string + ":" + dots[dk].fret + ","
        }
        var shapeKey = v.chord_quality + "|" + (v.fret_number || 0) + "|" + dotsKey + "|" + (v.mutes || []).join(",")
        if (seenShapes[shapeKey]) continue
        seenShapes[shapeKey] = true
        result.push(v)
    }

    if (opts.sortByProximity && opts.lastInsertedVoicing && opts.distanceFn) {
        var ref = opts.lastInsertedVoicing
        var distFn = opts.distanceFn
        result.sort(function(a, b) {
            return distFn(ref, a) - distFn(ref, b)
        })
    }

    return result
}
