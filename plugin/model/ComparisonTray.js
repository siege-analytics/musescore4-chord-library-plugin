.pragma library

// ComparisonTray.js — side-by-side voicing comparison state machine (#196).
//
// Pure-JS state container for the comparison tray. The tray holds up to
// `CAPACITY` voicings; adding a (CAPACITY+1)th evicts the oldest (FIFO).
// Adding a voicing already in the tray is a no-op (re-clicking "Compare"
// on the same card does not duplicate). The tray identifies voicings by
// `voicing.id`; voicings without an id are still accepted but compared by
// reference.

var CAPACITY = 3

function emptyTray() {
    return []
}

function _sameVoicing(a, b) {
    if (!a || !b) return false
    if (a.id && b.id) return a.id === b.id
    return a === b
}

function contains(tray, voicing) {
    if (!tray || !voicing) return false
    for (var i = 0; i < tray.length; i++) {
        if (_sameVoicing(tray[i], voicing)) return true
    }
    return false
}

// Add a voicing to the tray. Returns a NEW array (caller swaps assignment
// — QML property bindings rely on identity change to fire updates).
//   - if already present, returns the same array unchanged
//   - if at capacity, drops the oldest (index 0) and appends
function add(tray, voicing) {
    if (!voicing) return tray || []
    if (contains(tray, voicing)) return tray
    var next = (tray || []).slice()
    next.push(voicing)
    while (next.length > CAPACITY) next.shift()
    return next
}

// Remove the voicing at `index`. Returns a NEW array.
function removeAt(tray, index) {
    if (!tray || index < 0 || index >= tray.length) return tray || []
    var next = tray.slice()
    next.splice(index, 1)
    return next
}

// Remove voicing by id (or reference). Returns a NEW array.
function removeVoicing(tray, voicing) {
    if (!tray || !voicing) return tray || []
    for (var i = 0; i < tray.length; i++) {
        if (_sameVoicing(tray[i], voicing)) return removeAt(tray, i)
    }
    return tray
}

// Empty the tray. Returns a NEW (empty) array.
function clear() {
    return []
}
