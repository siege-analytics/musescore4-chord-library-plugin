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

MuseScore {
    id: chordLibrary
    title: "Siege Analytics Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "1.5.0"
    pluginType: "dialog"
    requiresScore: true
    categoryCode: "composing-arranging-tools"

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
        source: Qt.resolvedUrl("voicings-cache.json")
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
        source: Qt.resolvedUrl("../config/contexts.json")
    }

    FileIO {
        id: tuningFile
    }

    FileIO {
        id: audioFile
        source: Qt.resolvedUrl("play-chord.json")
    }

    // Default settings
    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"
    property string diagramPlacement: "above"  // "above" or "below"
    property string selectedTuning: "standard"  // matches config/tunings/<name>.json
    property var tuningList: [
        "standard", "7string-van-eps", "7string-low-b", "dadgad", "all-fourths",
        "baritone", "ukulele", "ukulele-low-g", "mandolin", "banjo-open-g",
        "bass-4string", "bass-5string"
    ]
    property var tuningLabels: {
        "standard": "Standard 6-String",
        "7string-van-eps": "7-String Van Eps (Low A)",
        "7string-low-b": "7-String Low B",
        "dadgad": "DADGAD",
        "all-fourths": "All Fourths",
        "baritone": "Baritone B (B-E-A-D-F#-B)",
        "ukulele": "Ukulele (Standard)",
        "ukulele-low-g": "Ukulele (Low G)",
        "mandolin": "Mandolin",
        "banjo-open-g": "Banjo (Open G)",
        "bass-4string": "Bass (4-String)",
        "bass-5string": "Bass (5-String)"
    }
    // String count per tuning — used to filter tuning combo by context
    property var tuningStringCounts: {
        "standard": 6, "7string-van-eps": 7, "7string-low-b": 7,
        "dadgad": 6, "all-fourths": 6, "baritone": 6,
        "ukulele": 4, "ukulele-low-g": 4, "mandolin": 4,
        "banjo-open-g": 5, "bass-4string": 4, "bass-5string": 5
    }
    // Filtered tuning list — respects context string count ceiling
    property var filteredTuningList: {
        if (!filterContext || !contextStringCounts[filterContext]) return tuningList
        var maxStrings = contextStringCounts[filterContext]
        var result = []
        for (var i = 0; i < tuningList.length; i++) {
            var slug = tuningList[i]
            var strCount = tuningStringCounts[slug] || 6
            if (strCount <= maxStrings) result.push(slug)
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
    property int melodyStaffIdx: -1  // -1 = same staff, 0+ = specific staff index for melody reading

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
        if (!melodyOnTop) return -1
        var noteText = melodyOverrideField ? melodyOverrideField.text : ""
        return MelodyEngine.parseNoteToSemitone(noteText, Transposer.SEMITONE_MAP)
    }

    // Dynamic filter lists (rebuilt when data changes)
    property var contextList: ["All Contexts"]
    property var categoryList: ["All Types"]
    property var qualityList: ["All Qualities"]

    // Context display names — loaded from config/contexts.json, extensible
    property var contextLabels: ({})
    property var contextLabelsShort: ({})
    // Context string counts — enforced as a ceiling on voicing selection
    property var contextStringCounts: ({"CM6": 6, "CM7": 7, "CV6": 6, "CV7": 7})

    function loadContextLabels() {
        // Defaults (used if config file not found)
        var labels = {
            "CM6": "Chord Melody — 6 string",
            "CM7": "Chord Melody — 7 string",
            "CV6": "Comping/Vocal — 6 string",
            "CV7": "Comping/Vocal — 7 string"
        }
        var shorts = {
            "CM6": "CM 6-str", "CM7": "CM 7-str",
            "CV6": "CV 6-str", "CV7": "CV 7-str"
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
            toolStatus.text = title + ": " + message
            toolStatus.color = isSuccess ? theme.successText : theme.errorText
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

    // === Batch insert ===

    property var batchQueue: []
    property int batchTotal: 0

    // Map chord quality strings from MuseScore Harmony to our quality IDs
    property var qualityMap: {
        "7": "dom7", "maj7": "maj7", "Maj7": "maj7", "M7": "maj7",
        "m7": "min7", "min7": "min7", "-7": "min7",
        "m7b5": "min7b5", "-7b5": "min7b5", "ø7": "min7b5",
        "dim7": "dim7", "o7": "dim7",
        "6": "maj6", "m6": "min6", "-6": "min6",
        "9": "dom9", "maj9": "maj9", "m9": "min9",
        "13": "dom13",
        "7b9": "dom7b9", "7#5": "dom7sharp5", "7b5": "dom7flat5",
        "7alt": "dom7alt", "alt": "dom7alt",
        "sus4": "sus4", "sus2": "sus2",
        "aug7": "aug7", "+7": "aug7",
        "mMaj7": "min-maj7", "m(maj7)": "min-maj7",
        "": "dom7",  // bare "C" = major, but with 7th context we default to dom7
    }

    function parseChordSymbol(text) {
        // Extract root and quality from a chord symbol like "Fmaj7", "Bb7", "D-7b5"
        if (!text || text.length === 0) return null
        var root = Transposer.extractRoot(text)
        if (!root) return null
        var suffix = text.substring(root.length)
        // Clean up common notation
        suffix = suffix.replace(/^\s*/, "").replace("Δ", "maj").replace("△", "maj")
            .replace("°", "dim").replace("ø", "m7b5").replace("+", "aug")
            .replace("−", "-")
        var quality = qualityMap[suffix] || null
        // If no exact match, try partial matches
        if (!quality) {
            if (suffix.indexOf("maj7") >= 0) quality = "maj7"
            else if (suffix.indexOf("m7b5") >= 0 || suffix.indexOf("-7b5") >= 0) quality = "min7b5"
            else if (suffix.indexOf("m7") >= 0 || suffix.indexOf("-7") >= 0) quality = "min7"
            else if (suffix.indexOf("dim") >= 0) quality = "dim7"
            else if (suffix.indexOf("7") >= 0) quality = "dom7"
            else if (suffix.indexOf("m") >= 0 || suffix.indexOf("-") >= 0) quality = "min7"
            else quality = "maj7"  // bare letter = major
        }
        return { root: root, quality: quality }
    }

    // Get the top (highest-pitched) note of a voicing as a semitone class (0-11)
    function voicingTopNoteSemitone(voicing, targetRoot) {
        return MelodyEngine.voicingTopNoteSemitone(voicing, targetRoot, Transposer.SEMITONE_MAP)
    }

    function findBestVoicing(targetRoot, quality, melodyMidi, bassMidi) {
        // Find the best matching voicing from the current data.
        // Respects current filter selections: context, category, tuning.
        // melodyMidi: optional MIDI note number of the melody at this position
        // bassMidi: optional MIDI semitone class (0-11) for preferred bass note
        var maxStrings = tuningMaxStrings
        if (filterContext && contextStringCounts[filterContext] !== undefined) {
            var contextMax = contextStringCounts[filterContext]
            if (contextMax < maxStrings) maxStrings = contextMax
        }
        var candidates = []
        var quartalCandidates = []
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            if ((v.strings || 6) > maxStrings) continue
            // For multi-root voicings (calculated), match by root too.
            // Standard library voicings are all root C and get transposed.
            // Calculated voicings with non-C roots must match the target root.
            if (v.root !== "C" && v.root !== targetRoot) continue
            if (v.chord_quality === quality) {
                if (filterCategory && v.category !== filterCategory) continue
                candidates.push(v)
            } else if (v.category === "quartal") {
                quartalCandidates.push(v)
            }
        }
        // If category filter is too restrictive, fall back to unfiltered
        if (candidates.length === 0 && filterCategory) {
            for (var j = 0; j < voicingsData.length; j++) {
                var v2 = voicingsData[j]
                if (v2.chord_quality !== quality) continue
                if (v2.root !== "C" && v2.root !== targetRoot) continue
                if ((v2.strings || 6) > maxStrings) continue
                candidates.push(v2)
            }
        }
        // Add quartal candidates to the pool
        for (var q = 0; q < quartalCandidates.length; q++) {
            candidates.push(quartalCandidates[q])
        }
        if (candidates.length === 0) {
            // Fallback: try dom7 if the specific quality isn't found
            if (quality !== "dom7") return findBestVoicing(targetRoot, "dom7", melodyMidi, bassMidi)
            return null
        }

        // Melody-on-top: compute target semitone class from melody MIDI note
        var melodyTarget = (melodyMidi !== undefined && melodyMidi >= 0)
            ? melodyMidi % 12 : -1

        // Bass note: compute target semitone class (0-11)
        var bassTarget = (bassMidi !== undefined && bassMidi >= 0)
            ? bassMidi % 12 : -1

        // Score: context match + category preference + voice leading + melody + bass
        var ref = lastInsertedVoicing
        candidates.sort(function(a, b) {
            var scoreA = 0, scoreB = 0
            // Exact quality match beats quartal
            if (a.chord_quality === quality) scoreA += 20
            if (b.chord_quality === quality) scoreB += 20
            if (filterContext && a.context === filterContext) scoreA += 100
            if (filterContext && b.context === filterContext) scoreB += 100
            if (filterCategory && a.category === filterCategory) scoreA += 50
            if (filterCategory && b.category === filterCategory) scoreB += 50
            if (a.category === "shell") scoreA += 10
            else if (a.category === "drop2") scoreA += 5
            if (b.category === "shell") scoreB += 10
            else if (b.category === "drop2") scoreB += 5
            // Melody-on-top: bonus depends on lock state
            // Locked = +500 (must match), Unlocked = +200 (prefer)
            if (melodyTarget >= 0) {
                var melodyBonus = _melodyLocked ? 500 : 200
                var topA = voicingTopNoteSemitone(a, targetRoot)
                var topB = voicingTopNoteSemitone(b, targetRoot)
                if (topA === melodyTarget) scoreA += melodyBonus
                if (topB === melodyTarget) scoreB += melodyBonus
            }
            // Bass note: bonus depends on lock state
            // Locked = +500 (must match), Unlocked = +250 (prefer)
            if (bassTarget >= 0) {
                var bassBonus = _bassLocked ? 500 : 250
                var bassA = MelodyEngine.voicingBassNoteSemitone(a, targetRoot, Transposer.SEMITONE_MAP)
                var bassB = MelodyEngine.voicingBassNoteSemitone(b, targetRoot, Transposer.SEMITONE_MAP)
                if (bassA === bassTarget) scoreA += bassBonus
                if (bassB === bassTarget) scoreB += bassBonus
            }
            // Voice leading: prefer voicings close to the last inserted one
            if (ref) {
                scoreA -= voicingDistance(ref, a) * 2
                scoreB -= voicingDistance(ref, b) * 2
            }
            return scoreB - scoreA
        })
        return candidates[0]
    }

    function generateXmlForVoicing(voicing, targetRoot) {
        // Generate EngravingItem XML for a voicing transposed to targetRoot.
        // When using tuning-specific voicings (from chord_calculator), the shapes
        // are already geometrically correct — no tuning offset needed.
        // For the standard library on non-standard tunings, apply the offset.
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
        var effectiveOffset = usingTuningVoicings ? 0 : tuningOffset
        var transposedFret = voicing.fret_number + offset - effectiveOffset
        if (transposedFret < 0) transposedFret += 12  // wrap around
        var numStrings = voicing.strings || 6
        var numFrets = voicing.visible_frets || 4

        var stringData = {}
        var dots = voicing.dots || []
        for (var d = 0; d < dots.length; d++) {
            var msStr = numStrings - dots[d].string
            if (!stringData[msStr]) stringData[msStr] = {}
            stringData[msStr].dot = dots[d].fret
        }
        var mutes = voicing.mutes || []
        for (var m = 0; m < mutes.length; m++) {
            var msMute = numStrings - mutes[m]
            if (!stringData[msMute]) stringData[msMute] = {}
            stringData[msMute].marker = "cross"
        }
        var opens = voicing.open || []
        for (var o = 0; o < opens.length; o++) {
            var msOpen = numStrings - opens[o]
            if (!stringData[msOpen]) stringData[msOpen] = {}
            stringData[msOpen].marker = "circle"
        }

        var fretOffset = transposedFret - 1
        var xml = '<EngravingItem>\n  <FretDiagram>\n'
        if (fretOffset > 0) xml += '    <fretOffset>' + fretOffset + '</fretOffset>\n'
        if (numFrets !== 4) xml += '    <frets>' + numFrets + '</frets>\n'
        if (numStrings !== 6) xml += '    <strings>' + numStrings + '</strings>\n'
        xml += '    <fretDiagram>\n'

        var sortedKeys = Object.keys(stringData).sort(function(a, b) { return a - b })
        for (var k = 0; k < sortedKeys.length; k++) {
            var sn = sortedKeys[k]
            var sd = stringData[sn]
            xml += '      <string no="' + sn + '">\n'
            if (sd.marker) xml += '        <marker>' + sd.marker + '</marker>\n'
            if (sd.dot !== undefined) xml += '        <dot fret="' + sd.dot + '">normal</dot>\n'
            xml += '      </string>\n'
        }
        xml += '    </fretDiagram>\n  </FretDiagram>\n</EngravingItem>'
        return xml
    }

    // Batch voicing state
    property int _batchIndex: 0
    property int _batchInserted: 0
    property var _batchChords: []  // [{text, root, quality, voicing}, ...]

    // Voice a single chord at the current cursor/selection position
    function voiceAtCursor() {
        if (!curScore) {
            statusMsg.text = "No score open"
            statusMsg.color = theme.errorText
            return
        }

        // Find the chord symbol at or near the current selection
        var sel = curScore.selection
        if (!sel || !sel.elements || sel.elements.length === 0) {
            statusMsg.text = "Select a note or rest at a chord symbol"
            statusMsg.color = theme.errorText
            return
        }

        var elem = sel.elements[0]
        var seg = null
        if (elem.type === Element.NOTE && elem.parent)
            seg = elem.parent.parent
        else if (elem.type === Element.REST || elem.type === Element.CHORD)
            seg = elem.parent

        if (!seg || !seg.annotations) {
            statusMsg.text = "No chord symbol at selection"
            statusMsg.color = theme.errorText
            return
        }

        // Find the HARMONY annotation at this segment
        var chordText = null
        for (var a = 0; a < seg.annotations.length; a++) {
            if (seg.annotations[a].type === Element.HARMONY) {
                chordText = seg.annotations[a].text
                break
            }
        }

        if (!chordText) {
            statusMsg.text = "No chord symbol at selection"
            statusMsg.color = theme.errorText
            return
        }

        var parsed = parseChordSymbol(chordText)
        if (!parsed) {
            statusMsg.text = "Could not parse: " + chordText
            statusMsg.color = theme.errorText
            return
        }

        // Extract melody note — use override if set, else detect from selection
        var melodyMidi = melodyOverrideMidi()
        if (melodyMidi < 0 && melodyOnTop) {
            var chordElem = null
            if (elem.type === Element.NOTE && elem.parent)
                chordElem = elem.parent
            else if (elem.type === Element.CHORD)
                chordElem = elem
            if (chordElem && chordElem.notes) {
                for (var n = 0; n < chordElem.notes.length; n++) {
                    if (chordElem.notes[n].pitch > melodyMidi)
                        melodyMidi = chordElem.notes[n].pitch
                }
            }
        }

        var voicing = findBestVoicing(parsed.root, parsed.quality, melodyMidi)
        if (!voicing) {
            statusMsg.text = "No voicing found for " + chordText
            statusMsg.color = theme.errorText
            return
        }

        // Use the single voicing insertion flow (same as "Open" button)
        generateDiagramFile(voicing)
    }

    function batchInsert() {
        if (!curScore) {
            statusMsg.text = "No score open"
            statusMsg.color = theme.errorText
            return
        }

        // Scan all chord symbols and build the voicing plan
        var chords = []
        var lastMelodyMidi = -1  // carry-forward: last melody note for rests
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)

        // If reading melody from a separate staff, create a second cursor
        var melodyCursor = null
        if (melodyStaffIdx >= 0 && melodyOnTop) {
            melodyCursor = curScore.newCursor()
            melodyCursor.staffIdx = melodyStaffIdx
            melodyCursor.voice = 0
            melodyCursor.rewind(0)
        }
        while (cursor.segment) {
            if (cursor.segment.annotations) {
                for (var a = 0; a < cursor.segment.annotations.length; a++) {
                    if (cursor.segment.annotations[a].type === Element.HARMONY) {
                        var text = cursor.segment.annotations[a].text
                        var parsed = parseChordSymbol(text)
                        if (parsed) {
                            // Extract melody note (highest pitch) at this position.
                            // If user set a manual override, use that for all positions.
                            var melodyMidi = melodyOverrideMidi()

                            // Try melody from a separate staff first (if configured)
                            if (melodyMidi < 0 && melodyOnTop && melodyCursor) {
                                // Advance melody cursor to same tick position
                                while (melodyCursor.segment && melodyCursor.tick < cursor.tick) {
                                    melodyCursor.next()
                                }
                                if (melodyCursor.segment && melodyCursor.tick === cursor.tick) {
                                    if (melodyCursor.element && melodyCursor.element.type === Element.CHORD) {
                                        var melNotes = melodyCursor.element.notes
                                        for (var mn = 0; mn < melNotes.length; mn++) {
                                            if (melNotes[mn].pitch > melodyMidi)
                                                melodyMidi = melNotes[mn].pitch
                                        }
                                    }
                                }
                            }

                            // Fall back to same-staff melody extraction
                            if (melodyMidi < 0 && melodyOnTop) {
                                var segEl = cursor.segment
                                // Check cursor.element first (voice 0)
                                if (cursor.element && cursor.element.type === Element.CHORD) {
                                    var notes0 = cursor.element.notes
                                    for (var n0 = 0; n0 < notes0.length; n0++) {
                                        if (notes0[n0].pitch > melodyMidi) melodyMidi = notes0[n0].pitch
                                    }
                                }
                                // Also scan all annotations' parent elements for notes
                                // (the chord symbol may be attached to a voice with notes)
                                if (melodyMidi < 0 && segEl && segEl.elementAt) {
                                    // Try voice 0 through 3
                                    for (var voice = 0; voice < 4 && melodyMidi < 0; voice++) {
                                        var el = segEl.elementAt(voice)
                                        if (el && el.type === Element.CHORD && el.notes) {
                                            for (var nv = 0; nv < el.notes.length; nv++) {
                                                if (el.notes[nv].pitch > melodyMidi)
                                                    melodyMidi = el.notes[nv].pitch
                                            }
                                        }
                                    }
                                }
                            }
                            // Carry forward: if at a rest, use the last melody note
                            if (melodyOnTop && melodyMidi < 0 && lastMelodyMidi >= 0) {
                                melodyMidi = lastMelodyMidi
                            }
                            if (melodyMidi >= 0) lastMelodyMidi = melodyMidi

                            // Suggest bass note (default: chord root)
                            var bassMidi = MelodyEngine.suggestBassNote(parsed.root, parsed.quality, Transposer.SEMITONE_MAP)

                            var voicing = findBestVoicing(parsed.root, parsed.quality, melodyMidi, bassMidi)
                            if (voicing) {
                                chords.push({
                                    text: text,
                                    root: parsed.root,
                                    quality: parsed.quality,
                                    voicing: voicing,
                                    melodyMidi: melodyMidi,
                                    bassMidi: bassMidi,
                                })
                            }
                        }
                    }
                }
            }
            cursor.next()
        }

        if (chords.length === 0) {
            statusMsg.text = "No matching chord symbols found"
            statusMsg.color = theme.errorText
            return
        }

        _batchChords = chords
        _batchIndex = 0
        batchTotal = chords.length
        batchQueue = [1]  // non-empty = in progress

        // Show guided walkthrough
        batchShowNext()
    }

    function batchShowNext() {
        if (_batchIndex >= _batchChords.length) {
            batchQueue = []
            showResult("Voice Score Complete",
                "All " + batchTotal + " chord voicings have been loaded.\n\n"
                + "Click 'Back to Library' to return to the voicing browser.", true)
            return
        }

        var item = _batchChords[_batchIndex]
        var remaining = _batchChords.length - _batchIndex
        var nameParts = item.voicing.name.split(" — ")
        var shape = nameParts.length > 1 ? nameParts.slice(1).join(" — ") : item.voicing.category

        // Load the clipboard with this voicing's diagram
        var xml = generateXmlForVoicing(item.voicing, item.root)
        var xmlPath = Qt.resolvedUrl("paste-clipboard.xml")
        tempDiagramFile.source = xmlPath
        try {
            tempDiagramFile.write(xml)
        } catch (e) {
            showResult("Error", "Failed to write clipboard: " + e, false)
            return
        }

        // Show the guided step with clear instructions
        var stepText = "▸ " + item.text + " — " + shape
        if (melodyOnTop && item.melodyMidi >= 0) {
            stepText += "\n  Melody: " + MelodyEngine.melodyNoteName(item.melodyMidi)
        }
        if (item.bassMidi >= 0) {
            stepText += "\n  Bass: " + MelodyEngine.melodyNoteName(item.bassMidi)
        }
        // Show any warnings from unfulfilled requests (bass/melody impossibilities)
        if (item._warnings && item._warnings.length > 0) {
            stepText += "\n"
            for (var w = 0; w < item._warnings.length; w++) {
                stepText += "\n  ⚠ " + item._warnings[w]
            }
        }

        stepText += "\n"
        stepText += "\n  1. Click the note/rest at the " + item.text + " chord symbol"
        stepText += "\n  2. Press ⌘V to paste the fretboard diagram"
        stepText += "\n  3. Click 'Next →' when ready"

        if (remaining > 1) {
            stepText += "\n\n" + (remaining - 1) + " chord" + (remaining > 2 ? "s" : "") + " remaining"
        }

        toolResultsTitle = "Voice Score — " + item.text
        toolResultsContent = stepText
        showToolResults = true

        _batchIndex++
    }

    // Re-voice the current walkthrough step with melody note name and category override.
    // Called from WalkthroughPanel's revoiceRequested signal.
    // Lock state for melody/bass priority (set by revoice, used by findBestVoicing)
    property bool _melodyLocked: false
    property bool _bassLocked: false

    function revoiceCurrentStepWith(melodyNoteText, melodyLocked, bassNoteText, bassLocked, categoryOverride) {
        var idx = _batchIndex - 1  // _batchIndex was already incremented
        if (idx < 0 || idx >= _batchChords.length) return

        var item = _batchChords[idx]

        // Parse melody override
        var newMidi = MelodyEngine.parseNoteToSemitone(melodyNoteText, Transposer.SEMITONE_MAP)
        if (newMidi < 0) newMidi = item.melodyMidi  // fallback to auto-detected
        item.melodyMidi = newMidi

        // Parse bass note override
        var newBass = MelodyEngine.parseNoteToSemitone(bassNoteText, Transposer.SEMITONE_MAP)
        if (newBass < 0) newBass = MelodyEngine.suggestBassNote(item.root, item.quality, Transposer.SEMITONE_MAP)
        item.bassMidi = newBass

        // Set lock states for findBestVoicing scoring
        _melodyLocked = melodyLocked || false
        _bassLocked = bassLocked || false

        // Temporarily set the category filter for findBestVoicing
        var savedCategory = filterCategory
        filterCategory = categoryOverride  // "" means "Any" (no filter)

        // Re-select voicing (inversions are pre-calculated at load time)
        var newVoicing = findBestVoicing(item.root, item.quality, newMidi, newBass)

        // Restore filter
        filterCategory = savedCategory

        if (!newVoicing) {
            toolResultsContent = "No voicing found for " + item.text
                + " with these settings.\n\nTry changing the Type, Bass note,"
                + " or adjust Voicing Constraints in Score Tools."
            return
        }

        // Track what couldn't be fulfilled — shown inline in the walkthrough
        var warnings = []

        var userRequestedBass = MelodyEngine.parseNoteToSemitone(bassNoteText, Transposer.SEMITONE_MAP)
        if (userRequestedBass >= 0) {
            var actualBass = MelodyEngine.voicingBassNoteSemitone(newVoicing, item.root, Transposer.SEMITONE_MAP)
            if (actualBass >= 0 && actualBass !== userRequestedBass) {
                warnings.push("No playable " + item.text + " with "
                    + MelodyEngine.NOTE_NAMES[userRequestedBass] + " in bass on this tuning."
                    + "\n     Offering alternative: " + MelodyEngine.NOTE_NAMES[actualBass]
                    + " in bass. Try adjusting stretch or mute limits in Score Tools.")
            }
        }

        var userRequestedMelody = MelodyEngine.parseNoteToSemitone(melodyNoteText, Transposer.SEMITONE_MAP)
        if (userRequestedMelody >= 0) {
            var actualTop = MelodyEngine.voicingTopNoteSemitone(newVoicing, item.root, Transposer.SEMITONE_MAP)
            if (actualTop >= 0 && actualTop !== userRequestedMelody) {
                warnings.push("No playable " + item.text + " with "
                    + MelodyEngine.NOTE_NAMES[userRequestedMelody] + " on top on this tuning."
                    + "\n     Offering alternative: " + MelodyEngine.NOTE_NAMES[actualTop]
                    + " on top.")
            }
        }

        // Store warnings so batchShowNext can display them
        item._warnings = warnings

        item.voicing = newVoicing

        // Regenerate clipboard XML
        var xml = generateXmlForVoicing(newVoicing, item.root)
        var xmlPath = Qt.resolvedUrl("paste-clipboard.xml")
        tempDiagramFile.source = xmlPath
        try {
            tempDiagramFile.write(xml)
        } catch (e) {
            console.log("[ChordLibrary] revoice write error: " + e)
            return
        }

        // Reset lock states after revoice (don't affect Voice All)
        _melodyLocked = false
        _bassLocked = false

        // Update the display — rewind batchIndex and re-show
        _batchIndex = idx
        batchShowNext()
    }

    function batchProcessNext() {
        // Called by "Next Chord" button — advance to next chord
        batchShowNext()
    }

    function rebuildFilterLists() {
        var contexts = {}, categories = {}, qualities = {}
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            if (v.context) contexts[v.context] = true
            if (v.category) categories[v.category] = true
            if (v.chord_quality) qualities[v.chord_quality] = true
        }
        contextList = ["All Contexts"].concat(Object.keys(contexts).sort())
        categoryList = ["All Types"].concat(Object.keys(categories).sort())
        qualityList = ["All Qualities"].concat(Object.keys(qualities).sort())
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
            if (raw && raw.length > 2) {
                var data = JSON.parse(raw)
                var cached = data.voicings || []
                if (cached.length > 0) {
                    voicingsData = cached
                    dataLoaded = true
                    rebuildFilterLists()
                    applyFilters()
                    statusMsg.text = "Loaded " + voicingsData.length + " voicings (cached)"
                    statusMsg.color = theme.successText
                    console.log("Loaded " + cached.length + " voicings from local cache")
                    return true
                }
            }
        } catch (e) {
            console.log("No local cache, fetching from URL")
        }
        return false
    }

    function saveToCache() {
        var data = JSON.stringify({ voicings: voicingsData }, null, 2)
        localCacheFile.write(data)
        console.log("Saved " + voicingsData.length + " voicings to local cache")
    }

    // === Settings persistence ===

    function loadSettings() {
        try {
            var raw = settingsFile.read()
            if (raw && raw.length > 0) {
                var s = JSON.parse(raw)
                if (s.voicingUrl) jsonUrl = s.voicingUrl
                if (s.diagramPlacement) diagramPlacement = s.diagramPlacement
                if (s.tuning) selectedTuning = s.tuning
                // Restore custom tunings that were added via Create/Import
                if (s.customTunings && Array.isArray(s.customTunings)) {
                    for (var i = 0; i < s.customTunings.length; i++) {
                        var ct = s.customTunings[i]
                        if (ct.slug && ct.name) {
                            addTuningToList(ct.slug, ct.name, ct.strings || 6)
                        }
                    }
                    console.log("Restored " + s.customTunings.length + " custom tuning(s)")
                }
                // Restore tuning order (if user reordered)
                if (s.tuningOrder && Array.isArray(s.tuningOrder)) {
                    // Merge: use saved order, then append any new built-ins not in the saved list
                    var ordered = []
                    for (var oi = 0; oi < s.tuningOrder.length; oi++) {
                        if (tuningList.indexOf(s.tuningOrder[oi]) >= 0) {
                            ordered.push(s.tuningOrder[oi])
                        }
                    }
                    for (var ti = 0; ti < tuningList.length; ti++) {
                        if (ordered.indexOf(tuningList[ti]) < 0) {
                            ordered.push(tuningList[ti])
                        }
                    }
                    tuningList = ordered
                }

                // Restore voicing calculator constraints
                if (s.calcMaxFret !== undefined) calcMaxFret = s.calcMaxFret
                if (s.calcMaxStretch !== undefined) calcMaxStretch = s.calcMaxStretch
                if (s.calcAllowOpen !== undefined) calcAllowOpen = s.calcAllowOpen
                if (s.calcRootInBass !== undefined) calcRootInBass = s.calcRootInBass
                if (s.calcMinNotes !== undefined) calcMinNotes = s.calcMinNotes
                if (s.calcMaxMuted !== undefined) calcMaxMuted = s.calcMaxMuted
                if (s.calcMaxPerQuality !== undefined) calcMaxPerQuality = s.calcMaxPerQuality

                console.log("Settings loaded: url=" + jsonUrl + ", placement=" + diagramPlacement + ", tuning=" + selectedTuning)
            }
        } catch (e) {
            console.log("No saved settings found, using defaults")
        }
    }

    // Build the custom tunings list (non-built-in tunings) for persistence
    function getCustomTuningsList() {
        var customs = []
        for (var i = 0; i < tuningList.length; i++) {
            var slug = tuningList[i]
            if (builtInTunings.indexOf(slug) < 0) {
                customs.push({ slug: slug, name: tuningLabels[slug] || slug, strings: tuningStringCounts[slug] || 6 })
            }
        }
        return customs
    }

    function saveSettings() {
        var s = {
            voicingUrl: jsonUrl,
            diagramPlacement: diagramPlacement,
            tuning: selectedTuning,
            customTunings: getCustomTuningsList(),
            tuningOrder: tuningList.slice(),
            calcMaxFret: calcMaxFret,
            calcMaxStretch: calcMaxStretch,
            calcAllowOpen: calcAllowOpen,
            calcRootInBass: calcRootInBass,
            calcMinNotes: calcMinNotes,
            calcMaxMuted: calcMaxMuted,
            calcMaxPerQuality: calcMaxPerQuality,
        }
        settingsFile.write(JSON.stringify(s, null, 2))
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

    function importTuning() {
        var path = tuningImportPath.text.trim()
        if (!path) {
            tuningImportStatus.text = "Enter a file path"
            tuningImportStatus.color = theme.errorText
            return
        }
        tuningFile.source = path
        try {
            var raw = tuningFile.read()
            if (!raw || raw.length === 0) {
                tuningImportStatus.text = "File not found or empty"
                tuningImportStatus.color = theme.errorText
                return
            }
            var tuning = JSON.parse(raw)
            if (!tuning.name || !tuning.strings) {
                tuningImportStatus.text = "Invalid tuning: needs 'name' and 'strings' fields"
                tuningImportStatus.color = theme.errorText
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
            saveSettings()

            tuningImportStatus.text = "Imported: " + tuning.name
            tuningImportStatus.color = theme.successText
        } catch (e) {
            tuningImportStatus.text = "Failed: " + e
            tuningImportStatus.color = theme.errorText
        }
    }

    function createTuning() {
        var name = tuningNameField.text.trim()
        if (!name) {
            tuningImportStatus.text = "Enter a tuning name"
            tuningImportStatus.color = theme.errorText
            return
        }

        var pitchStr = tuningPitchesField.text.trim()
        var rawParts = pitchStr.split(",")
        var pitches = []
        for (var p = 0; p < rawParts.length; p++) {
            var midi = noteNameToMidi(rawParts[p])
            if (midi < 0) {
                tuningImportStatus.text = "Can't parse: '" + rawParts[p].trim() + "' — use note names (E4, Bb3) or MIDI numbers (64, 59)"
                tuningImportStatus.color = theme.errorText
                return
            }
            pitches.push(midi)
        }
        var numStrings = tuningStringCount.value

        if (pitches.length < numStrings) {
            tuningImportStatus.text = "Need " + numStrings + " pitches, got " + pitches.length
            tuningImportStatus.color = theme.errorText
            return
        }
        pitches = pitches.slice(0, numStrings)

        // Validate pitches are reasonable MIDI values
        for (var i = 0; i < pitches.length; i++) {
            if (pitches[i] < 20 || pitches[i] > 100) {
                tuningImportStatus.text = "Pitch out of range: " + pitches[i] + " (expected 20-100)"
                tuningImportStatus.color = theme.errorText
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
            saveSettings()

            // Show the note names as feedback
            var noteStr = Object.keys(notes).map(function(k) { return notes[k] }).join("-")
            tuningImportStatus.text = "Created: " + name + " (" + noteStr + ")"
            tuningImportStatus.color = theme.successText
        } catch (e) {
            tuningImportStatus.text = "Failed to save: " + e
            tuningImportStatus.color = theme.errorText
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
                    tuningNameField.text = t.name || slug
                    var strings = t.strings || {}
                    var count = Object.keys(strings).length
                    tuningStringCount.value = count > 0 ? count : 6

                    // Convert MIDI values back to note names for display
                    var pitchParts = []
                    for (var s = 1; s <= count; s++) {
                        var midi = strings[String(s)]
                        if (midi !== undefined) {
                            pitchParts.push(midiNoteNames[midi] || String(midi))
                        }
                    }
                    tuningPitchesField.text = pitchParts.join(", ")
                    tuningImportStatus.text = "Editing: " + (t.name || slug) + " — change values and click Save"
                    tuningImportStatus.color = theme.textSecondary
                    return
                }
            } catch (e) {}
        }
        tuningImportStatus.text = "Could not load tuning: " + slug
        tuningImportStatus.color = theme.errorText
    }

    // Delete a custom tuning (built-in tunings cannot be deleted)
    function deleteTuning(slug) {
        if (!slug) return
        if (builtInTunings.indexOf(slug) >= 0) {
            tuningImportStatus.text = "Cannot delete built-in tuning"
            tuningImportStatus.color = theme.errorText
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

        tuningImportStatus.text = "Deleted: " + slug
        tuningImportStatus.color = theme.successText
    }

    // === Save to Library ===

    function saveVoicingToLibrary() {
        saveStatus.text = ""

        // Parse fret number
        var fretNum = parseInt(saveFretField.text.trim())
        if (isNaN(fretNum) || fretNum < 0 || fretNum > 24) {
            saveStatus.text = "Invalid fret number"; saveStatus.color = theme.errorText; return
        }

        // Parse dots: "6:1, 4:1, 3:2" → [{string:6, fret:1}, ...]
        var dotsStr = saveDotsField.text.trim()
        if (!dotsStr) { saveStatus.text = "Enter dot positions"; saveStatus.color = theme.errorText; return }
        var dotParts = dotsStr.split(",")
        var dots = []
        for (var d = 0; d < dotParts.length; d++) {
            var pair = dotParts[d].trim().split(":")
            if (pair.length !== 2) { saveStatus.text = "Bad dot format: " + dotParts[d]; saveStatus.color = theme.errorText; return }
            dots.push({ string: parseInt(pair[0]), fret: parseInt(pair[1]) })
        }

        // Parse mutes: "5, 2, 1" → [5, 2, 1]
        var mutesStr = saveMutesField.text.trim()
        var mutes = []
        if (mutesStr) {
            mutes = mutesStr.split(",").map(function(s) { return parseInt(s.trim()) })
        }

        var numStrings = saveStringsCount.value
        var quality = saveQualityCombo.currentText
        var category = saveCategoryCombo.currentText
        var context = saveContextCombo.currentText

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
                saveStatus.text = "ID already exists: " + id
                saveStatus.color = theme.errorText
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
        saveStatus.text = "Saved: " + voicing.name + keyNote
        saveStatus.color = theme.successText
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
        for (var i = 0; i < hygieneIgnoreList.length; i++) {
            if (hygieneIgnoreList[i].key === key) return true
        }
        return false
    }

    function clearDismissals() {
        hygieneIgnoreList = []
        saveHygieneIgnoreList()
        runHygieneAudit()
    }

    function runHygieneAudit() {
        loadHygieneIgnoreList()
        auditResultsModel.clear()
        var results = []
        var duplicates = 0
        var enharmonic = 0
        var crossCtx = 0
        var dismissed = 0

        // 1. Exact duplicates: same dots + fret + strings + context + quality
        var fpMap = {}
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            var dots = []
            for (var d = 0; d < v.dots.length; d++)
                dots.push(v.dots[d].string + ":" + v.dots[d].fret)
            dots.sort()
            var fp = v.strings + "|" + v.fret_number + "|" + dots.join(",") + "|" + v.context + "|" + v.chord_quality
            if (fpMap[fp]) {
                var dupKey = "DUP:" + v.id + "=" + fpMap[fp]
                if (isIgnored(dupKey)) { dismissed++; } else {
                    results.push("DUP: " + v.id + " = " + fpMap[fp])
                    duplicates++
                }
            } else {
                fpMap[fp] = v.id
            }
        }

        // 2. Enharmonic equivalents: same pitch class set, different quality
        // Compute pitch classes for each voicing
        var pcsMap = {}
        for (var j = 0; j < voicingsData.length; j++) {
            var vv = voicingsData[j]
            var pcs = []
            for (var dd = 0; dd < vv.dots.length; dd++) {
                var strNum = vv.dots[dd].string
                var strMidi = tuningMidi[String(strNum)]
                if (strMidi !== undefined) {
                    var absFret = vv.fret_number + (vv.dots[dd].fret - 1)
                    pcs.push((strMidi + absFret) % 12)
                }
            }
            // Add open strings
            for (var oo = 0; oo < (vv.open || []).length; oo++) {
                var openMidi = tuningMidi[String(vv.open[oo])]
                if (openMidi !== undefined) pcs.push(openMidi % 12)
            }
            pcs.sort()
            var pcsKey = pcs.join(",")
            if (!pcsMap[pcsKey]) pcsMap[pcsKey] = []
            pcsMap[pcsKey].push({ id: vv.id, quality: vv.chord_quality })
        }
        for (var pk in pcsMap) {
            var group = pcsMap[pk]
            if (group.length > 1) {
                var quals = {}
                for (var g = 0; g < group.length; g++) quals[group[g].quality] = true
                if (Object.keys(quals).length > 1) {
                    var ids = group.map(function(x) { return x.id + "(" + x.quality + ")" })
                    var enhKey = "ENH:" + pk
                    if (isIgnored(enhKey)) { dismissed++; } else {
                        results.push("ENHARMONIC: " + ids.join(" = "))
                        enharmonic++
                    }
                }
            }
        }

        // 3. Cross-context: same shape in different contexts
        var shapeMap = {}
        for (var k = 0; k < voicingsData.length; k++) {
            var vvv = voicingsData[k]
            var sdots = []
            for (var sd = 0; sd < vvv.dots.length; sd++)
                sdots.push(vvv.dots[sd].string + ":" + vvv.dots[sd].fret)
            sdots.sort()
            var shapeFp = vvv.strings + "|" + sdots.join(",")
            if (!shapeMap[shapeFp]) shapeMap[shapeFp] = []
            shapeMap[shapeFp].push({ id: vvv.id, context: vvv.context })
        }
        for (var sk in shapeMap) {
            var sgroup = shapeMap[sk]
            if (sgroup.length > 1) {
                var ctxs = {}
                for (var sg = 0; sg < sgroup.length; sg++) ctxs[sgroup[sg].context] = true
                if (Object.keys(ctxs).length > 1) {
                    var sids = sgroup.map(function(x) { return x.id + "(" + x.context + ")" })
                    var ctxKey = "CTX:" + sk
                    if (isIgnored(ctxKey)) { dismissed++; } else {
                        results.push("CROSS-CTX: " + sids.join(" | "))
                        crossCtx++
                    }
                }
            }
        }

        // Summary
        var total = duplicates + enharmonic + crossCtx
        var summary = voicingsData.length + " voicings audited\n"
            + duplicates + " duplicates, "
            + enharmonic + " enharmonic, "
            + crossCtx + " cross-context"
        if (dismissed > 0)
            summary += "\n(" + dismissed + " dismissed findings hidden)"
        hygieneResult.text = summary
        hygieneResult.color = duplicates > 0 ? theme.errorText : theme.successText

        lastAuditResults = results
        for (var r = 0; r < results.length; r++)
            auditResultsModel.append({ "modelData": results[r] })
    }

    // Store last audit results for report export
    property var lastAuditResults: []

    function fixDuplicates() {
        // Remove exact duplicates (same dots + fret + context + quality)
        var seen = {}
        var removed = 0
        var cleaned = []
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            var dots = []
            for (var d = 0; d < v.dots.length; d++)
                dots.push(v.dots[d].string + ":" + v.dots[d].fret)
            dots.sort()
            var fp = v.strings + "|" + v.fret_number + "|" + dots.join(",") + "|" + v.context + "|" + v.chord_quality
            if (seen[fp]) {
                removed++
            } else {
                seen[fp] = v.id
                cleaned.push(v)
            }
        }
        if (removed > 0) {
            voicingsData = cleaned
            rebuildFilterLists()
            applyFilters()
            saveToCache()
            hygieneResult.text = "Removed " + removed + " duplicates. " + voicingsData.length + " voicings remain."
            hygieneResult.color = theme.successText
        } else {
            hygieneResult.text = "No duplicates found."
            hygieneResult.color = theme.successText
        }
    }

    function saveAuditReport() {
        var path = auditReportPath.text.trim()
        if (!path) { hygieneResult.text = "Enter a file path"; return }

        var report = "CHORD LIBRARY AUDIT REPORT\n"
            + "=" .repeat(60) + "\n"
            + "Date:     " + new Date().toISOString().split("T")[0] + "\n"
            + "Voicings: " + voicingsData.length + "\n"
            + "Tuning:   " + (tuningLabels[selectedTuning] || selectedTuning) + "\n"
            + "Dismissed: " + hygieneIgnoreList.length + " findings suppressed\n"
            + "=".repeat(60) + "\n\n"

        // Group results by type
        var dups = [], enhs = [], ctxs = []
        for (var i = 0; i < lastAuditResults.length; i++) {
            var r = lastAuditResults[i]
            if (r.indexOf("DUP:") === 0) dups.push(r)
            else if (r.indexOf("ENHARMONIC:") === 0) enhs.push(r)
            else if (r.indexOf("CROSS-CTX:") === 0) ctxs.push(r)
        }

        if (dups.length > 0) {
            report += "EXACT DUPLICATES (" + dups.length + ")\n"
                + "-".repeat(40) + "\n"
                + "Same dots + fret + context + quality. Click 'Fix Duplicates' in the\n"
                + "plugin to remove these automatically.\n\n"
            for (var d = 0; d < dups.length; d++) {
                var dupKey = "DUP:" + dups[d].substring(5).replace(/ /g, "")
                report += "  " + dups[d] + "\n"
                report += "    DISMISS KEY: " + dupKey + "\n\n"
            }
        }

        if (enhs.length > 0) {
            report += "ENHARMONIC EQUIVALENTS (" + enhs.length + ")\n"
                + "-".repeat(40) + "\n"
                + "Same pitch classes, different chord quality name.\n"
                + "Usually legitimate (e.g., C6 and Am7 share the same notes).\n"
                + "If both names make sense, dismiss the finding.\n\n"
            for (var e = 0; e < enhs.length; e++) {
                var enhKey = "ENH:" + enhs[e].substring(12, 30).replace(/ /g, "")
                report += "  " + enhs[e] + "\n"
                report += "    DISMISS KEY: " + enhKey + "\n\n"
            }
        }

        if (ctxs.length > 0) {
            report += "CROSS-CONTEXT MATCHES (" + ctxs.length + ")\n"
                + "-".repeat(40) + "\n"
                + "Same shape in different contexts (CM6 vs CV6). Expected — same shape,\n"
                + "different musical purpose. Informational only.\n\n"
            for (var c = 0; c < ctxs.length; c++) {
                var ctxKey = "CTX:" + ctxs[c].substring(11, 30).replace(/ /g, "")
                report += "  " + ctxs[c] + "\n"
                report += "    DISMISS KEY: " + ctxKey + "\n\n"
            }
        }

        if (lastAuditResults.length === 0) {
            report += "No issues found. Library is clean.\n"
        }

        report += "\n" + "=".repeat(60) + "\n"
            + "HOW TO ACT ON FINDINGS\n"
            + "-".repeat(40) + "\n"
            + "DUPLICATES: Click 'Fix Duplicates' in the plugin to auto-remove.\n"
            + "DISMISS:    Copy a DISMISS KEY from above, paste it into the\n"
            + "            'Dismiss' field in Settings > Library Health, click Dismiss.\n"
            + "RESET:      Click 'Reset All Dismissed' to un-suppress everything.\n"

        tempDiagramFile.source = path
        try {
            tempDiagramFile.write(report)
            hygieneResult.text = hygieneResult.text + "\nReport opened"
        } catch (e) {
            hygieneResult.text = "Failed to save report: " + e
            hygieneResult.color = theme.errorText
        }
    }

    // Pre-fill Save to Library from a selected FretDiagram in the score
    function captureFromScore() {
        if (!curScore) { saveStatus.text = "No score open"; saveStatus.color = theme.errorText; return }

        var sel = curScore.selection
        if (!sel || !sel.elements || sel.elements.length === 0) {
            saveStatus.text = "Select a fretboard diagram first"
            saveStatus.color = theme.errorText
            return
        }

        var elem = sel.elements[0]

        // Check if it's a FretDiagram or if a note is selected with a diagram nearby
        if (elem.type === Element.FRET_DIAGRAM) {
            // Read what we can from the API
            var strings = elem.fretStrings || 6
            var frets = elem.fretFrets || 4
            var fretOff = elem.fretOffset || 0

            saveStringsCount.value = strings
            saveFretField.text = String(fretOff + 1)  // convert 0-indexed back

            saveStatus.text = "Captured: " + strings + " strings, fret " + (fretOff + 1)
                + "\nDots not readable from API — enter them manually."
            saveStatus.color = theme.successText
        } else {
            saveStatus.text = "Selected element is not a fretboard diagram.\nSelect a diagram in the score, then click Capture."
            saveStatus.color = theme.errorText
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

    // Generate voicings for the current tuning using the runtime calculator.
    // For standard tuning, uses the pre-built 820-voicing library (much richer).
    // For all other tunings, calculates geometrically correct voicings on the fly.
    function loadTuningVoicings() {
        // Save the standard library on first call so we can restore it
        if (standardVoicingsData.length === 0 && voicingsData.length > 0 && !usingTuningVoicings) {
            standardVoicingsData = voicingsData
        }

        // Standard tuning uses the pre-built library (820 hand-curated voicings)
        if (selectedTuning === "standard") {
            if (usingTuningVoicings && standardVoicingsData.length > 0) {
                voicingsData = standardVoicingsData
                usingTuningVoicings = false
                rebuildFilterLists()
                applyFilters()
                console.log("Restored standard voicing library (" + voicingsData.length + " voicings)")
                statusMsg.text = "Loaded " + voicingsData.length + " voicings (standard library)"
                statusMsg.color = theme.successText
            }
            return
        }

        // Non-standard tuning: calculate voicings from the tuning geometry
        console.log("Calculating voicings for tuning: " + selectedTuning + " ...")
        var calculated = VoicingCalculator.generateAll(tuningMidi, calcConstraints())

        if (calculated.length > 0) {
            voicingsData = calculated
            usingTuningVoicings = true
            rebuildFilterLists()
            applyFilters()
            console.log("Calculated " + calculated.length + " voicings for " + selectedTuning)
            statusMsg.text = calculated.length + " voicings calculated for " + (tuningLabels[selectedTuning] || selectedTuning)
            statusMsg.color = theme.successText
        } else {
            // Fallback to standard library with offset if calculation produced nothing
            console.log("No voicings calculated — falling back to standard library")
            if (standardVoicingsData.length > 0) {
                voicingsData = standardVoicingsData
                usingTuningVoicings = false
                rebuildFilterLists()
                applyFilters()
            }
        }
    }

    // Calculate "distance" between two voicings (lower = closer hand position)
    function voicingDistance(a, b) {
        return MelodyEngine.voicingDistance(a, b)
    }

    function applyFilters() {
        // Use the smaller of tuning string count and context string count as ceiling
        var maxStrings = tuningMaxStrings
        if (filterContext && contextStringCounts[filterContext] !== undefined) {
            var contextMax = contextStringCounts[filterContext]
            if (contextMax < maxStrings) maxStrings = contextMax
        }

        var result = []
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            if (filterContext && v.context !== filterContext) continue
            if (filterCategory && v.category !== filterCategory) continue
            // Quartal voicings work over any chord quality (stacked 4ths
            // serve multiple harmonic functions), so they always pass
            // the quality filter.
            if (filterQuality && v.chord_quality !== filterQuality
                && v.chord_quality !== "quartal") continue

            // Filter by string count — context string count is the ceiling
            var voicingStrings = v.strings || 6
            if (voicingStrings > maxStrings) continue

            if (searchText) {
                var q = searchText.toLowerCase()
                var match = v.name.toLowerCase().indexOf(q) >= 0
                    || v.chord_quality.toLowerCase().indexOf(q) >= 0
                    || (v.tags && v.tags.join(" ").toLowerCase().indexOf(q) >= 0)
                if (!match) continue
            }
            result.push(v)
        }

        // Sort by proximity to last inserted voicing
        if (sortByProximity && lastInsertedVoicing) {
            var ref = lastInsertedVoicing
            result.sort(function(a, b) {
                return voicingDistance(ref, a) - voicingDistance(ref, b)
            })
        }

        filteredData = result
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
            + pluginDir + '/voicings-cache.json" -o "' + outDir + '" 2>&1; open "' + outDir + '"')
    }

    function exportChordSheet() {
        var defaultName = homePath() + "/Documents/chord-sheet.pdf"
        openSaveDialog("Save Chord Sheet", "PDF files (*.pdf)", defaultName, function(outPath) {
            _doExportChordSheet(outPath)
        })
    }

    function _doExportChordSheet(outPath) {
        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var dataPath = pluginDir + "/voicings-cache.json"

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
        var dataPath = pluginDir + "/voicings-cache.json"

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
        var dataPath = pluginDir + "/voicings-cache.json"
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
            toolStatus.text = "Open a score with chord symbols first."
            toolStatus.color = theme.errorText
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            toolStatus.text = "No chord symbols found in the score."
            toolStatus.color = theme.errorText
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
            toolStatus.text = "Open a score with chord symbols first."
            toolStatus.color = theme.errorText
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            toolStatus.text = "No chord symbols found in the score."
            toolStatus.color = theme.errorText
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
            toolStatus.text = "Open a score with chord symbols first."
            toolStatus.color = theme.errorText
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            toolStatus.text = "No chord symbols found."
            toolStatus.color = theme.errorText
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

    // Simple fingering heuristic (QML-side, for inline annotation)
    // Returns a string like "1-X-1-2-X-X" (finger per string, low to high)
    function computeFingeringString(voicing) {
        var dots = voicing.dots || []
        var mutes = voicing.mutes || []
        var opens = voicing.open || []
        var numStrings = voicing.strings || 6
        var fretNumber = voicing.fret_number || 1

        if (dots.length === 0) return ""

        // Convert to absolute frets
        var fretted = []
        for (var d = 0; d < dots.length; d++) {
            fretted.push({
                string: dots[d].string,
                absFret: fretNumber + (dots[d].fret - 1),
            })
        }
        fretted.sort(function(a, b) { return a.absFret - b.absFret })

        var minFret = fretted[0].absFret
        var maxFret = fretted[fretted.length - 1].absFret

        // Group by fret for barre detection
        var fretGroups = {}
        for (var i = 0; i < fretted.length; i++) {
            if (!fretGroups[fretted[i].absFret])
                fretGroups[fretted[i].absFret] = []
            fretGroups[fretted[i].absFret].push(fretted[i].string)
        }

        // Assign fingers: one per unique fret, 1=index for lowest
        var uniqueFrets = Object.keys(fretGroups).sort(function(a, b) { return a - b })
        var fretToFinger = {}
        var fingers = [1, 2, 3, 4]
        for (var f = 0; f < uniqueFrets.length && f < 4; f++) {
            fretToFinger[uniqueFrets[f]] = fingers[f]
        }

        // Build per-string result
        var result = {}
        for (var j = 0; j < fretted.length; j++) {
            result[fretted[j].string] = fretToFinger[fretted[j].absFret] || 1
        }

        // Build display string (low string to high)
        var parts = []
        for (var s = numStrings; s >= 1; s--) {
            if (result[s] !== undefined)
                parts.push(String(result[s]))
            else if (mutes.indexOf(s) >= 0)
                parts.push("X")
            else if (opens.indexOf(s) >= 0)
                parts.push("O")
            else
                parts.push("·")
        }
        return parts.join(" ")
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
                + '" --data "' + pluginDir + '/voicings-cache.json" -o "' + outPath
                + '" 2>&1; open "' + outPath + '"')
        })
    }

    function doImport() {
        importStatus.text = "Loading..."
        importStatus.color = theme.textMuted

        var path = importPathField.text.trim()
        if (!path) {
            importStatus.text = "Enter a file path"
            importStatus.color = theme.errorText
            return
        }
        importFile.source = path
        try {
            var raw = importFile.read()
            if (!raw || raw.length === 0) {
                importStatus.text = "FAILED: file is empty or not found"
                importStatus.color = theme.errorText
                return
            }
            var data = JSON.parse(raw)
            var imported = data.voicings || []

            if (!Array.isArray(imported) || imported.length === 0) {
                importStatus.text = "FAILED: no voicings array found in file"
                importStatus.color = theme.errorText
                return
            }

            // Validate required fields
            var errors = validateImport(imported)
            if (errors.length > 0) {
                importStatus.text = "FAILED: " + errors[0]
                importStatus.color = theme.errorText
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
                importStatus.text = "SUCCESS: " + added + " voicings added"
                    + (skipped > 0 ? ", " + skipped + " duplicates skipped" : "")
                    + " (" + voicingsData.length + " total)"
                importStatus.color = theme.successText
            } else {
                importStatus.text = "No new voicings — all " + skipped + " were duplicates"
                importStatus.color = theme.textMuted
            }
        } catch (e) {
            importStatus.text = "FAILED: " + e
            importStatus.color = theme.errorText
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

        // === Tab 1: Score Tools ===
        Flickable {
            visible: currentTab === 1 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: scoreToolsColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: scoreToolsColumn
                width: parent.width - 16
                spacing: 12

                Label {
                    text: "Score analysis and fingering tools (open a score with chord symbols first):"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Button {
                        text: "Analyze Score"
                        font.pixelSize: 10
                        onClicked: analyzeCurrentScore()
                    }

                    Button {
                        text: "Voice Leading"
                        font.pixelSize: 10
                        onClicked: runVoiceLeading()
                    }

                    Button {
                        text: "Suggest Fingerings"
                        font.pixelSize: 10
                        onClicked: suggestFingerings()
                    }
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // --- Voicing Calculator Constraints ---
                Label {
                    text: "VOICING CONSTRAINTS"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: "Controls how voicings are generated for non-standard tunings. These are defaults — override per chord in the walkthrough."
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 6

                    Label { text: "Max fret:"; font.pixelSize: 10 }
                    SpinBox {
                        id: calcMaxFretSpin
                        from: 7; to: 24; value: calcMaxFret
                        implicitWidth: 70
                        onValueChanged: {
                            if (value !== calcMaxFret) {
                                calcMaxFret = value
                                if (usingTuningVoicings) loadTuningVoicings()
                            }
                        }
                    }

                    Label { text: "Max stretch:"; font.pixelSize: 10 }
                    SpinBox {
                        id: calcMaxStretchSpin
                        from: 2; to: 7; value: calcMaxStretch
                        implicitWidth: 70
                        onValueChanged: {
                            if (value !== calcMaxStretch) {
                                calcMaxStretch = value
                                if (usingTuningVoicings) loadTuningVoicings()
                            }
                        }
                    }

                    Label { text: "Min notes:"; font.pixelSize: 10 }
                    SpinBox {
                        id: calcMinNotesSpin
                        from: 2; to: 6; value: calcMinNotes
                        implicitWidth: 70
                        onValueChanged: {
                            if (value !== calcMinNotes) {
                                calcMinNotes = value
                                if (usingTuningVoicings) loadTuningVoicings()
                            }
                        }
                    }

                    Label { text: "Max muted:"; font.pixelSize: 10 }
                    SpinBox {
                        id: calcMaxMutedSpin
                        from: 0; to: 4; value: calcMaxMuted
                        implicitWidth: 70
                        onValueChanged: {
                            if (value !== calcMaxMuted) {
                                calcMaxMuted = value
                                if (usingTuningVoicings) loadTuningVoicings()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "Max per quality:"; font.pixelSize: 10 }
                    SpinBox {
                        from: 0; to: 999; value: calcMaxPerQuality
                        implicitWidth: 80
                        ToolTip.visible: hovered
                        ToolTip.text: "0 = unlimited (Ted Greene mode). Higher = fewer voicings, faster."
                        onValueChanged: {
                            if (value !== calcMaxPerQuality) {
                                calcMaxPerQuality = value
                                if (usingTuningVoicings) loadTuningVoicings()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    CheckBox {
                        text: "Open strings"
                        font.pixelSize: 10
                        checked: calcAllowOpen
                        onCheckedChanged: {
                            calcAllowOpen = checked
                            if (usingTuningVoicings) loadTuningVoicings()
                        }
                    }

                    CheckBox {
                        text: "Root in bass"
                        font.pixelSize: 10
                        checked: calcRootInBass
                        onCheckedChanged: {
                            calcRootInBass = checked
                            if (usingTuningVoicings) loadTuningVoicings()
                        }
                    }
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                Label {
                    text: "TEXT ANNOTATIONS"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: "Add text notation (e.g. 1-X-1-2-X-X) above each chord symbol as staff text.\nAt positions with existing diagrams, annotation matches the diagram."
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Button {
                        text: "Annotate Staff Text"
                        font.pixelSize: 10
                        onClicked: addFingeringsToScore()
                        ToolTip.visible: hovered
                        ToolTip.text: "Adds fret notation as staff text — reads existing diagrams when present"
                    }

                    Button {
                        text: "Fingering Sheet (PDF)"
                        font.pixelSize: 10
                        onClicked: exportFingeringSheet()
                    }

                    CheckBox {
                        text: "Skip diagrams"
                        font.pixelSize: 9
                        checked: skipDiagramPositions
                        onCheckedChanged: skipDiagramPositions = checked
                        ToolTip.visible: hovered
                        ToolTip.text: "When checked, skip positions that already have a fretboard diagram"
                    }
                }

                Label {
                    id: toolStatus
                    visible: text.length > 0
                    font.pixelSize: 10
                    font.family: "Menlo, Monaco, Courier New, monospace"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    padding: 8
                    background: Rectangle {
                        color: theme.consoleBg
                        radius: 4
                    }
                }
            }
        }

        // === Tab 2: Export ===
        Flickable {
            visible: currentTab === 2 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: exportColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: exportColumn
                width: parent.width - 16
                spacing: 12

                Label {
                    text: "Save current library to a file:"
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: exportPathField
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        text: homePath() + "/Documents/chord-library-export.json"
                        selectByMouse: true
                    }

                    Button {
                        text: "Browse"
                        onClicked: openFileBrowser("save", exportPathField, null)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Button {
                        text: "Export JSON"
                        font.pixelSize: 10
                        onClicked: doExport()
                    }

                    Button {
                        text: "Export MusicXML"
                        font.pixelSize: 10
                        onClicked: exportMusicXML()
                    }

                    Button {
                        text: "Export GP5"
                        font.pixelSize: 10
                        onClicked: exportGP5()
                    }

                    Button {
                        text: "Chord Sheet (PDF)"
                        font.pixelSize: 10
                        onClicked: exportChordSheet()
                    }

                    Button {
                        text: "Diagrams (SVG)"
                        font.pixelSize: 10
                        onClicked: exportDiagramsSVG()
                    }
                }

                Label {
                    id: exportStatus
                    visible: text.length > 0
                    font.pixelSize: 11
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // === Tab 3: Import ===
        Flickable {
            visible: currentTab === 3 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: importColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: importColumn
                width: parent.width - 16
                spacing: 12

                // --- Voicing Source URL ---
                Label {
                    text: "VOICING SOURCE URL"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                TextField {
                    id: urlField
                    Layout.fillWidth: true
                    text: jsonUrl
                    font.pixelSize: 11
                    selectByMouse: true
                }

                RowLayout {
                    spacing: 6

                    Button {
                        text: "Apply URL"
                        onClicked: {
                            jsonUrl = urlField.text
                            dataLoaded = false
                            saveSettings()
                            fetchVoicings()
                        }
                    }

                    Button {
                        text: "Reset Default"
                        onClicked: {
                            var defaultUrl = "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"
                            urlField.text = defaultUrl
                            jsonUrl = defaultUrl
                            dataLoaded = false
                            saveSettings()
                            fetchVoicings()
                        }
                    }

                    Button {
                        text: "Refresh"
                        onClicked: {
                            dataLoaded = false
                            fetchVoicings()
                        }
                    }
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // --- Import Voicings ---
                Label {
                    text: "IMPORT VOICINGS"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: "Merge voicings from a JSON file (duplicates skipped):"
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: importPathField
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        placeholderText: "/path/to/voicings.json"
                        selectByMouse: true
                    }

                    Button {
                        text: "Browse"
                        onClicked: openFileBrowser("open", importPathField, null)
                    }
                }

                Button {
                    text: "Import & Merge"
                    onClicked: doImport()
                }

                Label {
                    id: importStatus
                    visible: text.length > 0
                    font.pixelSize: 11
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // === Tab 4: Practice (Flash Cards) ===
        Flickable {
            visible: currentTab === 4 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: practiceColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: practiceColumn
                width: parent.width - 16
                spacing: 12

                // Score display
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Score: " + practiceCorrect + " / " + practiceTotal
                        font.pixelSize: 13
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: practiceTotal > 0
                            ? Math.round(practiceCorrect / practiceTotal * 100) + "% correct"
                            : ""
                        font.pixelSize: 11
                        color: theme.textMuted
                    }

                    Button {
                        text: "Reset"
                        font.pixelSize: 10
                        onClicked: practiceReset()
                    }
                }

                // Mode selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: "Mode:"
                        font.pixelSize: 11
                    }

                    Button {
                        text: "Name the Chord"
                        font.pixelSize: 10
                        highlighted: practiceMode === "name"
                        onClicked: { practiceMode = "name"; practiceNext() }
                    }

                    Button {
                        text: "Find the Shape"
                        font.pixelSize: 10
                        highlighted: practiceMode === "shape"
                        onClicked: { practiceMode = "shape"; practiceNext() }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // Flash card area
                Rectangle {
                    Layout.fillWidth: true
                    height: 220
                    radius: 8
                    color: theme.cardBackground
                    border.color: theme.cardBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // "Name the Chord" mode: show fretboard, hide name
                        Label {
                            visible: practiceMode === "name" && !practiceShowAnswer
                            text: "What chord is this voicing?"
                            font.pixelSize: 12
                            color: theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // "Find the Shape" mode: show chord name, hide fretboard
                        Label {
                            visible: practiceMode === "shape"
                            text: practiceVoicing ? practiceVoicing.name || "" : ""
                            font.pixelSize: 16
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Label {
                            visible: practiceMode === "shape" && !practiceShowAnswer
                            text: "Visualize the fretboard shape, then reveal"
                            font.pixelSize: 11
                            color: theme.textMuted
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Fretboard preview (hidden in "shape" mode until revealed)
                        Canvas {
                            id: practiceCanvas
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 140
                            Layout.alignment: Qt.AlignHCenter
                            visible: practiceMode === "name" || practiceShowAnswer

                            property var pv: practiceVoicing

                            onPvChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var v = pv
                                if (!v || !v.dots) return

                                var ns = v.strings || 6
                                var nf = v.visible_frets || 4
                                var mg = 10, tm = 18
                                var ss = (width - 2 * mg) / (ns - 1)
                                var fs = (height - tm - mg) / nf

                                var isDark = theme.isDark
                                var gridColor = isDark ? Qt.rgba(0.85, 0.85, 0.85, 0.7) : Qt.rgba(0.4, 0.4, 0.4, 0.6)
                                var textColor = isDark ? Qt.rgba(0.8, 0.8, 0.8, 0.8) : Qt.rgba(0.4, 0.4, 0.4, 0.8)
                                var muteColor = isDark ? Qt.rgba(0.7, 0.7, 0.7, 0.8) : Qt.rgba(0.5, 0.5, 0.5, 0.7)

                                ctx.strokeStyle = gridColor
                                ctx.lineWidth = 0.5
                                for (var s = 0; s < ns; s++) {
                                    ctx.beginPath()
                                    ctx.moveTo(mg + s * ss, tm)
                                    ctx.lineTo(mg + s * ss, height - mg)
                                    ctx.stroke()
                                }
                                for (var f = 0; f <= nf; f++) {
                                    ctx.lineWidth = (f === 0 && (v.fret_number || 1) <= 1) ? 2.5 : 0.5
                                    ctx.beginPath()
                                    ctx.moveTo(mg, tm + f * fs)
                                    ctx.lineTo(width - mg, tm + f * fs)
                                    ctx.stroke()
                                }
                                if ((v.fret_number || 0) > 1) {
                                    ctx.fillStyle = textColor
                                    ctx.font = "10px sans-serif"
                                    ctx.textAlign = "right"
                                    ctx.fillText(v.fret_number, mg - 3, tm + fs * 0.6)
                                }
                                var dots = v.dots || []
                                var ivs = v.intervals || []
                                for (var d = 0; d < dots.length; d++) {
                                    var iv = (d < ivs.length) ? ivs[d] : ""
                                    if (iv === "1") ctx.fillStyle = theme.dotRoot
                                    else if (iv === "3" || iv === "b3") ctx.fillStyle = theme.dotThird
                                    else if (iv === "5" || iv === "b5" || iv === "#5") ctx.fillStyle = theme.dotFifth
                                    else if (iv === "7" || iv === "b7" || iv === "bb7") ctx.fillStyle = theme.dotSeventh
                                    else if (iv === "6" || iv === "13" || iv === "b13") ctx.fillStyle = theme.dotSixth
                                    else if (iv === "9" || iv === "b9" || iv === "#9" || iv === "2") ctx.fillStyle = theme.dotNinth
                                    else if (iv === "4" || iv === "11" || iv === "#11") ctx.fillStyle = theme.dotFourth
                                    else ctx.fillStyle = theme.dotDefault
                                    ctx.beginPath()
                                    ctx.arc(mg + (ns - dots[d].string) * ss, tm + (dots[d].fret - 0.5) * fs, 5, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                                ctx.fillStyle = muteColor
                                ctx.font = "11px sans-serif"
                                ctx.textAlign = "center"
                                var mutes = v.mutes || []
                                for (var m = 0; m < mutes.length; m++) {
                                    ctx.fillText("×", mg + (ns - mutes[m]) * ss, tm - 3)
                                }
                                ctx.strokeStyle = muteColor
                                ctx.lineWidth = 1
                                var opens = v.open || []
                                for (var o = 0; o < opens.length; o++) {
                                    ctx.beginPath()
                                    ctx.arc(mg + (ns - opens[o]) * ss, tm - 7, 3.5, 0, 2 * Math.PI)
                                    ctx.stroke()
                                }
                            }
                        }

                        // Answer (chord name + details)
                        Label {
                            visible: practiceShowAnswer && practiceMode === "name"
                            text: practiceVoicing ? practiceVoicing.name || "" : ""
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Label {
                            visible: practiceShowAnswer
                            text: practiceVoicing
                                ? (practiceVoicing.intervals || []).join(" ")
                                    + "  |  Fret " + (practiceVoicing.fret_number || "?")
                                    + "  |  " + (practiceVoicing.category || "")
                                : ""
                            font.pixelSize: 10
                            color: theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Button {
                        visible: !practiceShowAnswer
                        text: "Reveal Answer"
                        font.pixelSize: 12
                        onClicked: practiceReveal()
                    }

                    Button {
                        visible: practiceShowAnswer
                        text: "✓ Got it"
                        font.pixelSize: 12
                        onClicked: practiceMarkCorrect()
                    }

                    Button {
                        visible: practiceShowAnswer
                        text: "✗ Missed"
                        font.pixelSize: 12
                        onClicked: practiceMarkWrong()
                    }

                    Button {
                        text: "Skip"
                        font.pixelSize: 10
                        onClicked: practiceNext()
                    }
                }
            }
        }

        // === Tab 5: Settings ===
        Flickable {
            visible: currentTab === 5 && !showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsColumn
                width: parent.width - 16
                spacing: 12

                // --- Diagram placement ---
                Label {
                    text: "DIAGRAM PLACEMENT"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                ComboBox {
                    id: placementCombo
                    model: ["Above staff (default)", "Below staff"]
                    Layout.fillWidth: true
                    currentIndex: diagramPlacement === "below" ? 1 : 0
                    onCurrentIndexChanged: {
                        diagramPlacement = currentIndex === 1 ? "below" : "above"
                        saveSettings()
                    }
                }

                Label {
                    text: "You can also show all diagrams at the top of the first page:\nFormat > Style > Fretboard Diagrams"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // --- Tuning ---
                Label {
                    text: "TUNING"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        text: "Active: " + (tuningLabels[selectedTuning] || selectedTuning)
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Edit"
                        font.pixelSize: 10
                        ToolTip.visible: hovered
                        ToolTip.text: "Load this tuning into the form below for editing"
                        onClicked: editTuning(selectedTuning)
                    }

                    Button {
                        text: "Delete"
                        font.pixelSize: 10
                        enabled: builtInTunings.indexOf(selectedTuning) < 0
                        ToolTip.visible: hovered
                        ToolTip.text: builtInTunings.indexOf(selectedTuning) >= 0
                            ? "Built-in tunings cannot be deleted"
                            : "Delete this custom tuning"
                        onClicked: deleteTuning(selectedTuning)
                    }

                    Button {
                        text: "▲"
                        font.pixelSize: 10
                        implicitWidth: 28
                        enabled: tuningList.indexOf(selectedTuning) > 0
                        ToolTip.visible: hovered
                        ToolTip.text: "Move this tuning up in the list"
                        onClicked: moveTuning(selectedTuning, -1)
                    }

                    Button {
                        text: "▼"
                        font.pixelSize: 10
                        implicitWidth: 28
                        enabled: tuningList.indexOf(selectedTuning) < tuningList.length - 1
                        ToolTip.visible: hovered
                        ToolTip.text: "Move this tuning down in the list"
                        onClicked: moveTuning(selectedTuning, 1)
                    }
                }

                // --- Import tuning ---
                Label {
                    text: "Import a tuning JSON file:"
                    font.pixelSize: 10
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: tuningImportPath
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        placeholderText: "/path/to/tuning.json"
                        selectByMouse: true
                    }

                    Button {
                        text: "Import"
                        font.pixelSize: 10
                        onClicked: importTuning()
                    }
                }

                Label {
                    id: tuningImportStatus
                    visible: text.length > 0
                    font.pixelSize: 11
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // --- Create / edit tuning ---
                Label {
                    text: "Create or edit a tuning:"
                    font.pixelSize: 10
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: tuningNameField
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        placeholderText: "Name (e.g. Open G)"
                        selectByMouse: true
                    }

                    SpinBox {
                        id: tuningStringCount
                        from: 4
                        to: 12
                        value: 6
                        implicitWidth: 80
                    }
                }

                Label {
                    text: "String pitches (high to low, note names or MIDI):"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                TextField {
                    id: tuningPitchesField
                    Layout.fillWidth: true
                    font.pixelSize: 11
                    placeholderText: "E4, B3, G3, D3, A2, E2"
                    selectByMouse: true
                    text: "E4, B3, G3, D3, A2, E2"
                }

                Button {
                    text: "Save Tuning"
                    font.pixelSize: 10
                    ToolTip.visible: hovered
                    ToolTip.text: "Create a new tuning or save changes to an existing one"
                    onClicked: createTuning()
                }

                Label {
                    text: '<a href="https://github.com/siege-analytics/musescore4-chord-library-plugin/tree/main/config/tunings">View tuning format on GitHub</a>'
                    font.pixelSize: 10
                    onLinkActivated: Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton
                    }
                }

                Label {
                    text: '<a href="https://gtdb.org">Guitar Tuning Database (gtdb.org)</a> — reference for string pitches'
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    onLinkActivated: Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton
                    }
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // --- Save to Library ---
                Label {
                    text: "SAVE TO LIBRARY"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: "Enter a voicing or capture from the score."
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Button {
                    text: "Capture from Score"
                    font.pixelSize: 10
                    onClicked: captureFromScore()
                }

                Label {
                    text: "Dots: string:fret pairs (e.g. 6:1,4:1,3:2)"
                    font.pixelSize: 9
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    ComboBox {
                        id: saveQualityCombo
                        model: ["dom7","maj7","min7","min7b5","dim7","maj6","min6",
                                "dom7b9","dom7sharp5","dom7alt","dom9","dom13",
                                "sus4","sus2","aug7","min-maj7","augMaj7"]
                        Layout.fillWidth: true
                    }

                    ComboBox {
                        id: saveCategoryCombo
                        model: ["shell","drop2","drop3","extended","altered","quartal"]
                        implicitWidth: 90
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    ComboBox {
                        id: saveContextCombo
                        model: ["CV6","CV7","CM6","CM7"]
                        implicitWidth: 70
                    }

                    TextField {
                        id: saveFretField
                        placeholderText: "Fret#"
                        implicitWidth: 50
                        font.pixelSize: 11
                        selectByMouse: true
                    }

                    SpinBox {
                        id: saveStringsCount
                        from: 4; to: 12; value: 6
                        implicitWidth: 75
                    }
                }

                TextField {
                    id: saveDotsField
                    Layout.fillWidth: true
                    font.pixelSize: 11
                    placeholderText: "Dots: 6:1, 4:1, 3:2"
                    selectByMouse: true
                }

                TextField {
                    id: saveMutesField
                    Layout.fillWidth: true
                    font.pixelSize: 11
                    placeholderText: "Mutes: 5, 2, 1"
                    selectByMouse: true
                }

                Label {
                    text: "Enter positions as played. The plugin will reproject to C."
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Button {
                    text: "Save Voicing"
                    font.pixelSize: 10
                    onClicked: saveVoicingToLibrary()
                }

                Label {
                    id: saveStatus
                    visible: text.length > 0
                    font.pixelSize: 11
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // --- Library Health ---
                Label {
                    text: "LIBRARY HEALTH"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: auditReportPath
                        Layout.fillWidth: true
                        font.pixelSize: 10
                        text: homePath() + "/Documents/chord-library-audit.txt"
                        selectByMouse: true
                    }

                    Button {
                        text: "Browse"
                        font.pixelSize: 10
                        onClicked: openFileBrowser("save", auditReportPath, null)
                    }
                }

                Button {
                    text: "Run Audit"
                    font.pixelSize: 10
                    onClicked: {
                        runHygieneAudit()
                        saveAuditReport()
                        Qt.openUrlExternally(auditReportPath.text)
                    }
                }

                Label {
                    id: hygieneResult
                    visible: text.length > 0
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // --- Dismiss / Fix actions ---
                Label {
                    visible: lastAuditResults.length > 0
                    text: "Paste a DISMISS KEY from the report to suppress it:"
                    font.pixelSize: 9
                }

                RowLayout {
                    visible: lastAuditResults.length > 0
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: dismissKeyField
                        Layout.fillWidth: true
                        font.pixelSize: 10
                        placeholderText: "e.g. ENH:0,4,9,11"
                        selectByMouse: true
                    }

                    Button {
                        text: "Dismiss"
                        font.pixelSize: 10
                        onClicked: {
                            var key = dismissKeyField.text.trim()
                            if (key) {
                                dismissFinding(key)
                                dismissKeyField.text = ""
                                hygieneResult.text = "Dismissed. Run audit again to see updated results."
                                hygieneResult.color = theme.successText
                            }
                        }
                    }
                }

                RowLayout {
                    visible: lastAuditResults.length > 0 || hygieneIgnoreList.length > 0
                    Layout.fillWidth: true
                    spacing: 4

                    Button {
                        text: "Fix Duplicates"
                        font.pixelSize: 10
                        visible: lastAuditResults.some(function(r) { return r.indexOf("DUP:") === 0 })
                        onClicked: fixDuplicates()
                    }

                    Button {
                        text: "Reset All Dismissed"
                        font.pixelSize: 10
                        visible: hygieneIgnoreList.length > 0
                        onClicked: clearDismissals()
                    }
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // --- About ---
                Label {
                    text: "ABOUT"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: "Siege Analytics Chord Library v1.5.0"
                    font.pixelSize: 12
                    font.bold: true
                }

                Label {
                    text: "Author: Dheeraj Chand"
                    font.pixelSize: 11
                }

                Label {
                    text: '<a href="https://github.com/siege-analytics/musescore4-chord-library-plugin">GitHub Repository</a>'
                    font.pixelSize: 11
                    onLinkActivated: Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton
                    }
                }

                Label {
                    text: '<a href="https://siegeanalytics.com">Siege Analytics</a>'
                    font.pixelSize: 11
                    onLinkActivated: Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton
                    }
                }

                Label {
                    text: '<a href="https://creativecommons.org/licenses/by/4.0/">Licensed under CC BY 4.0</a>'
                    font.pixelSize: 10
                    onLinkActivated: Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton
                    }
                }

                Label {
                    text: '<a href="https://github.com/siege-analytics/musescore4-chord-library-plugin/blob/main/DEVELOPMENT.md">Documentation</a>'
                    font.pixelSize: 11
                    onLinkActivated: Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }

        // === Tool Results panel (overlay) — extracted to WalkthroughPanel.qml ===
        WalkthroughPanel {
            id: walkthroughPanel
            visible: showToolResults
            Layout.fillWidth: true
            Layout.fillHeight: true

            batchChords: _batchChords
            batchIndex: _batchIndex
            batchTotal: chordLibrary.batchTotal
            batchActive: batchQueue.length > 0
            resultsTitle: toolResultsTitle
            resultsContent: toolResultsContent
            availableCategories: categoryList
            tuningName: tuningLabels[selectedTuning] || selectedTuning
            calculatedVoicings: usingTuningVoicings
            tuningPitches: tuningPitchNotation

            onPrevClicked: {
                _batchIndex = _batchIndex - 2
                batchShowNext()
            }
            onNextClicked: batchShowNext()
            onStopClicked: {
                batchQueue = []
                _batchChords = []
                showToolResults = false
            }
            onRevoiceRequested: function(melodyNote, melodyLocked, bassNote, bassLocked, category) {
                revoiceCurrentStepWith(melodyNote, melodyLocked, bassNote, bassLocked, category)
            }
            onReharmSelected: function(newRoot, newQuality) {
                // Apply the reharm suggestion: change the current chord's root/quality
                var idx = _batchIndex - 1
                if (idx < 0 || idx >= _batchChords.length) return
                var item = _batchChords[idx]
                item.root = newRoot
                item.quality = newQuality
                item.text = newRoot + (newQuality === "dom7" ? "7" : newQuality === "min7" ? "m7" : newQuality === "maj7" ? "maj7" : newQuality === "dim7" ? "dim7" : newQuality === "min6" ? "m6" : newQuality === "sus4" ? "sus4" : newQuality)
                // Update bass suggestion for new root
                item.bassMidi = MelodyEngine.suggestBassNote(newRoot, newQuality, Transposer.SEMITONE_MAP)
                // Re-voice with the new chord
                var voicing = findBestVoicing(newRoot, newQuality, item.melodyMidi, item.bassMidi)
                if (voicing) {
                    item.voicing = voicing
                    var xml = generateXmlForVoicing(voicing, newRoot)
                    var xmlPath = Qt.resolvedUrl("paste-clipboard.xml")
                    tempDiagramFile.source = xmlPath
                    try { tempDiagramFile.write(xml) } catch(e) {}
                }
                // Refresh the display
                _batchIndex = idx
                batchShowNext()
            }
        }

        // === Tab 0: Library (main panel) ===
        TextField {
            visible: currentTab === 0 && !showToolResults
            id: searchField
            placeholderText: "Search voicings..."
            Layout.fillWidth: true
            onTextChanged: {
                searchText = text
                applyFilters()
            }
        }

        RowLayout {
            visible: currentTab === 0 && !showToolResults
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: contextCombo
                model: contextList
                Layout.fillWidth: true
                displayText: {
                    if (currentText === "All Contexts") return currentText
                    var wide = chordLibrary.width > 360
                    return wide ? (contextLabels[currentText] || currentText)
                                : (contextLabelsShort[currentText] || currentText)
                }
                onCurrentTextChanged: {
                    filterContext = currentText === "All Contexts" ? "" : currentText
                    applyFilters()
                }
            }
            ComboBox {
                id: categoryCombo
                model: categoryList
                Layout.fillWidth: true
                onCurrentTextChanged: {
                    filterCategory = currentText === "All Types" ? "" : currentText
                    applyFilters()
                }
            }
        }

        ComboBox {
            visible: currentTab === 0 && !showToolResults
            id: qualityCombo
            model: qualityList
            Layout.fillWidth: true
            onCurrentTextChanged: {
                filterQuality = currentText === "All Qualities" ? "" : currentText
                applyFilters()
            }
        }

        RowLayout {
            visible: currentTab === 0 && !showToolResults
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: tuningMainCombo
                model: filteredTuningDisplayList
                Layout.fillWidth: true
                currentIndex: Math.max(0, filteredTuningList.indexOf(selectedTuning))
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < filteredTuningList.length) {
                        var newTuning = filteredTuningList[currentIndex]
                        if (newTuning && newTuning !== selectedTuning) {
                            selectedTuning = newTuning
                            loadTuningStringCount()
                            loadTuningVoicings()
                            saveSettings()
                        }
                    }
                }
            }

            Label {
                text: filteredData.length + " of " + voicingsData.length
                font.pixelSize: 11
            }

            Button {
                text: "Voice Here"
                font.pixelSize: 10
                implicitWidth: 64
                ToolTip.visible: hovered
                ToolTip.text: "Suggest a voicing for the chord at the current cursor position"
                onClicked: voiceAtCursor()
            }

            Button {
                text: batchQueue.length > 0 ? "Stop" : "Voice All"
                font.pixelSize: 10
                implicitWidth: 64
                ToolTip.visible: hovered
                ToolTip.text: "Voice all chord symbols in the score"
                onClicked: {
                    if (batchQueue.length > 0) {
                        batchQueue = []
                        statusMsg.text = "Voicing stopped"
                        statusMsg.color = theme.textMuted
                    } else {
                        batchInsert()
                    }
                }
            }

            Button {
                text: sortByProximity ? "Nearest" : "Default"
                font.pixelSize: 10
                implicitWidth: 56
                onClicked: {
                    sortByProximity = !sortByProximity
                    applyFilters()
                    statusMsg.text = sortByProximity
                        ? "Sorting by proximity to last voicing"
                        : "Default sort order"
                    statusMsg.color = theme.textMuted
                }
            }

            Button {
                text: melodyOnTop ? "Melody ✓" : "Melody"
                font.pixelSize: 10
                implicitWidth: 56
                ToolTip.visible: hovered
                ToolTip.text: "Match voicing top note to the melody (Martin Taylor approach)"
                onClicked: {
                    melodyOnTop = !melodyOnTop
                    statusMsg.text = melodyOnTop
                        ? "Melody on top: voicings will match the melody note"
                        : "Melody on top: off"
                    statusMsg.color = theme.textMuted
                }
            }

            TextField {
                id: melodyOverrideField
                visible: melodyOnTop
                implicitWidth: 36
                font.pixelSize: 10
                placeholderText: "auto"
                selectByMouse: true
                ToolTip.visible: hovered
                ToolTip.text: "Override melody note (e.g. E, Bb, F#). Leave blank for auto-detect."
            }

            ComboBox {
                visible: melodyOnTop
                implicitWidth: 80
                font.pixelSize: 10
                model: ["Same staff", "Staff 1", "Staff 2", "Staff 3"]
                currentIndex: melodyStaffIdx + 1  // -1 → 0 (Same staff)
                onCurrentIndexChanged: {
                    melodyStaffIdx = currentIndex - 1  // 0 → -1 (Same staff)
                }
                ToolTip.visible: hovered
                ToolTip.text: "Which staff to read the melody from"
            }
        }

        // Color legend for fretboard dot intervals
        Flow {
            visible: currentTab === 0 && !showToolResults
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: theme.legendColors

                Row {
                    spacing: 2
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: modelData.label
                        font.pixelSize: 9
                    }
                }
            }
        }

        ListView {
            visible: currentTab === 0 && !showToolResults
            id: voicingList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: filteredData.length

            delegate: Rectangle {
                width: voicingList.width
                height: 80
                radius: 4
                color: ma.containsMouse ? theme.chipHover : theme.chipBackground
                border.color: theme.divider
                border.width: 1

                property var v: filteredData[index] || {}

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onDoubleClicked: generateDiagramFile(v)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    // Fretboard thumbnail
                    Canvas {
                        id: fretCanvas
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 66

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            if (!v || !v.dots) return

                            var ns = v.strings || 6
                            var nf = v.visible_frets || 4
                            var mg = 5, tm = 12
                            var ss = (width - 2 * mg) / (ns - 1)
                            var fs = (height - tm - mg) / nf

                            // Dark mode colors from centralized theme
                            var isDark = theme.isDark
                            var gridColor = isDark ? Qt.rgba(0.85, 0.85, 0.85, 0.7) : Qt.rgba(0.4, 0.4, 0.4, 0.6)
                            var textColor = isDark ? Qt.rgba(0.8, 0.8, 0.8, 0.8) : Qt.rgba(0.4, 0.4, 0.4, 0.8)
                            var muteColor = isDark ? Qt.rgba(0.7, 0.7, 0.7, 0.8) : Qt.rgba(0.5, 0.5, 0.5, 0.7)

                            // Strings
                            ctx.strokeStyle = gridColor
                            ctx.lineWidth = 0.5
                            for (var s = 0; s < ns; s++) {
                                ctx.beginPath()
                                ctx.moveTo(mg + s * ss, tm)
                                ctx.lineTo(mg + s * ss, height - mg)
                                ctx.stroke()
                            }

                            // Frets
                            for (var f = 0; f <= nf; f++) {
                                ctx.lineWidth = (f === 0 && (v.fret_number || 1) <= 1) ? 2.5 : 0.5
                                var fy = tm + f * fs
                                ctx.beginPath()
                                ctx.moveTo(mg, fy)
                                ctx.lineTo(width - mg, fy)
                                ctx.stroke()
                            }

                            // Fret number label
                            if ((v.fret_number || 0) > 1) {
                                ctx.fillStyle = textColor
                                ctx.font = "7px sans-serif"
                                ctx.textAlign = "right"
                                ctx.fillText(v.fret_number, mg - 1, tm + fs * 0.6)
                            }

                            // Dots — color-coded by interval (brighter in dark mode)
                            var dots = v.dots || []
                            var ivs = v.intervals || []
                            for (var d = 0; d < dots.length; d++) {
                                var iv = (d < ivs.length) ? ivs[d] : ""
                                // Color by interval family (from theme palette)
                                if (iv === "1")
                                    ctx.fillStyle = theme.dotRoot
                                else if (iv === "3" || iv === "b3")
                                    ctx.fillStyle = theme.dotThird
                                else if (iv === "5" || iv === "b5" || iv === "#5")
                                    ctx.fillStyle = theme.dotFifth
                                else if (iv === "7" || iv === "b7" || iv === "bb7")
                                    ctx.fillStyle = theme.dotSeventh
                                else if (iv === "6" || iv === "13" || iv === "b13")
                                    ctx.fillStyle = theme.dotSixth
                                else if (iv === "9" || iv === "b9" || iv === "#9" || iv === "2")
                                    ctx.fillStyle = theme.dotNinth
                                else if (iv === "4" || iv === "11" || iv === "#11")
                                    ctx.fillStyle = theme.dotFourth
                                else
                                    ctx.fillStyle = theme.dotDefault

                                var dx = mg + (ns - dots[d].string) * ss
                                var dy = tm + (dots[d].fret - 0.5) * fs
                                ctx.beginPath()
                                ctx.arc(dx, dy, 3.5, 0, 2 * Math.PI)
                                ctx.fill()
                            }

                            // Mute markers (×)
                            ctx.fillStyle = muteColor
                            ctx.font = "9px sans-serif"
                            ctx.textAlign = "center"
                            var mutes = v.mutes || []
                            for (var m = 0; m < mutes.length; m++) {
                                ctx.fillText("×", mg + (ns - mutes[m]) * ss, tm - 2)
                            }

                            // Open markers (○)
                            ctx.strokeStyle = muteColor
                            ctx.lineWidth = 1
                            var opens = v.open || []
                            for (var o = 0; o < opens.length; o++) {
                                ctx.beginPath()
                                ctx.arc(mg + (ns - opens[o]) * ss, tm - 5, 3, 0, 2 * Math.PI)
                                ctx.stroke()
                            }
                        }

                        Component.onCompleted: requestPaint()
                    }

                    // Text info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: v.name || ""
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                // Find which interval is on top (highest-pitched sounding string)
                                var topInterval = ""
                                if (v.dots && v.dots.length > 0 && v.intervals) {
                                    var minStr = 99
                                    var topIdx = -1
                                    for (var ti = 0; ti < v.dots.length; ti++) {
                                        if (v.dots[ti].string < minStr) {
                                            minStr = v.dots[ti].string
                                            topIdx = ti
                                        }
                                    }
                                    // Also check open strings (they can be the highest)
                                    var opens = v.open || []
                                    for (var oi = 0; oi < opens.length; oi++) {
                                        if (opens[oi] < minStr) {
                                            minStr = opens[oi]
                                            topIdx = -2 // open string, interval unknown from dots
                                        }
                                    }
                                    if (topIdx >= 0 && topIdx < v.intervals.length) {
                                        var iv = v.intervals[topIdx]
                                        var ivLabels = {"1":"root","3":"3rd","b3":"b3","5":"5th","b5":"b5","#5":"#5",
                                            "7":"7th","b7":"b7","bb7":"bb7","9":"9th","b9":"b9","#9":"#9",
                                            "4":"4th","11":"11th","#11":"#11","6":"6th","13":"13th","b13":"b13"}
                                        topInterval = ivLabels[iv] || iv
                                    }
                                }
                                var info = (v.intervals || []).join(" ") + "  |  Fret " + (v.fret_number || "?")
                                if (topInterval) info += "  |  " + topInterval + " on top"
                                return info
                            }
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        Label {
                            text: computeNotesForTuning(v).join(" ")
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        spacing: 2

                        Button {
                            text: "Open"
                            font.pixelSize: 9
                            implicitWidth: 44
                            onClicked: generateDiagramFile(v)
                        }

                        RowLayout {
                            spacing: 1

                            Button {
                                text: "\u266B"  // beamed eighth notes — chord strum
                                font.pixelSize: 11
                                implicitWidth: 22
                                onClicked: playVoicing(v, "chord")
                            }

                            Button {
                                text: "\u2191"  // up arrow — arpeggio
                                font.pixelSize: 11
                                implicitWidth: 22
                                onClicked: playVoicing(v, "arp")
                            }
                        }
                    }
                }
            }
        }

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
