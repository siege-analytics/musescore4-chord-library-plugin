import QtQuick 2.15

// TuningManager.qml — Tuning CRUD operations.
// Extracted from ChordLibrary.qml (B3, #102).
//
// Manages: tuning import, create, edit, delete, move, MIDI note parsing.
// Requires FileIO for reading/writing tuning JSON files.

Item {
    id: tuningManager

    // === External dependencies ===
    property var tuningFile: null        // FileIO component from parent
    property var settingsPanel: null     // SettingsPanel for status feedback
    property var state: null             // tuningState QtObject — read/write directly

    // Convenience accessors — read/write through state
    property var tuningList: state ? state.tuningList : []
    property var tuningLabels: state ? state.tuningLabels : ({})
    property var tuningStringCounts: state ? state.tuningStringCounts : ({})
    property string selectedTuning: state ? state.selectedTuning : "standard"

    // === Signals ===
    signal tuningChanged()              // tuning list/selection changed, parent should reload
    signal settingsSaveRequested()      // parent should call saveSettings()

    // === MIDI note utilities ===

    property var midiNoteNames: {
        var names = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        var map = {}
        for (var midi = 21; midi <= 108; midi++) {
            var octave = Math.floor(midi / 12) - 1
            map[midi] = names[midi % 12] + octave
        }
        return map
    }

    property var noteToMidiMap: {
        "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
    }

    function noteNameToMidi(str) {
        str = str.trim()
        var asInt = parseInt(str)
        if (!isNaN(asInt) && str.match(/^\d+$/)) return asInt
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

    // === Tuning list management ===

    function addTuningToList(slug, name, stringCount) {
        var list = tuningList.slice()
        if (list.indexOf(slug) < 0) {
            list.push(slug)
            state.tuningList = list
        }
        var labels = {}
        for (var k in tuningLabels) labels[k] = tuningLabels[k]
        labels[slug] = name
        state.tuningLabels = labels
        if (stringCount) {
            var counts = {}
            for (var c in tuningStringCounts) counts[c] = tuningStringCounts[c]
            counts[slug] = stringCount
            state.tuningStringCounts = counts
        }
    }

    function moveTuning(slug, direction) {
        var list = tuningList.slice()
        var idx = list.indexOf(slug)
        if (idx < 0) return
        var newIdx = idx + direction
        if (newIdx < 0 || newIdx >= list.length) return
        var temp = list[newIdx]
        list[newIdx] = list[idx]
        list[idx] = temp
        tuningList = list
        tuningManager.settingsSaveRequested()
    }

    // === Built-in tunings ===

    property var builtInTunings: [
        "standard", "7string-van-eps", "7string-low-b", "dadgad", "all-fourths",
        "baritone", "ukulele", "ukulele-low-g", "mandolin", "banjo-open-g",
        "bass-4string", "bass-5string"
    ]

    // === CRUD operations ===

    function importTuning(path) {
        if (!path) {
            _setTuningStatus("Enter a file path", "error")
            return
        }
        tuningFile.source = path
        try {
            var raw = tuningFile.read()
            if (!raw || raw.length === 0) {
                _setTuningStatus("File not found or empty", "error")
                return
            }
            var tuning = JSON.parse(raw)
            if (!tuning.name || !tuning.strings) {
                _setTuningStatus("Invalid tuning: needs 'name' and 'strings' fields", "error")
                return
            }
            var slug = tuning.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
            var destPath = Qt.resolvedUrl("../tunings/" + slug + ".json")
            tuningFile.source = destPath
            tuningFile.write(raw)

            addTuningToList(slug, tuning.name, Object.keys(tuning.strings || {}).length || 6)
            state.selectedTuning = slug
            tuningManager.tuningChanged()
            tuningManager.settingsSaveRequested()
            _setTuningStatus("Imported: " + tuning.name, "success")
        } catch (e) {
            _setTuningStatus("Failed: " + e, "error")
        }
    }

    function createTuning(name, pitchStr, numStrings) {
        if (!name) {
            _setTuningStatus("Enter a tuning name", "error")
            return
        }
        var rawParts = pitchStr.split(",")
        var pitches = []
        for (var p = 0; p < rawParts.length; p++) {
            var midi = noteNameToMidi(rawParts[p])
            if (midi < 0) {
                _setTuningStatus("Can't parse: '" + rawParts[p].trim() + "' — use note names (E4, Bb3) or MIDI numbers (64, 59)", "error")
                return
            }
            pitches.push(midi)
        }
        if (pitches.length < numStrings) {
            _setTuningStatus("Need " + numStrings + " pitches, got " + pitches.length, "error")
            return
        }
        pitches = pitches.slice(0, numStrings)
        for (var i = 0; i < pitches.length; i++) {
            if (pitches[i] < 20 || pitches[i] > 100) {
                _setTuningStatus("Pitch out of range: " + pitches[i] + " (expected 20-100)", "error")
                return
            }
        }

        var strings = {}
        var notes = {}
        for (var s = 0; s < pitches.length; s++) {
            var strNum = s + 1
            strings[strNum] = pitches[s]
            notes[strNum] = midiNoteNames[pitches[s]] || ("?" + pitches[s])
        }
        var tuning = { name: name, description: "Custom tuning created in Chord Library", strings: strings, notes: notes }
        var slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
        var destPath = Qt.resolvedUrl("../tunings/" + slug + ".json")
        tuningFile.source = destPath
        try {
            tuningFile.write(JSON.stringify(tuning, null, 2))
            addTuningToList(slug, name, numStrings)
            state.selectedTuning = slug
            tuningManager.tuningChanged()
            tuningManager.settingsSaveRequested()
            var noteStr = Object.keys(notes).map(function(k) { return notes[k] }).join("-")
            _setTuningStatus("Created: " + name + " (" + noteStr + ")", "success")
        } catch (e) {
            _setTuningStatus("Failed to save: " + e, "error")
        }
    }

    function editTuning(slug) {
        if (!slug || !settingsPanel) return
        var paths = [
            Qt.resolvedUrl("../tunings/" + slug + ".json"),
            Qt.resolvedUrl("../../config/tunings/" + slug + ".json")
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
                    var pitchParts = []
                    for (var s = 1; s <= count; s++) {
                        var midi = strings[String(s)]
                        if (midi !== undefined) {
                            pitchParts.push(midiNoteNames[midi] || String(midi))
                        }
                    }
                    settingsPanel.tuningPitchesValue = pitchParts.join(", ")
                    _setTuningStatus("Editing: " + (t.name || slug) + " — change values and click Save", "info")
                    return
                }
            } catch (e) {}
        }
        _setTuningStatus("Could not load tuning: " + slug, "error")
    }

    function deleteTuning(slug) {
        if (!slug) return
        if (builtInTunings.indexOf(slug) >= 0) {
            _setTuningStatus("Cannot delete built-in tuning", "error")
            return
        }
        var list = tuningList.slice()
        var idx = list.indexOf(slug)
        if (idx >= 0) { list.splice(idx, 1); tuningList = list }
        var labels = {}
        for (var k in tuningLabels) { if (k !== slug) labels[k] = tuningLabels[k] }
        state.tuningLabels = labels
        if (state.selectedTuning === slug) {
            state.selectedTuning = "standard"
            tuningManager.tuningChanged()
        }
        tuningManager.settingsSaveRequested()
        var destPath = Qt.resolvedUrl("../tunings/" + slug + ".json")
        tuningFile.source = destPath
        try { tuningFile.write("") } catch (e) {}
        _setTuningStatus("Deleted: " + slug, "success")
    }

    // === Internal helpers ===

    function _setTuningStatus(text, type) {
        if (!settingsPanel) return
        settingsPanel.tuningStatus = text
        if (type === "error") settingsPanel.tuningStatusColor = "#e74c3c"
        else if (type === "success") settingsPanel.tuningStatusColor = "#27ae60"
        else settingsPanel.tuningStatusColor = "#888"
    }
}
