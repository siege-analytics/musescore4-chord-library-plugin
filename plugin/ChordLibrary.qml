import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import FileIO 3.0
import "ui"
import "model"
import "model/Transposer.js" as Transposer
import "model/MelodyEngine.js" as MelodyEngine
import "model/VoicingCalculator.js" as VoicingCalculator
import "model/ReharmonizationEngine.js" as Reharm
import "model/ChordScales.js" as ChordScales
import "model/ChordSelector.js" as ChordSelector
import "model/FilterEngine.js" as FilterEngine
import "model/DataCache.js" as DataCache
import "model/HygieneEngine.js" as HygieneEngine
import "model/FingeringEngine.js" as FingeringEngine
import "model/BackupManager.js" as BackupManager
import "model/StyleComposer.js" as StyleComposer
import "model/DiagramEngine.js" as DiagramEngine
import "model/IRealParser.js" as IRealParser

MuseScore {
    id: chordLibrary
    title: "Siege Analytics Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "1.5.0"
    pluginType: "dialog"
    requiresScore: true
    categoryCode: "composing-arranging-tools"
    thumbnailName: "thumbnail.svg"

    width: 560
    height: 850

    // System palette for dark mode detection
    SystemPalette { id: palette }

    // Centralized theme palette — all UI colors derive from OS light/dark mode
    QtObject {
        id: theme
        readonly property bool isDark: {
            // Check windowText brightness — in dark mode, text is light
            // More reliable than window background in MuseScore's plugin sandbox
            var fg = palette.windowText
            return (fg.r + fg.g + fg.b) / 3 > 0.5
        }

        // Card / surface colors
        readonly property color cardBackground: isDark ? "#2d2d2d" : "#f5f5f5"
        readonly property color cardHover:      isDark ? "#3a3a3a" : "#e8e8e8"
        readonly property color cardBorder:     isDark ? "#555555" : "#dddddd"

        // Text hierarchy
        readonly property color textPrimary:   isDark ? "#e0e0e0" : "#333333"
        readonly property color textSecondary:  isDark ? "#b0b0b0" : "#666666"
        readonly property color textMuted:      isDark ? "#888888" : "#888888"
        readonly property color textFaint:      isDark ? "#777777" : "#aaaaaa"

        // Status colors
        readonly property color successText: isDark ? "#4caf50" : "#006600"
        readonly property color errorText:   isDark ? "#ef5350" : "#cc0000"

        // Dividers and borders
        readonly property color divider: Qt.rgba(0.5, 0.5, 0.5, isDark ? 0.4 : 0.3)

        // Tool status console background
        readonly property color consoleBg: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)

        // Legend / chip backgrounds
        readonly property color chipBackground: isDark ? Qt.rgba(0.5, 0.5, 0.5, 0.2) : Qt.rgba(0.5, 0.5, 0.5, 0.1)
        readonly property color chipHover:      isDark ? Qt.rgba(0.5, 0.5, 0.5, 0.3) : Qt.rgba(0.5, 0.5, 0.5, 0.2)
        readonly property color chipBorder:     Qt.rgba(0.5, 0.5, 0.5, 0.3)

        // Fretboard canvas (thumbnail in VoicingCard)
        readonly property color fretGrid:   isDark ? "#999999" : "#999999"
        readonly property color fretDot:    isDark ? "#e0e0e0" : "#333333"
        readonly property color fretMute:   isDark ? "#b0b0b0" : "#999999"

        // Interval dot colors — light and dark variants
        readonly property color dotRoot:    isDark ? "#EF5350" : "#D32F2F"
        readonly property color dotThird:   isDark ? "#42A5F5" : "#1976D2"
        readonly property color dotFifth:   isDark ? "#66BB6A" : "#388E3C"
        readonly property color dotSeventh: isDark ? "#FFA726" : "#F57C00"
        readonly property color dotNinth:   isDark ? "#CE93D8" : "#7B1FA2"
        readonly property color dotFourth:  isDark ? "#4DB6AC" : "#00897B"
        readonly property color dotSixth:   isDark ? "#FFEE58" : "#FBC02D"
        readonly property color dotDefault: isDark ? Qt.rgba(0.7, 0.7, 0.7, 0.9) : Qt.rgba(0.3, 0.3, 0.3, 0.9)

        // Interval legend (light mode values — used in the static legend Flow)
        readonly property var legendColors: [
            {label: "R",    color: dotRoot},
            {label: "3",    color: dotThird},
            {label: "5",    color: dotFifth},
            {label: "7",    color: dotSeventh},
            {label: "9",    color: dotNinth},
            {label: "4/11", color: dotFourth},
            {label: "6/13", color: dotSixth}
        ]
    }

    // Data model for hygiene audit results
    ListModel { id: auditResultsModel }

    // === Persistent settings via FileIO ===
    // MuseScore 4 plugins don't support Qt.labs.settings,
    // so we persist to a JSON file in the plugin directory.
    FileIO {
        id: settingsFile
        source: Qt.resolvedUrl("settings.json")
    }

    FileIO {
        id: localCacheFile
        source: Qt.resolvedUrl("data/voicings.json")
    }

    FileIO {
        id: exportFile
    }

    FileIO {
        id: importFile
    }

    FileIO {
        id: tempDiagramFile
    }

    FileIO {
        id: scalesConfigFile
        source: Qt.resolvedUrl("config/scales.json")
    }

    FileIO {
        id: profilesConfigFile
        source: Qt.resolvedUrl("config/styles.json")
    }

    FileIO {
        id: modesConfigFile
        source: Qt.resolvedUrl("config/modes.json")
    }

    FileIO {
        id: backupFile   // (#172) user-data backup / restore
    }

    FileIO {
        id: tuningFile
    }

    FileIO {
        id: tuningCacheFile
    }

    FileIO {
        id: audioFile
        source: Qt.resolvedUrl("play-chord.json")
    }

    // === Centralized state groups (C1, #104) ===

    QtObject {
        id: tuningState
        property string selectedTuning: "7string-van-eps"
        property var tuningList: [
            "standard", "7string-van-eps", "7string-low-b", "dadgad", "all-fourths",
            "baritone"
        ]
        property var tuningLabels: ({
            "standard": "Standard 6-String",
            "7string-van-eps": "Van Eps 7-String (Low A)",
            "7string-low-b": "Low B 7-String",
            "dadgad": "DADGAD 6-String",
            "all-fourths": "All Fourths 6-String",
            "baritone": "Baritone Guitar 6-String (B Standard)"
        })
        property var tuningStringCounts: ({
            "standard": 6, "7string-van-eps": 7, "7string-low-b": 7,
            "dadgad": 6, "all-fourths": 6, "baritone": 6
        })
    }

    QtObject {
        id: calcState
        property int maxFret: 12
        property int maxStretch: 4
        property bool allowOpen: true
        property bool rootInBass: true
        property int minNotes: 3
        property int maxMuted: 3
        property int maxPerQuality: 0
    }

    // Compatibility aliases — existing code references these unqualified
    property alias selectedTuning: tuningState.selectedTuning
    property alias tuningList: tuningState.tuningList
    property alias tuningLabels: tuningState.tuningLabels
    property alias tuningStringCounts: tuningState.tuningStringCounts
    property alias calcMaxFret: calcState.maxFret
    property alias calcMaxStretch: calcState.maxStretch
    property alias calcAllowOpen: calcState.allowOpen
    property alias calcRootInBass: calcState.rootInBass
    property alias calcMinNotes: calcState.minNotes
    property alias calcMaxMuted: calcState.maxMuted
    property alias calcMaxPerQuality: calcState.maxPerQuality

    // Default settings
    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/plugin/data/voicings.json"
    property string diagramPlacement: "above"  // "above" or "below"
    property var filteredTuningList: []
    property var filteredTuningDisplayList: []

    function refreshFilteredTunings() {
        // Context retirement (#174). Previously this capped the tuning list to
        // the current context's string count, which left users with a stale
        // defaultContext (e.g. CM6) unable to see 7-string tunings after we
        // hid the context dropdown. Mode + tuning selection now carry that
        // responsibility; show every tuning here.
        filteredTuningList = tuningList
        var display = []
        for (var d = 0; d < tuningList.length; d++) {
            display.push(tuningLabels[tuningList[d]] || tuningList[d])
        }
        filteredTuningDisplayList = display
    }

    property var voicingsData: []
    property var filteredData: []
    property bool dataLoaded: false
    property var standardVoicingsData: []  // backup of the standard library for tuning switches
    property bool usingTuningVoicings: false  // true when tuning-specific voicings are loaded
    // Tab navigation: 0=Library, 1=ScoreTools, 2=Export, 3=Import, 4=Practice, 5=Settings
    property int currentTab: 0
    property bool showToolResults: false
    property string toolResultsTitle: ""
    property string toolResultsContent: ""

    // Practice mode state
    property var practiceVoicing: null      // current flash card voicing
    property bool practiceShowAnswer: false // whether answer is revealed
    property string practiceMode: "name"   // "name" = guess name, "shape" = guess fretboard
    property int practiceCorrect: 0
    property int practiceTotal: 0

    function practiceNext() {
        if (voicingsData.length === 0) return
        practiceShowAnswer = false
        var idx = Math.floor(Math.random() * voicingsData.length)
        practiceVoicing = voicingsData[idx]
    }

    function practiceReveal() {
        practiceShowAnswer = true
        practiceTotal++
    }

    function practiceMarkCorrect() {
        practiceCorrect++
        practiceNext()
    }

    function practiceMarkWrong() {
        practiceNext()
    }

    function practiceReset() {
        practiceCorrect = 0
        practiceTotal = 0
        practiceNext()
    }

    // Filter state
    property string filterContext: ""
    property string filterCategory: ""
    property string filterQuality: ""
    property string filterScale: ""
    property var _scaleNameList: ["All Scales"]
    property var _profileList: []          // Array of profile objects from profiles.json
    property string _activeProfileId: ""   // ID of the active profile (empty = default)
    property var _modesById: ({})          // Map of modeId -> mode config, from modes.json (#164)
    property string activeMode: "chord-melody"  // active mode (#164) — drives scoring via modeConfig
    // Score-level section overrides (#167). Each entry: { startIdx: int, mode: string, name: string }.
    // The earliest-matching entry with startIdx <= chord index wins. Empty array = whole score uses activeMode.
    property var scoreSections: []
    property string searchText: ""

    // Voice leading state
    property var lastInsertedVoicing: null  // tracks fret position for proximity sort
    property bool sortByProximity: false    // when true, sort filtered results by distance
    property bool melodyOnTop: false         // when true, prefer voicings with melody note as highest voice
    property bool skipDiagramPositions: false // when true, Annotate Staff Text skips positions with existing diagrams
    property string _toolStatusText: ""  // routed to ScoreToolsPanel
    property int melodyStaffIdx: -1  // -1 = same staff, 0+ = specific staff index for melody reading
    property bool writeVoice2: false  // when true, write voicing pitches as notes on voice 2

    // Voicing calculator constraints — backed by calcState QtObject above

    // Returns override melody MIDI pitch (0-11) or -1 if no override set
    function melodyOverrideMidi() {
        return batchEngine.melodyOverrideMidi()
    }

    // Dynamic filter lists (rebuilt when data changes)
    property var contextList: ["All Contexts"]
    property var categoryList: ["All Types"]
    property var qualityList: ["All Qualities"]

    // Display names for context combos (shows full labels in dropdown)
    property var contextDisplayList: {
        var result = []
        for (var i = 0; i < contextList.length; i++) {
            var code = contextList[i]
            result.push(code === "All Contexts" ? code : (contextLabels[code] || code))
        }
        return result
    }

    // Context display labels — legacy, baked in directly after #174/#184 retirement.
    // The plugin no longer surfaces a context picker; these labels exist only
    // for the few code paths that still group voicings by suitableModes (e.g.
    // FilterEngine's string-count cap). Removing them entirely is its own
    // future refactor; until then they're held as constants.
    property var contextLabels: ({
        "CM6": "Chord Melody 6-String",
        "CM7": "Chord Melody 7-String",
        "CV6": "Chord + Voice 6-String",
        "CV7": "Chord + Voice 7-String",
        "CM4": "Chord Melody 4-String",
        "CV4": "Chord + Voice 4-String",
        "CM5": "Chord Melody 5-String",
        "CV5": "Chord + Voice 5-String"
    })
    property var contextLabelsShort: ({
        "CM6": "CM 6", "CM7": "CM 7",
        "CV6": "CV 6", "CV7": "CV 7",
        "CM4": "CM 4", "CV4": "CV 4",
        "CM5": "CM 5", "CV5": "CV 5"
    })
    // Context string counts — still used by ChordSelector as a max-strings cap.
    property var contextStringCounts: ({"CM4": 4, "CV4": 4, "CM5": 5, "CV5": 5, "CM6": 6, "CV6": 6, "CM7": 7, "CV7": 7})


    // === Scale config loading/saving (#142) ===

    function loadScalesConfig() {
        try {
            var raw = scalesConfigFile.read()
            if (raw && raw.length > 2) {
                var data = JSON.parse(raw)
                if (ChordScales.loadScales(data)) {
                    console.log("Loaded scales config (" + data.scales.length + " scales)")
                } else {
                    console.log("Scale config parse failed, using defaults")
                }
            } else {
                console.log("No scales.json found, using built-in defaults")
            }
        } catch (e) {
            console.log("Error loading scales config: " + e)
        }
        // Populate SettingsPanel with scale data
        settingsPanel.scalesData = ChordScales.getScaleList()
        settingsPanel.customQualities = ChordScales.getCustomQualities()
        // Pass name-based map (not ID-based) for the UI editor
        var nameMap = {}
        var csm = ChordScales.CHORD_SCALE_MAP
        for (var q in csm) nameMap[q] = csm[q].slice()
        settingsPanel.chordScaleMap = nameMap
        // Populate scale filter list for Library tab dropdown
        var names = ["All Scales"]
        var list = ChordScales.getScaleList()
        for (var i = 0; i < list.length; i++) names.push(list[i].name)
        _scaleNameList = names
    }

    function saveScalesConfig() {
        try {
            var data = ChordScales.saveScales()
            scalesConfigFile.write(JSON.stringify(data, null, 2))
            console.log("Saved scales config")
        } catch (e) {
            console.log("Error saving scales config: " + e)
        }
    }

    // === Style profiles (#146) ===

    function loadProfiles() {
        try {
            var raw = profilesConfigFile.read()
            if (raw && raw.length > 2) {
                var data = JSON.parse(raw)
                _profileList = data.profiles || []
                console.log("Loaded " + _profileList.length + " style profiles")
            }
        } catch (e) {
            console.log("Error loading profiles: " + e)
        }
    }

    // === Modes (#164) ===

    function loadModes() {
        try {
            var raw = modesConfigFile.read()
            if (raw && raw.length > 2) {
                var data = JSON.parse(raw)
                _modesById = data.modes || {}
                var keys = Object.keys(_modesById)
                console.log("Loaded " + keys.length + " modes: " + keys.join(", "))
            }
        } catch (e) {
            console.log("Error loading modes: " + e)
        }
    }

    function setActiveMode(modeId) {
        if (!modeId || !_modesById[modeId]) {
            console.log("setActiveMode: unknown id " + modeId + " — defaulting to chord-melody")
            modeId = "chord-melody"
        }
        activeMode = modeId
        console.log("Mode: " + (_modesById[modeId] ? _modesById[modeId].name : modeId))
        saveSettings()
    }

    // Resolve current mode to its config object (or null if not loaded yet).
    function currentModeConfig() {
        return (_modesById && _modesById[activeMode]) ? _modesById[activeMode] : null
    }

    // Reset a built-in tuning's label + pitches to the factory defaults. Rereads
    // the bundled tuning JSON from the plugin's own tunings/ dir (the one deploy.sh
    // overwrites) and applies it.
    function resetBuiltInTuning(slug) {
        if (builtInTunings.indexOf(slug) < 0) {
            settingsPanel.tuningStatus = "Only built-in tunings can be reset to factory"
            settingsPanel.tuningStatusColor = theme.errorText
            return
        }
        try {
            tuningFile.source = Qt.resolvedUrl("tunings/" + slug + ".json")
            var raw = tuningFile.read()
            if (!raw || raw.length === 0) {
                settingsPanel.tuningStatus = "Factory file missing for " + slug
                settingsPanel.tuningStatusColor = theme.errorText
                return
            }
            var t = JSON.parse(raw)
            var nlab = Object.assign({}, tuningLabels); nlab[slug] = t.name; tuningLabels = nlab
            var ncnt = Object.assign({}, tuningStringCounts); ncnt[slug] = Object.keys(t.strings || {}).length || 6; tuningStringCounts = ncnt
            if (selectedTuning === slug) { loadTuningStringCount(); loadTuningVoicings() }
            saveSettings()
            settingsPanel.tuningStatus = "Reset " + t.name + " to factory defaults"
            settingsPanel.tuningStatusColor = theme.successText
        } catch (e) {
            settingsPanel.tuningStatus = "Reset failed: " + String(e)
            settingsPanel.tuningStatusColor = theme.errorText
        }
    }

    // Section-aware mode lookup (#167). Returns the mode id active at chord index.
    function modeForChord(idx) {
        if (!scoreSections || scoreSections.length === 0) return activeMode
        var best = null, bestStart = -1
        for (var i = 0; i < scoreSections.length; i++) {
            var s = scoreSections[i]
            if (typeof s.startIdx !== "number") continue
            if (s.startIdx <= idx && s.startIdx > bestStart) {
                best = s; bestStart = s.startIdx
            }
        }
        return best ? best.mode : activeMode
    }

    // Section-aware mode config (#167). Used by BatchEngine per chord.
    function modeConfigForChord(idx) {
        var id = modeForChord(idx)
        return (_modesById && _modesById[id]) ? _modesById[id] : null
    }

    // ============================================================
    // === Backup / restore + URL import =========================
    // ============================================================
    // The pure logic (archive shape, version checking, merge rules,
    // timestamps, error messages) lives in plugin/model/BackupManager.js.
    // The QML-side functions below glue that to FileIO, plugin state,
    // and the SettingsPanel status surface. They were considered for
    // extraction into a separate QML controller in #181 but the residue
    // is genuinely QML-glue and gains nothing from a controller split.
    //
    // Related tickets: #172 (initial backup MVP), #179 (version migration),
    // #67 (URL import + community packs), #181 (extraction re-evaluation).
    //
    // Function index:
    //   exportBackup()                — write archive to Desktop
    //   restoreBackup(path)           — read archive from path and apply
    //   importFromUrl(url)            — fetch JSON via HTTP, sniff, dispatch
    //   _importTuningFromObject(t)    — apply a single tuning JSON
    //   _restoreFromArchive(archive)  — apply a verified archive
    //   _reportArchiveError(pres)     — surface parseArchive failures to UI
    // ============================================================

    function exportBackup() {
        try {
            var customTuningSlugs = []
            for (var i = 0; i < tuningList.length; i++) {
                if (builtInTunings.indexOf(tuningList[i]) < 0) customTuningSlugs.push(tuningList[i])
            }
            var settings = {
                voicingUrl: jsonUrl, diagramPlacement: diagramPlacement,
                tuning: selectedTuning, customTunings: DataCache.getCustomTuningsList(
                    tuningList, builtInTunings, tuningLabels, tuningStringCounts),
                tuningOrder: tuningList.slice(),
                calcMaxFret: calcMaxFret, calcMaxStretch: calcMaxStretch,
                calcAllowOpen: calcAllowOpen, calcRootInBass: calcRootInBass,
                calcMinNotes: calcMinNotes, calcMaxMuted: calcMaxMuted,
                calcMaxPerQuality: calcMaxPerQuality,
                activeProfile: _activeProfileId, activeMode: activeMode
            }
            var readTuningFile = function(slug) {
                backupFile.source = Qt.resolvedUrl("tunings/" + slug + ".json")
                return backupFile.read()
            }
            var allScales = (typeof ChordScales.getScaleList === "function") ? ChordScales.getScaleList() : []
            var archive = BackupManager.buildArchive({
                settings: settings,
                allStyles: _profileList,
                allScales: allScales,
                customTuningSlugs: customTuningSlugs,
                readTuningFile: readTuningFile,
                version: "v2.2"
            })
            var path = homePath() + "/Desktop/chordlibrary-backup-" + BackupManager.timestampForFilename() + ".json"
            backupFile.source = path
            backupFile.write(BackupManager.serialize(archive))
            settingsPanel.backupStatus = "Exported to " + path
            settingsPanel.backupStatusColor = theme.successText
        } catch (e) {
            settingsPanel.backupStatus = "Export failed: " + String(e)
            settingsPanel.backupStatusColor = theme.errorText
        }
    }

    // Fetch a URL and dispatch to the right import flow based on content shape (#67).
    function importFromUrl(url) {
        if (!url) {
            settingsPanel.backupStatus = "Enter a URL"
            settingsPanel.backupStatusColor = theme.errorText
            return
        }
        settingsPanel.backupStatus = "Fetching " + url + " …"
        settingsPanel.backupStatusColor = theme.textMuted
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200 && xhr.status !== 0) {
                settingsPanel.backupStatus = "Fetch failed: HTTP " + xhr.status
                settingsPanel.backupStatusColor = theme.errorText
                return
            }
            // Route through BackupManager so version-checking applies to URL
            // imports the same way it does to file restores (#179).
            var pres = BackupManager.parseArchive(xhr.responseText)
            if (pres.ok) {
                _restoreFromArchive(pres.archive)
                if (pres.migrated) {
                    settingsPanel.backupStatus += " (migrated from older archive version)"
                }
                return
            }
            if (pres.reason === "not-chordlibrary" || pres.reason === "missing-version") {
                // Could still be a single tuning file. Try sniff path.
                try {
                    var parsed = JSON.parse(xhr.responseText)
                    if (parsed.strings && parsed.notes && parsed.name) {
                        _importTuningFromObject(parsed)
                        return
                    }
                    settingsPanel.backupStatus = "Unrecognised file shape. Expected a tuning or backup-archive JSON."
                    settingsPanel.backupStatusColor = theme.errorText
                } catch (e) {
                    settingsPanel.backupStatus = "Parse failed: " + String(e)
                    settingsPanel.backupStatusColor = theme.errorText
                }
                return
            }
            _reportArchiveError(pres)
        }
        xhr.send()
    }

    // Import a tuning from an already-parsed object (shared with URL import path).
    function _importTuningFromObject(tuningObj) {
        try {
            var slug = tuningObj.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
            var stringCount = Object.keys(tuningObj.strings || {}).length || 6
            backupFile.source = Qt.resolvedUrl("tunings/" + slug + ".json")
            backupFile.write(JSON.stringify(tuningObj, null, 2))
            if (tuningList.indexOf(slug) < 0) {
                var nl = tuningList.slice(); nl.push(slug); tuningList = nl
            }
            var nlab = Object.assign({}, tuningLabels); nlab[slug] = tuningObj.name; tuningLabels = nlab
            var ncnt = Object.assign({}, tuningStringCounts); ncnt[slug] = stringCount; tuningStringCounts = ncnt
            saveSettings()
            settingsPanel.backupStatus = "Imported tuning: " + tuningObj.name
            settingsPanel.backupStatusColor = theme.successText
        } catch (e) {
            settingsPanel.backupStatus = "Tuning import failed: " + String(e)
            settingsPanel.backupStatusColor = theme.errorText
        }
    }

    // Restore from an already-parsed archive (shared with URL import path).
    function _restoreFromArchive(archive) {
        try {
            var styleRes = BackupManager.mergeStyles(archive, _profileList || [])
            if (styleRes.list) {
                _profileList = styleRes.list
                profilesConfigFile.write(JSON.stringify({ profiles: _profileList }, null, 2))
            }
            var tFiles = BackupManager.tuningFilesToRestore(archive)
            var restoredTunings = 0
            for (var i = 0; i < tFiles.length; i++) {
                backupFile.source = Qt.resolvedUrl("tunings/" + tFiles[i].slug + ".json")
                backupFile.write(JSON.stringify(tFiles[i].body, null, 2))
                restoredTunings += 1
            }
            if (archive.settings && archive.settings.customTunings) {
                for (var j = 0; j < archive.settings.customTunings.length; j++) {
                    var ct = archive.settings.customTunings[j]
                    if (!ct.slug) continue
                    if (tuningList.indexOf(ct.slug) < 0) {
                        var nl = tuningList.slice(); nl.push(ct.slug); tuningList = nl
                    }
                    var nlab = Object.assign({}, tuningLabels); nlab[ct.slug] = ct.name; tuningLabels = nlab
                    var ncnt = Object.assign({}, tuningStringCounts); ncnt[ct.slug] = ct.strings || 6; tuningStringCounts = ncnt
                }
            }
            saveSettings()
            settingsPanel.backupStatus = "Imported " + (styleRes.added + styleRes.updated) +
                " style(s), " + restoredTunings + " tuning(s). Restart MuseScore to pick up all changes."
            settingsPanel.backupStatusColor = theme.successText
        } catch (e) {
            settingsPanel.backupStatus = "Archive import failed: " + String(e)
            settingsPanel.backupStatusColor = theme.errorText
        }
    }

    function restoreBackup(path) {
        if (!path) {
            settingsPanel.backupStatus = "No path provided"
            settingsPanel.backupStatusColor = theme.errorText
            return
        }
        try {
            backupFile.source = path
            var raw = backupFile.read()
            var pres = BackupManager.parseArchive(raw)
            if (!pres.ok) {
                _reportArchiveError(pres)
                return
            }
            _restoreFromArchive(pres.archive)
            if (pres.migrated) {
                settingsPanel.backupStatus += " (migrated from older archive version)"
            }
        } catch (e) {
            settingsPanel.backupStatus = "Restore failed: " + String(e)
            settingsPanel.backupStatusColor = theme.errorText
        }
    }

    // Translate a parseArchive failure into a user-facing message (#179, #181).
    // The catalog itself lives in BackupManager.reasonMessage so the messages
    // sit beside the parseArchive that produces the reasons; this function
    // just routes the result to the SettingsPanel surface.
    function _reportArchiveError(pres) {
        settingsPanel.backupStatus = BackupManager.reasonMessage(pres)
        settingsPanel.backupStatusColor = theme.errorText
    }

    function setProfile(profileId) {
        _activeProfileId = profileId
        if (!profileId || profileId === "default") {
            ChordScales.setActiveProfile(null)
            console.log("Profile: Default (no overrides)")
        } else {
            for (var i = 0; i < _profileList.length; i++) {
                if (_profileList[i].id === profileId) {
                    ChordScales.setActiveProfile(_profileList[i])
                    console.log("Profile: " + _profileList[i].name)
                    break
                }
            }
        }
        // Refresh scale filter list and voicing cards (scale names may change with profile)
        var names = ["All Scales"]
        var list = ChordScales.getScaleList()
        for (var j = 0; j < list.length; j++) names.push(list[j].name)
        _scaleNameList = names
        applyFilters()
        saveSettings()
    }

    // Custom context creation retired in #184 (followup to #174).
    // Mode + tuning replace what the context axis used to do. The hardcoded
    // context labels above remain for the few code paths that still group
    // voicings by string count.

    // === Tool feedback (uses toolStatus label + console) ===

    function showResult(title, message, isSuccess) {
        console.log("[ChordLibrary] " + title + ": " + message)
        // Short messages go in toolStatus, long ones open the results panel
        if (message.indexOf("\n") >= 0 || message.length > 80) {
            toolResultsTitle = title
            toolResultsContent = message
            showToolResults = true
        } else {
            _toolStatusText = title + ": " + message
        }
    }

    // === Paste infrastructure ===

    property var _pendingVoicing: null  // voicing being pasted (for tracking)

    // Timer: waits for the launchd agent to write clipboard data.
    // Note: cmd("paste") does NOT work in MuseScore 4's plugin API.
    // The user must press Cmd+V manually. For single "Open" clicks,
    // the osascript in clipboard-and-paste.sh attempts auto-paste.
    // For batch Voice Score, the guided walkthrough handles timing.
    Timer {
        id: pasteTimer
        interval: 1500
        repeat: false
        onTriggered: {
            statusMsg.text = statusMsg.text.replace("Pasting", "Pasted")
            if (insertionEngine._pendingVoicing) {
                lastInsertedVoicing = insertionEngine._pendingVoicing
                insertionEngine._pendingVoicing = null
                if (sortByProximity) applyFilters()
            }
        }
    }

    // === Batch insert (extracted to model/BatchEngine.qml, #100) ===

    // Quality map delegated to ChordSelector module
    property var qualityMap: ChordSelector.qualityMap

    // Compatibility aliases — delegate to batchEngine for code that still uses these names
    // (inline tools, import panel, library panel wiring). Will be removed in Phase C.
    property alias batchQueue: batchEngine.batchQueue
    property alias batchTotal: batchEngine.batchTotal
    property alias _batchChords: batchEngine.batchChords
    property alias _batchIndex: batchEngine.batchIndex

    BatchEngine {
        id: batchEngine
        pluginRef: chordLibrary
        curScore: chordLibrary.curScore
        tempDiagramFile: tempDiagramFile
        clipboardXmlPath: Qt.resolvedUrl("paste-clipboard.xml")
        voicingsData: chordLibrary.voicingsData
        filterContext: chordLibrary.filterContext
        filterCategory: chordLibrary.filterCategory
        tuningMaxStrings: chordLibrary.tuningMaxStrings
        contextStringCounts: chordLibrary.contextStringCounts
        tuningMidi: chordLibrary.tuningMidi
        usingTuningVoicings: chordLibrary.usingTuningVoicings
        tuningOffset: chordLibrary.tuningOffset
        melodyOnTop: chordLibrary.melodyOnTop
        melodyStaffIdx: chordLibrary.melodyStaffIdx
        writeVoice2: chordLibrary.writeVoice2
        melodyOverrideText: libraryPanel.melodyOverrideField ? libraryPanel.melodyOverrideField.text : ""
        // Mode axis (#164) — activeMode drives mode-aware scoring in ChordSelector
        activeMode: chordLibrary.activeMode
        modeConfig: chordLibrary.currentModeConfig()
        // Section-aware mode resolution (#167)
        modeIdResolverFn: function(chordIdx) { return chordLibrary.modeForChord(chordIdx) }
        modeConfigResolverFn: function(chordIdx) { return chordLibrary.modeConfigForChord(chordIdx) }

        onStatusMessage: function(text, colorName) {
            statusMsg.text = text
            statusMsg.color = colorName === "error" ? theme.errorText
                            : colorName === "success" ? theme.successText
                            : theme.textMuted
        }
        onShowWalkthrough: function(title, content) {
            toolResultsTitle = title
            toolResultsContent = content
            showToolResults = true
        }
        onWalkthroughComplete: function(total) {
            showResult("Voice Score Complete",
                "All " + total + " chord voicings have been loaded.\n\n"
                + "Click 'Back to Library' to return to the voicing browser.", true)
        }
        onWalkthroughDataChanged: {
            walkthroughPanel.batchChords = batchEngine.batchChords
        }
        onInsertDiagramRequested: function(voicing) {
            generateDiagramFile(voicing)
        }
    }

    // Convenience delegates for code that still calls these from the parent scope
    function voiceAtCursor() { batchEngine.voiceAtCursor() }
    function batchInsert() { batchEngine.batchInsert() }
    function batchShowNext() { batchEngine.batchShowNext() }
    function generateXmlForVoicing(voicing, targetRoot) { return batchEngine.generateXmlForVoicing(voicing, targetRoot) }
    function findBestVoicing(targetRoot, quality, melodyMidi, bassMidi) { return batchEngine.findBestVoicing(targetRoot, quality, melodyMidi, bassMidi) }
    function parseChordSymbol(text) { return batchEngine.parseChordSymbol(text) }

    function rebuildFilterLists() {
        var lists = FilterEngine.rebuildFilterLists(voicingsData)
        // Always include all known contexts (from contextStringCounts) so the
        // dropdown isn't empty on non-standard tunings that only have a subset.
        var allContexts = {}
        var csKeys = Object.keys(contextStringCounts || {})
        for (var c = 0; c < csKeys.length; c++) allContexts[csKeys[c]] = true
        for (var i = 1; i < lists.contextList.length; i++) allContexts[lists.contextList[i]] = true
        contextList = ["All Contexts"].concat(Object.keys(allContexts).sort())
        categoryList = lists.categoryList
        qualityList = lists.qualityList
    }

    // Deferred tuning load — lets the UI render before heavy calculation (#112)
    Timer {
        id: startupTuningTimer
        interval: 100
        repeat: false
        onTriggered: {
            statusMsg.text = "Loading voicings for " + (tuningLabels[selectedTuning] || selectedTuning) + "..."
            statusMsg.color = theme.textSecondary
            loadTuningVoicings()
        }
    }

    onRun: {
        loadScalesConfig()
        loadProfiles()
        loadModes()
        loadSettings()
        loadTuningStringCount()
        if (!dataLoaded) {
            // Try local cache first (contains imports), fall back to URL
            if (!loadFromCache()) {
                fetchVoicings()
            }
        }
        // Auto-select CM context if none saved
        if (!filterContext) {
            var strCount = tuningStringCounts[selectedTuning] || 6
            var autoCtx = "CM" + strCount
            if (contextStringCounts[autoCtx]) filterContext = autoCtx
        }
        refreshFilteredTunings()
        // Defer tuning voicing load so UI renders first (#112)
        startupTuningTimer.start()
    }

    function loadFromCache() {
        try {
            var raw = localCacheFile.read()
            var cached = DataCache.parseCache(raw)
            if (cached) {
                voicingsData = cached
                dataLoaded = true
                rebuildFilterLists()
                refreshFilteredTunings()
                applyFilters()
                statusMsg.text = "Loaded " + voicingsData.length + " voicings (cached)"
                statusMsg.color = theme.successText
                console.log("Loaded " + cached.length + " voicings from local cache")
                return true
            }
        } catch (e) {
            console.log("No local cache, fetching from URL")
        }
        return false
    }

    function saveToCache() {
        localCacheFile.write(DataCache.serializeCache(voicingsData))
        console.log("Saved " + voicingsData.length + " voicings to local cache")
    }

    // === Settings persistence ===

    function loadSettings() {
        try {
            var raw = settingsFile.read()
            var s = DataCache.parseSettings(raw)
            if (s.voicingUrl) jsonUrl = s.voicingUrl
            if (s.diagramPlacement) diagramPlacement = s.diagramPlacement
            if (s.tuning) selectedTuning = s.tuning
            if (s.defaultContext) filterContext = s.defaultContext
            // Hardcoded built-in tuning data — avoids Object.keys() on QML property aliases (#154)
            var newLabels = {
                "standard": "Standard 6-String",
                "7string-van-eps": "Van Eps 7-String (Low A)",
                "7string-low-b": "Low B 7-String",
                "dadgad": "DADGAD 6-String",
                "all-fourths": "All Fourths 6-String",
                "baritone": "Baritone Guitar 6-String (B Standard)"
            }
            var newCounts = {
                "standard": 6,
                "7string-van-eps": 7,
                "7string-low-b": 7,
                "dadgad": 6,
                "all-fourths": 6,
                "baritone": 6
            }
            var newList = tuningList.slice()
            // Overlay custom tunings from settings
            if (s.customTunings.length > 0) {
                for (var i = 0; i < s.customTunings.length; i++) {
                    var ct = s.customTunings[i]
                    if (ct.slug && ct.name) {
                        if (newList.indexOf(ct.slug) < 0) newList.push(ct.slug)
                        newLabels[ct.slug] = ct.name
                        newCounts[ct.slug] = ct.strings || 6
                    }
                }
                console.log("Restored " + s.customTunings.length + " custom tuning(s)")
            }
            tuningList = newList
            tuningLabels = newLabels
            tuningStringCounts = newCounts
            // Restore tuning order (if user reordered)
            if (s.tuningOrder.length > 0) {
                tuningList = DataCache.mergeTuningOrder(s.tuningOrder, tuningList)
            }
            // settingsPanel.tuningListModel is a declarative binding on tuningList.slice()
            // (SettingsPanel instantiation). Don't write it imperatively — that would
            // break the binding.
            // Restore voicing calculator constraints
            calcMaxFret = s.calcMaxFret
            calcMaxStretch = s.calcMaxStretch
            calcAllowOpen = s.calcAllowOpen
            calcRootInBass = s.calcRootInBass
            calcMinNotes = s.calcMinNotes
            calcMaxMuted = s.calcMaxMuted
            calcMaxPerQuality = s.calcMaxPerQuality
            // Restore active style profile (#146)
            if (s.activeProfile) setProfile(s.activeProfile)
            // Restore active mode (#164). Default "chord-melody" preserves v2.0 behavior.
            if (s.activeMode) setActiveMode(s.activeMode)
            // Restore score sections (#167). Array of {startIdx, mode, name}.
            if (s.scoreSections && Array.isArray(s.scoreSections)) scoreSections = s.scoreSections
            refreshFilteredTunings()
            console.log("Settings loaded: url=" + jsonUrl + ", placement=" + diagramPlacement + ", tuning=" + selectedTuning + ", context=" + filterContext + ", profile=" + (s.activeProfile || "default"))
        } catch (e) {
            console.log("No saved settings found, using defaults")
        }
    }

    function saveSettings() {
        var s = {
            voicingUrl: jsonUrl,
            diagramPlacement: diagramPlacement,
            tuning: selectedTuning,
            defaultContext: filterContext,
            customTunings: DataCache.getCustomTuningsList(tuningList, builtInTunings, tuningLabels, tuningStringCounts),
            tuningOrder: tuningList.slice(),
            calcMaxFret: calcMaxFret,
            calcMaxStretch: calcMaxStretch,
            calcAllowOpen: calcAllowOpen,
            calcRootInBass: calcRootInBass,
            calcMinNotes: calcMinNotes,
            calcMaxMuted: calcMaxMuted,
            calcMaxPerQuality: calcMaxPerQuality,
            activeProfile: _activeProfileId,
            activeMode: activeMode,
            scoreSections: scoreSections,
        }
        settingsFile.write(DataCache.serializeSettings(s))
        console.log("Settings saved")
    }

    // === Tuning management (extracted to model/TuningManager.qml, #102) ===

    TuningManager {
        id: tuningManager
        tuningFile: chordLibrary.tuningFile
        settingsPanel: settingsPanel
        state: tuningState  // TuningManager reads/writes tuningState directly
        onTuningChanged: { loadTuningStringCount(); loadTuningVoicings() }
        onSettingsSaveRequested: saveSettings()
    }

    // Compatibility aliases
    property var builtInTunings: tuningManager.builtInTunings
    property var midiNoteNames: tuningManager.midiNoteNames
    function noteNameToMidi(str) { return tuningManager.noteNameToMidi(str) }
    function moveTuning(slug, direction) { tuningManager.moveTuning(slug, direction) }
    function importTuning(path) {
        // Direct implementation — bypasses TuningManager for...in bug (#154)
        function _setImportStatus(text, color) {
            settingsPanel.tuningStatus = text
            settingsPanel.tuningStatusColor = color
            importPanel.tuningStatus = text
            importPanel.tuningStatusColor = color
        }
        if (!path) {
            _setImportStatus("Enter a file path", "#e74c3c")
            return
        }
        try {
            tuningFile.source = path
            var raw = tuningFile.read()
            if (!raw || raw.length === 0) {
                _setImportStatus("File not found or empty", "#e74c3c")
                return
            }
            var t = JSON.parse(raw)
            if (!t.name || !t.strings) {
                _setImportStatus("Invalid tuning: needs 'name' and 'strings' fields", "#e74c3c")
                return
            }
            var slug = t.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
            var stringCount = Object.keys(t.strings || {}).length || 6
            // Write file to tunings directory
            tuningFile.source = Qt.resolvedUrl("tunings/" + slug + ".json")
            tuningFile.write(raw)
            // Build new lists using Object.keys (not for...in)
            var newList = tuningList.slice()
            if (newList.indexOf(slug) < 0) newList.push(slug)
            var newLabels = {}
            var oldLabels = tuningLabels || {}
            var lKeys = Object.keys(oldLabels)
            for (var li = 0; li < lKeys.length; li++) newLabels[lKeys[li]] = oldLabels[lKeys[li]]
            newLabels[slug] = t.name
            var newCounts = {}
            var oldCounts = tuningStringCounts || {}
            var cKeys = Object.keys(oldCounts)
            for (var ci = 0; ci < cKeys.length; ci++) newCounts[cKeys[ci]] = oldCounts[cKeys[ci]]
            newCounts[slug] = stringCount
            tuningList = newList
            tuningLabels = newLabels
            tuningStringCounts = newCounts
            selectedTuning = slug
            loadTuningStringCount()
            loadTuningVoicings()
            refreshFilteredTunings()
            saveSettings()
            // tuningListModel updates automatically via its binding to tuningList
            _setImportStatus("Imported: " + t.name, "#27ae60")
        } catch(e) {
            _setImportStatus("Failed: " + String(e), "#e74c3c")
        }
    }
    function createTuning(name, pitchStr, numStrings) { tuningManager.createTuning(name, pitchStr, numStrings) }
    function editTuning(slug) {
        // Direct implementation — bypasses TuningManager (#154)
        if (!slug) return
        var paths = [
            Qt.resolvedUrl("tunings/" + slug + ".json"),
            Qt.resolvedUrl("config/tunings/" + slug + ".json")
        ]
        for (var p = 0; p < paths.length; p++) {
            tuningFile.source = paths[p]
            try {
                var raw = tuningFile.read()
                if (raw && raw.length > 2) {
                    var t = JSON.parse(raw)
                    var strings = t.strings || {}
                    var count = Object.keys(strings).length
                    var pitchParts = []
                    for (var s = 1; s <= count; s++) {
                        var midi = strings[String(s)]
                        if (midi !== undefined) {
                            pitchParts.push(midiNoteNames[midi] || String(midi))
                        }
                    }
                    var pitchStr = pitchParts.join(", ")
                    settingsPanel.tuningNameValue = t.name || slug
                    settingsPanel.tuningStringCountValue = count > 0 ? count : 6
                    settingsPanel.tuningPitchesValue = pitchStr
                    settingsPanel.editingTuningSlug = slug
                    settingsPanel.tuningStatus = "Editing: " + (t.name || slug) + " — change values and click Save"
                    settingsPanel.tuningStatusColor = "#2980b9"
                    return
                }
            } catch (e) {}
        }
        settingsPanel.tuningStatus = "Could not load tuning: " + slug
        settingsPanel.tuningStatusColor = "#e74c3c"
    }
    function deleteTuning(slug) { tuningManager.deleteTuning(slug) }

    // These were previously inline — now delegate but keep the old function signatures
    function addTuningToList(slug, name, stringCount) { tuningManager.addTuningToList(slug, name, stringCount) }

    // === Save to Library ===

    function saveVoicingToLibrary(quality, category, context, fretStr, numStrings, dotsStr, mutesStr) {
        settingsPanel.saveStatus = ""

        // Parse fret number
        var fretNum = parseInt(fretStr)
        if (isNaN(fretNum) || fretNum < 0 || fretNum > 24) {
            settingsPanel.saveStatus = "Invalid fret number"; settingsPanel.saveStatusColor = theme.errorText; return
        }

        // Parse dots: "6:1, 4:1, 3:2" → [{string:6, fret:1}, ...]
        if (!dotsStr) { settingsPanel.saveStatus = "Enter dot positions"; settingsPanel.saveStatusColor = theme.errorText; return }
        var dotParts = dotsStr.split(",")
        var dots = []
        for (var d = 0; d < dotParts.length; d++) {
            var pair = dotParts[d].trim().split(":")
            if (pair.length !== 2) { settingsPanel.saveStatus = "Bad dot format: " + dotParts[d]; settingsPanel.saveStatusColor = theme.errorText; return }
            dots.push({ string: parseInt(pair[0]), fret: parseInt(pair[1]) })
        }

        // Parse mutes: "5, 2, 1" → [5, 2, 1]
        var mutes = []
        if (mutesStr) {
            mutes = mutesStr.split(",").map(function(s) { return parseInt(s.trim()) })
        }

        // Determine current key from score chord symbol
        var targetRoot = "C"
        if (curScore) {
            var sel = curScore.selection
            if (sel && sel.elements && sel.elements.length > 0) {
                var elem = sel.elements[0]
                var seg = null
                if (elem.type === Element.NOTE && elem.parent) seg = elem.parent.parent
                else if (elem.type === Element.REST || elem.type === Element.CHORD) seg = elem.parent
                if (seg && seg.annotations) {
                    for (var a = 0; a < seg.annotations.length; a++) {
                        if (seg.annotations[a].type === Element.HARMONY) {
                            var parsed = Transposer.extractRoot(seg.annotations[a].text)
                            if (parsed) targetRoot = parsed
                            break
                        }
                    }
                }
            }
        }

        // Reproject to C: subtract transposition offset from fret number
        var offset = Transposer.semitoneOffset("C", targetRoot)
        var cFretNum = fretNum - offset
        if (cFretNum < 0) cFretNum += 12  // wrap around

        // Compute notes and intervals in C position using tuning
        var noteNames = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"]
        var intervalLabels = {0:"1",1:"b9",2:"9",3:"b3",4:"3",5:"4",6:"b5",7:"5",8:"#5",9:"6",10:"b7",11:"7"}
        var notes = []
        var intervals = []
        for (var i = 0; i < dots.length; i++) {
            var strMidi = tuningMidi[String(dots[i].string)]
            if (strMidi !== undefined) {
                var absFret = cFretNum + (dots[i].fret - 1)
                var midi = strMidi + absFret
                var noteName = noteNames[midi % 12]
                notes.push(noteName)
                var semitones = midi % 12  // C = 0
                intervals.push(intervalLabels[semitones] || "?")
            }
        }

        // Compute open strings
        var allStrings = []
        for (var s = 1; s <= numStrings; s++) allStrings.push(s)
        var dottedStrings = dots.map(function(d) { return d.string })
        var opens = allStrings.filter(function(s) {
            return dottedStrings.indexOf(s) < 0 && mutes.indexOf(s) < 0
        })

        // Generate ID
        var qSlug = quality.toLowerCase().replace("#", "s").replace(/[^a-z0-9]/g, "")
        var id = "c" + qSlug + "-" + category + "-custom-" + numStrings + "-f" + cFretNum

        // Check for duplicate
        for (var j = 0; j < voicingsData.length; j++) {
            if (voicingsData[j].id === id) {
                settingsPanel.saveStatus = "ID already exists: " + id
                settingsPanel.saveStatusColor = theme.errorText
                return
            }
        }

        // Build the voicing
        var chordPrefix = {
            "dom7":"C7","maj7":"Cmaj7","min7":"Cm7","min7b5":"Cm7b5","dim7":"Cdim7",
            "maj6":"C6","min6":"Cm6","dom7b9":"C7b9","dom7sharp5":"C7#5",
            "dom7alt":"C7alt","dom9":"C9","dom13":"C13","sus4":"Csus4","sus2":"Csus2",
            "aug7":"Caug7","min-maj7":"CmMaj7","augMaj7":"CaugMaj7"
        }
        var prefix = chordPrefix[quality] || ("C" + quality)

        var voicing = {
            id: id,
            name: prefix + " — Custom — " + category.charAt(0).toUpperCase() + category.slice(1),
            chord_quality: quality,
            root: "C",
            category: category,
            context: context,
            strings: numStrings,
            fret_number: cFretNum,
            visible_frets: 4,
            dots: dots,
            mutes: mutes.sort(),
            open: opens.sort(),
            notes: notes,
            intervals: intervals,
            tags: ["custom", category]
        }

        // Add to library and save
        var merged = voicingsData.slice()
        merged.push(voicing)
        voicingsData = merged
        rebuildFilterLists()
        refreshFilteredTunings()
        applyFilters()
        saveToCache()

        var keyNote = targetRoot === "C" ? "" : " (reprojected from " + targetRoot + ")"
        settingsPanel.saveStatus = "Saved: " + voicing.name + keyNote
        settingsPanel.saveStatusColor = theme.successText
    }

    // === Library hygiene audit ===

    FileIO {
        id: hygieneIgnoreFile
        source: Qt.resolvedUrl("hygiene-ignore.json")
    }

    property var hygieneIgnoreList: []

    function loadHygieneIgnoreList() {
        try {
            var raw = hygieneIgnoreFile.read()
            if (raw && raw.length > 2) {
                hygieneIgnoreList = JSON.parse(raw)
                console.log("Loaded " + hygieneIgnoreList.length + " hygiene dismissals")
            }
        } catch (e) {
            hygieneIgnoreList = []
        }
    }

    function saveHygieneIgnoreList() {
        hygieneIgnoreFile.write(JSON.stringify(hygieneIgnoreList, null, 2))
    }

    function dismissFinding(key) {
        // Add to ignore list and save
        for (var i = 0; i < hygieneIgnoreList.length; i++) {
            if (hygieneIgnoreList[i].key === key) return  // already dismissed
        }
        var list = hygieneIgnoreList.slice()
        list.push({ key: key, date: new Date().toISOString().split("T")[0] })
        hygieneIgnoreList = list
        saveHygieneIgnoreList()
        // Re-run audit to refresh the display
        runHygieneAudit()
    }

    function isIgnored(key) {
        return HygieneEngine.isIgnored(key, hygieneIgnoreList)
    }

    function clearDismissals() {
        hygieneIgnoreList = []
        saveHygieneIgnoreList()
        runHygieneAudit()
    }

    function runHygieneAudit() {
        loadHygieneIgnoreList()
        auditResultsModel.clear()

        var audit = HygieneEngine.runAudit(voicingsData, tuningMidi, hygieneIgnoreList)

        var summary = voicingsData.length + " voicings audited\n"
            + audit.duplicates + " duplicates, "
            + audit.enharmonic + " enharmonic, "
            + audit.crossCtx + " cross-context"
        if (audit.dismissed > 0)
            summary += "\n(" + audit.dismissed + " dismissed findings hidden)"
        settingsPanel.hygieneStatus = summary
        settingsPanel.hygieneStatusColor = audit.duplicates > 0 ? theme.errorText : theme.successText

        lastAuditResults = audit.results
        for (var r = 0; r < audit.results.length; r++)
            auditResultsModel.append({ "modelData": audit.results[r] })
    }

    // Store last audit results for report export
    property var lastAuditResults: []

    function fixDuplicates() {
        var result = HygieneEngine.dedup(voicingsData)
        if (result.removed > 0) {
            voicingsData = result.cleaned
            rebuildFilterLists()
            refreshFilteredTunings()
            applyFilters()
            saveToCache()
            settingsPanel.hygieneStatus = "Removed " + result.removed + " duplicates. " + voicingsData.length + " voicings remain."
            settingsPanel.hygieneStatusColor = theme.successText
        } else {
            settingsPanel.hygieneStatus = "No duplicates found."
            settingsPanel.hygieneStatusColor = theme.successText
        }
    }

    function saveAuditReport(path) {
        if (!path) { settingsPanel.hygieneStatus = "Enter a file path"; return }

        var tuningLabel = tuningLabels[selectedTuning] || selectedTuning
        var report = HygieneEngine.buildReport(voicingsData, tuningLabel, hygieneIgnoreList.length, lastAuditResults)

        tempDiagramFile.source = path
        try {
            tempDiagramFile.write(report)
            settingsPanel.hygieneStatus = settingsPanel.hygieneStatus + "\nReport opened"
        } catch (e) {
            settingsPanel.hygieneStatus = "Failed to save report: " + e
            settingsPanel.hygieneStatusColor = theme.errorText
        }
    }

    // Pre-fill Save to Library from a selected FretDiagram in the score
    function captureFromScore() {
        if (!curScore) { settingsPanel.saveStatus = "No score open"; settingsPanel.saveStatusColor = theme.errorText; return }

        var sel = curScore.selection
        if (!sel || !sel.elements || sel.elements.length === 0) {
            settingsPanel.saveStatus = "Select a fretboard diagram first"
            settingsPanel.saveStatusColor = theme.errorText
            return
        }

        var elem = sel.elements[0]

        // Check if it's a FretDiagram or if a note is selected with a diagram nearby
        if (elem.type === Element.FRET_DIAGRAM) {
            // Read what we can from the API
            var strings = elem.fretStrings || 6
            var frets = elem.fretFrets || 4
            var fretOff = elem.fretOffset || 0

            settingsPanel.saveStringsCountValue = strings
            settingsPanel.saveFretValue = String(fretOff + 1)  // convert 0-indexed back

            settingsPanel.saveStatus = "Captured: " + strings + " strings, fret " + (fretOff + 1)
                + "\nDots not readable from API — enter them manually."
            settingsPanel.saveStatusColor = theme.successText
        } else {
            settingsPanel.saveStatus = "Selected element is not a fretboard diagram.\nSelect a diagram in the score, then click Capture."
            settingsPanel.saveStatusColor = theme.errorText
        }
    }

    // === Data fetching ===

    function fetchVoicings() {
        statusMsg.text = "Loading voicings..."
        statusMsg.color = theme.textSecondary
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        voicingsData = data.voicings || []
                        dataLoaded = true
                        rebuildFilterLists()
                        refreshFilteredTunings()
                        applyFilters()
                        saveToCache()
                        // T-001: trigger tuning-specific voicings now that data is loaded.
                        // loadTuningVoicings() in onRun ran before this async callback,
                        // so non-standard tunings need a second call here.
                        if (selectedTuning !== "standard") {
                            loadTuningVoicings()
                        }
                        statusMsg.text = "Loaded " + voicingsData.length + " voicings"
                        statusMsg.color = theme.successText
                    } catch (e) {
                        statusMsg.text = "Failed to parse voicings: " + e
                        statusMsg.color = theme.errorText
                    }
                } else if (xhr.status === 0) {
                    statusMsg.text = "Could not reach URL. Check connection or URL."
                    statusMsg.color = theme.errorText
                } else {
                    statusMsg.text = "Failed to fetch: HTTP " + xhr.status
                    statusMsg.color = theme.errorText
                }
            }
        }
        xhr.open("GET", jsonUrl)
        xhr.send()
    }

    // === Filtering ===

    // Current tuning data (updated when tuning changes)
    property int tuningMaxStrings: 7
    property int tuningOffset: 0  // semitones from standard (positive = higher, negative = lower)
    property var tuningMidi: {  // string number → MIDI note of open string
        "1": 64, "2": 59, "3": 55, "4": 50, "5": 45, "6": 40, "7": 33
    }

    // Tuning string pitches in scientific notation (e.g. "A3-E3-C3-G2-D2-A1")
    property string tuningPitchNotation: {
        var parts = []
        for (var s = 1; s <= tuningMaxStrings; s++) {
            var midi = tuningMidi[String(s)]
            if (midi !== undefined) {
                parts.push(midiNoteNames[midi] || "?")
            }
        }
        return parts.join("-")
    }

    // MIDI → note name lookup
    property var midiNoteTable: {
        var names = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        var t = {}
        for (var m = 0; m < 128; m++) t[m] = names[m % 12]
        return t
    }

    // Compute actual notes for a voicing in the current tuning
    function computeNotesForTuning(voicing) {
        var result = []
        var dots = voicing.dots || []
        for (var d = 0; d < dots.length; d++) {
            var strMidi = tuningMidi[String(dots[d].string)]
            if (strMidi !== undefined) {
                var absFret = voicing.fret_number + (dots[d].fret - 1)
                var midi = strMidi + absFret
                result.push(midiNoteTable[midi] || "?")
            } else {
                result.push("?")
            }
        }
        // Add open strings
        var opens = voicing.open || []
        for (var o = 0; o < opens.length; o++) {
            var openMidi = tuningMidi[String(opens[o])]
            if (openMidi !== undefined) {
                result.push(midiNoteTable[openMidi] || "?")
            }
        }
        return result
    }

    // Standard tuning reference MIDI values (for computing tuning offset)
    // 6-string: E4=64, 7-string: E4=64 (1st string is always the reference)
    readonly property int standardFirstStringMidi: 64

    function loadTuningStringCount() {
        // Read the selected tuning's JSON to get its string count and MIDI values
        var paths = [
            Qt.resolvedUrl("tunings/" + selectedTuning + ".json"),
            Qt.resolvedUrl("../config/tunings/" + selectedTuning + ".json")
        ]
        for (var p = 0; p < paths.length; p++) {
            tuningFile.source = paths[p]
            try {
                var raw = tuningFile.read()
                if (raw && raw.length > 2) {
                    var t = JSON.parse(raw)
                    var strings = t.strings || {}
                    var count = Object.keys(strings).length
                    if (count > 0) {
                        tuningMaxStrings = count
                        tuningMidi = strings
                        // Compute tuning offset: how many semitones the 1st string
                        // differs from standard E4 (MIDI 64). This offset adjusts
                        // fret transposition so chord shapes land on the correct pitch.
                        var firstMidi = strings["1"] || 64
                        tuningOffset = firstMidi - standardFirstStringMidi
                        console.log("Tuning " + selectedTuning + ": " + count + " strings, offset=" + tuningOffset)
                        return
                    }
                }
            } catch (e) {}
        }
        // Fallback: standard tuning
        tuningMaxStrings = 7
        tuningOffset = 0
        tuningMidi = {"1": 64, "2": 59, "3": 55, "4": 50, "5": 45, "6": 40, "7": 33}
    }

    // Load tuning-specific voicings if available (e.g., tunings/a-standard-voicings.json).
    // These are geometrically correct shapes calculated by chord_calculator.py.
    // Falls back to the standard library when no tuning-specific file exists.
    // Build the current calculator constraints object from properties
    function calcConstraints() {
        return {
            maxFret: calcMaxFret,
            maxStretch: calcMaxStretch,
            allowOpenStrings: calcAllowOpen,
            requireRootInBass: calcRootInBass,
            minSoundingNotes: calcMinNotes,
            maxMutedStrings: calcMaxMuted,
            maxPerQuality: calcMaxPerQuality,
        }
    }

    // Cache of calculated voicings per tuning slug — avoids re-running
    // the expensive calculator when switching back to a previously used tuning.
    property var _tuningVoicingCache: ({})
    property bool _loadingTuningVoicings: false  // re-entry guard

    // Build a cache key from current calculator constraints.
    // If user changes any constraint, cached voicings are invalidated.
    function _tuningCacheKey() {
        return "v2|" + calcMaxFret + "|" + calcMaxStretch + "|"
            + (calcAllowOpen ? 1 : 0) + "|" + (calcRootInBass ? 1 : 0) + "|"
            + calcMinNotes + "|" + calcMaxMuted + "|" + calcMaxPerQuality
    }

    // Generate voicings for the current tuning using the runtime calculator.
    // For standard tuning, uses the pre-built 820-voicing library (much richer).
    // For all other tunings, calculates (or loads from cache) voicings on the fly.
    function loadTuningVoicings() {
        // Prevent re-entry from cascade (combo bindings triggering during rebuild)
        if (_loadingTuningVoicings) return
        _loadingTuningVoicings = true

        // Save the standard library on first call so we can restore it
        if (standardVoicingsData.length === 0 && voicingsData.length > 0 && !usingTuningVoicings) {
            standardVoicingsData = voicingsData
        }

        // Standard tuning uses the pre-built library (820 hand-curated voicings)
        if (selectedTuning === "standard") {
            if (usingTuningVoicings && standardVoicingsData.length > 0) {
                var savedCtx = filterContext
                var savedCat = filterCategory
                var savedQual = filterQuality
                voicingsData = standardVoicingsData
                usingTuningVoicings = false
                rebuildFilterLists()
                if (savedCtx && contextList.indexOf(savedCtx) >= 0) filterContext = savedCtx
                if (savedCat && categoryList.indexOf(savedCat) >= 0) filterCategory = savedCat
                if (savedQual && qualityList.indexOf(savedQual) >= 0) filterQuality = savedQual
                refreshFilteredTunings()
                applyFilters()
                console.log("Restored standard voicing library (" + voicingsData.length + " voicings)")
                statusMsg.text = "Loaded " + voicingsData.length + " voicings (standard library)"
                statusMsg.color = theme.successText
            }
            _loadingTuningVoicings = false;
            return
        }

        // Non-standard tuning: check memory cache → disk cache → calculate
        var calculated
        if (_tuningVoicingCache[selectedTuning]) {
            calculated = _tuningVoicingCache[selectedTuning]
            console.log("Loaded " + calculated.length + " cached voicings for " + selectedTuning + " (memory)")
        } else {
            // Try disk cache: tunings/<slug>-voicings.json
            var cacheKey = _tuningCacheKey()
            var diskCachePath = Qt.resolvedUrl("tunings/" + selectedTuning + "-voicings.json")
            tuningCacheFile.source = diskCachePath
            try {
                var raw = tuningCacheFile.read()
                if (raw && raw.length > 2) {
                    var diskData = JSON.parse(raw)
                    if (diskData.cacheKey === cacheKey && diskData.voicings && diskData.voicings.length > 0) {
                        calculated = diskData.voicings
                        console.log("Loaded " + calculated.length + " cached voicings for " + selectedTuning + " (disk)")
                    }
                }
            } catch (e) {
                // No disk cache or stale — will recalculate
            }

            if (!calculated) {
                console.log("Calculating voicings for tuning: " + selectedTuning + " ...")
                var constraints = calcConstraints()
                calculated = VoicingCalculator.generateAll(tuningMidi, constraints)
                // Persist to disk for next startup
                if (calculated.length > 0) {
                    try {
                        tuningCacheFile.source = diskCachePath
                        tuningCacheFile.write(JSON.stringify({
                            cacheKey: cacheKey,
                            tuning: selectedTuning,
                            count: calculated.length,
                            voicings: calculated
                        }))
                        console.log("Saved " + calculated.length + " voicings to disk cache for " + selectedTuning)
                    } catch (e) {
                        console.log("Failed to write tuning cache: " + e)
                    }
                }
            }

            if (calculated && calculated.length > 0) {
                // Also store in memory cache for instant switching
                var cache = {}
                for (var ck in _tuningVoicingCache) cache[ck] = _tuningVoicingCache[ck]
                cache[selectedTuning] = calculated
                _tuningVoicingCache = cache
            }
        }

        // Preserve current filter state across tuning changes
        var savedContext = filterContext
        var savedCategory = filterCategory
        var savedQuality = filterQuality

        if (calculated && calculated.length > 0) {
            // Merge: keep standard library voicings (bass-on-4 drop2s, shells)
            // alongside calculated tuning voicings. A 6-string drop2 with bass
            // on string 4 is perfectly valid on a 7-string guitar.
            var merged = calculated.slice()
            if (standardVoicingsData.length > 0) {
                var calcIds = {}
                for (var ci = 0; ci < calculated.length; ci++) calcIds[calculated[ci].id] = true
                for (var si = 0; si < standardVoicingsData.length; si++) {
                    var sv = standardVoicingsData[si]
                    if (!calcIds[sv.id] && (sv.strings || 6) <= tuningMaxStrings) {
                        merged.push(sv)
                    }
                }
            }
            voicingsData = merged
            usingTuningVoicings = true
            rebuildFilterLists()
            if (savedContext && contextList.indexOf(savedContext) >= 0) filterContext = savedContext
            if (savedCategory && categoryList.indexOf(savedCategory) >= 0) filterCategory = savedCategory
            if (savedQuality && qualityList.indexOf(savedQuality) >= 0) filterQuality = savedQuality
            refreshFilteredTunings()
            applyFilters()
            statusMsg.text = calculated.length + " voicings for " + (tuningLabels[selectedTuning] || selectedTuning)
            statusMsg.color = theme.successText
        } else {
            console.log("No voicings — falling back to standard library")
            if (standardVoicingsData.length > 0) {
                voicingsData = standardVoicingsData
                usingTuningVoicings = false
                rebuildFilterLists()
                if (savedContext && contextList.indexOf(savedContext) >= 0) filterContext = savedContext
                if (savedCategory && categoryList.indexOf(savedCategory) >= 0) filterCategory = savedCategory
                if (savedQuality && qualityList.indexOf(savedQuality) >= 0) filterQuality = savedQuality
                refreshFilteredTunings()
                applyFilters()
            }
        }
        _loadingTuningVoicings = false
    }

    // Hidden TextEdit used for clipboard operations
    TextEdit {
        id: clipboardHelper
        visible: false
    }

    // Copy tuning info to system clipboard for pasting into a subtitle.
    function copyTuningToClipboard() {
        if (selectedTuning === "standard") {
            statusMsg.text = "Standard tuning — nothing to copy"
            statusMsg.color = theme.textMuted
            return
        }
        var tuningLabel = tuningLabels[selectedTuning] || selectedTuning
        var pitchStr = tuningPitchNotation
        var text = "Tuning: " + tuningLabel
        if (pitchStr) text += "  (" + pitchStr + ")"

        // Copy to system clipboard via TextEdit
        try {
            clipboardHelper.text = text
            clipboardHelper.selectAll()
            clipboardHelper.copy()
            statusMsg.text = "Tuning copied! Paste into a Subtitle (Add > Text > Subtitle)"
            statusMsg.color = theme.successText
        } catch (e) {
            statusMsg.text = "Copy failed: " + e
            statusMsg.color = theme.errorText
        }
    }

    // Calculate "distance" between two voicings (lower = closer hand position)
    function voicingDistance(a, b) {
        return MelodyEngine.voicingDistance(a, b)
    }

    function applyFilters() {
        filteredData = FilterEngine.applyFilters(voicingsData, {
            filterContext: filterContext,
            filterCategory: filterCategory,
            filterQuality: filterQuality,
            filterScale: filterScale,
            voicingFitsScaleFn: function(v, scaleName) {
                // Get the scale intervals by name, check if voicing fits
                var scaleIntervals = ChordScales.SCALES[scaleName]
                if (!scaleIntervals) return false
                // Extract semitone values from voicing intervals
                var ivMap = {"1":0,"b2":1,"2":2,"b3":3,"3":4,"4":5,"b5":6,"5":7,"#5":8,"b6":8,"6":9,"bb7":9,"b7":10,"7":11,"#9":3,"#11":6,"9":2,"11":5,"13":9,"b9":1,"b13":8}
                var semis = []
                var ivs = v.intervals || []
                for (var i = 0; i < ivs.length; i++) {
                    var s = ivMap[ivs[i]]
                    if (s !== undefined) semis.push(s)
                }
                if (semis.length === 0) return false
                return ChordScales.voicingFitsScale(semis, scaleIntervals)
            },
            searchText: searchText,
            maxStrings: tuningMaxStrings,
            contextStringCounts: contextStringCounts,
            sortByProximity: sortByProximity,
            lastInsertedVoicing: lastInsertedVoicing,
            distanceFn: MelodyEngine.voicingDistance
        })
    }

    // === Voicing insertion (extracted to model/InsertionEngine.qml, #103) ===

    InsertionEngine {
        id: insertionEngine
        pluginRef: chordLibrary
        curScore: chordLibrary.curScore
        tempDiagramFile: tempDiagramFile
        audioFile: audioFile
        pasteTimer: pasteTimer
        diagramPlacement: chordLibrary.diagramPlacement
        tuningMidi: chordLibrary.tuningMidi
        sortByProximity: chordLibrary.sortByProximity
        generateXmlFn: function(voicing, root) { return batchEngine.generateXmlForVoicing(voicing, root) }
        applyFiltersFn: function() { applyFilters() }

        onStatusMessage: function(text, colorType) {
            statusMsg.text = text
            statusMsg.color = colorType === "error" ? theme.errorText
                            : colorType === "success" ? theme.successText
                            : theme.textMuted
        }
        onVoicingInserted: function(voicing) {
            lastInsertedVoicing = voicing
            if (sortByProximity) applyFilters()
        }
    }

    // Convenience delegates
    function insertVoicing(voicing) { insertionEngine.insertVoicing(voicing) }
    function generateDiagramFile(voicing) { insertionEngine.generateDiagramFile(voicing) }
    function playVoicing(voicing, mode) { insertionEngine.playVoicing(voicing, mode) }

    // Keep paste infrastructure in parent (Timer needs parent scope for cmd("paste"))
    function _insertionPasteComplete() {
        if (insertionEngine._pendingVoicing) {
            lastInsertedVoicing = insertionEngine._pendingVoicing
            insertionEngine._pendingVoicing = null
            if (sortByProximity) applyFilters()
        }
    }

    // Old insertion code removed — now in InsertionEngine.qml
    // Keeping paste timer handler in parent (needs cmd("paste") in QML scope)


    // === File browser (dynamic loading to avoid import issues) ===

    property var _fileDialogComponent: null

    // Open a save dialog with a specific title, filter, and default name.
    // Calls callback(path) with the chosen file path.
    function openSaveDialog(dialogTitle, nameFilter, defaultPath, callback) {
        if (!_fileDialogComponent) {
            // probe support first
            try {
                var probe = Qt.createQmlObject(
                    'import QtQuick.Dialogs; FileDialog { }',
                    chordLibrary, "probe"
                )
                if (probe) probe.destroy()
                _fileDialogComponent = "supported"
            } catch (e) {
                _fileDialogComponent = "unsupported"
            }
        }

        if (_fileDialogComponent === "supported") {
            try {
                var dlg = Qt.createQmlObject(
                    'import QtQuick.Dialogs\n'
                    + 'FileDialog {\n'
                    + '  title: "' + dialogTitle + '"\n'
                    + '  fileMode: FileDialog.SaveFile\n'
                    + '  nameFilters: ["' + nameFilter + '"]\n'
                    + '}',
                    chordLibrary, "saveDialog"
                )
                dlg.onAccepted.connect(function() {
                    var path = dlg.selectedFile.toString().replace("file://", "")
                    dlg.destroy()
                    if (callback) callback(path)
                })
                dlg.onRejected.connect(function() { dlg.destroy() })
                dlg.open()
                return
            } catch (e) {
                _fileDialogComponent = "unsupported"
            }
        }

        // Fallback: use default path directly
        if (callback) callback(defaultPath)
    }

    function openFileBrowser(mode, targetField, callback) {
        // Try to dynamically create a FileDialog from QtQuick.Dialogs
        // If it fails (MuseScore doesn't support it), show a message
        if (!_fileDialogComponent) {
            try {
                _fileDialogComponent = Qt.createQmlObject(
                    'import QtQuick.Dialogs; FileDialog { }',
                    chordLibrary, "dynamicFileDialog"
                )
                if (_fileDialogComponent) _fileDialogComponent.destroy()
                _fileDialogComponent = "supported"
            } catch (e) {
                _fileDialogComponent = "unsupported"
                console.log("FileDialog not available: " + e)
            }
        }

        if (_fileDialogComponent === "supported") {
            try {
                var dlg = Qt.createQmlObject(
                    'import QtQuick.Dialogs\n'
                    + 'FileDialog {\n'
                    + '  title: "' + (mode === "save" ? "Export" : "Import") + '"\n'
                    + '  fileMode: FileDialog.' + (mode === "save" ? "SaveFile" : "OpenFile") + '\n'
                    + '  nameFilters: ["All supported (*.json *.html *.htm *.txt)", "JSON files (*.json)", "HTML files (*.html *.htm)", "All files (*)"]\n'
                    + '}',
                    chordLibrary, "fileBrowser"
                )
                dlg.onAccepted.connect(function() {
                    var path = dlg.selectedFile.toString().replace("file://", "")
                    targetField.text = path
                    dlg.destroy()
                    if (callback) callback()
                })
                dlg.onRejected.connect(function() { dlg.destroy() })
                dlg.open()
                return
            } catch (e) {
                _fileDialogComponent = "unsupported"
            }
        }

        statusMsg.text = "File browser not available in this MuseScore version. Type the path manually."
        statusMsg.color = theme.textMuted
    }

    // === Export/Import ===

    function doExport() {
        exportStatus.text = ""
        var path = exportPathField.text.trim()
        if (!path) {
            exportStatus.text = "Enter a file path"
            exportStatus.color = theme.errorText
            return
        }
        try {
            var data = JSON.stringify({ voicings: voicingsData }, null, 2)
            exportFile.source = path
            exportFile.write(data)
            exportStatus.text = "Exported " + voicingsData.length + " voicings"
            exportStatus.color = theme.successText
        } catch (e) {
            exportStatus.text = "Export failed: " + e
            exportStatus.color = theme.errorText
        }
    }

    function exportMusicXML() {
        exportStatus.text = "Generating MusicXML..."
        var basePath = exportPathField.text.trim().replace(/\.[^.]+$/, "")
        if (!basePath) basePath = homePath() + "/Documents/chord-library-export"
        var path = basePath + ".musicxml"

        // Build MusicXML with frame elements for each voicing
        var xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
            + '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">\n'
            + '<score-partwise version="4.0">\n'
            + '  <part-list><score-part id="P1"><part-name>Guitar</part-name></score-part></part-list>\n'
            + '  <part id="P1">\n'

        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            var ns = v.strings || 6
            xml += '    <measure number="' + (i + 1) + '">\n'
            xml += '      <attributes><divisions>1</divisions>'
            if (i === 0) xml += '<time><beats>4</beats><beat-type>4</beat-type></time>'
            xml += '</attributes>\n'

            // Harmony + frame (chord diagram)
            xml += '      <harmony>\n'
            xml += '        <root><root-step>C</root-step></root>\n'
            xml += '        <kind text="' + v.chord_quality + '">other</kind>\n'
            xml += '        <frame>\n'
            xml += '          <frame-strings>' + ns + '</frame-strings>\n'
            xml += '          <frame-frets>' + (v.visible_frets || 4) + '</frame-frets>\n'
            if (v.fret_number > 1)
                xml += '          <first-fret>' + v.fret_number + '</first-fret>\n'

            for (var d = 0; d < v.dots.length; d++) {
                var absFret = v.fret_number + (v.dots[d].fret - 1)
                xml += '          <frame-note><string>' + v.dots[d].string + '</string><fret>' + absFret + '</fret></frame-note>\n'
            }
            for (var o = 0; o < (v.open || []).length; o++)
                xml += '          <frame-note><string>' + v.open[o] + '</string><fret>0</fret></frame-note>\n'

            xml += '        </frame>\n      </harmony>\n'
            xml += '      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>\n'
            xml += '    </measure>\n'
        }

        xml += '  </part>\n</score-partwise>\n'

        exportFile.source = path
        try {
            exportFile.write(xml)
            exportStatus.text = "MusicXML: " + voicingsData.length + " voicings → " + path
            exportStatus.color = theme.successText
            Qt.openUrlExternally(path)
        } catch (e) {
            exportStatus.text = "MusicXML export failed: " + e
            exportStatus.color = theme.errorText
        }
    }

    // Write a JSON config and launch the pre-installed runner script.
    // MuseScore's FileIO can't write .command/.sh files, but can write .json.
    function launchExport(command) {
        var config = JSON.stringify({ command: command })
        var configPath = Qt.resolvedUrl("export-config.json")
        tempDiagramFile.source = configPath
        try {
            tempDiagramFile.write(config)
            Qt.openUrlExternally(Qt.resolvedUrl("run-export.command"))
            exportStatus.text = "Export launched — output will open when ready"
            exportStatus.color = theme.successText
        } catch (e) {
            exportStatus.text = "Export failed: " + e
            exportStatus.color = theme.errorText
        }
    }

    function exportGP5() {
        var basePath = exportPathField.text.trim().replace(/\.[^.]+$/, "")
        if (!basePath) basePath = homePath() + "/Documents/chord-library-export"
        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var outDir = basePath.replace(/\/[^/]+$/, "")
        launchExport('python3 "' + pluginDir + '/scripts/export_gp5.py" --data "'
            + pluginDir + '/data/voicings.json" -o "' + outDir + '" 2>&1; open "' + outDir + '"')
    }

    function exportChordSheet() {
        var defaultName = homePath() + "/Documents/chord-sheet.pdf"
        openSaveDialog("Save Chord Sheet", "PDF files (*.pdf)", defaultName, function(outPath) {
            _doExportChordSheet(outPath)
        })
    }

    function _doExportChordSheet(outPath) {
        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var dataPath = pluginDir + "/data/voicings.json"

        var filterArgs = ""
        if (selectedQuality && selectedQuality !== "All Qualities")
            filterArgs += ' --quality "' + selectedQuality + '"'
        if (selectedContext && selectedContext !== "All Contexts")
            filterArgs += ' --context "' + selectedContext + '"'
        if (selectedCategory && selectedCategory !== "All Types")
            filterArgs += ' --category "' + selectedCategory + '"'

        var title = "Chord Reference Sheet"
        if (selectedQuality && selectedQuality !== "All Qualities")
            title = selectedQuality + " Voicings"
        if (selectedContext && selectedContext !== "All Contexts")
            title += " (" + selectedContext + ")"

        launchExport('cd "' + pluginDir + '"; python3 "' + pluginDir + '/scripts/generate_chord_sheet.py"'
            + ' --data "' + dataPath + '"' + filterArgs + ' --title "' + title + '"'
            + ' -o "' + outPath + '" 2>&1; open "' + outPath + '"')
    }

    function exportDiagramsSVG() {
        var basePath = exportPathField.text.trim().replace(/\.[^.]+$/, "")
        if (!basePath) basePath = homePath() + "/Documents/chord-library-diagrams"
        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var dataPath = pluginDir + "/data/voicings.json"

        var filterArgs = ""
        if (selectedQuality && selectedQuality !== "All Qualities")
            filterArgs += ' --quality "' + selectedQuality + '"'
        if (selectedContext && selectedContext !== "All Contexts")
            filterArgs += ' --context "' + selectedContext + '"'
        if (selectedCategory && selectedCategory !== "All Types")
            filterArgs += ' --category "' + selectedCategory + '"'

        launchExport('mkdir -p "' + basePath + '"; python3 "' + pluginDir
            + '/scripts/fretboard_renderer.py" --data "' + dataPath + '"'
            + filterArgs + ' -o "' + basePath + '" 2>&1; open "' + basePath + '"')
    }

    // === Tools (launch Python scripts, output to file, open with default handler) ===

    function launchTool(scriptName, args, statusLabel, successMsg, outputExt) {
        // Runs a Python script silently, captures output to a temp file,
        // and opens it with the system's default application (TextEdit for .txt,
        // Preview for .pdf, etc.). No terminal window.
        if (!outputExt) outputExt = "txt"
        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var scriptPath = pluginDir + "/scripts/" + scriptName
        var dataPath = pluginDir + "/data/voicings.json"
        var outputPath = pluginDir + "/tool-output." + outputExt

        // Write the tool config as JSON (FileIO can write .json reliably)
        var toolConfig = JSON.stringify({
            script: scriptPath,
            args: args.replace("DATA_PATH", dataPath),
            output: outputPath,
            pluginDir: pluginDir,
        })

        var configPath = Qt.resolvedUrl("tool-config.json")
        tempDiagramFile.source = configPath
        try {
            tempDiagramFile.write(toolConfig)
        } catch (e) {
            showResult("Error", "Failed to write tool config: " + e, false)
            return
        }

        // Execute via the pre-installed runner script (has +x permission)
        Qt.openUrlExternally(Qt.resolvedUrl("run-tool.command"))
        showResult("Done", successMsg, true)
    }

    // Extract chord symbols from the open score via the plugin API
    // and write them to a JSON file for Python scripts to consume.
    function extractChordsToFile() {
        if (!curScore) return null

        var chords = []
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)

        var measureNum = 0
        while (cursor.segment) {
            var seg = cursor.segment
            if (seg.annotations) {
                for (var a = 0; a < seg.annotations.length; a++) {
                    if (seg.annotations[a].type === Element.HARMONY) {
                        chords.push({
                            text: seg.annotations[a].text,
                            tick: seg.tick,
                            measure: measureNum,
                        })
                    }
                }
            }
            cursor.next()
            measureNum++
        }

        var title = curScore.scoreName || curScore.title || "Untitled"
        var composer = curScore.composer || ""

        var data = JSON.stringify({
            title: title,
            composer: composer,
            total_measures: measureNum,
            chords: chords,
        }, null, 2)

        var outPath = Qt.resolvedUrl("score-chords.json")
        tempDiagramFile.source = outPath
        try {
            tempDiagramFile.write(data)
            return outPath.toString().replace("file://", "")
        } catch (e) {
            console.log("Failed to extract chords: " + e)
            showResult("Error", "Failed to extract chords: " + e, false)
            return null
        }
    }

    // === Inline tools (extracted to model/InlineTools.qml, #101) ===

    InlineTools {
        id: inlineTools
        pluginRef: chordLibrary
        curScore: chordLibrary.curScore
        voicingsData: chordLibrary.voicingsData
        filterContext: chordLibrary.filterContext
        filterCategory: chordLibrary.filterCategory
        skipDiagramPositions: chordLibrary.skipDiagramPositions
        diagramPlacement: chordLibrary.diagramPlacement
        findBestVoicingFn: function(root, quality) { return findBestVoicing(root, quality) }
        parseChordSymbolFn: function(text) { return parseChordSymbol(text) }
        showResultFn: function(title, msg, ok) { showResult(title, msg, ok) }
        openSaveDialogFn: function(title, filter, path, cb) { openSaveDialog(title, filter, path, cb) }
        launchExportFn: function(cmd) { launchExport(cmd) }
        extractChordsToFileFn: function() { return extractChordsToFile() }
        homePath: chordLibrary.homePath()

        onStatusMessage: function(text, colorType) {
            if (colorType === "error") {
                _toolStatusText = text
            } else {
                statusMsg.text = text
                statusMsg.color = colorType === "success" ? theme.successText : theme.textMuted
            }
        }
    }

    // Convenience delegates for existing callers
    function analyzeCurrentScore() { inlineTools.analyzeCurrentScore() }
    function runVoiceLeading() { inlineTools.runVoiceLeading() }
    function suggestFingerings() { inlineTools.suggestFingerings() }
    function addFingeringsToScore() { inlineTools.addFingeringsToScore() }
    function exportFingeringSheet() { inlineTools.exportFingeringSheet() }
    function computeFingeringString(voicing) { return inlineTools.computeFingeringString(voicing) }
    function suggestFingering(voicing) { return inlineTools.suggestFingering(voicing) }

    function doImport(path) {
        importPanel.importMergeStatus = "Loading..."
        importPanel.importMergeStatusColor = theme.textMuted

        if (!path) {
            importPanel.importMergeStatus = "Enter a file path"
            importPanel.importMergeStatusColor = theme.errorText
            return
        }
        importFile.source = path
        try {
            var raw = importFile.read()
            if (!raw || raw.length === 0) {
                importPanel.importMergeStatus = "FAILED: file is empty or not found"
                importPanel.importMergeStatusColor = theme.errorText
                return
            }
            var data = JSON.parse(raw)
            var imported = data.voicings || []

            if (!Array.isArray(imported) || imported.length === 0) {
                importPanel.importMergeStatus = "FAILED: no voicings array found in file"
                importPanel.importMergeStatusColor = theme.errorText
                return
            }

            // Validate required fields
            var errors = validateImport(imported)
            if (errors.length > 0) {
                importPanel.importMergeStatus = "FAILED: " + errors[0]
                importPanel.importMergeStatusColor = theme.errorText
                return
            }

            // Merge: add imported voicings, skip duplicates by ID
            var existingIds = {}
            for (var i = 0; i < voicingsData.length; i++) {
                existingIds[voicingsData[i].id] = true
            }

            var added = 0
            var skipped = 0
            var merged = voicingsData.slice()
            for (var j = 0; j < imported.length; j++) {
                if (existingIds[imported[j].id]) {
                    skipped++
                } else {
                    merged.push(imported[j])
                    added++
                }
            }

            voicingsData = merged
            rebuildFilterLists()
            refreshFilteredTunings()
            applyFilters()
            saveToCache()

            if (added > 0) {
                importPanel.importMergeStatus = "SUCCESS: " + added + " voicings added"
                    + (skipped > 0 ? ", " + skipped + " duplicates skipped" : "")
                    + " (" + voicingsData.length + " total)"
                importPanel.importMergeStatusColor = theme.successText
            } else {
                importPanel.importMergeStatus = "No new voicings — all " + skipped + " were duplicates"
                importPanel.importMergeStatusColor = theme.textMuted
            }
        } catch (e) {
            importPanel.importMergeStatus = "FAILED: " + e
            importPanel.importMergeStatusColor = theme.errorText
        }
    }

    function validateImport(voicings) {
        var errors = []
        var requiredFields = ["id", "name", "chord_quality", "root", "category",
                              "context", "strings", "fret_number", "dots", "mutes",
                              "open", "notes", "intervals", "tags"]

        for (var i = 0; i < voicings.length && i < 5; i++) {
            var v = voicings[i]
            for (var f = 0; f < requiredFields.length; f++) {
                if (v[requiredFields[f]] === undefined) {
                    errors.push("Voicing " + (v.id || "#" + i) + " missing field: " + requiredFields[f])
                }
            }
            if (v.root && v.root !== "C") {
                errors.push("Voicing " + v.id + " root is '" + v.root + "' — must be C")
            }
        }
        return errors
    }

    // === T-014: Arrangement Presets ===

    FileIO {
        id: presetFile
    }

    function savePreset(path) {
        if (_batchChords.length === 0) {
            statusMsg.text = "No walkthrough loaded — nothing to save"
            statusMsg.color = theme.errorText
            return
        }
        var preset = {
            version: 1,
            tuning: selectedTuning,
            context: filterContext,
            category: filterCategory,
            chords: []
        }
        for (var i = 0; i < _batchChords.length; i++) {
            var item = _batchChords[i]
            preset.chords.push({
                text: item.text,
                root: item.root,
                quality: item.quality,
                voicingId: item.voicing ? item.voicing.id : null,
                voicingName: item.voicing ? item.voicing.name : null,
                bassMidi: item.bassMidi,
                melodyMidi: item.melodyMidi,
            })
        }
        presetFile.source = path
        presetFile.write(JSON.stringify(preset, null, 2))
        statusMsg.text = "Preset saved: " + preset.chords.length + " chords → " + path.split("/").pop()
        statusMsg.color = theme.successText
    }

    function loadPreset(path) {
        presetFile.source = path
        try {
            var raw = presetFile.read()
            if (!raw || raw.length === 0) {
                statusMsg.text = "Preset file empty or not found"
                statusMsg.color = theme.errorText
                return
            }
            var preset = JSON.parse(raw)
            if (!preset.chords || preset.chords.length === 0) {
                statusMsg.text = "No chords in preset file"
                statusMsg.color = theme.errorText
                return
            }

            // Build voicing ID lookup from both current and standard library
            // so presets saved on one tuning can be loaded on another.
            var idLookup = {}
            for (var v = 0; v < voicingsData.length; v++) {
                idLookup[voicingsData[v].id] = voicingsData[v]
            }
            for (var sv = 0; sv < standardVoicingsData.length; sv++) {
                if (!idLookup[standardVoicingsData[sv].id])
                    idLookup[standardVoicingsData[sv].id] = standardVoicingsData[sv]
            }

            var chords = []
            var matched = 0, fallback = 0
            for (var i = 0; i < preset.chords.length; i++) {
                var pc = preset.chords[i]
                var voicing = null

                // Try exact ID match first
                if (pc.voicingId && idLookup[pc.voicingId]) {
                    voicing = idLookup[pc.voicingId]
                    matched++
                } else {
                    // Fall back to findBestVoicing
                    voicing = findBestVoicing(pc.root, pc.quality, pc.melodyMidi, pc.bassMidi)
                    fallback++
                }

                if (voicing) {
                    chords.push({
                        text: pc.text,
                        root: pc.root,
                        quality: pc.quality,
                        voicing: voicing,
                        melodyMidi: pc.melodyMidi || -1,
                        bassMidi: pc.bassMidi || -1,
                        tick: 0,
                        ambiguous: false,
                    })
                }
            }

            if (chords.length === 0) {
                statusMsg.text = "No voicings matched for this preset"
                statusMsg.color = theme.errorText
                return
            }

            _batchChords = chords
            _batchIndex = 0
            batchTotal = chords.length
            batchQueue = [1]
            batchShowNext()

            statusMsg.text = "Loaded preset: " + chords.length + " chords (" + matched + " exact, " + fallback + " re-matched)"
            statusMsg.color = theme.successText
        } catch (e) {
            statusMsg.text = "Failed to load preset: " + e
            statusMsg.color = theme.errorText
        }
    }

    // === T-010: iReal Pro Import ===

    function importIRealPro(input) {
        var chords
        if (input.indexOf("irealb") === 0) {
            var parsed = IRealParser.parseUrl(input)
            if (!parsed || !parsed.chords || parsed.chords.length === 0) {
                statusMsg.text = "Could not parse iReal Pro URL"
                statusMsg.color = theme.errorText
                return
            }
            chords = parsed.chords
            statusMsg.text = "Parsed: " + (parsed.title || "Untitled") + " — " + chords.length + " chords"
        } else {
            // Plain text chord chart
            chords = IRealParser.parsePlainText(input)
            if (!chords || chords.length === 0) {
                statusMsg.text = "No chords found in text"
                statusMsg.color = theme.errorText
                return
            }
        }

        // Build batch chords with voicing selection
        var batchItems = []
        for (var i = 0; i < chords.length; i++) {
            var c = chords[i]
            var bassMidi = -1
            if (c.slashBass) {
                bassMidi = Transposer.SEMITONE_MAP[c.slashBass]
                if (bassMidi === undefined) bassMidi = -1
            }
            if (bassMidi < 0) {
                bassMidi = MelodyEngine.suggestBassNote(c.root, c.quality, Transposer.SEMITONE_MAP)
            }
            var voicing = findBestVoicing(c.root, c.quality, -1, bassMidi)
            if (voicing) {
                batchItems.push({
                    text: c.text,
                    root: c.root,
                    quality: c.quality,
                    voicing: voicing,
                    melodyMidi: -1,
                    bassMidi: bassMidi,
                    tick: 0,
                    ambiguous: false,
                })
            }
        }

        if (batchItems.length === 0) {
            statusMsg.text = "No voicings found for parsed chords"
            statusMsg.color = theme.errorText
            return
        }

        _batchChords = batchItems
        _batchIndex = 0
        batchTotal = batchItems.length
        batchQueue = [1]
        batchShowNext()

        statusMsg.text = "Loaded " + batchItems.length + " chords from import"
        statusMsg.color = theme.successText
    }

    // === T-015: Voicing Comparison ===

    property var compareVoicings: []  // up to 3 voicings for side-by-side comparison
    property bool showComparison: false

    function addToComparison(voicing) {
        if (compareVoicings.length >= 3) {
            statusMsg.text = "Comparison full (max 3) — clear first"
            statusMsg.color = theme.textMuted
            return
        }
        // Check for duplicates
        for (var i = 0; i < compareVoicings.length; i++) {
            if (compareVoicings[i].id === voicing.id) {
                statusMsg.text = "Already in comparison"
                statusMsg.color = theme.textMuted
                return
            }
        }
        var updated = compareVoicings.slice()
        updated.push(voicing)
        compareVoicings = updated
        showComparison = true
        statusMsg.text = "Added to comparison (" + compareVoicings.length + "/3)"
        statusMsg.color = theme.successText
    }

    function clearComparison() {
        compareVoicings = []
        showComparison = false
    }


    // === UI ===

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Header
        Label {
            text: "Siege Analytics Chord Library"
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
            visible: !showToolResults
        }

        // Tab navigation
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            visible: !showToolResults
            currentIndex: currentTab
            onCurrentIndexChanged: currentTab = currentIndex

            TabButton { text: "Library"; font.pixelSize: 10 }
            TabButton { text: "Score Tools"; font.pixelSize: 10 }
            TabButton { text: "Export"; font.pixelSize: 10 }
            TabButton { text: "Import"; font.pixelSize: 10 }
            TabButton { text: "Practice"; font.pixelSize: 10 }
            TabButton { text: "Settings"; font.pixelSize: 10 }
        }

        // === Tab 1: Score Tools (extracted to ui/ScoreToolsPanel.qml, #97) ===
        ScoreToolsPanel {
            id: scoreToolsPanel
            visible: currentTab === 1 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            calc: calcState
            theme: theme
            usingTuningVoicings: chordLibrary.usingTuningVoicings
            skipDiagramPositions: chordLibrary.skipDiagramPositions
            toolStatusText: _toolStatusText

            onAnalyzeRequested: analyzeCurrentScore()
            onVoiceLeadingRequested: runVoiceLeading()
            onFingeringsRequested: suggestFingerings()
            onConstraintChanged: function(key, value) {
                chordLibrary[key] = value
                if (usingTuningVoicings) loadTuningVoicings()
            }
            onAnnotateRequested: addFingeringsToScore()
            onFingeringSheetRequested: exportFingeringSheet()
            onSkipDiagramsChanged: function(checked) { skipDiagramPositions = checked }
        }

        // === Tab 2: Export (extracted to ui/ExportPanel.qml, #94) ===
        ExportPanel {
            visible: currentTab === 2 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            defaultPath: homePath() + "/Documents/chord-library-export.json"
            onExportJson: doExport()
            onExportMusicXML: exportMusicXML()
            onExportGP5: exportGP5()
            onExportChordSheet: exportChordSheet()
            onExportDiagramsSVG: exportDiagramsSVG()
            onBrowseClicked: function(field) { openFileBrowser("save", field, null) }
        }

        // === Tab 3: Import (extracted to ui/ImportPanel.qml, #95) ===
        ImportPanel {
            id: importPanel
            visible: currentTab === 3 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            // State groups (centralized, C1 #104)
            library: QtObject {
                property var voicingsData: chordLibrary.voicingsData
                property bool dataLoaded: chordLibrary.dataLoaded
            }
            tuning: tuningState
            theme: theme

            // Scalar properties
            jsonUrl: chordLibrary.jsonUrl
            hasBatchChords: _batchChords.length > 0

            // Signal handlers
            onRebuildRequested: {
                var diskPath = Qt.resolvedUrl("tunings/" + selectedTuning + "-voicings.json")
                tuningCacheFile.source = diskPath
                try { tuningCacheFile.write("") } catch(e) {}
                var cache = {}
                for (var ck in _tuningVoicingCache) {
                    if (ck !== selectedTuning) cache[ck] = _tuningVoicingCache[ck]
                }
                _tuningVoicingCache = cache
                loadTuningVoicings()
                importPanel.rebuildStatus = "Done! " + voicingsData.length + " voicings ready for " + (tuningLabels[selectedTuning] || selectedTuning) + "."
                importPanel.rebuildStatusColor = theme.successText
                importPanel._rebuildInProgress = false
            }

            onResetRequested: {
                _tuningVoicingCache = {}
                standardVoicingsData = []
                usingTuningVoicings = false
                dataLoaded = false
                if (loadFromCache()) {
                    loadTuningVoicings()
                }
                importPanel.rebuildStatus = "Data reset. Loaded " + voicingsData.length + " voicings."
                importPanel.rebuildStatusColor = theme.successText
            }

            onUrlApplyRequested: function(url) {
                jsonUrl = url
                dataLoaded = false
                saveSettings()
                fetchVoicings()
            }
            onUrlResetRequested: {
                var defaultUrl = "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/plugin/data/voicings.json"
                jsonUrl = defaultUrl
                dataLoaded = false
                saveSettings()
                fetchVoicings()
            }
            onRefreshRequested: {
                dataLoaded = false
                fetchVoicings()
            }

            onImportMergeRequested: function(path) { doImport(path) }
            onBrowseImportRequested: function(field) { openFileBrowser("open", field, null) }
            onImportIRealRequested: function(text) { importIRealPro(text) }

            onPresetSaveRequested: function(path) { savePreset(path) }
            onPresetLoadRequested: function(path) { loadPreset(path) }

            // --- iReal file import (#149) ---
            onLoadIRealFileRequested: function(path) {
                try {
                    // Use file:// prefix for absolute paths, Qt.resolvedUrl for relative
                    if (path.indexOf("/") === 0) {
                        importFile.source = "file://" + path
                    } else {
                        importFile.source = Qt.resolvedUrl(path)
                    }
                    var content = importFile.read()
                    if (!content || content.length < 5) {
                        importPanel.importMergeStatus = "File is empty or unreadable: " + path
                        importPanel.importMergeStatusColor = theme.errorText
                        return
                    }
                    // Try to extract irealb:// URL from HTML
                    var urlMatch = content.match(/irealb:\/\/[^"'<\s]+/)
                    if (urlMatch) {
                        // Decode URL-encoded characters before parsing
                        var url = urlMatch[0]
                        try { url = decodeURIComponent(url) } catch(de) {}
                        importIRealPro(url)
                    } else {
                        // Treat as plain text chord chart
                        importIRealPro(content)
                    }
                } catch (e) {
                    importPanel.importMergeStatus = "Error reading file: " + e
                    importPanel.importMergeStatusColor = theme.errorText
                }
            }

            // --- Tuning import/create (moved from Settings, #144) ---
            onImportTuningRequested: function(path) { importTuning(path) }
            onCreateTuningRequested: function(name, pitches, numStrings) {
                // Use the same bypass as Settings saveTuningFn (#154)
                settingsPanel.saveTuningFn(name, pitches, numStrings, "")
            }
        }

        // === Tab 4: Practice (extracted to ui/PracticePanel.qml, #96) ===
        PracticePanel {
            visible: currentTab === 4 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            practice: QtObject {
                property var voicing: chordLibrary.practiceVoicing
                property bool showAnswer: chordLibrary.practiceShowAnswer
                property string mode: chordLibrary.practiceMode
                property int correct: chordLibrary.practiceCorrect
                property int total: chordLibrary.practiceTotal
            }
            theme: theme

            onResetRequested: practiceReset()
            onModeChanged: function(mode) { practiceMode = mode; practiceNext() }
            onRevealRequested: practiceReveal()
            onMarkCorrectRequested: practiceMarkCorrect()
            onMarkWrongRequested: practiceMarkWrong()
            onSkipRequested: practiceNext()
        }

        // === Tab 5: Settings (extracted to ui/SettingsPanel.qml, #98) ===
        SettingsPanel {
            id: settingsPanel
            visible: currentTab === 5 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            tuning: tuningState
            tuningListModel: tuningList.slice()
            theme: theme
            diagramPlacement: chordLibrary.diagramPlacement
            builtInTunings: chordLibrary.builtInTunings
            saveTuningFn: function(name, pitches, numStrings, originalSlug) {
                try {
                    // Direct implementation — bypasses TuningManager (#154)
                    var rawParts = pitches.split(",")
                    var midiPitches = []
                    for (var p = 0; p < rawParts.length; p++) {
                        var midi = noteNameToMidi(rawParts[p].trim())
                        if (midi < 0) {
                            settingsPanel.tuningStatus = "Can't parse: '" + rawParts[p].trim() + "'"
                            settingsPanel.tuningStatusColor = "#e74c3c"
                            return
                        }
                        midiPitches.push(midi)
                    }
                    if (midiPitches.length < numStrings) {
                        settingsPanel.tuningStatus = "Need " + numStrings + " pitches, got " + midiPitches.length
                        settingsPanel.tuningStatusColor = "#e74c3c"
                        return
                    }
                    midiPitches = midiPitches.slice(0, numStrings)
                    var strings = {}
                    var notes = {}
                    for (var s = 0; s < midiPitches.length; s++) {
                        strings[s + 1] = midiPitches[s]
                        notes[s + 1] = midiNoteNames[midiPitches[s]] || ("?" + midiPitches[s])
                    }
                    var tuningObj = { name: name, description: "Custom tuning", strings: strings, notes: notes }
                    var slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
                    var isUpdate = originalSlug && originalSlug.length > 0
                    var oldSlug = isUpdate ? originalSlug : ""
                    // Built-in tunings keep their slug under rename so the factory file on disk
                    // stays in sync and the builtInTunings registry doesn't develop ghosts.
                    // Label changes freely; pitches can change too (Reset to factory restores).
                    if (isUpdate && builtInTunings.indexOf(oldSlug) >= 0) {
                        slug = oldSlug
                    }
                    // Write file
                    tuningFile.source = Qt.resolvedUrl("tunings/" + slug + ".json")
                    tuningFile.write(JSON.stringify(tuningObj, null, 2))
                    // Build new lists
                    var newList = []
                    var newLabels = {}
                    var newCounts = {}
                    var oldLabels = tuningLabels || {}
                    var oldCounts = tuningStringCounts || {}
                    var lKeys = Object.keys(oldLabels)
                    var cKeys = Object.keys(oldCounts)
                    // Copy existing entries, skipping old slug if renaming
                    for (var li = 0; li < tuningList.length; li++) {
                        if (isUpdate && tuningList[li] === oldSlug && oldSlug !== slug) continue
                        newList.push(tuningList[li])
                    }
                    for (var ki = 0; ki < lKeys.length; ki++) {
                        if (isUpdate && lKeys[ki] === oldSlug && oldSlug !== slug) continue
                        newLabels[lKeys[ki]] = oldLabels[lKeys[ki]]
                    }
                    for (var ci = 0; ci < cKeys.length; ci++) {
                        if (isUpdate && cKeys[ci] === oldSlug && oldSlug !== slug) continue
                        newCounts[cKeys[ci]] = oldCounts[cKeys[ci]]
                    }
                    // Add/update new slug
                    if (newList.indexOf(slug) < 0) newList.push(slug)
                    newLabels[slug] = name
                    newCounts[slug] = numStrings
                    tuningList = newList
                    tuningLabels = newLabels
                    tuningStringCounts = newCounts
                    // Select the tuning
                    selectedTuning = slug
                    loadTuningStringCount()
                    loadTuningVoicings()
                    refreshFilteredTunings()
                    saveSettings()
                    // Clear editing state AND the form so a second Save click can't
                    // duplicate. Previously only editingTuningSlug was cleared, which
                    // meant clicking Save again on the still-populated form created a
                    // new custom tuning even when the user meant to rename a built-in.
                    settingsPanel.editingTuningSlug = ""
                    settingsPanel.tuningNameValue = ""
                    settingsPanel.tuningPitchesValue = ""
                    settingsPanel.tuningStringCountValue = 6
                    // tuningListModel updates automatically via its binding to tuningList
                    // Show success
                    var noteArr = []
                    for (var n = 1; n <= numStrings; n++) noteArr.push(notes[n])
                    var action = isUpdate ? "Updated" : "Created"
                    settingsPanel.tuningStatus = action + ": " + name + " (" + noteArr.join("-") + ")"
                    settingsPanel.tuningStatusColor = "#27ae60"
                } catch(e) {
                    settingsPanel.tuningStatus = "Error: " + String(e)
                    settingsPanel.tuningStatusColor = "#e74c3c"
                }
            }
            profilesData: chordLibrary._profileList
            activeProfileId: chordLibrary._activeProfileId
            onProfileSelected: function(profileId) { setProfile(profileId) }
            // Backup / restore (#172) + URL import (#67)
            onBackupExportRequested: function() { exportBackup() }
            onUrlImportRequested: function(url) { importFromUrl(url) }
            onBackupRestoreRequested: function() {
                // Try native FileDialog; fall back to a fixed Desktop path if not available
                var tmpField = { text: "" }
                openFileBrowser("open", tmpField, function() {
                    if (tmpField.text) restoreBackup(tmpField.text)
                })
                // If the dialog wasn't supported, openFileBrowser sets statusMsg and returns.
                // User can also drop a backup at ~/Desktop/chordlibrary-backup-restore.json
                // and click Restore again if the dialog didn't appear.
            }
            // Active style readout callback (#195) — SettingsPanel uses this
            // to live-preview what its composition-form draft resolves to.
            resolveCompositionFn: function(composition, allStyles) {
                return StyleComposer.resolve(composition, allStyles)
            }
            // Save a new composition to styles.json and reload (#170)
            onCompositionSaveRequested: function(composition) {
                try {
                    // Append to in-memory list, avoiding duplicate ids
                    var updated = _profileList.slice()
                    var replaced = false
                    for (var i = 0; i < updated.length; i++) {
                        if (updated[i].id === composition.id) {
                            updated[i] = composition
                            replaced = true
                            break
                        }
                    }
                    if (!replaced) updated.push(composition)
                    _profileList = updated
                    // Persist to styles.json
                    profilesConfigFile.write(JSON.stringify({ profiles: updated }, null, 2))
                    settingsPanel.profileStatus = (replaced ? "Updated: " : "Created: ") + composition.name
                    settingsPanel.profileStatusColor = theme.successText
                    console.log("Composition saved: " + composition.id)
                } catch (e) {
                    settingsPanel.profileStatus = "Error: " + String(e)
                    settingsPanel.profileStatusColor = theme.errorText
                    console.log("Composition save failed: " + e)
                }
            }

            onPlacementChanged: function(placement) {
                diagramPlacement = placement
                saveSettings()
            }
            onEditTuningRequested: function(slug) { editTuning(slug) }
            onResetBuiltInTuningRequested: function(slug) { resetBuiltInTuning(slug) }
            onDeleteTuningRequested: function(slug) {
                // Direct implementation — bypasses TuningManager for...in bug (#154)
                if (!slug) return
                if (builtInTunings.indexOf(slug) >= 0) {
                    settingsPanel.tuningStatus = "Cannot delete built-in tuning"
                    settingsPanel.tuningStatusColor = "#e74c3c"
                    return
                }
                try {
                    var newList = []
                    for (var i = 0; i < tuningList.length; i++) {
                        if (tuningList[i] !== slug) newList.push(tuningList[i])
                    }
                    var newLabels = {}
                    var oldLabels = tuningLabels || {}
                    var lKeys = Object.keys(oldLabels)
                    for (var li = 0; li < lKeys.length; li++) {
                        if (lKeys[li] !== slug) newLabels[lKeys[li]] = oldLabels[lKeys[li]]
                    }
                    var newCounts = {}
                    var oldCounts = tuningStringCounts || {}
                    var cKeys = Object.keys(oldCounts)
                    for (var ci = 0; ci < cKeys.length; ci++) {
                        if (cKeys[ci] !== slug) newCounts[cKeys[ci]] = oldCounts[cKeys[ci]]
                    }
                    tuningList = newList
                    tuningLabels = newLabels
                    tuningStringCounts = newCounts
                    if (selectedTuning === slug) {
                        selectedTuning = "standard"
                        loadTuningStringCount()
                        loadTuningVoicings()
                    }
                    // Clear file
                    tuningFile.source = Qt.resolvedUrl("tunings/" + slug + ".json")
                    try { tuningFile.write("") } catch(e2) {}
                    refreshFilteredTunings()
                    saveSettings()
                    // tuningListModel updates automatically via its binding to tuningList
                    settingsPanel.tuningStatus = "Deleted: " + slug
                    settingsPanel.tuningStatusColor = "#27ae60"
                } catch(e) {
                    settingsPanel.tuningStatus = "Error: " + String(e)
                    settingsPanel.tuningStatusColor = "#e74c3c"
                }
            }
            onMoveTuningRequested: function(slug, direction) {
                var list = tuningList.slice()
                var idx = list.indexOf(slug)
                if (idx < 0) return
                var newIdx = idx + direction
                if (newIdx < 0 || newIdx >= list.length) return
                var temp = list[newIdx]
                list[newIdx] = list[idx]
                list[idx] = temp
                tuningList = list
                refreshFilteredTunings()
                // tuningListModel updates automatically via its binding to tuningList
                saveSettings()
            }
            onCreateTuningRequested: function(name, pitches, numStrings) {
                settingsPanel.tuningStatus = "Saving..."
                settingsPanel.tuningStatusColor = "#888"
                settingsPanel.saveTuningFn(name, pitches, numStrings, "")
            }
            onImportTuningRequested: function(path) { importTuning(path) }
            onBrowseTuningRequested: function(field) { openFileBrowser("open", field, null) }
            // createCustomContext handler removed in #184 — Contexts sub-tab retired.

            // --- Scale signals (#142) ---
            onScaleAdded: function(jsonData) {
                var s = JSON.parse(jsonData)
                var id = ChordScales.addScale(s.name, s.intervals, s.category, s.aliases)
                if (id) {
                    saveScalesConfig()
                    settingsPanel.scaleStatus = "Added: " + s.name
                    settingsPanel.scaleStatusColor = theme.successText
                    settingsPanel.scalesData = ChordScales.getScaleList()
                } else {
                    settingsPanel.scaleStatus = "Failed to add scale (name may already exist)"
                    settingsPanel.scaleStatusColor = theme.errorText
                }
            }
            onScaleUpdated: function(jsonData) {
                var s = JSON.parse(jsonData)
                if (ChordScales.updateScale(s.id, s.name, s.intervals, s.category, s.aliases)) {
                    saveScalesConfig()
                    settingsPanel.scaleStatus = "Updated: " + s.name
                    settingsPanel.scaleStatusColor = theme.successText
                    settingsPanel.scalesData = ChordScales.getScaleList()
                } else {
                    settingsPanel.scaleStatus = "Failed to update scale"
                    settingsPanel.scaleStatusColor = theme.errorText
                }
            }
            onScaleDeleted: function(scaleId) {
                var info = ChordScales.getScaleById(scaleId)
                if (ChordScales.deleteScale(scaleId)) {
                    saveScalesConfig()
                    settingsPanel.scaleStatus = "Deleted: " + (info ? info.name : scaleId)
                    settingsPanel.scaleStatusColor = theme.successText
                    settingsPanel.scalesData = ChordScales.getScaleList()
                } else {
                    settingsPanel.scaleStatus = "Cannot delete built-in scale"
                    settingsPanel.scaleStatusColor = theme.errorText
                }
            }
            onChordScaleMappingChanged: function(quality, scaleIdsJson) {
                var scaleNames = JSON.parse(scaleIdsJson)
                if (ChordScales.setChordScaleMapping(quality, scaleNames)) {
                    saveScalesConfig()
                    settingsPanel.scaleStatus = "Updated mapping for " + quality
                    settingsPanel.scaleStatusColor = theme.successText
                    // Refresh the name-based map for UI
                    var nameMap = {}
                    var csm = ChordScales.CHORD_SCALE_MAP
                    for (var q in csm) nameMap[q] = csm[q].slice()
                    settingsPanel.chordScaleMap = nameMap
                } else {
                    // Find which names are invalid
                    var bad = []
                    for (var i = 0; i < scaleNames.length; i++) {
                        if (!ChordScales.SCALES[scaleNames[i]]) bad.push(scaleNames[i])
                    }
                    settingsPanel.scaleStatus = "Unknown scale" + (bad.length > 1 ? "s" : "") + ": " + bad.join(", ")
                    settingsPanel.scaleStatusColor = theme.errorText
                }
            }
            onCustomQualityAdded: function(qualityName) {
                if (ChordScales.addCustomQuality(qualityName)) {
                    saveScalesConfig()
                    settingsPanel.scaleStatus = "Added quality: " + qualityName
                    settingsPanel.scaleStatusColor = theme.successText
                    settingsPanel.customQualities = ChordScales.getCustomQualities()
                } else {
                    settingsPanel.scaleStatus = "Quality already exists: " + qualityName
                    settingsPanel.scaleStatusColor = theme.errorText
                }
            }
            onCustomQualityRemoved: function(qualityName) {
                if (ChordScales.removeCustomQuality(qualityName)) {
                    saveScalesConfig()
                    settingsPanel.scaleStatus = "Removed quality: " + qualityName
                    settingsPanel.scaleStatusColor = theme.successText
                    settingsPanel.customQualities = ChordScales.getCustomQualities()
                } else {
                    settingsPanel.scaleStatus = "Quality not found: " + qualityName
                    settingsPanel.scaleStatusColor = theme.errorText
                }
            }
        }

        // === Tool Results panel (overlay) — extracted to WalkthroughPanel.qml ===
        WalkthroughPanel {
            id: walkthroughPanel
            visible: showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            batchChords: batchEngine.batchChords
            batchIndex: batchEngine.batchIndex
            batchTotal: batchEngine.batchTotal
            batchActive: batchEngine.batchQueue.length > 0
            resultsTitle: toolResultsTitle
            activeProfileName: {
                for (var i = 0; i < _profileList.length; i++) {
                    if (_profileList[i].id === _activeProfileId) return _profileList[i].name
                }
                return ""
            }
            resultsContent: toolResultsContent
            availableCategories: categoryList
            tuningName: tuningLabels[selectedTuning] || selectedTuning
            calculatedVoicings: usingTuningVoicings
            // Section-aware mode (#167)
            scoreSections: chordLibrary.scoreSections
            activeMode: chordLibrary.activeMode
            modeIdList: ["chord-melody", "comping", "solo-guitar", "duo"]
            modeDisplayList: ["Chord Melody", "Comping", "Solo Guitar", "Duo"]
            onSectionsChanged: function(sections) {
                chordLibrary.scoreSections = sections
                chordLibrary.saveSettings()
            }
            tuningPitches: tuningPitchNotation
            tuningOffset: chordLibrary.tuningOffset
            altCount: batchEngine.altCount
            altIndex: batchEngine.altIndex
            difficultyFn: FingeringEngine.computeDifficulty
            fingeringFn: function(v) { return computeFingeringString(v) }
            melodyLockDefault: chordLibrary.melodyOnTop
            bassStringList: batchEngine.bassStringList
            selectedBassString: batchEngine.selectedBassString
            bassStringCounts: {
                var counts = {}
                var groups = batchEngine.bassStringGroups
                for (var bs in groups) {
                    counts[bs] = groups[bs].length
                }
                return counts
            }

            onPrevClicked: {
                batchEngine.batchIndex = batchEngine.batchIndex - 2
                batchEngine.batchShowNext()
            }
            onNextClicked: batchEngine.batchShowNext()
            onStopClicked: {
                batchEngine.batchQueue = []
                batchEngine.batchChords = []
                showToolResults = false
            }
            onBassStringClicked: function(bassStr) {
                // Sync lock states from UI before selecting bass string
                batchEngine._melodyLocked = walkthroughPanel.melodyLocked
                batchEngine._bassLocked = walkthroughPanel.bassLocked
                batchEngine.selectBassString(bassStr)
            }
            onAltSelected: function(index) {
                batchEngine.selectAlternativeVoicing(index)
            }
            onRevoiceRequested: function(melodyNote, melodyLocked, bassNote, bassLocked, category) {
                batchEngine.revoiceCurrentStepWith(melodyNote, melodyLocked, bassNote, bassLocked, category)
            }
            onReharmSelected: function(newRoot, newQuality) {
                batchEngine.applyReharm(newRoot, newQuality)
            }
        }

        // === Tab 0: Library (extracted to ui/LibraryPanel.qml, #99) ===
        LibraryPanel {
            id: libraryPanel
            visible: currentTab === 0 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            filteredData: chordLibrary.filteredData
            voicingsData: chordLibrary.voicingsData
            contextDisplayList: chordLibrary.contextDisplayList
            contextList: chordLibrary.contextList
            categoryList: chordLibrary.categoryList
            qualityList: chordLibrary.qualityList
            filteredTuningDisplayList: chordLibrary.filteredTuningDisplayList
            filteredTuningList: chordLibrary.filteredTuningList
            selectedTuning: chordLibrary.selectedTuning
            filterContext: chordLibrary.filterContext
            theme: theme
            batchActive: batchQueue.length > 0
            sortByProximity: chordLibrary.sortByProximity
            melodyOnTop: chordLibrary.melodyOnTop
            melodyStaffIdx: chordLibrary.melodyStaffIdx
            writeVoice2: chordLibrary.writeVoice2
            showComparison: chordLibrary.showComparison
            compareVoicings: chordLibrary.compareVoicings
            computeNotesForTuningFn: function(v) { return computeNotesForTuning(v) }
            suggestFingeringFn: function(v) { return suggestFingering(v) }
            fingeringStringFn: function(v) { return computeFingeringString(v) }
            matchingScalesFn: function(v) {
                if (!v || !v.chord_quality) return []
                return ChordScales.getScaleNames(v.chord_quality)
            }
            getScaleNotesFn: function(scaleName, root) {
                return ChordScales.getScaleNotes(scaleName, root)
            }
            scaleFilterList: chordLibrary._scaleNameList

            onScaleFilterChanged: function(scaleName) {
                chordLibrary.filterScale = scaleName
                chordLibrary.applyFilters()
            }

            // --- Style profiles (#146) ---
            profileDisplayList: {
                var names = []
                for (var i = 0; i < _profileList.length; i++) names.push(_profileList[i].name)
                return names.length > 0 ? names : ["Default"]
            }
            profileIdList: {
                var ids = []
                for (var i = 0; i < _profileList.length; i++) ids.push(_profileList[i].id)
                return ids.length > 0 ? ids : ["default"]
            }
            activeProfileId: _activeProfileId
            onProfileChanged: function(profileId) { chordLibrary.setProfile(profileId) }
            activeMode: chordLibrary.activeMode
            onModeChanged: function(modeId) { chordLibrary.setActiveMode(modeId) }
            onSearchChanged: function(text) { chordLibrary.searchText = text; chordLibrary.applyFilters() }
            onContextFilterChanged: function(code) {
                // Context dropdown is hidden as of #174 Stage 2; the signal is
                // still emitted by the hidden ComboBox on model rebuild but no
                // longer needs to switch tunings. The auto-link path retired
                // in #184 alongside contexts.json.
                chordLibrary.filterContext = code
                chordLibrary.refreshFilteredTunings()
                chordLibrary.applyFilters()
            }
            onCategoryFilterChanged: function(text) { chordLibrary.filterCategory = text; chordLibrary.applyFilters() }
            onQualityFilterChanged: function(text) { chordLibrary.filterQuality = text; chordLibrary.applyFilters() }
            onTuningSelected: function(slug) {
                chordLibrary.selectedTuning = slug
                chordLibrary.loadTuningStringCount()
                chordLibrary.loadTuningVoicings()
                // Auto-select matching CM context if none is selected
                if (!chordLibrary.filterContext) {
                    var strCount = chordLibrary.tuningStringCounts[slug] || 6
                    var autoCtx = "CM" + strCount
                    if (chordLibrary.contextStringCounts[autoCtx]) {
                        chordLibrary.filterContext = autoCtx
                    }
                }
                chordLibrary.refreshFilteredTunings()
                chordLibrary.saveSettings()
            }
            onVoiceHereRequested: chordLibrary.voiceAtCursor()
            onBatchInsertRequested: chordLibrary.batchInsert()
            onBatchStopRequested: {
                chordLibrary.batchQueue = []
                statusMsg.text = "Voicing stopped"
                statusMsg.color = theme.textMuted
            }
            onSortToggled: {
                chordLibrary.sortByProximity = !chordLibrary.sortByProximity
                chordLibrary.applyFilters()
                statusMsg.text = chordLibrary.sortByProximity
                    ? "Sorting by proximity to last voicing"
                    : "Default sort order"
                statusMsg.color = theme.textMuted
            }
            onMelodyToggled: {
                chordLibrary.melodyOnTop = !chordLibrary.melodyOnTop
                statusMsg.text = chordLibrary.melodyOnTop
                    ? "Melody on top: voicings will match the melody note"
                    : "Melody on top: off"
                statusMsg.color = theme.textMuted
            }
            onVoice2Toggled: {
                chordLibrary.writeVoice2 = !chordLibrary.writeVoice2
                statusMsg.text = chordLibrary.writeVoice2
                    ? "Voice 2 export: voicing notes will be written to Voice 2"
                    : "Voice 2 export: off"
                statusMsg.color = theme.textMuted
            }
            onMelodyStaffChanged: function(idx) { chordLibrary.melodyStaffIdx = idx }
            onCopyTuningRequested: chordLibrary.copyTuningToClipboard()
            onOpenVoicingRequested: function(voicing) { chordLibrary.generateDiagramFile(voicing) }
            onPlayVoicingRequested: function(voicing, mode) { chordLibrary.playVoicing(voicing, mode) }
            onCompareRequested: function(voicing) { chordLibrary.addToComparison(voicing) }
            onClearComparisonRequested: chordLibrary.clearComparison()

            // --- Save to Library + Library Health (moved from Settings, #144) ---
            homePath: chordLibrary.homePath()
            lastAuditResults: chordLibrary.lastAuditResults
            hygieneIgnoreList: chordLibrary.hygieneIgnoreList

            onCaptureRequested: chordLibrary.captureFromScore()
            onSaveVoicingRequested: function(quality, category, context, fret, strings, dots, mutes) {
                chordLibrary.saveVoicingToLibrary(quality, category, context, fret, strings, dots, mutes)
            }
            onAuditRequested: function(reportPath) {
                chordLibrary.runHygieneAudit()
                chordLibrary.saveAuditReport(reportPath)
                Qt.openUrlExternally(reportPath)
            }
            onDismissRequested: function(key) {
                chordLibrary.dismissFinding(key)
                libraryPanel.hygieneStatus = "Dismissed. Run audit again to see updated results."
                libraryPanel.hygieneStatusColor = theme.successText
            }
            onFixDuplicatesRequested: chordLibrary.fixDuplicates()
            onClearDismissalsRequested: chordLibrary.clearDismissals()
            onBrowseAuditRequested: function(field) { chordLibrary.openFileBrowser("save", field, null) }
        }

        // Global status bar (used by many functions — stays in parent, migrate in Phase C #104)
        Label {
            id: statusMsg
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 10
            text: ""
        }
    }

    // Helper to get home directory path for default export location
    function homePath() {
        // Extract the user's home directory from the plugin's resolved URL. Handles
        // both POSIX (file:///Users/…, file:///home/…) and Windows (file:///C:/Users/…).
        // Qt normalises URLs to forward slashes; FileIO accepts forward-slash Windows
        // paths, so we keep them that way.
        var str = Qt.resolvedUrl(".").toString().replace("file:///", "").replace("file://", "")
        if (Qt.platform.os === "windows") {
            // str = "C:/Users/Name/Documents/MuseScore4/Plugins/chordlibrary/"
            var wparts = str.split("/")
            if (wparts.length >= 3 && wparts[0].indexOf(":") >= 0) {
                return wparts[0] + "/" + wparts[1] + "/" + wparts[2]
            }
            return str
        }
        // POSIX: str = "/Users/Name/..." → re-add the leading slash we stripped
        if (str.charAt(0) !== "/") str = "/" + str
        var parts = str.split("/")
        if (parts.length >= 3) {
            return "/" + parts[1] + "/" + parts[2]
        }
        return "~"
    }
}
