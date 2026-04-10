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
        id: contextsConfigFile
        source: Qt.resolvedUrl("config/contexts.json")
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

    // Default settings
    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/plugin/data/voicings.json"
    property string diagramPlacement: "above"  // "above" or "below"
    property string selectedTuning: "standard"  // matches config/tunings/<name>.json
    property var tuningList: [
        "standard", "7string-van-eps", "7string-low-b", "dadgad", "all-fourths",
        "baritone"
    ]
    property var tuningLabels: {
        "standard": "Standard 6-String",
        "7string-van-eps": "7-String Van Eps (Low A)",
        "7string-low-b": "7-String Low B",
        "dadgad": "DADGAD",
        "all-fourths": "All Fourths",
        "baritone": "Baritone B (B-E-A-D-F#-B)"
    }
    // String count per tuning — used to filter tuning combo by context
    property var tuningStringCounts: {
        "standard": 6, "7string-van-eps": 7, "7string-low-b": 7,
        "dadgad": 6, "all-fourths": 6, "baritone": 6
    }
    // Filtered tuning list — shows tunings compatible with the context's string count.
    // Exact match preferred; if no exact match includes the current tuning, show all compatible (<=).
    property var filteredTuningList: {
        if (!filterContext || !contextStringCounts[filterContext]) return tuningList
        var requiredStrings = contextStringCounts[filterContext]
        // First try exact match
        var exact = []
        for (var i = 0; i < tuningList.length; i++) {
            var slug = tuningList[i]
            var strCount = tuningStringCounts[slug] || 6
            if (strCount === requiredStrings) exact.push(slug)
        }
        if (exact.length > 0) return exact
        // Fallback: show tunings with <= required strings
        var result = []
        for (var j = 0; j < tuningList.length; j++) {
            var slug2 = tuningList[j]
            var strCount2 = tuningStringCounts[slug2] || 6
            if (strCount2 <= requiredStrings) result.push(slug2)
        }
        return result
    }
    // Display names for tuning combos (shows labels instead of slugs in dropdown)
    property var filteredTuningDisplayList: {
        var result = []
        for (var i = 0; i < filteredTuningList.length; i++) {
            result.push(tuningLabels[filteredTuningList[i]] || filteredTuningList[i])
        }
        return result
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
    property string searchText: ""

    // Voice leading state
    property var lastInsertedVoicing: null  // tracks fret position for proximity sort
    property bool sortByProximity: false    // when true, sort filtered results by distance
    property bool melodyOnTop: false         // when true, prefer voicings with melody note as highest voice
    property bool skipDiagramPositions: false // when true, Annotate Staff Text skips positions with existing diagrams
    property string _toolStatusText: ""  // routed to ScoreToolsPanel
    property int melodyStaffIdx: -1  // -1 = same staff, 0+ = specific staff index for melody reading
    property bool writeVoice2: false  // when true, write voicing pitches as notes on voice 2

    // Voicing calculator constraints (defaults, overridable per chord in walkthrough)
    property int calcMaxFret: 12           // highest fret to consider
    property int calcMaxStretch: 4         // max fret span in one voicing
    property bool calcAllowOpen: true      // allow open strings in voicings
    property bool calcRootInBass: true     // require root as lowest note
    property int calcMinNotes: 3           // minimum sounding strings
    property int calcMaxMuted: 3           // maximum muted strings
    property int calcMaxPerQuality: 0      // max voicings per quality (0 = unlimited / Ted Greene mode)

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

    // Context display names — loaded from config/contexts.json, extensible
    property var contextLabels: ({})
    property var contextLabelsShort: ({})
    // Context string counts — enforced as a ceiling on voicing selection
    property var contextStringCounts: ({"CM4": 4, "CV4": 4, "CM5": 5, "CV5": 5, "CM6": 6, "CV6": 6, "CM7": 7, "CV7": 7})

    function loadContextLabels() {
        // Defaults (used if config file not found)
        var labels = {
            "CM6": "Chord Melody 6-String",
            "CM7": "Chord Melody 7-String",
            "CV6": "Chord + Voice 6-String",
            "CV7": "Chord + Voice 7-String",
            "CM4": "Chord Melody 4-String",
            "CV4": "Chord + Voice 4-String",
            "CM5": "Chord Melody 5-String",
            "CV5": "Chord + Voice 5-String"
        }
        var shorts = {
            "CM6": "CM 6", "CM7": "CM 7",
            "CV6": "CV 6", "CV7": "CV 7",
            "CM4": "CM 4", "CV4": "CV 4",
            "CM5": "CM 5", "CV5": "CV 5"
        }
        var strCounts = {"CM6": 6, "CM7": 7, "CV6": 6, "CV7": 7}

        try {
            var raw = contextsConfigFile.read()
            if (raw && raw.length > 2) {
                var config = JSON.parse(raw)
                var ctxs = config.contexts || {}
                for (var code in ctxs) {
                    if (ctxs[code].name) labels[code] = ctxs[code].name
                    if (ctxs[code].short) shorts[code] = ctxs[code].short
                    if (ctxs[code].strings) strCounts[code] = ctxs[code].strings
                }
                console.log("Loaded context labels from config (" + Object.keys(ctxs).length + " contexts)")
            }
        } catch (e) {
            console.log("Using default context labels: " + e)
        }

        contextLabels = labels
        contextLabelsShort = shorts
        contextStringCounts = strCounts
    }

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
            if (_pendingVoicing) {
                lastInsertedVoicing = _pendingVoicing
                _pendingVoicing = null
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
        for (var c in contextStringCounts) allContexts[c] = true
        for (var i = 1; i < lists.contextList.length; i++) allContexts[lists.contextList[i]] = true
        contextList = ["All Contexts"].concat(Object.keys(allContexts).sort())
        categoryList = lists.categoryList
        qualityList = lists.qualityList
    }

    onRun: {
        loadContextLabels()
        loadSettings()
        loadTuningStringCount()
        if (!dataLoaded) {
            // Try local cache first (contains imports), fall back to URL
            if (!loadFromCache()) {
                fetchVoicings()
            }
        }
        // After loading the standard library, check for tuning-specific voicings
        loadTuningVoicings()
    }

    function loadFromCache() {
        try {
            var raw = localCacheFile.read()
            var cached = DataCache.parseCache(raw)
            if (cached) {
                voicingsData = cached
                dataLoaded = true
                rebuildFilterLists()
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
            // Restore custom tunings that were added via Create/Import
            if (s.customTunings.length > 0) {
                for (var i = 0; i < s.customTunings.length; i++) {
                    var ct = s.customTunings[i]
                    if (ct.slug && ct.name) {
                        addTuningToList(ct.slug, ct.name, ct.strings || 6)
                    }
                }
                console.log("Restored " + s.customTunings.length + " custom tuning(s)")
            }
            // Restore tuning order (if user reordered)
            if (s.tuningOrder.length > 0) {
                tuningList = DataCache.mergeTuningOrder(s.tuningOrder, tuningList)
            }
            // Restore voicing calculator constraints
            calcMaxFret = s.calcMaxFret
            calcMaxStretch = s.calcMaxStretch
            calcAllowOpen = s.calcAllowOpen
            calcRootInBass = s.calcRootInBass
            calcMinNotes = s.calcMinNotes
            calcMaxMuted = s.calcMaxMuted
            calcMaxPerQuality = s.calcMaxPerQuality
            console.log("Settings loaded: url=" + jsonUrl + ", placement=" + diagramPlacement + ", tuning=" + selectedTuning)
        } catch (e) {
            console.log("No saved settings found, using defaults")
        }
    }

    function saveSettings() {
        var s = {
            voicingUrl: jsonUrl,
            diagramPlacement: diagramPlacement,
            tuning: selectedTuning,
            customTunings: DataCache.getCustomTuningsList(tuningList, builtInTunings, tuningLabels, tuningStringCounts),
            tuningOrder: tuningList.slice(),
            calcMaxFret: calcMaxFret,
            calcMaxStretch: calcMaxStretch,
            calcAllowOpen: calcAllowOpen,
            calcRootInBass: calcRootInBass,
            calcMinNotes: calcMinNotes,
            calcMaxMuted: calcMaxMuted,
            calcMaxPerQuality: calcMaxPerQuality,
        }
        settingsFile.write(DataCache.serializeSettings(s))
        console.log("Settings saved")
    }

    // === Tuning import/create ===

    // MIDI note to name for display
    property var midiNoteNames: {
        var names = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        var map = {}
        for (var midi = 21; midi <= 108; midi++) {
            var octave = Math.floor(midi / 12) - 1
            map[midi] = names[midi % 12] + octave
        }
        return map
    }

    // Parse a note name like "E4", "Bb3", "F#2" to MIDI number
    // Returns -1 if not a valid note name (caller falls back to parseInt)
    property var noteToMidiMap: {
        "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
    }
    function noteNameToMidi(str) {
        str = str.trim()
        // Try as plain integer first
        var asInt = parseInt(str)
        if (!isNaN(asInt) && str.match(/^\d+$/)) return asInt

        // Parse note name: letter + optional accidental + octave
        var match = str.match(/^([A-Ga-g])(#|b|)(\d)$/)
        if (!match) return -1
        var letter = match[1].toUpperCase()
        var accidental = match[2]
        var octave = parseInt(match[3])
        var base = noteToMidiMap[letter]
        if (base === undefined) return -1
        var midi = (octave + 1) * 12 + base
        if (accidental === "#") midi += 1
        else if (accidental === "b") midi -= 1
        return midi
    }

    // Move a tuning up or down in the list. direction: -1 = up, +1 = down
    function moveTuning(slug, direction) {
        var list = tuningList.slice()
        var idx = list.indexOf(slug)
        if (idx < 0) return
        var newIdx = idx + direction
        if (newIdx < 0 || newIdx >= list.length) return
        // Swap
        var temp = list[newIdx]
        list[newIdx] = list[idx]
        list[idx] = temp
        tuningList = list
        saveSettings()
    }

    function addTuningToList(slug, name, stringCount) {
        // Add to the runtime lists if not already present
        var list = tuningList.slice()
        if (list.indexOf(slug) < 0) {
            list.push(slug)
            tuningList = list
        }
        var labels = {}
        for (var k in tuningLabels) labels[k] = tuningLabels[k]
        labels[slug] = name
        tuningLabels = labels
        // Record string count for combo filtering
        if (stringCount) {
            var counts = {}
            for (var c in tuningStringCounts) counts[c] = tuningStringCounts[c]
            counts[slug] = stringCount
            tuningStringCounts = counts
        }
    }

    function importTuning(path) {
        if (!path) {
            settingsPanel.tuningStatus = "Enter a file path"
            settingsPanel.tuningStatusColor = theme.errorText
            return
        }
        tuningFile.source = path
        try {
            var raw = tuningFile.read()
            if (!raw || raw.length === 0) {
                settingsPanel.tuningStatus = "File not found or empty"
                settingsPanel.tuningStatusColor = theme.errorText
                return
            }
            var tuning = JSON.parse(raw)
            if (!tuning.name || !tuning.strings) {
                settingsPanel.tuningStatus = "Invalid tuning: needs 'name' and 'strings' fields"
                settingsPanel.tuningStatusColor = theme.errorText
                return
            }

            // Save to plugin directory as custom tuning
            var slug = tuning.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
            var destPath = Qt.resolvedUrl("tunings/" + slug + ".json")
            tuningFile.source = destPath
            tuningFile.write(raw)

            addTuningToList(slug, tuning.name, Object.keys(tuning.strings || {}).length || 6)
            selectedTuning = slug
            loadTuningStringCount()
            loadTuningVoicings()
            saveSettings()

            settingsPanel.tuningStatus = "Imported: " + tuning.name
            settingsPanel.tuningStatusColor = theme.successText
        } catch (e) {
            settingsPanel.tuningStatus = "Failed: " + e
            settingsPanel.tuningStatusColor = theme.errorText
        }
    }

    function createTuning(name, pitchStr, numStrings) {
        if (!name) {
            settingsPanel.tuningStatus = "Enter a tuning name"
            settingsPanel.tuningStatusColor = theme.errorText
            return
        }

        var rawParts = pitchStr.split(",")
        var pitches = []
        for (var p = 0; p < rawParts.length; p++) {
            var midi = noteNameToMidi(rawParts[p])
            if (midi < 0) {
                settingsPanel.tuningStatus = "Can't parse: '" + rawParts[p].trim() + "' — use note names (E4, Bb3) or MIDI numbers (64, 59)"
                settingsPanel.tuningStatusColor = theme.errorText
                return
            }
            pitches.push(midi)
        }

        if (pitches.length < numStrings) {
            settingsPanel.tuningStatus = "Need " + numStrings + " pitches, got " + pitches.length
            settingsPanel.tuningStatusColor = theme.errorText
            return
        }
        pitches = pitches.slice(0, numStrings)

        // Validate pitches are reasonable MIDI values
        for (var i = 0; i < pitches.length; i++) {
            if (pitches[i] < 20 || pitches[i] > 100) {
                settingsPanel.tuningStatus = "Pitch out of range: " + pitches[i] + " (expected 20-100)"
                settingsPanel.tuningStatusColor = theme.errorText
                return
            }
        }

        // Build the tuning JSON
        var strings = {}
        var notes = {}
        for (var s = 0; s < pitches.length; s++) {
            var strNum = s + 1
            strings[strNum] = pitches[s]
            notes[strNum] = midiNoteNames[pitches[s]] || ("?" + pitches[s])
        }

        var tuning = {
            name: name,
            description: "Custom tuning created in Chord Library",
            strings: strings,
            notes: notes
        }

        var slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
        var destPath = Qt.resolvedUrl("tunings/" + slug + ".json")
        tuningFile.source = destPath
        try {
            tuningFile.write(JSON.stringify(tuning, null, 2))
            addTuningToList(slug, name, numStrings)
            selectedTuning = slug
            loadTuningStringCount()
            loadTuningVoicings()
            saveSettings()

            // Show the note names as feedback
            var noteStr = Object.keys(notes).map(function(k) { return notes[k] }).join("-")
            settingsPanel.tuningStatus = "Created: " + name + " (" + noteStr + ")"
            settingsPanel.tuningStatusColor = theme.successText
        } catch (e) {
            settingsPanel.tuningStatus = "Failed to save: " + e
            settingsPanel.tuningStatusColor = theme.errorText
        }
    }

    // The built-in tunings that ship with the plugin (cannot be deleted)
    property var builtInTunings: [
        "standard", "7string-van-eps", "7string-low-b", "dadgad", "all-fourths",
        "baritone", "ukulele", "ukulele-low-g", "mandolin", "banjo-open-g",
        "bass-4string", "bass-5string"
    ]

    // Load a tuning's data into the create/edit form fields for editing
    function editTuning(slug) {
        if (!slug) return
        var paths = [
            Qt.resolvedUrl("tunings/" + slug + ".json"),
            Qt.resolvedUrl("../config/tunings/" + slug + ".json")
        ]
        for (var p = 0; p < paths.length; p++) {
            tuningFile.source = paths[p]
            try {
                var raw = tuningFile.read()
                if (raw && raw.length > 2) {
                    var t = JSON.parse(raw)
                    settingsPanel.tuningNameValue = t.name || slug
                    var strings = t.strings || {}
                    var count = Object.keys(strings).length
                    settingsPanel.tuningStringCountValue = count > 0 ? count : 6

                    // Convert MIDI values back to note names for display
                    var pitchParts = []
                    for (var s = 1; s <= count; s++) {
                        var midi = strings[String(s)]
                        if (midi !== undefined) {
                            pitchParts.push(midiNoteNames[midi] || String(midi))
                        }
                    }
                    settingsPanel.tuningPitchesValue = pitchParts.join(", ")
                    settingsPanel.tuningStatus = "Editing: " + (t.name || slug) + " — change values and click Save"
                    settingsPanel.tuningStatusColor = theme.textSecondary
                    return
                }
            } catch (e) {}
        }
        settingsPanel.tuningStatus = "Could not load tuning: " + slug
        settingsPanel.tuningStatusColor = theme.errorText
    }

    // Delete a custom tuning (built-in tunings cannot be deleted)
    function deleteTuning(slug) {
        if (!slug) return
        if (builtInTunings.indexOf(slug) >= 0) {
            settingsPanel.tuningStatus = "Cannot delete built-in tuning"
            settingsPanel.tuningStatusColor = theme.errorText
            return
        }

        // Remove from tuning list
        var list = tuningList.slice()
        var idx = list.indexOf(slug)
        if (idx >= 0) {
            list.splice(idx, 1)
            tuningList = list
        }

        // Remove from labels
        var labels = {}
        for (var k in tuningLabels) {
            if (k !== slug) labels[k] = tuningLabels[k]
        }
        tuningLabels = labels

        // If we just deleted the active tuning, switch to standard
        if (selectedTuning === slug) {
            selectedTuning = "standard"
            loadTuningStringCount()
            applyFilters()
        }
        saveSettings()

        // Delete the tuning file (write empty string — FileIO can't delete)
        var destPath = Qt.resolvedUrl("tunings/" + slug + ".json")
        tuningFile.source = destPath
        try {
            tuningFile.write("")
        } catch (e) {
            // File may not exist in writable location — that's OK
        }

        settingsPanel.tuningStatus = "Deleted: " + slug
        settingsPanel.tuningStatusColor = theme.successText
    }

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
            voicingsData = calculated
            usingTuningVoicings = true
            rebuildFilterLists()
            if (savedContext && contextList.indexOf(savedContext) >= 0) filterContext = savedContext
            if (savedCategory && categoryList.indexOf(savedCategory) >= 0) filterCategory = savedCategory
            if (savedQuality && qualityList.indexOf(savedQuality) >= 0) filterQuality = savedQuality
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
            searchText: searchText,
            maxStrings: tuningMaxStrings,
            contextStringCounts: contextStringCounts,
            sortByProximity: sortByProximity,
            lastInsertedVoicing: lastInsertedVoicing,
            distanceFn: MelodyEngine.voicingDistance
        })
    }

    // === Voicing insertion ===

    function insertVoicing(voicing) {
        if (!curScore) {
            statusMsg.text = "No score open"
            statusMsg.color = theme.errorText
            return
        }

        var selection = curScore.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            statusMsg.text = "Select a note or rest first"
            statusMsg.color = theme.errorText
            return
        }

        var targetRoot = null
        var selectedElement = selection.elements[0]
        var segment = null

        if (selectedElement.type === Element.NOTE) {
            var ch = selectedElement.parent
            if (ch) segment = ch.parent
        } else if (selectedElement.type === Element.REST) {
            segment = selectedElement.parent
        } else if (selectedElement.type === Element.CHORD) {
            segment = selectedElement.parent
        }

        if (segment && segment.annotations) {
            for (var a = 0; a < segment.annotations.length; a++) {
                if (segment.annotations[a].type === Element.HARMONY) {
                    targetRoot = Transposer.extractRoot(segment.annotations[a].text)
                    break
                }
            }
        }

        if (!targetRoot) {
            targetRoot = voicing.root
        }

        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)

        var targetTick = -1
        if (segment) {
            targetTick = segment.tick
        } else if (selectedElement.type === Element.NOTE) {
            var parentChord = selectedElement.parent
            if (parentChord && parentChord.parent) {
                targetTick = parentChord.parent.tick
            }
        }

        if (targetTick < 0) {
            statusMsg.text = "Could not determine position. Select a note or rest."
            statusMsg.color = theme.errorText
            return
        }

        curScore.startCmd()

        var fd = newElement(Element.FRET_DIAGRAM)
        fd.fretStrings = voicing.strings || 6
        fd.fretFrets = voicing.visible_frets || 4
        fd.fretOffset = voicing.fret_number + offset - 1

        // Set placement based on user preference
        if (typeof Placement !== "undefined") {
            if (diagramPlacement === "below") {
                fd.placement = Placement.BELOW
            } else {
                fd.placement = Placement.ABOVE
            }
        }

        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)

        while (cursor.segment && cursor.tick < targetTick) {
            cursor.next()
        }

        cursor.add(fd)

        curScore.endCmd()

        var transposed = Transposer.transposeVoicing(voicing, targetRoot)
        statusMsg.text = "Inserted " + transposed.name
            + " [" + transposed.notes.join(" ") + "]"
            + " (" + diagramPlacement + " staff)"
        statusMsg.color = theme.successText
    }

    // === Diagram insertion (setDot API or clipboard workaround) ===

    // Cached result of setDot() availability (null = not yet tested)
    property var _hasSetDot: null
    property var _selectedVoicing: null

    function hasSetDotApi() {
        if (_hasSetDot !== null) return _hasSetDot
        try {
            var fd = newElement(Element.FRET_DIAGRAM)
            _hasSetDot = (typeof fd.setDot === "function")
            if (_hasSetDot)
                console.log("setDot() API detected — using direct insertion")
            else
                console.log("setDot() not available — using clipboard workaround")
        } catch (e) {
            console.log("Could not probe setDot(): " + e)
            _hasSetDot = false
        }
        return _hasSetDot
    }

    // Insert a voicing directly via setDot() API (no clipboard needed).
    // Returns true if successful, false if setDot() not available or insert failed.
    function insertDirect(voicing, targetRoot) {
        if (!hasSetDotApi()) return false
        if (!curScore) return false

        var numStrings = voicing.strings || 6
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)

        try {
            curScore.startCmd()

            var fd = newElement(Element.FRET_DIAGRAM)
            fd.fretStrings = numStrings
            fd.fretFrets = voicing.visible_frets || 4
            fd.fretOffset = voicing.fret_number + offset - 1

            // Set dots via setDot(string, fret, fingerNumber)
            // MuseScore uses 0-based string index (0 = leftmost in diagram)
            var dots = voicing.dots || []
            for (var d = 0; d < dots.length; d++) {
                var msStr = numStrings - dots[d].string
                fd.setDot(msStr, dots[d].fret, 0)
            }

            // Set mutes and open strings via setMarker
            var mutes = voicing.mutes || []
            for (var m = 0; m < mutes.length; m++) {
                var msMute = numStrings - mutes[m]
                fd.setMarker(msMute, 1)  // 1 = cross/muted
            }
            var opens = voicing.open || []
            for (var o = 0; o < opens.length; o++) {
                var msOpen = numStrings - opens[o]
                fd.setMarker(msOpen, 2)  // 2 = circle/open
            }

            var cursor = curScore.newCursor()
            cursor.rewind(1)  // SELECTION_START
            cursor.add(fd)

            curScore.endCmd()
            return true
        } catch (e) {
            try { curScore.endCmd() } catch (ignore) {}
            console.log("setDot() insert failed: " + e + " — falling back to clipboard")
            _hasSetDot = null  // reset cache so clipboard path is used
            return false
        }
    }

    function generateDiagramFile(voicing) {
        // Determine target root from score selection, or default to C
        var targetRoot = voicing.root
        if (curScore) {
            var sel = curScore.selection
            if (sel && sel.elements && sel.elements.length > 0) {
                var elem = sel.elements[0]
                var seg = null
                if (elem.type === Element.NOTE && elem.parent)
                    seg = elem.parent.parent
                else if (elem.type === Element.REST || elem.type === Element.CHORD)
                    seg = elem.parent
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

        var transposed = Transposer.transposeVoicing(voicing, targetRoot)
        var displayName = transposed.name

        // Try direct insertion via setDot() API first (instant, no clipboard)
        if (insertDirect(voicing, targetRoot)) {
            lastInsertedVoicing = voicing
            if (sortByProximity) applyFilters()
            statusMsg.text = "Inserted " + displayName
                + " [" + transposed.notes.join(" ") + "]"
            statusMsg.color = theme.successText
            return
        }

        // Fall back to clipboard workaround
        var xml = generateXmlForVoicing(voicing, targetRoot)

        var xmlPath = Qt.resolvedUrl("paste-clipboard.xml")
        tempDiagramFile.source = xmlPath
        try {
            tempDiagramFile.write(xml)
        } catch (e) {
            statusMsg.text = "Failed to write clipboard XML: " + e
            statusMsg.color = theme.errorText
            return
        }

        // A launchd agent (com.siegeanalytics.chord-library-clipboard) watches
        // paste-clipboard.xml for changes and runs ms-clipboard to write to
        // the macOS pasteboard. No Terminal, no visible windows.
        _pendingVoicing = voicing
        // The Timer then fires cmd("paste") to insert the diagram with dots.
        pasteTimer.start()

        statusMsg.text = "Pasting " + displayName + " [" + transposed.notes.join(" ") + "]..."
        statusMsg.color = theme.successText
    }

    // === Voicing preview (MIDI playback via ms-audio) ===

    function playVoicing(voicing, mode) {
        // mode: "chord" (all at once) or "arp" (strum low to high)
        if (!mode) mode = "chord"

        // Compute MIDI note numbers for this voicing in the current tuning
        var midiNotes = []
        var dots = voicing.dots || []
        for (var d = 0; d < dots.length; d++) {
            var strMidi = tuningMidi[String(dots[d].string)]
            if (strMidi !== undefined) {
                var absFret = voicing.fret_number + (dots[d].fret - 1)
                midiNotes.push(strMidi + absFret)
            }
        }
        // Add open strings
        var opens = voicing.open || []
        for (var o = 0; o < opens.length; o++) {
            var openMidi = tuningMidi[String(opens[o])]
            if (openMidi !== undefined) {
                midiNotes.push(openMidi)
            }
        }

        if (midiNotes.length === 0) return

        // Write JSON that the launchd agent + ms-audio will pick up
        var request = JSON.stringify({
            notes: midiNotes,
            duration: 1.5,
            mode: mode,
        })
        try {
            audioFile.write(request)
        } catch (e) {
            console.log("Audio playback failed: " + e)
        }
    }

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
                    + '  title: "' + (mode === "save" ? "Export Voicings" : "Import Voicings") + '"\n'
                    + '  fileMode: FileDialog.' + (mode === "save" ? "SaveFile" : "OpenFile") + '\n'
                    + '  nameFilters: ["JSON files (*.json)"]\n'
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

    // === Inline tools (pure QML, no Python/terminal) ===

    // Collect unique chord symbols from the open score
    function collectScoreChords() {
        if (!curScore) return []
        var chords = []
        var seen = {}
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)
        while (cursor.segment) {
            var seg = cursor.segment
            if (seg.annotations) {
                for (var a = 0; a < seg.annotations.length; a++) {
                    if (seg.annotations[a].type === Element.HARMONY) {
                        var text = seg.annotations[a].text
                        if (!seen[text]) {
                            seen[text] = true
                            chords.push(text)
                        }
                    }
                }
            }
            cursor.next()
        }
        return chords
    }

    function analyzeCurrentScore() {
        if (!curScore) {
            _toolStatusText = "Open a score with chord symbols first."
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            _toolStatusText = "No chord symbols found in the score."
            return
        }

        var ctx = filterContext || "all"
        var cat = filterCategory || "all"

        var lines = []
        var covered = 0
        var gaps = 0
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbol(chords[i])
            if (!parsed) {
                lines.push("  ✗  " + chords[i] + " — could not parse")
                gaps++
                continue
            }
            var matches = voicingsData.filter(function(v) {
                // Quartal voicings work over any chord quality
                if (v.chord_quality !== parsed.quality && v.chord_quality !== "quartal") return false
                if (ctx !== "all" && v.context !== ctx) return false
                if (cat !== "all" && v.category !== cat) return false
                return true
            })
            if (matches.length > 0) {
                var cats = {}
                for (var m = 0; m < matches.length; m++) cats[matches[m].category] = (cats[matches[m].category] || 0) + 1
                var catStr = Object.keys(cats).map(function(c) { return c + "(" + cats[c] + ")" }).join(", ")
                lines.push("  ✓  " + chords[i] + " — " + matches.length + " voicings: " + catStr)
                covered++
            } else {
                lines.push("  ✗  " + chords[i] + " — NO VOICINGS")
                gaps++
            }
        }

        var pct = Math.round(covered / chords.length * 100)
        var header = "Coverage: " + covered + "/" + chords.length + " (" + pct + "%)"
        if (gaps > 0) header += " — " + gaps + " gap(s)"
        else header += " — full coverage!"
        header += "\nContext: " + (ctx === "all" ? "All" : ctx) + "  |  Type: " + (cat === "all" ? "All" : cat)

        showResult("Score Analysis", header + "\n\n" + lines.join("\n"), true)
    }

    function runVoiceLeading() {
        if (!curScore) {
            _toolStatusText = "Open a score with chord symbols first."
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            _toolStatusText = "No chord symbols found in the score."
            return
        }

        var lines = []
        lastInsertedVoicing = null  // reset voice leading chain
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbol(chords[i])
            if (!parsed) {
                lines.push("  " + chords[i] + " — ?")
                continue
            }
            var voicing = findBestVoicing(parsed.root, parsed.quality)
            if (voicing) {
                var nameParts = voicing.name.split(" — ")
                var shape = nameParts.length > 1 ? nameParts[1] : voicing.category
                var topNote = nameParts.length > 2 ? nameParts[2] : ""
                lines.push("  " + chords[i] + "  →  " + shape + (topNote ? " — " + topNote : ""))
                lastInsertedVoicing = voicing
            } else {
                lines.push("  " + chords[i] + "  →  no match")
            }
        }

        var ctx = filterContext || "all"
        var cat = filterCategory || "all"
        var header = "Voice leading path (" + chords.length + " chords)"
        header += "\nContext: " + (ctx === "all" ? "All" : ctx) + "  |  Type: " + (cat === "all" ? "All" : cat)

        showResult("Voice Leading", header + "\n\n" + lines.join("\n"), true)
    }

    function voiceEntireScore() {
        if (!curScore) {
            statusMsg.text = "No score open"
            statusMsg.color = theme.errorText
            return
        }

        var ctx = filterContext || "all"
        var cat = filterCategory || "all"

        // Preview: show what voicings will be assigned
        var chords = collectScoreChords()
        if (chords.length === 0) {
            statusMsg.text = "No chord symbols found"
            statusMsg.color = theme.errorText
            return
        }

        var lines = []
        var matchCount = 0
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbol(chords[i])
            if (!parsed) {
                lines.push("  ✗  " + chords[i] + " — could not parse")
                continue
            }
            var voicing = findBestVoicing(parsed.root, parsed.quality)
            if (voicing) {
                var nameParts = voicing.name.split(" — ")
                var shape = nameParts.length > 1 ? nameParts[1] : voicing.category
                lines.push("  ✓  " + chords[i] + "  →  " + shape + " (" + voicing.category + ")")
                matchCount++
            } else {
                lines.push("  ✗  " + chords[i] + " — no matching voicing")
            }
        }

        var header = "Ready to insert " + matchCount + " diagrams for " + chords.length + " chords"
        header += "\nContext: " + (ctx === "all" ? "All" : ctx) + "  |  Type: " + (cat === "all" ? "All" : cat)
        header += "\n\nChange the filters on the main panel to use different voicing types."
        header += "\nClick 'Batch' to insert these voicings into the score."

        showResult("Voice Entire Score", header + "\n\n" + lines.join("\n"), true)
    }

    function suggestFingerings() {
        if (!curScore) {
            _toolStatusText = "Open a score with chord symbols first."
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            _toolStatusText = "No chord symbols found."
            return
        }

        var lines = []
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbol(chords[i])
            if (!parsed) continue
            var voicing = findBestVoicing(parsed.root, parsed.quality)
            if (voicing) {
                var fg = computeFingeringString(voicing)
                var nameParts = voicing.name.split(" — ")
                var shape = nameParts.length > 1 ? nameParts[1] : voicing.category
                lines.push("  " + chords[i] + "  →  " + shape + "\n     Fingering: " + fg)
            } else {
                lines.push("  " + chords[i] + "  →  no voicing found")
            }
        }

        showResult("Fingering Suggestions", "Fingerings for " + chords.length + " chords:\n\n" + lines.join("\n\n"), true)
    }

    function computeFingeringString(voicing) {
        return FingeringEngine.computeFingeringString(voicing)
    }

    // Extract fingering string from an existing FretDiagram element in the score.
    // MuseScore 4's FretDiagram exposes: fretOffset, strings, frets, and per-string
    // dot/marker data. We build a pseudo-voicing object and reuse computeFingeringString.
    function fingeringFromDiagram(diagram) {
        try {
            var numStrings = diagram.strings || 6
            var fretOffset = (diagram.fretOffset || 0) + 1  // fretOffset is 0-based
            var dots = []
            var mutes = []
            var opens = []

            for (var s = 0; s < numStrings; s++) {
                // MuseScore string numbering: 0 = leftmost (low E), we need 1 = high E
                var msString = numStrings - s  // our string numbering
                var marker = diagram.marker(s)
                var dot = diagram.dot(s)

                if (marker === 1) {  // cross = muted
                    mutes.push(msString)
                } else if (marker === 2) {  // circle = open
                    opens.push(msString)
                } else if (dot && dot > 0) {
                    dots.push({ string: msString, fret: dot })
                }
            }

            if (dots.length === 0 && opens.length === 0) return null

            var pseudoVoicing = {
                dots: dots,
                mutes: mutes,
                open: opens,
                strings: numStrings,
                fret_number: fretOffset,
            }
            return computeFingeringString(pseudoVoicing)
        } catch (e) {
            console.log("[ChordLibrary] Could not read diagram: " + e)
            return null
        }
    }

    function addFingeringsToScore() {
        if (!curScore) {
            showResult("No Score", "Open a score with chord symbols first.", false)
            return
        }

        // Collect chord positions using cursor.tick (more reliable than seg.tick in MS4)
        var chordPositions = []
        var scanCursor = curScore.newCursor()
        scanCursor.staffIdx = 0
        scanCursor.voice = 0
        scanCursor.rewind(0)

        var skippedDiagram = 0
        var usedDiagram = 0
        while (scanCursor.segment) {
            var seg = scanCursor.segment
            var currentTick = scanCursor.tick
            if (seg.annotations) {
                // Find existing fretboard diagram at this position (if any)
                var existingDiagram = null
                for (var c = 0; c < seg.annotations.length; c++) {
                    if (seg.annotations[c].type === Element.FRET_DIAGRAM) {
                        existingDiagram = seg.annotations[c]
                        break
                    }
                }

                for (var a = 0; a < seg.annotations.length; a++) {
                    if (seg.annotations[a].type === Element.HARMONY) {
                        var chordText = seg.annotations[a].text

                        if (existingDiagram) {
                            if (skipDiagramPositions) {
                                skippedDiagram++
                                continue
                            }
                            // Read fingering from the existing diagram
                            var diagramFinger = fingeringFromDiagram(existingDiagram)
                            if (diagramFinger) {
                                chordPositions.push({
                                    tick: currentTick,
                                    fingering: diagramFinger,
                                    chord: chordText,
                                })
                                usedDiagram++
                                continue
                            }
                        }

                        // No diagram (or couldn't read it) — pick a voicing
                        var parsed = parseChordSymbol(chordText)
                        if (parsed) {
                            var voicing = findBestVoicing(parsed.root, parsed.quality)
                            if (voicing) {
                                var fingerStr = computeFingeringString(voicing)
                                if (fingerStr) {
                                    chordPositions.push({
                                        tick: currentTick,
                                        fingering: fingerStr,
                                        chord: chordText,
                                    })
                                }
                            }
                        }
                    }
                }
            }
            scanCursor.next()
        }

        if (chordPositions.length === 0) {
            showResult("No Chords Found", "The score has no chord symbols to annotate.", false)
            return
        }

        // Add staff text annotations at each position
        var added = 0
        var errors = []

        curScore.startCmd()

        for (var i = 0; i < chordPositions.length; i++) {
            var pos = chordPositions[i]
            try {
                var cursor = curScore.newCursor()
                cursor.staffIdx = 0
                cursor.voice = 0
                cursor.rewind(0)

                // Advance cursor to the target tick
                while (cursor.segment && cursor.tick < pos.tick) {
                    cursor.next()
                }

                if (cursor.segment) {
                    var staffText = newElement(Element.STAFF_TEXT)
                    staffText.text = pos.fingering
                    cursor.add(staffText)
                    added++
                }
            } catch (e) {
                errors.push(pos.chord + ": " + e)
            }
        }

        curScore.endCmd()

        var msg = "Added staff text annotations to " + added + " of " + chordPositions.length + " chord positions."
        if (usedDiagram > 0) {
            msg += "\n" + usedDiagram + " annotation(s) derived from existing fretboard diagrams."
        }
        if (skippedDiagram > 0) {
            msg += "\nSkipped " + skippedDiagram + " position(s) with existing fretboard diagrams."
        }
        if (errors.length > 0) {
            msg += "\n\nErrors:\n" + errors.join("\n")
        }
        msg += "\n\nNotation format: 1=index, 2=middle, 3=ring, 4=pinky, X=muted, O=open"
        showResult("Staff Text", msg, errors.length === 0)
    }

    function exportFingeringSheet() {
        if (!curScore) {
            showResult("No Score", "Open a score first, then try again.", false)
            return
        }
        var chordsFile = extractChordsToFile()
        if (!chordsFile) return

        var scoreName = (curScore.scoreName || curScore.title || "fingerings").replace(/[^a-zA-Z0-9-_ ]/g, "")
        var defaultPath = homePath() + "/Documents/" + scoreName + "-fingerings.pdf"

        openSaveDialog("Save Fingering Sheet", "PDF files (*.pdf)", defaultPath, function(outPath) {
            var ctx = selectedContext && selectedContext !== "All Contexts" ? selectedContext : "CV6"
            var catArg = selectedCategory && selectedCategory !== "All Types" ? " --category " + selectedCategory : ""
            var title = curScore.scoreName || curScore.title || "Fingering Reference"
            var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")

            launchExport('cd "' + pluginDir + '"; python3 "' + pluginDir
                + '/scripts/generate_fingering_sheet.py" --chords "' + chordsFile
                + '" --context ' + ctx + catArg + ' --title "' + title
                + '" --data "' + pluginDir + '/data/voicings.json" -o "' + outPath
                + '" 2>&1; open "' + outPath + '"')
        })
    }

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

    function suggestFingering(voicing) {
        return FingeringEngine.suggestFingering(voicing)
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

            calc: QtObject {
                property int maxFret: chordLibrary.calcMaxFret
                property int maxStretch: chordLibrary.calcMaxStretch
                property int minNotes: chordLibrary.calcMinNotes
                property int maxMuted: chordLibrary.calcMaxMuted
                property int maxPerQuality: chordLibrary.calcMaxPerQuality
                property bool allowOpen: chordLibrary.calcAllowOpen
                property bool rootInBass: chordLibrary.calcRootInBass
            }
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

            // State groups
            library: QtObject {
                property var voicingsData: chordLibrary.voicingsData
                property bool dataLoaded: chordLibrary.dataLoaded
            }
            tuning: QtObject {
                property string selectedTuning: chordLibrary.selectedTuning
                property var tuningLabels: chordLibrary.tuningLabels
            }
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

            tuning: QtObject {
                property string selectedTuning: chordLibrary.selectedTuning
                property var tuningLabels: chordLibrary.tuningLabels
                property var tuningList: chordLibrary.tuningList
            }
            theme: theme
            diagramPlacement: chordLibrary.diagramPlacement
            builtInTunings: chordLibrary.builtInTunings
            lastAuditResults: chordLibrary.lastAuditResults
            hygieneIgnoreList: chordLibrary.hygieneIgnoreList
            homePath: homePath()

            onPlacementChanged: function(placement) {
                diagramPlacement = placement
                saveSettings()
            }
            onEditTuningRequested: function(slug) { editTuning(slug) }
            onDeleteTuningRequested: function(slug) { deleteTuning(slug) }
            onMoveTuningRequested: function(slug, direction) { moveTuning(slug, direction) }
            onImportTuningRequested: function(path) { importTuning(path) }
            onCreateTuningRequested: function(name, pitches, numStrings) { createTuning(name, pitches, numStrings) }
            onCaptureRequested: captureFromScore()
            onSaveVoicingRequested: function(quality, category, context, fret, strings, dots, mutes) {
                saveVoicingToLibrary(quality, category, context, fret, strings, dots, mutes)
            }
            onAuditRequested: function(reportPath) {
                runHygieneAudit()
                saveAuditReport(reportPath)
                Qt.openUrlExternally(reportPath)
            }
            onDismissRequested: function(key) {
                dismissFinding(key)
                settingsPanel.hygieneStatus = "Dismissed. Run audit again to see updated results."
                settingsPanel.hygieneStatusColor = theme.successText
            }
            onFixDuplicatesRequested: fixDuplicates()
            onClearDismissalsRequested: clearDismissals()
            onBrowseAuditRequested: function(field) { openFileBrowser("save", field, null) }
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
            resultsContent: toolResultsContent
            availableCategories: categoryList
            tuningName: tuningLabels[selectedTuning] || selectedTuning
            calculatedVoicings: usingTuningVoicings
            tuningPitches: tuningPitchNotation
            tuningOffset: chordLibrary.tuningOffset
            altCount: batchEngine.altCount
            altIndex: batchEngine.altIndex
            difficultyFn: FingeringEngine.computeDifficulty
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

            onSearchChanged: function(text) { searchText = text; applyFilters() }
            onContextFilterChanged: function(code) { filterContext = code; applyFilters() }
            onCategoryFilterChanged: function(text) { filterCategory = text; applyFilters() }
            onQualityFilterChanged: function(text) { filterQuality = text; applyFilters() }
            onTuningSelected: function(slug) {
                selectedTuning = slug
                loadTuningStringCount()
                loadTuningVoicings()
                saveSettings()
            }
            onVoiceHereRequested: voiceAtCursor()
            onBatchInsertRequested: batchInsert()
            onBatchStopRequested: {
                batchQueue = []
                statusMsg.text = "Voicing stopped"
                statusMsg.color = theme.textMuted
            }
            onSortToggled: {
                sortByProximity = !sortByProximity
                applyFilters()
                statusMsg.text = sortByProximity
                    ? "Sorting by proximity to last voicing"
                    : "Default sort order"
                statusMsg.color = theme.textMuted
            }
            onMelodyToggled: {
                melodyOnTop = !melodyOnTop
                statusMsg.text = melodyOnTop
                    ? "Melody on top: voicings will match the melody note"
                    : "Melody on top: off"
                statusMsg.color = theme.textMuted
            }
            onVoice2Toggled: {
                writeVoice2 = !writeVoice2
                statusMsg.text = writeVoice2
                    ? "Voice 2 export: voicing notes will be written to Voice 2"
                    : "Voice 2 export: off"
                statusMsg.color = theme.textMuted
            }
            onMelodyStaffChanged: function(idx) { melodyStaffIdx = idx }
            onCopyTuningRequested: copyTuningToClipboard()
            onOpenVoicingRequested: function(voicing) { generateDiagramFile(voicing) }
            onPlayVoicingRequested: function(voicing, mode) { playVoicing(voicing, mode) }
            onCompareRequested: function(voicing) { addToComparison(voicing) }
            onClearComparisonRequested: clearComparison()
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
        var url = Qt.resolvedUrl(".")
        // Extract up to /Users/username or /home/username
        var str = url.toString().replace("file://", "")
        var parts = str.split("/")
        if (parts.length >= 3) {
            return "/" + parts[1] + "/" + parts[2]
        }
        return "~"
    }
}
