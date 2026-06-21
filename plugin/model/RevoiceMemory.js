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

// Schema versioning:
//   v1 — choice values are voicing IDs (introduced in #197).
//   v2 — choice values are root-relative signature keys (#211 Stage 3).
//        Stable across voicings.json removal because signatures are
//        computed from the voicing's shape, not from any persisted id.
var CURRENT_VERSION = "v2"

function emptyMemory() {
    return { version: CURRENT_VERSION, scopes: {} }
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
        // Accept both v1 and v2 schemas; caller handles migration when v1.
        if (m.version !== "v1" && m.version !== "v2") return emptyMemory()
        if (!m.scopes || typeof m.scopes !== "object") return emptyMemory()
        return m
    } catch (e) {
        return emptyMemory()
    }
}

// Migrate v1 (id-keyed) memory to v2 (signature-keyed) (#211 Stage 3).
// Caller provides idToSigLookup — a map { voicingId -> signatureKey } built
// from voicings.json one last time before the runtime read paths are dropped.
//
// Mutates `memory` in place AND returns it. Choices whose voicingId can't
// be resolved (e.g. voicing was removed from voicings.json across upgrades)
// are dropped, with a log line per dropped entry returned via the result's
// `droppedIds` array.
//
// No-op if memory is already v2.
function migrateFromV1(memory, idToSigLookup) {
    if (!memory) return emptyMemory()
    if (memory.version === "v2") return memory
    if (memory.version !== "v1") return memory  // unknown — leave alone
    var droppedIds = []
    var scopes = memory.scopes || {}
    for (var scopeKey in scopes) {
        var scope = scopes[scopeKey]
        var choices = (scope && scope.choices) || {}
        var newChoices = {}
        for (var chord in choices) {
            var id = choices[chord]
            var sig = idToSigLookup ? idToSigLookup[id] : null
            if (sig) {
                newChoices[chord] = sig
            } else {
                droppedIds.push({ scopeKey: scopeKey, chordSymbol: chord, voicingId: id })
            }
        }
        scope.choices = newChoices
    }
    memory.version = "v2"
    memory._droppedIds = droppedIds  // surfaced for diagnostic logging
    return memory
}
