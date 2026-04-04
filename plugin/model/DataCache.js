// DataCache.js — Settings and voicing cache serialisation.
// Extracted from ChordLibrary.qml (Phase 1 decomposition).
// Handles parsing and serialisation only — FileIO stays in QML.

// Note: NOT .pragma library — runs in QML component context for
// consistent object handling across QML/JS boundary.

// Parse a voicing cache file. Returns the voicings array, or null on failure.
function parseCache(rawJson) {
    if (!rawJson || rawJson.length <= 2) return null
    try {
        var data = JSON.parse(rawJson)
        var cached = data.voicings || []
        return cached.length > 0 ? cached : null
    } catch (e) {
        return null
    }
}

// Serialise voicing data for writing to the cache file.
function serializeCache(voicingsData) {
    return JSON.stringify({ voicings: voicingsData }, null, 2)
}

// Parse a settings file. Returns a structured settings object with defaults
// for any missing fields.
function parseSettings(rawJson) {
    var defaults = {
        voicingUrl: "",
        diagramPlacement: "above",
        tuning: "standard",
        customTunings: [],
        tuningOrder: [],
        calcMaxFret: 12,
        calcMaxStretch: 4,
        calcAllowOpen: true,
        calcRootInBass: true,
        calcMinNotes: 3,
        calcMaxMuted: 3,
        calcMaxPerQuality: 0
    }
    if (!rawJson || rawJson.length === 0) return defaults
    try {
        var s = JSON.parse(rawJson)
        return {
            voicingUrl: s.voicingUrl || defaults.voicingUrl,
            diagramPlacement: s.diagramPlacement || defaults.diagramPlacement,
            tuning: s.tuning || defaults.tuning,
            customTunings: (s.customTunings && Array.isArray(s.customTunings)) ? s.customTunings : defaults.customTunings,
            tuningOrder: (s.tuningOrder && Array.isArray(s.tuningOrder)) ? s.tuningOrder : defaults.tuningOrder,
            calcMaxFret: s.calcMaxFret !== undefined ? s.calcMaxFret : defaults.calcMaxFret,
            calcMaxStretch: s.calcMaxStretch !== undefined ? s.calcMaxStretch : defaults.calcMaxStretch,
            calcAllowOpen: s.calcAllowOpen !== undefined ? s.calcAllowOpen : defaults.calcAllowOpen,
            calcRootInBass: s.calcRootInBass !== undefined ? s.calcRootInBass : defaults.calcRootInBass,
            calcMinNotes: s.calcMinNotes !== undefined ? s.calcMinNotes : defaults.calcMinNotes,
            calcMaxMuted: s.calcMaxMuted !== undefined ? s.calcMaxMuted : defaults.calcMaxMuted,
            calcMaxPerQuality: s.calcMaxPerQuality !== undefined ? s.calcMaxPerQuality : defaults.calcMaxPerQuality
        }
    } catch (e) {
        return defaults
    }
}

// Serialise a settings object for writing to the settings file.
function serializeSettings(settings) {
    return JSON.stringify(settings, null, 2)
}

// Build the custom tunings list (non-built-in tunings) for persistence.
//
// @param tuningList       — array of all tuning slugs
// @param builtInTunings   — array of built-in tuning slugs
// @param tuningLabels     — { slug: displayName }
// @param tuningStringCounts — { slug: numberOfStrings }
function getCustomTuningsList(tuningList, builtInTunings, tuningLabels, tuningStringCounts) {
    var customs = []
    for (var i = 0; i < tuningList.length; i++) {
        var slug = tuningList[i]
        if (builtInTunings.indexOf(slug) < 0) {
            customs.push({
                slug: slug,
                name: tuningLabels[slug] || slug,
                strings: tuningStringCounts[slug] || 6
            })
        }
    }
    return customs
}

// Merge a saved tuning order with the current tuning list.
// Preserves the saved order, then appends any new built-ins not in the saved list.
function mergeTuningOrder(savedOrder, currentList) {
    var ordered = []
    for (var i = 0; i < savedOrder.length; i++) {
        if (currentList.indexOf(savedOrder[i]) >= 0) {
            ordered.push(savedOrder[i])
        }
    }
    for (var j = 0; j < currentList.length; j++) {
        if (ordered.indexOf(currentList[j]) < 0) {
            ordered.push(currentList[j])
        }
    }
    return ordered
}
