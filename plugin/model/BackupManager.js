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

// Versions this plugin can read on restore (#179). Append as the archive shape
// stabilizes across releases. Anything not in this list returns a structured
// "unsupported-version" error from parseArchive.
var SUPPORTED_VERSIONS = ["v2.2"]
var CURRENT_VERSION = "v2.2"

// Migration registry: { fromVersion: function(archive) -> archive }
// Keyed by the archive's manifest.version. Migrations run in order from the
// archive's declared version up to CURRENT_VERSION. Empty today because v2.2
// is the only supported version; declared structure for future use.
var MIGRATIONS = {}

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
            version: opts.version || CURRENT_VERSION,
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

// Parse + version-check an archive. Returns one of:
//   { ok: true,  archive: <archive>, migrated: <bool> }
//   { ok: false, reason: "empty" }
//   { ok: false, reason: "not-json", detail: <string> }
//   { ok: false, reason: "not-chordlibrary" }
//   { ok: false, reason: "missing-version" }
//   { ok: false, reason: "unsupported-version", detail: <version-string> }
//
// Callers should switch on `reason` to produce user-facing messages. Future
// versions add migrations to MIGRATIONS; an older-but-known version chains
// through the registered migrations until current.
function parseArchive(rawJson) {
    if (!rawJson || rawJson.length === 0) return { ok: false, reason: "empty" }
    var a
    try {
        a = JSON.parse(rawJson)
    } catch (e) {
        return { ok: false, reason: "not-json", detail: String(e) }
    }
    if (!a.manifest || a.manifest.plugin !== "chordlibrary") {
        return { ok: false, reason: "not-chordlibrary" }
    }
    if (!a.manifest.version) {
        return { ok: false, reason: "missing-version" }
    }
    var v = a.manifest.version
    if (SUPPORTED_VERSIONS.indexOf(v) < 0) {
        return { ok: false, reason: "unsupported-version", detail: v }
    }
    // Run any migrations chained from `v` up to CURRENT_VERSION. v2.2 only
    // supports its own version today, so this loop is a no-op until we add
    // entries to MIGRATIONS.
    var migrated = false
    var current = v
    while (current !== CURRENT_VERSION && MIGRATIONS[current]) {
        a = MIGRATIONS[current](a)
        current = a.manifest.version
        migrated = true
    }
    return { ok: true, archive: a, migrated: migrated }
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
