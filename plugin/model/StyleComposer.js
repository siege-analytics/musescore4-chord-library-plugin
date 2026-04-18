// StyleComposer.js — Blend multiple style entries into a single effective style
// per #162. Consumers (ChordSelector/MelodyEngine) see a plain style object
// regardless of whether the user selected one style or a composition.
//
// Numeric rules (categoryWeights, qualityBoosts):
//   weighted-sum : final = clamp( Σ(weight_i × delta_i) )
//   max          : final = strongest-absolute-value opinion per field
//   average      : final = Σ(weight_i × delta_i) / Σ(weight_i)
//
// Scale rules (chordScaleOverrides):
//   union-priority : concat in weight-desc order, dedupe, first wins
//   intersect      : only scales present in every contributing style
//   first-only     : scales from the single highest-weighted style
//
// Resolution:
//   re-resolve : recompute from base styles at call time (follows base edits)
//   freeze     : snapshot resolved deltas at save time (stable)
//
// Call `resolve(composition, allStyles)` to get the effective style. Pass a
// style that carries no `composedFrom` through — it's already the shape callers
// expect.

.pragma library

var _EMPTY = { chordScaleOverrides: {}, categoryWeights: {}, qualityBoosts: {} }

function _clone(obj) {
    return obj ? JSON.parse(JSON.stringify(obj)) : {}
}

function _findStyle(id, allStyles) {
    for (var i = 0; i < allStyles.length; i++) {
        if (allStyles[i].id === id) return allStyles[i]
    }
    return null
}

function _clamp(v, bounds) {
    if (!bounds || bounds.length !== 2) return v
    if (v < bounds[0]) return bounds[0]
    if (v > bounds[1]) return bounds[1]
    return v
}

// Collect contributing style entries paired with their weights, sorted descending.
function _contributors(composition, allStyles) {
    var from = composition.composedFrom || []
    var weights = (composition.composition && composition.composition.weights) || {}
    var out = []
    for (var i = 0; i < from.length; i++) {
        var id = from[i]
        var s = _findStyle(id, allStyles)
        if (!s) continue
        var w = (weights[id] !== undefined) ? weights[id] : 1.0
        if (w <= 0) continue
        out.push({ style: s, weight: w, id: id })
    }
    out.sort(function(a, b) { return b.weight - a.weight })
    return out
}

// Apply one of the numeric-rule strategies to a pair of fields — key-by-key merge.
function _mergeNumeric(contributors, fieldName, rule, clamp) {
    var result = {}
    if (contributors.length === 0) return result

    // Collect all keys across contributors
    var keys = {}
    for (var i = 0; i < contributors.length; i++) {
        var src = contributors[i].style[fieldName] || {}
        for (var k in src) keys[k] = true
    }

    for (var key in keys) {
        var vals = []
        var weights = []
        for (var ci = 0; ci < contributors.length; ci++) {
            var c = contributors[ci]
            var v = (c.style[fieldName] || {})[key]
            if (v === undefined) continue
            vals.push(v)
            weights.push(c.weight)
        }
        if (vals.length === 0) continue

        var final = 0
        if (rule === "max") {
            // Strongest absolute-value wins (preserves sign of that opinion).
            var bestAbs = -1
            var best = 0
            for (var mi = 0; mi < vals.length; mi++) {
                var a = Math.abs(vals[mi])
                if (a > bestAbs) { bestAbs = a; best = vals[mi] }
            }
            final = best
        } else if (rule === "average") {
            var sumW = 0, sumV = 0
            for (var ai = 0; ai < vals.length; ai++) {
                sumV += vals[ai] * weights[ai]
                sumW += weights[ai]
            }
            final = sumW > 0 ? (sumV / sumW) : 0
        } else {
            // weighted-sum (default)
            for (var si = 0; si < vals.length; si++) {
                final += vals[si] * weights[si]
            }
        }
        result[key] = _clamp(Math.round(final), clamp)
    }
    return result
}

// Merge chordScaleOverrides per scale-rule.
function _mergeScales(contributors, rule) {
    var result = {}
    if (contributors.length === 0) return result

    // first-only takes the highest-weighted style's entire overrides map —
    // other contributors' qualities don't leak in.
    if (rule === "first-only") {
        var top = contributors[0].style.chordScaleOverrides || {}
        for (var tq in top) result[tq] = top[tq].slice()
        return result
    }

    var qualities = {}
    for (var ci = 0; ci < contributors.length; ci++) {
        var src = contributors[ci].style.chordScaleOverrides || {}
        for (var q in src) qualities[q] = true
    }

    for (var qual in qualities) {
        var lists = []
        for (var cj = 0; cj < contributors.length; cj++) {
            var arr = (contributors[cj].style.chordScaleOverrides || {})[qual]
            if (arr && arr.length) lists.push({ weight: contributors[cj].weight, scales: arr })
        }
        if (lists.length === 0) continue

        if (rule === "intersect") {
            var inter = lists[0].scales.slice()
            for (var li = 1; li < lists.length; li++) {
                inter = inter.filter(function(x) { return lists[li].scales.indexOf(x) >= 0 })
            }
            if (inter.length > 0) result[qual] = inter
        } else {
            // union-priority (default) — concat in weight-desc order, dedupe, first wins
            var seen = {}
            var union = []
            for (var ui = 0; ui < lists.length; ui++) {
                var scales = lists[ui].scales
                for (var sj = 0; sj < scales.length; sj++) {
                    if (!seen[scales[sj]]) {
                        seen[scales[sj]] = true
                        union.push(scales[sj])
                    }
                }
            }
            result[qual] = union
        }
    }
    return result
}

// Resolve a composition (or plain style) into a flat effective style.
// Returns a fresh object with { chordScaleOverrides, categoryWeights, qualityBoosts }.
// For plain styles (no composedFrom), returns a deep clone of the existing fields.
function resolve(composition, allStyles) {
    if (!composition) return _clone(_EMPTY)

    var composedFrom = composition.composedFrom || []
    if (composedFrom.length === 0) {
        // Plain style — return its own deltas.
        return {
            chordScaleOverrides: _clone(composition.chordScaleOverrides || {}),
            categoryWeights: _clone(composition.categoryWeights || {}),
            qualityBoosts: _clone(composition.qualityBoosts || {})
        }
    }

    var compCfg = composition.composition || {}

    // Frozen compositions already store the resolved deltas on the composition
    // itself; just return those instead of recomputing from base styles.
    if (compCfg.resolution === "freeze" && composition.chordScaleOverrides !== undefined) {
        return {
            chordScaleOverrides: _clone(composition.chordScaleOverrides),
            categoryWeights: _clone(composition.categoryWeights || {}),
            qualityBoosts: _clone(composition.qualityBoosts || {})
        }
    }

    var contributors = _contributors(composition, allStyles)
    var numericRule = compCfg.numericRule || "weighted-sum"
    var scaleRule = compCfg.scaleRule || "union-priority"
    var clamp = compCfg.clampNumeric || null

    return {
        chordScaleOverrides: _mergeScales(contributors, scaleRule),
        categoryWeights: _mergeNumeric(contributors, "categoryWeights", numericRule, clamp),
        qualityBoosts: _mergeNumeric(contributors, "qualityBoosts", numericRule, clamp)
    }
}

// Freeze a composition — snapshot the resolved deltas onto the composition itself
// so later deletion of base styles doesn't break it. Returns a new composition
// object with resolution="freeze" and deltas baked in.
function freeze(composition, allStyles) {
    var resolved = resolve(composition, allStyles)
    var frozen = _clone(composition)
    frozen.chordScaleOverrides = resolved.chordScaleOverrides
    frozen.categoryWeights = resolved.categoryWeights
    frozen.qualityBoosts = resolved.qualityBoosts
    frozen.composition = _clone(composition.composition || {})
    frozen.composition.resolution = "freeze"
    return frozen
}

// Find all compositions in allStyles that depend on a given base style id.
// Frozen compositions are excluded — they no longer need their bases.
function findDependents(baseStyleId, allStyles) {
    var deps = []
    for (var i = 0; i < allStyles.length; i++) {
        var s = allStyles[i]
        var cf = s.composedFrom || []
        if (cf.indexOf(baseStyleId) < 0) continue
        var res = (s.composition && s.composition.resolution) || "re-resolve"
        if (res === "freeze") continue
        deps.push(s.id)
    }
    return deps
}
