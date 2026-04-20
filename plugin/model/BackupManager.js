// BackupManager.js — Serialise and restore user-owned data (#172).
// User data = custom tunings, custom styles/compositions, custom scales,
// active-selection settings, hygiene dismissal list. Built-ins are excluded.
//
// Archive shape:
//   {
//     "manifest": { "plugin": "chordlibrary", "version": "v2.2", "exportedAt": ISO },
//     "settings": {...},           // parseable by DataCache.parseSettings
//     "customStyles": [...],       // entries from styles.json where builtin !== true
//     "customScales": [...],       // entries from scales.json where builtin !== true
//     "customTuningFiles": {        // slug -> file contents (JSON-parsed tuning)
//         "baritone-a-a-standard": {...}
//     }
//   }

.pragma library

function buildArchive(opts) {
    // opts: { settings, allStyles, allScales, customTuningSlugs, readTuningFile }
    var custStyles = []
    if (opts.allStyles) {
        for (var i = 0; i < opts.allStyles.length; i++) {
            var s = opts.allStyles[i]
            if (s.builtin) continue
            custStyles.push(s)
        }
    }
    var custScales = []
    if (opts.allScales) {
        for (var j = 0; j < opts.allScales.length; j++) {
            var sc = opts.allScales[j]
            if (sc.builtin) continue
            custScales.push(sc)
        }
    }
    var tuningFiles = {}
    if (opts.customTuningSlugs && opts.readTuningFile) {
        for (var k = 0; k < opts.customTuningSlugs.length; k++) {
            var slug = opts.customTuningSlugs[k]
            try {
                var raw = opts.readTuningFile(slug)
                if (raw) tuningFiles[slug] = JSON.parse(raw)
            } catch (e) {
                // skip unreadable — manifest will show fewer entries
            }
        }
    }
    return {
        manifest: {
            plugin: "chordlibrary",
            version: opts.version || "v2.2",
            exportedAt: new Date().toISOString()
        },
        settings: opts.settings || {},
        customStyles: custStyles,
        customScales: custScales,
        customTuningFiles: tuningFiles
    }
}

function serialize(archive) {
    return JSON.stringify(archive, null, 2)
}

function parseArchive(rawJson) {
    if (!rawJson || rawJson.length === 0) return null
    try {
        var a = JSON.parse(rawJson)
        if (!a.manifest || a.manifest.plugin !== "chordlibrary") return null
        return a
    } catch (e) {
        return null
    }
}

// Merge restore helpers — each returns a summary object {added, updated, skipped}
function mergeStyles(archive, existing) {
    if (!archive || !archive.customStyles) return { added: 0, updated: 0 }
    var existingIds = {}
    for (var i = 0; i < existing.length; i++) existingIds[existing[i].id] = i
    var added = 0, updated = 0
    var out = existing.slice()
    for (var j = 0; j < archive.customStyles.length; j++) {
        var s = archive.customStyles[j]
        if (existingIds[s.id] !== undefined) {
            out[existingIds[s.id]] = s
            updated += 1
        } else {
            out.push(s)
            added += 1
        }
    }
    return { list: out, added: added, updated: updated }
}

function mergeScales(archive, existing) {
    if (!archive || !archive.customScales) return { added: 0, updated: 0 }
    var existingIds = {}
    for (var i = 0; i < existing.length; i++) existingIds[existing[i].id] = i
    var added = 0, updated = 0
    var out = existing.slice()
    for (var j = 0; j < archive.customScales.length; j++) {
        var s = archive.customScales[j]
        if (existingIds[s.id] !== undefined) {
            out[existingIds[s.id]] = s
            updated += 1
        } else {
            out.push(s)
            added += 1
        }
    }
    return { list: out, added: added, updated: updated }
}

function tuningFilesToRestore(archive) {
    if (!archive || !archive.customTuningFiles) return []
    var out = []
    var keys = Object.keys(archive.customTuningFiles)
    for (var i = 0; i < keys.length; i++) {
        out.push({ slug: keys[i], body: archive.customTuningFiles[keys[i]] })
    }
    return out
}
