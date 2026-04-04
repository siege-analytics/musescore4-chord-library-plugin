// FilterEngine.js — Voicing filtering, search, and filter list management.
// Extracted from ChordLibrary.qml (Phase 1 decomposition).
// All functions are pure — they take inputs and return results.

// Note: NOT .pragma library — runs in QML component context to avoid
// cross-boundary issues with callback functions.

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

    var result = []
    for (var i = 0; i < voicingsData.length; i++) {
        var v = voicingsData[i]
        if (opts.filterContext && v.context !== opts.filterContext) continue
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
