.pragma library

// MastersStore.js — load + validate + query the Masters' Lessons bookshelf
// (#220).
//
// Source-of-truth file: plugin/data/masters.json. Authoritative schema:
// schema/masters.schema.json. Each Master may declare legacy `principles[]`
// AND/OR new `systems[]` (#276 Stage A dual-shape window). Per-master
// migration lands in #277-#285; Stage C removes `principles`.
//
// Legacy shape:
//   {
//     version: "v1",
//     masters: [
//       {
//         id, name, lived, traditions: [...], instrument, biography,
//         principles: [
//           {
//             id, name, summary,
//             voicingStyleTags: [...],   // forward-compat for Track 3
//             playStyleTags: [...],
//             applies_to_modes: [...],
//             applies_to_tunings?: [...],
//             tolerance_hints?: { maxStretch?, minSoundingNotes?, ... },
//             references?: [{ source, citation?, url? }],
//             example_voicing_signatures?: [...]
//           }
//         ]
//       }
//     ]
//   }

function emptyStore() {
    return { version: "v1", masters: [] }
}

// Parse raw JSON text into a validated store. On any parse/schema error,
// returns emptyStore() (defensive; UI degrades to "no masters loaded").
function parseStore(raw) {
    if (!raw) return emptyStore()
    try {
        var data = JSON.parse(raw)
        if (!data || typeof data !== "object") return emptyStore()
        if (data.version !== "v1") return emptyStore()
        if (!Array.isArray(data.masters)) return emptyStore()
        return data
    } catch (e) {
        return emptyStore()
    }
}

// Find a master by id; returns null if not found.
function findMaster(store, masterId) {
    if (!store || !store.masters) return null
    for (var i = 0; i < store.masters.length; i++) {
        if (store.masters[i].id === masterId) return store.masters[i]
    }
    return null
}

// Find a principle by (masterId, principleId); returns null if not found.
function findPrinciple(store, masterId, principleId) {
    var master = findMaster(store, masterId)
    if (!master || !master.principles) return null
    for (var i = 0; i < master.principles.length; i++) {
        if (master.principles[i].id === principleId) return master.principles[i]
    }
    return null
}

// Flat list of every principle across all masters, each carrying the
// owning master's id so UI surfaces can render attribution chips.
// Returns [{ masterId, masterName, principle }, ...].
function allPrinciples(store) {
    var out = []
    if (!store || !store.masters) return out
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        var ps = m.principles || []
        for (var j = 0; j < ps.length; j++) {
            out.push({ masterId: m.id, masterName: m.name, principle: ps[j] })
        }
    }
    return out
}

// Principles whose voicingStyleTags include `tag` (e.g. "greene", "drop-2").
// Use by future engine code that wants to find "what does this voicing
// taxonomy tag mean across the bookshelf?"
function principlesByVoicingStyle(store, tag) {
    if (!tag) return []
    var hits = allPrinciples(store)
    var out = []
    for (var i = 0; i < hits.length; i++) {
        var tags = (hits[i].principle.voicingStyleTags) || []
        if (tags.indexOf(tag) >= 0) out.push(hits[i])
    }
    return out
}

// Principles applicable to a given (mode, tuning) combo. tuningSlug
// optional; principle's applies_to_tunings (if present) must include it.
function principlesFor(store, modeId, tuningSlug) {
    var hits = allPrinciples(store)
    var out = []
    for (var i = 0; i < hits.length; i++) {
        var p = hits[i].principle
        var modes = p.applies_to_modes || []
        if (modeId && modes.indexOf(modeId) < 0) continue
        if (tuningSlug && p.applies_to_tunings) {
            if (p.applies_to_tunings.indexOf(tuningSlug) < 0) continue
        }
        out.push(hits[i])
    }
    return out
}

// Collect the union of voicingStyleTags across all principles of one master.
// Returns a deduped array. Used by the scorer to know which voicing tags to
// boost when this master is active (#222 Track 3).
function collectVoicingStyleTags(master) {
    var seen = {}
    var out = []
    if (!master || !master.principles) return out
    for (var i = 0; i < master.principles.length; i++) {
        var tags = master.principles[i].voicingStyleTags || []
        for (var j = 0; j < tags.length; j++) {
            if (!seen[tags[j]]) {
                seen[tags[j]] = true
                out.push(tags[j])
            }
        }
    }
    return out
}

// Derive a single tolerance-hints object from a master's principles by
// folding each principle's tolerance_hints together with "stricter wins"
// semantics (#222 Track 3). Returns null if no principle declared any
// hints (signal to skip the overlay entirely).
function deriveTolerancesFromMaster(master, tightenFn) {
    if (!master || !master.principles) return null
    if (!tightenFn) {
        // Caller forgot to pass the tightener; degrade gracefully by
        // returning the FIRST hint we find (better than nothing).
        for (var ii = 0; ii < master.principles.length; ii++) {
            var h0 = master.principles[ii].tolerance_hints
            if (h0 && Object.keys(h0).length > 0) return h0
        }
        return null
    }
    var combined = null
    for (var i = 0; i < master.principles.length; i++) {
        var h = master.principles[i].tolerance_hints
        if (!h || Object.keys(h).length === 0) continue
        if (combined === null) {
            combined = {}
            for (var k0 in h) combined[k0] = h[k0]
        } else {
            combined = tightenFn(combined, h)
        }
    }
    return combined
}

// Summary counts useful for UI badges.
function counts(store) {
    var c = { masters: 0, principles: 0, systems: 0 }
    if (!store || !store.masters) return c
    c.masters = store.masters.length
    for (var i = 0; i < store.masters.length; i++) {
        c.principles += (store.masters[i].principles || []).length
        c.systems += (store.masters[i].systems || []).length
    }
    return c
}

// --- Systems accessors (#276 Stage A) -----------------------------------
// Each Master may carry a `systems[]` array alongside `principles[]` per
// the dual-shape window in schema/masters.schema.json. Per-master migration
// from principles -> systems lands in #277-#285.

// Flat list of every system across all masters with attribution.
// Returns [{ masterId, masterName, system }, ...].
function allSystems(store) {
    var out = []
    if (!store || !store.masters) return out
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        var ss = m.systems || []
        for (var j = 0; j < ss.length; j++) {
            out.push({ masterId: m.id, masterName: m.name, system: ss[j] })
        }
    }
    return out
}

// Find a system by (masterId, systemId); returns null if not found.
function findSystem(store, masterId, systemId) {
    var master = findMaster(store, masterId)
    if (!master || !master.systems) return null
    for (var i = 0; i < master.systems.length; i++) {
        if (master.systems[i].id === systemId) return master.systems[i]
    }
    return null
}

// Flat list of preferences across systems. If masterId is provided, scope
// to that master; otherwise scan all masters.
// Returns [{ masterId, masterName, systemId, preference }, ...].
function preferencesFor(store, masterId) {
    var out = []
    if (!store || !store.masters) return out
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        if (masterId && m.id !== masterId) continue
        var ss = m.systems || []
        for (var j = 0; j < ss.length; j++) {
            var prefs = ss[j].preferences || []
            for (var k = 0; k < prefs.length; k++) {
                out.push({
                    masterId: m.id,
                    masterName: m.name,
                    systemId: ss[j].id,
                    preference: prefs[k]
                })
            }
        }
    }
    return out
}

// Find the first preference by id across all systems of all masters.
// Returns { masterId, masterName, systemId, preference } or null.
function findPreferenceById(store, preferenceId) {
    if (!preferenceId) return null
    var hits = preferencesFor(store, null)
    for (var i = 0; i < hits.length; i++) {
        if (hits[i].preference && hits[i].preference.id === preferenceId) {
            return hits[i]
        }
    }
    return null
}
