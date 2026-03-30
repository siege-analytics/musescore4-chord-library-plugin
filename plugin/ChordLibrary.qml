import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import FileIO 3.0
import "ui"
import "model"
import "model/Transposer.js" as Transposer

MuseScore {
    id: chordLibrary
    title: "Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "1.1.0"
    pluginType: "dialog"
    requiresScore: true
    categoryCode: "composing-arranging-tools"

    width: 460
    height: 750

    // System palette for dark mode detection
    SystemPalette { id: palette }

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
        "baritone": "Baritone Guitar",
        "ukulele": "Ukulele (Standard)",
        "ukulele-low-g": "Ukulele (Low G)",
        "mandolin": "Mandolin",
        "banjo-open-g": "Banjo (Open G)",
        "bass-4string": "Bass (4-String)",
        "bass-5string": "Bass (5-String)"
    }

    property var voicingsData: []
    property var filteredData: []
    property bool dataLoaded: false
    property bool showSettings: false

    // Filter state
    property string filterContext: ""
    property string filterCategory: ""
    property string filterQuality: ""
    property string searchText: ""

    // Voice leading state
    property var lastInsertedVoicing: null  // tracks fret position for proximity sort
    property bool sortByProximity: false    // when true, sort filtered results by distance

    // Dynamic filter lists (rebuilt when data changes)
    property var contextList: ["All Contexts"]
    property var categoryList: ["All Types"]
    property var qualityList: ["All Qualities"]

    // Context display names — loaded from config/contexts.json, extensible
    property var contextLabels: ({})
    property var contextLabelsShort: ({})

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

        try {
            var raw = contextsConfigFile.read()
            if (raw && raw.length > 2) {
                var config = JSON.parse(raw)
                var ctxs = config.contexts || {}
                for (var code in ctxs) {
                    if (ctxs[code].name) labels[code] = ctxs[code].name
                    if (ctxs[code].short) shorts[code] = ctxs[code].short
                }
                console.log("Loaded context labels from config (" + Object.keys(ctxs).length + " contexts)")
            }
        } catch (e) {
            console.log("Using default context labels: " + e)
        }

        contextLabels = labels
        contextLabelsShort = shorts
    }

    // === Paste infrastructure ===

    property var _pendingVoicing: null  // voicing being pasted (for tracking)

    // Timer to paste after launchd agent writes diagram data to clipboard
    Timer {
        id: pasteTimer
        interval: 1000
        repeat: false
        onTriggered: {
            try {
                cmd("paste")
                statusMsg.text = statusMsg.text.replace("Pasting", "Pasted")
                // Track for voice leading
                if (_pendingVoicing) {
                    lastInsertedVoicing = _pendingVoicing
                    _pendingVoicing = null
                    if (sortByProximity) applyFilters()
                }
            } catch (e) {
                statusMsg.text = "Paste failed: " + e + " — try Cmd+V manually"
                statusMsg.color = "#c00"
            }
            // If batch queue has more items, process next
            if (batchQueue.length > 0) {
                batchProcessNext()
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

    function findBestVoicing(targetRoot, quality) {
        // Find the best matching voicing from the current data
        // Prefer: current filter context > shell > drop2, and E-shape first
        var candidates = []
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            if (v.chord_quality !== quality) continue
            // Filter by string count for current tuning
            if ((v.strings || 6) > tuningMaxStrings) continue
            candidates.push(v)
        }
        if (candidates.length === 0) {
            // Fallback: try dom7 if the specific quality isn't found
            if (quality !== "dom7") return findBestVoicing(targetRoot, "dom7")
            return null
        }

        // Score: context match + category preference + voice leading proximity
        var ref = lastInsertedVoicing
        candidates.sort(function(a, b) {
            var scoreA = 0, scoreB = 0
            if (filterContext && a.context === filterContext) scoreA += 100
            if (filterContext && b.context === filterContext) scoreB += 100
            if (a.category === "shell") scoreA += 10
            else if (a.category === "drop2") scoreA += 5
            if (b.category === "shell") scoreB += 10
            else if (b.category === "drop2") scoreB += 5
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
        // Generate EngravingItem XML for a voicing transposed to targetRoot
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
        var transposedFret = voicing.fret_number + offset
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

    function batchInsert() {
        if (!curScore) {
            statusMsg.text = "No score open"
            statusMsg.color = "#c00"
            return
        }

        // Scan the entire score for chord symbols
        var queue = []
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
                        var parsed = parseChordSymbol(text)
                        if (parsed) {
                            var voicing = findBestVoicing(parsed.root, parsed.quality)
                            if (voicing) {
                                queue.push({
                                    tick: seg.tick,
                                    root: parsed.root,
                                    quality: parsed.quality,
                                    voicing: voicing,
                                    chordText: text,
                                })
                            }
                        }
                    }
                }
            }
            cursor.next()
        }

        if (queue.length === 0) {
            statusMsg.text = "No chord symbols found in the score"
            statusMsg.color = "#c00"
            return
        }

        batchQueue = queue
        batchTotal = queue.length
        statusMsg.text = "Batch: inserting " + batchTotal + " diagrams..."
        statusMsg.color = "#060"

        // Start processing
        batchProcessNext()
    }

    function batchProcessNext() {
        if (batchQueue.length === 0) {
            statusMsg.text = "Batch complete: " + batchTotal + " diagrams inserted"
            statusMsg.color = "#060"
            return
        }

        var item = batchQueue.shift()
        var remaining = batchQueue.length
        statusMsg.text = "Batch: " + (batchTotal - remaining) + " of " + batchTotal
            + " — " + item.chordText
        statusMsg.color = "#060"

        // Move cursor to this chord's position
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)
        while (cursor.segment && cursor.tick < item.tick) {
            cursor.next()
        }
        // Select the element at this position so paste targets it
        if (cursor.segment && cursor.element) {
            curScore.selection.select(cursor.element)
        }

        // Generate and write clipboard XML
        var xml = generateXmlForVoicing(item.voicing, item.root)
        var xmlPath = Qt.resolvedUrl("paste-clipboard.xml")
        tempDiagramFile.source = xmlPath
        try {
            tempDiagramFile.write(xml)
        } catch (e) {
            statusMsg.text = "Batch error: " + e
            statusMsg.color = "#c00"
            batchQueue = []
            return
        }

        // Track for voice leading (batch uses this for next voicing selection too)
        _pendingVoicing = item.voicing
        // The launchd agent writes to clipboard, then pasteTimer fires cmd("paste")
        // pasteTimer.onTriggered checks batchQueue and calls batchProcessNext()
        pasteTimer.start()
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
                    statusMsg.color = "#060"
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
                console.log("Settings loaded: url=" + jsonUrl + ", placement=" + diagramPlacement + ", tuning=" + selectedTuning)
            }
        } catch (e) {
            console.log("No saved settings found, using defaults")
        }
    }

    function saveSettings() {
        var s = {
            voicingUrl: jsonUrl,
            diagramPlacement: diagramPlacement,
            tuning: selectedTuning
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

    function addTuningToList(slug, name) {
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
    }

    function importTuning() {
        var path = tuningImportPath.text.trim()
        if (!path) {
            tuningImportStatus.text = "Enter a file path"
            tuningImportStatus.color = "#c00"
            return
        }
        tuningFile.source = path
        try {
            var raw = tuningFile.read()
            if (!raw || raw.length === 0) {
                tuningImportStatus.text = "File not found or empty"
                tuningImportStatus.color = "#c00"
                return
            }
            var tuning = JSON.parse(raw)
            if (!tuning.name || !tuning.strings) {
                tuningImportStatus.text = "Invalid tuning: needs 'name' and 'strings' fields"
                tuningImportStatus.color = "#c00"
                return
            }

            // Save to plugin directory as custom tuning
            var slug = tuning.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
            var destPath = Qt.resolvedUrl("tunings/" + slug + ".json")
            tuningFile.source = destPath
            tuningFile.write(raw)

            addTuningToList(slug, tuning.name)
            selectedTuning = slug
            saveSettings()

            tuningImportStatus.text = "Imported: " + tuning.name
            tuningImportStatus.color = "#060"
        } catch (e) {
            tuningImportStatus.text = "Failed: " + e
            tuningImportStatus.color = "#c00"
        }
    }

    function createTuning() {
        var name = tuningNameField.text.trim()
        if (!name) {
            tuningImportStatus.text = "Enter a tuning name"
            tuningImportStatus.color = "#c00"
            return
        }

        var pitchStr = tuningPitchesField.text.trim()
        var rawParts = pitchStr.split(",")
        var pitches = []
        for (var p = 0; p < rawParts.length; p++) {
            var midi = noteNameToMidi(rawParts[p])
            if (midi < 0) {
                tuningImportStatus.text = "Can't parse: '" + rawParts[p].trim() + "' — use note names (E4, Bb3) or MIDI numbers (64, 59)"
                tuningImportStatus.color = "#c00"
                return
            }
            pitches.push(midi)
        }
        var numStrings = tuningStringCount.value

        if (pitches.length < numStrings) {
            tuningImportStatus.text = "Need " + numStrings + " pitches, got " + pitches.length
            tuningImportStatus.color = "#c00"
            return
        }
        pitches = pitches.slice(0, numStrings)

        // Validate pitches are reasonable MIDI values
        for (var i = 0; i < pitches.length; i++) {
            if (pitches[i] < 20 || pitches[i] > 100) {
                tuningImportStatus.text = "Pitch out of range: " + pitches[i] + " (expected 20-100)"
                tuningImportStatus.color = "#c00"
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
            addTuningToList(slug, name)
            selectedTuning = slug
            saveSettings()

            // Show the note names as feedback
            var noteStr = Object.keys(notes).map(function(k) { return notes[k] }).join("-")
            tuningImportStatus.text = "Created: " + name + " (" + noteStr + ")"
            tuningImportStatus.color = "#060"
        } catch (e) {
            tuningImportStatus.text = "Failed to save: " + e
            tuningImportStatus.color = "#c00"
        }
    }

    // === Data fetching ===

    function fetchVoicings() {
        statusMsg.text = "Loading voicings..."
        statusMsg.color = "#666"
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
                        statusMsg.color = "#060"
                    } catch (e) {
                        statusMsg.text = "Failed to parse voicings: " + e
                        statusMsg.color = "#c00"
                    }
                } else if (xhr.status === 0) {
                    statusMsg.text = "Could not reach URL. Check connection or URL."
                    statusMsg.color = "#c00"
                } else {
                    statusMsg.text = "Failed to fetch: HTTP " + xhr.status
                    statusMsg.color = "#c00"
                }
            }
        }
        xhr.open("GET", jsonUrl)
        xhr.send()
    }

    // === Filtering ===

    // Current tuning data (updated when tuning changes)
    property int tuningMaxStrings: 7
    property var tuningMidi: {  // string number → MIDI note of open string
        "1": 64, "2": 59, "3": 55, "4": 50, "5": 45, "6": 40, "7": 33
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
                        console.log("Tuning " + selectedTuning + ": " + count + " strings, MIDI loaded")
                        return
                    }
                }
            } catch (e) {}
        }
        // Fallback: standard tuning
        tuningMaxStrings = 7
        tuningMidi = {"1": 64, "2": 59, "3": 55, "4": 50, "5": 45, "6": 40, "7": 33}
    }

    // Calculate "distance" between two voicings (lower = closer hand position)
    function voicingDistance(a, b) {
        if (!a || !b) return 999
        // Primary: fret position distance
        var fretDist = Math.abs((a.fret_number || 0) - (b.fret_number || 0))
        // Secondary: different number of strings sounding (penalize big shape changes)
        var dotDist = Math.abs((a.dots || []).length - (b.dots || []).length)
        return fretDist * 3 + dotDist
    }

    function applyFilters() {
        var maxStrings = tuningMaxStrings

        var result = []
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            if (filterContext && v.context !== filterContext) continue
            if (filterCategory && v.category !== filterCategory) continue
            if (filterQuality && v.chord_quality !== filterQuality) continue

            // Filter by string count
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
            statusMsg.color = "#c00"
            return
        }

        var selection = curScore.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            statusMsg.text = "Select a note or rest first"
            statusMsg.color = "#c00"
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
            statusMsg.color = "#c00"
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
        statusMsg.color = "#060"
    }

    // === Temp .mscx diagram file (workaround for missing setDot API) ===

    property var _selectedVoicing: null

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

        // Generate the clipboard XML using the shared function
        var xml = generateXmlForVoicing(voicing, targetRoot)

        // Write the clipboard XML to a file that ms-clipboard will read
        var xmlPath = Qt.resolvedUrl("paste-clipboard.xml")
        tempDiagramFile.source = xmlPath
        try {
            tempDiagramFile.write(xml)
        } catch (e) {
            statusMsg.text = "Failed to write clipboard XML: " + e
            statusMsg.color = "#c00"
            return
        }

        // A launchd agent (com.siegeanalytics.chord-library-clipboard) watches
        // paste-clipboard.xml for changes and runs ms-clipboard to write to
        // the macOS pasteboard. No Terminal, no visible windows.
        // Track for voice leading
        _pendingVoicing = voicing
        // The Timer then fires cmd("paste") to insert the diagram with dots.
        pasteTimer.start()

        statusMsg.text = "Pasting " + displayName + " [" + transposed.notes.join(" ") + "]..."
        statusMsg.color = "#060"
    }

    // === File browser (dynamic loading to avoid import issues) ===

    property var _fileDialogComponent: null

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
        statusMsg.color = "#888"
    }

    // === Export/Import ===

    function doExport() {
        exportStatus.text = ""
        var path = exportPathField.text.trim()
        if (!path) {
            exportStatus.text = "Enter a file path"
            exportStatus.color = "#c00"
            return
        }
        try {
            var data = JSON.stringify({ voicings: voicingsData }, null, 2)
            exportFile.source = path
            exportFile.write(data)
            exportStatus.text = "Exported " + voicingsData.length + " voicings"
            exportStatus.color = "#060"
        } catch (e) {
            exportStatus.text = "Export failed: " + e
            exportStatus.color = "#c00"
        }
    }

    function doImport() {
        importStatus.text = "Loading..."
        importStatus.color = "#888"

        var path = importPathField.text.trim()
        if (!path) {
            importStatus.text = "Enter a file path"
            importStatus.color = "#c00"
            return
        }
        importFile.source = path
        try {
            var raw = importFile.read()
            if (!raw || raw.length === 0) {
                importStatus.text = "FAILED: file is empty or not found"
                importStatus.color = "#c00"
                return
            }
            var data = JSON.parse(raw)
            var imported = data.voicings || []

            if (!Array.isArray(imported) || imported.length === 0) {
                importStatus.text = "FAILED: no voicings array found in file"
                importStatus.color = "#c00"
                return
            }

            // Validate required fields
            var errors = validateImport(imported)
            if (errors.length > 0) {
                importStatus.text = "FAILED: " + errors[0]
                importStatus.color = "#c00"
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
                importStatus.color = "#060"
            } else {
                importStatus.text = "No new voicings — all " + skipped + " were duplicates"
                importStatus.color = "#888"
            }
        } catch (e) {
            importStatus.text = "FAILED: " + e
            importStatus.color = "#c00"
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

        // Header with settings toggle
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Chord Library"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: showSettings ? "Back" : "Settings"
                font.pixelSize: 11
                onClicked: showSettings = !showSettings
            }
        }

        // === Settings panel ===
        Flickable {
            visible: showSettings
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: settingsColumn
                width: parent.width
                spacing: 12

                // --- Source URL ---
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
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

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
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

                // --- Tuning ---
                Label {
                    text: "TUNING"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: "Active: " + (tuningLabels[selectedTuning] || selectedTuning)
                    font.pixelSize: 11
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

                // --- Quick create ---
                Label {
                    text: "Or create a tuning:"
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
                    text: "Create Tuning"
                    font.pixelSize: 10
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
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

                // --- Export ---
                Label {
                    text: "EXPORT VOICINGS"
                    font.pixelSize: 11
                    font.bold: true
                    
                    Layout.fillWidth: true
                }

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

                Button {
                    text: "Export"
                    onClicked: doExport()
                }

                Label {
                    id: exportStatus
                    visible: text.length > 0
                    font.pixelSize: 11
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

                // --- Import ---
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

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

                // --- About ---
                Label {
                    text: "ABOUT"
                    font.pixelSize: 11
                    font.bold: true
                    
                    Layout.fillWidth: true
                }

                Label {
                    text: "Chord Library v1.1.0"
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

        // === Main panel (hidden when settings open) ===
        TextField {
            visible: !showSettings
            id: searchField
            placeholderText: "Search voicings..."
            Layout.fillWidth: true
            onTextChanged: {
                searchText = text
                applyFilters()
            }
        }

        RowLayout {
            visible: !showSettings
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
            visible: !showSettings
            id: qualityCombo
            model: qualityList
            Layout.fillWidth: true
            onCurrentTextChanged: {
                filterQuality = currentText === "All Qualities" ? "" : currentText
                applyFilters()
            }
        }

        RowLayout {
            visible: !showSettings
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: tuningMainCombo
                model: tuningList
                Layout.fillWidth: true
                displayText: tuningLabels[currentText] || currentText
                currentIndex: Math.max(0, tuningList.indexOf(selectedTuning))
                onCurrentIndexChanged: {
                    var newTuning = tuningList[currentIndex]
                    if (newTuning && newTuning !== selectedTuning) {
                        selectedTuning = newTuning
                        loadTuningStringCount()
                        saveSettings()
                        applyFilters()
                    }
                }
            }

            Label {
                text: filteredData.length + " of " + voicingsData.length
                font.pixelSize: 11
            }

            Button {
                text: batchQueue.length > 0 ? "Stop" : "Batch"
                font.pixelSize: 10
                implicitWidth: 48
                onClicked: {
                    if (batchQueue.length > 0) {
                        batchQueue = []
                        statusMsg.text = "Batch stopped"
                        statusMsg.color = "#888"
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
                    statusMsg.color = "#888"
                }
            }
        }

        // Color legend for fretboard dot intervals
        Flow {
            visible: !showSettings
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {label: "R", color: "#D32F2F"},
                    {label: "3", color: "#1976D2"},
                    {label: "5", color: "#388E3C"},
                    {label: "7", color: "#F57C00"},
                    {label: "9", color: "#7B1FA2"},
                    {label: "4/11", color: "#00897B"},
                    {label: "6/13", color: "#FBC02D"}
                ]

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
            visible: !showSettings
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
                color: ma.containsMouse ? Qt.rgba(0.5, 0.5, 0.5, 0.2) : Qt.rgba(0.5, 0.5, 0.5, 0.1)
                border.color: Qt.rgba(0.5, 0.5, 0.5, 0.3)
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

                            // Detect dark mode from system palette
                            var bgColor = palette.window.color || Qt.rgba(1,1,1,1)
                            var isDark = (bgColor.r + bgColor.g + bgColor.b) / 3 < 0.5
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
                                // Color by interval family
                                if (iv === "1")
                                    ctx.fillStyle = isDark ? "#EF5350" : "#D32F2F"       // root — red
                                else if (iv === "3" || iv === "b3")
                                    ctx.fillStyle = isDark ? "#42A5F5" : "#1976D2"       // 3rd — blue
                                else if (iv === "5" || iv === "b5" || iv === "#5")
                                    ctx.fillStyle = isDark ? "#66BB6A" : "#388E3C"       // 5th — green
                                else if (iv === "7" || iv === "b7" || iv === "bb7")
                                    ctx.fillStyle = isDark ? "#FFA726" : "#F57C00"       // 7th — orange
                                else if (iv === "6" || iv === "13" || iv === "b13")
                                    ctx.fillStyle = isDark ? "#FFEE58" : "#FBC02D"       // 6th/13th — gold
                                else if (iv === "9" || iv === "b9" || iv === "#9" || iv === "2")
                                    ctx.fillStyle = isDark ? "#CE93D8" : "#7B1FA2"       // 9th — purple
                                else if (iv === "4" || iv === "11" || iv === "#11")
                                    ctx.fillStyle = isDark ? "#4DB6AC" : "#00897B"       // 4th/11th — teal
                                else
                                    ctx.fillStyle = isDark ? Qt.rgba(0.7, 0.7, 0.7, 0.9) : Qt.rgba(0.3, 0.3, 0.3, 0.9)

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
                            text: (v.intervals || []).join(" ") + "  |  " + (v.context || "") + "  |  Fret " + (v.fret_number || "?")
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

                    Button {
                        text: "Open"
                        font.pixelSize: 10
                        implicitWidth: 48
                        onClicked: generateDiagramFile(v)
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
