.pragma library

// RevoiceMemory.js — Persistent per-chord voicing choices across walkthrough
// sessions (#197).
//
// Memory shape:
//   {
//     version: "v1",
//     scopes: {
//       "<scopeKey>": {
//         choices: { "<chordSymbol>": "<voicingId>", ... },
//         ts: <millisecond epoch — LRU recency for pruning>
//       },
//       ...
//     }
//   }
//
// Scope key: "(scorePath, mode, style, tuning)" joined; ensures that changing
// any of those axes scopes to a fresh memory (per ticket AC: "Changing the
// mode/style/tuning resets the saved choices"). When the user comes back with
// the same axes, prior choices are restored.

function emptyMemory() {
    return { version: "v1", scopes: {} }
}

function buildScopeKey(scorePath, mode, style, tuning) {
    var sp = scorePath || "<no-path>"
    var m = mode || ""
    var s = style || ""
    var t = tuning || ""
    return sp + "|m:" + m + "|s:" + s + "|t:" + t
}

function _ensureScope(memory, scopeKey) {
    if (!memory.scopes) memory.scopes = {}
    if (!memory.scopes[scopeKey]) memory.scopes[scopeKey] = { choices: {}, ts: 0 }
    return memory.scopes[scopeKey]
}

// Record a per-chord choice. Mutates memory in place and returns it.
function recordChoice(memory, scopeKey, chordSymbol, voicingId, timestamp) {
    if (!memory) memory = emptyMemory()
    if (!chordSymbol || !voicingId) return memory
    var scope = _ensureScope(memory, scopeKey)
    scope.choices[chordSymbol] = voicingId
    scope.ts = timestamp || Date.now()
    return memory
}

// Retrieve a saved voicing id for (scopeKey, chordSymbol), or null.
// Updates the scope's recency on hit (so frequently-used scopes survive prune).
function getChoice(memory, scopeKey, chordSymbol, timestamp) {
    if (!memory || !memory.scopes) return null
    var scope = memory.scopes[scopeKey]
    if (!scope || !scope.choices) return null
    var id = scope.choices[chordSymbol]
    if (id) scope.ts = timestamp || Date.now()
    return id || null
}

// Remove a single scope (e.g., "Clear saved choices" for the current scope).
function clearScope(memory, scopeKey) {
    if (!memory || !memory.scopes) return memory || emptyMemory()
    delete memory.scopes[scopeKey]
    return memory
}

// Remove all scopes (full wipe — for tests, settings reset).
function clearAll() {
    return emptyMemory()
}

// Serialize, then drop oldest scopes (lowest ts) until under maxBytes.
// Returns the pruned memory. Acceptance #4 requires < 100KB.
function pruneToSize(memory, maxBytes) {
    if (!memory || !memory.scopes) return memory || emptyMemory()
    var serialized = JSON.stringify(memory)
    if (serialized.length <= maxBytes) return memory
    // Sort scope keys ascending by ts (oldest first) and drop until under budget.
    var keys = Object.keys(memory.scopes)
    keys.sort(function(a, b) {
        return (memory.scopes[a].ts || 0) - (memory.scopes[b].ts || 0)
    })
    while (keys.length > 0 && JSON.stringify(memory).length > maxBytes) {
        var oldest = keys.shift()
        delete memory.scopes[oldest]
    }
    return memory
}

// Parse a JSON string into a valid memory object, returning emptyMemory() on
// failure or schema mismatch (defensive against corrupt settings file).
function parseMemory(raw) {
    if (!raw) return emptyMemory()
    try {
        var m = JSON.parse(raw)
        if (!m || typeof m !== "object") return emptyMemory()
        if (m.version !== "v1") return emptyMemory()
        if (!m.scopes || typeof m.scopes !== "object") return emptyMemory()
        return m
    } catch (e) {
        return emptyMemory()
    }
}
