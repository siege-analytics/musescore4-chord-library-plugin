.pragma library

// MastersStore.js — load + validate + query the Masters' Lessons bookshelf
// (#220).
//
// Source-of-truth file: plugin/data/masters.json. Authoritative schema:
// schema/masters.schema.json. Each Master may declare any of:
//   - principles[]  (#276 Stage A legacy, untouched)
//   - systems[]     (#276 Stage A, for single-method masters like Berklee)
//   - works[]       (#293 Stage A.1, for multi-method masters like Van Eps's
//                    1939 Method vs Harmonic Mechanisms, or Martin Taylor's
//                    multiple books)
// At least one must be present. When a master has works[], its systems live
// inside each work; the engine consults a specific work, not the master.
// Per-master migration lands in #277-#285; Stage C removes `principles`.
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

// Summary counts useful for UI badges. `systems` includes both master-level
// systems and any systems living inside works[].systems.
function counts(store) {
    var c = { masters: 0, principles: 0, systems: 0, works: 0 }
    if (!store || !store.masters) return c
    c.masters = store.masters.length
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        c.principles += (m.principles || []).length
        c.systems += (m.systems || []).length
        var ws = m.works || []
        c.works += ws.length
        for (var j = 0; j < ws.length; j++) {
            c.systems += (ws[j].systems || []).length
        }
    }
    return c
}

// --- Systems accessors (#276 Stage A, extended #293 Stage A.1) ----------
// `allSystems` walks both master.systems and master.works[*].systems. Each
// entry carries workId/workTitle (null for master-level systems) so UI
// surfaces can render per-work provenance.

// Flat list of every system across all masters with attribution.
// Returns [{ masterId, masterName, workId, workTitle, system }, ...].
function allSystems(store) {
    var out = []
    if (!store || !store.masters) return out
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        var ss = m.systems || []
        for (var j = 0; j < ss.length; j++) {
            out.push({
                masterId: m.id, masterName: m.name,
                workId: null, workTitle: null,
                system: ss[j]
            })
        }
        var ws = m.works || []
        for (var w = 0; w < ws.length; w++) {
            var work = ws[w]
            var wss = work.systems || []
            for (var k = 0; k < wss.length; k++) {
                out.push({
                    masterId: m.id, masterName: m.name,
                    workId: work.id, workTitle: work.title,
                    system: wss[k]
                })
            }
        }
    }
    return out
}

// Find a system by (masterId, systemId); checks master.systems first then
// every works[*].systems. Returns null if not found.
function findSystem(store, masterId, systemId) {
    var master = findMaster(store, masterId)
    if (!master) return null
    var ss = master.systems || []
    for (var i = 0; i < ss.length; i++) {
        if (ss[i].id === systemId) return ss[i]
    }
    var ws = master.works || []
    for (var w = 0; w < ws.length; w++) {
        var wss = ws[w].systems || []
        for (var k = 0; k < wss.length; k++) {
            if (wss[k].id === systemId) return wss[k]
        }
    }
    return null
}

// --- Works accessors (#293 Stage A.1) -----------------------------------

// Flat list of every work across all masters with attribution.
// Returns [{ masterId, masterName, work }, ...].
function allWorks(store) {
    var out = []
    if (!store || !store.masters) return out
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        var ws = m.works || []
        for (var j = 0; j < ws.length; j++) {
            out.push({ masterId: m.id, masterName: m.name, work: ws[j] })
        }
    }
    return out
}

// Find a work by (masterId, workId); returns null if not found.
function findWork(store, masterId, workId) {
    var master = findMaster(store, masterId)
    if (!master || !master.works) return null
    for (var i = 0; i < master.works.length; i++) {
        if (master.works[i].id === workId) return master.works[i]
    }
    return null
}

// Systems[] array of a specific work (empty array if work missing or empty).
function systemsForWork(store, masterId, workId) {
    var work = findWork(store, masterId, workId)
    if (!work) return []
    return work.systems || []
}

// Flat list of preferences across systems. If masterId is provided, scope
// to that master; otherwise scan all masters. Walks both master.systems
// and master.works[*].systems.
// Returns [{ masterId, masterName, workId, systemId, preference }, ...].
function preferencesFor(store, masterId) {
    var out = []
    if (!store || !store.masters) return out
    for (var i = 0; i < store.masters.length; i++) {
        var m = store.masters[i]
        if (masterId && m.id !== masterId) continue
        var buckets = [{ workId: null, systems: m.systems || [] }]
        var ws = m.works || []
        for (var w = 0; w < ws.length; w++) {
            buckets.push({ workId: ws[w].id, systems: ws[w].systems || [] })
        }
        for (var b = 0; b < buckets.length; b++) {
            var bk = buckets[b]
            for (var j = 0; j < bk.systems.length; j++) {
                var prefs = bk.systems[j].preferences || []
                for (var k = 0; k < prefs.length; k++) {
                    out.push({
                        masterId: m.id,
                        masterName: m.name,
                        workId: bk.workId,
                        systemId: bk.systems[j].id,
                        preference: prefs[k]
                    })
                }
            }
        }
    }
    return out
}

// Find the first preference by id across all systems of all masters
// (including all works). Returns { masterId, masterName, workId, systemId,
// preference } or null.
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
