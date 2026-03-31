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
    title: "Siege Analytics Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "1.2.0"
    pluginType: "dialog"
    requiresScore: true
    categoryCode: "composing-arranging-tools"

    width: 460
    height: 750

    // System palette for dark mode detection
    SystemPalette { id: palette }

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

        // Try direct insertion via setDot() API first (instant, no timer delay)
        if (insertDirect(item.voicing, item.root)) {
            lastInsertedVoicing = item.voicing
            // Immediately process next item (no timer delay needed)
            if (batchQueue.length > 0) {
                batchProcessNext()
            } else {
                statusMsg.text = "Batch complete: " + batchTotal + " diagrams inserted"
                statusMsg.color = "#060"
            }
            return
        }

        // Fall back to clipboard workaround
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

    // === Save to Library ===

    function saveVoicingToLibrary() {
        saveStatus.text = ""

        // Parse fret number
        var fretNum = parseInt(saveFretField.text.trim())
        if (isNaN(fretNum) || fretNum < 0 || fretNum > 24) {
            saveStatus.text = "Invalid fret number"; saveStatus.color = "#c00"; return
        }

        // Parse dots: "6:1, 4:1, 3:2" → [{string:6, fret:1}, ...]
        var dotsStr = saveDotsField.text.trim()
        if (!dotsStr) { saveStatus.text = "Enter dot positions"; saveStatus.color = "#c00"; return }
        var dotParts = dotsStr.split(",")
        var dots = []
        for (var d = 0; d < dotParts.length; d++) {
            var pair = dotParts[d].trim().split(":")
            if (pair.length !== 2) { saveStatus.text = "Bad dot format: " + dotParts[d]; saveStatus.color = "#c00"; return }
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
                saveStatus.color = "#c00"
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
        saveStatus.color = "#060"
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
        hygieneResult.color = duplicates > 0 ? "#c00" : "#060"

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
            hygieneResult.color = "#060"
        } else {
            hygieneResult.text = "No duplicates found."
            hygieneResult.color = "#060"
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
            hygieneResult.color = "#c00"
        }
    }

    // Pre-fill Save to Library from a selected FretDiagram in the score
    function captureFromScore() {
        if (!curScore) { saveStatus.text = "No score open"; saveStatus.color = "#c00"; return }

        var sel = curScore.selection
        if (!sel || !sel.elements || sel.elements.length === 0) {
            saveStatus.text = "Select a fretboard diagram first"
            saveStatus.color = "#c00"
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
            saveStatus.color = "#060"
        } else {
            saveStatus.text = "Selected element is not a fretboard diagram.\nSelect a diagram in the score, then click Capture."
            saveStatus.color = "#c00"
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
            // Quartal voicings are quality-ambiguous (stacked 4ths serve multiple
            // harmonic functions). When filtering by category=quartal, show all
            // quartal voicings regardless of the quality filter.
            if (filterQuality && v.chord_quality !== filterQuality
                && v.category !== "quartal") continue

            // Filter by string count — but if the user has explicitly selected
            // a 7-string context (CV7/CM7), show all voicings in that context
            // regardless of the tuning's string count
            var voicingStrings = v.strings || 6
            var contextIs7 = filterContext === "CV7" || filterContext === "CM7"
            if (!contextIs7 && voicingStrings > maxStrings) continue

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
            statusMsg.color = "#060"
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
            statusMsg.color = "#c00"
            return
        }

        // A launchd agent (com.siegeanalytics.chord-library-clipboard) watches
        // paste-clipboard.xml for changes and runs ms-clipboard to write to
        // the macOS pasteboard. No Terminal, no visible windows.
        _pendingVoicing = voicing
        // The Timer then fires cmd("paste") to insert the diagram with dots.
        pasteTimer.start()

        statusMsg.text = "Pasting " + displayName + " [" + transposed.notes.join(" ") + "]..."
        statusMsg.color = "#060"
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
            exportStatus.color = "#060"
            Qt.openUrlExternally(path)
        } catch (e) {
            exportStatus.text = "MusicXML export failed: " + e
            exportStatus.color = "#c00"
        }
    }

    function exportGP5() {
        exportStatus.text = "Generating GP5 (requires Python + PyGuitarPro)..."

        // Write the current voicings to a temp file for the Python script to read
        var basePath = exportPathField.text.trim().replace(/\.[^.]+$/, "")
        if (!basePath) basePath = homePath() + "/Documents/chord-library-export"

        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var scriptPath = pluginDir + "/scripts/export_gp5.py"
        var dataPath = pluginDir + "/voicings-cache.json"
        var outDir = basePath.replace(/\/[^/]+$/, "")  // parent directory

        // Write a .command script that runs the GP5 exporter
        var cmd = '#!/bin/bash\n'
            + 'python3 "' + scriptPath + '" --data "' + dataPath + '" -o "' + outDir + '"\n'
            + 'echo "GP5 files generated in ' + outDir + '"\n'
            + 'echo "Press any key to close..."\n'
            + 'read -n 1\n'
            + 'exit 0\n'

        var cmdPath = Qt.resolvedUrl("export-gp5.command")
        tempDiagramFile.source = cmdPath
        try {
            tempDiagramFile.write(cmd)
            Qt.openUrlExternally(cmdPath)
            exportStatus.text = "GP5 export launched — check Terminal for progress"
            exportStatus.color = "#060"
        } catch (e) {
            exportStatus.text = "GP5 export failed: " + e
            exportStatus.color = "#c00"
        }
    }

    function exportChordSheet() {
        exportStatus.text = "Generating PDF chord sheet..."

        var basePath = exportPathField.text.trim().replace(/\.[^.]+$/, "")
        if (!basePath) basePath = homePath() + "/Documents/chord-library-export"
        var outPath = basePath + "-chord-sheet.pdf"

        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var scriptPath = pluginDir + "/scripts/generate_chord_sheet.py"
        var dataPath = pluginDir + "/voicings-cache.json"

        // Build filter args based on current UI state
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

        var cmd = '#!/bin/bash\n'
            + 'cd "' + pluginDir + '"\n'
            + 'python3 "' + scriptPath + '" --data "' + dataPath + '"'
            + filterArgs
            + ' --title "' + title + '"'
            + ' -o "' + outPath + '"\n'
            + 'echo ""\n'
            + 'echo "Chord sheet saved to ' + outPath + '"\n'
            + 'open "' + outPath + '"\n'
            + 'exit 0\n'

        var cmdPath = Qt.resolvedUrl("export-chord-sheet.command")
        tempDiagramFile.source = cmdPath
        try {
            tempDiagramFile.write(cmd)
            Qt.openUrlExternally(cmdPath)
            exportStatus.text = "Chord sheet export launched — PDF will open when ready"
            exportStatus.color = "#060"
        } catch (e) {
            exportStatus.text = "Chord sheet export failed: " + e
            exportStatus.color = "#c00"
        }
    }

    function exportDiagramsSVG() {
        exportStatus.text = "Exporting SVG diagrams..."

        var basePath = exportPathField.text.trim().replace(/\.[^.]+$/, "")
        if (!basePath) basePath = homePath() + "/Documents/chord-library-export"
        var outDir = basePath + "-diagrams"

        var pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        var scriptPath = pluginDir + "/scripts/fretboard_renderer.py"
        var dataPath = pluginDir + "/voicings-cache.json"

        var filterArgs = ""
        if (selectedQuality && selectedQuality !== "All Qualities")
            filterArgs += ' --quality "' + selectedQuality + '"'
        if (selectedContext && selectedContext !== "All Contexts")
            filterArgs += ' --context "' + selectedContext + '"'
        if (selectedCategory && selectedCategory !== "All Types")
            filterArgs += ' --category "' + selectedCategory + '"'

        var cmd = '#!/bin/bash\n'
            + 'mkdir -p "' + outDir + '"\n'
            + 'python3 "' + scriptPath + '" --data "' + dataPath + '"'
            + filterArgs
            + ' -o "' + outDir + '"\n'
            + 'echo ""\n'
            + 'echo "SVG diagrams saved to ' + outDir + '"\n'
            + 'open "' + outDir + '"\n'
            + 'exit 0\n'

        var cmdPath = Qt.resolvedUrl("export-diagrams.command")
        tempDiagramFile.source = cmdPath
        try {
            tempDiagramFile.write(cmd)
            Qt.openUrlExternally(cmdPath)
            exportStatus.text = "SVG export launched — folder will open when ready"
            exportStatus.color = "#060"
        } catch (e) {
            exportStatus.text = "SVG export failed: " + e
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
                text: "Siege Analytics Chord Library"
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
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

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
                                hygieneResult.color = "#060"
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
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }

                // --- About ---
                Label {
                    text: "ABOUT"
                    font.pixelSize: 11
                    font.bold: true
                    
                    Layout.fillWidth: true
                }

                Label {
                    text: "Siege Analytics Chord Library v1.2.0"
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
