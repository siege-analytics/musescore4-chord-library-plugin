import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import MuseScore 3.0
import FileIO 3.0
import "ui"
import "model"
import "model/Transposer.js" as Transposer

MuseScore {
    id: chordLibrary
    title: "Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "0.3.1"
    pluginType: "dialog"
    requiresScore: true
    categoryCode: "composing-arranging-tools"

    width: 420
    height: 750

    // === Persistent settings via FileIO ===
    // MuseScore 4 plugins don't support Qt.labs.settings,
    // so we persist to a JSON file in the plugin directory.
    FileIO {
        id: settingsFile
        source: Qt.resolvedUrl("settings.json")
    }

    FileIO {
        id: exportFile
    }

    FileIO {
        id: importFile
    }

    // Default settings
    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"
    property string diagramPlacement: "above"  // "above" or "below"

    property var voicingsData: []
    property var filteredData: []
    property bool dataLoaded: false
    property bool showSettings: false

    // Filter state
    property string filterContext: ""
    property string filterCategory: ""
    property string filterQuality: ""
    property string searchText: ""

    onRun: {
        loadSettings()
        if (!dataLoaded) {
            fetchVoicings()
        }
    }

    // === Settings persistence ===

    function loadSettings() {
        try {
            var raw = settingsFile.read()
            if (raw && raw.length > 0) {
                var s = JSON.parse(raw)
                if (s.voicingUrl) jsonUrl = s.voicingUrl
                if (s.diagramPlacement) diagramPlacement = s.diagramPlacement
                console.log("Settings loaded: url=" + jsonUrl + ", placement=" + diagramPlacement)
            }
        } catch (e) {
            console.log("No saved settings found, using defaults")
        }
    }

    function saveSettings() {
        var s = {
            voicingUrl: jsonUrl,
            diagramPlacement: diagramPlacement
        }
        settingsFile.write(JSON.stringify(s, null, 2))
        console.log("Settings saved")
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
                        applyFilters()
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

    function applyFilters() {
        var result = []
        for (var i = 0; i < voicingsData.length; i++) {
            var v = voicingsData[i]
            if (filterContext && v.context !== filterContext) continue
            if (filterCategory && v.category !== filterCategory) continue
            if (filterQuality && v.chord_quality !== filterQuality) continue
            if (searchText) {
                var q = searchText.toLowerCase()
                var match = v.name.toLowerCase().indexOf(q) >= 0
                    || v.chord_quality.toLowerCase().indexOf(q) >= 0
                    || (v.tags && v.tags.join(" ").toLowerCase().indexOf(q) >= 0)
                if (!match) continue
            }
            result.push(v)
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

        statusMsg.text = "Inserted " + voicing.name + " → " + targetRoot
            + " (" + diagramPlacement + " staff)"
        statusMsg.color = "#060"
    }

    // === File dialogs (Qt6 style) ===

    FileDialog {
        id: exportFileDialog
        title: "Export Voicings"
        fileMode: FileDialog.SaveFile
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            exportPathField.text = path
            doExport()
        }
    }

    FileDialog {
        id: importFileDialog
        title: "Import Voicings"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            importPathField.text = path
            doImport()
        }
    }

    // === Export/Import ===

    function doExport() {
        var path = exportPathField.text.trim()
        if (!path) {
            statusMsg.text = "Enter an export file path"
            statusMsg.color = "#c00"
            return
        }
        var data = JSON.stringify({ voicings: voicingsData }, null, 2)
        exportFile.source = path
        exportFile.write(data)
        statusMsg.text = "Exported " + voicingsData.length + " voicings to " + path
        statusMsg.color = "#060"
    }

    function doImport() {
        var path = importPathField.text.trim()
        if (!path) {
            statusMsg.text = "Enter an import file path"
            statusMsg.color = "#c00"
            return
        }
        importFile.source = path
        try {
            var raw = importFile.read()
            if (!raw || raw.length === 0) {
                statusMsg.text = "Import failed: file is empty or not found"
                statusMsg.color = "#c00"
                return
            }
            var data = JSON.parse(raw)
            var imported = data.voicings || []

            if (!Array.isArray(imported) || imported.length === 0) {
                statusMsg.text = "Import failed: no voicings found in file"
                statusMsg.color = "#c00"
                return
            }

            // Validate required fields
            var errors = validateImport(imported)
            if (errors.length > 0) {
                statusMsg.text = "Import failed: " + errors[0]
                statusMsg.color = "#c00"
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
            applyFilters()
            statusMsg.text = "Imported " + added + " voicings"
                + (skipped > 0 ? " (" + skipped + " duplicates skipped)" : "")
            statusMsg.color = "#060"
        } catch (e) {
            statusMsg.text = "Import failed: " + e
            statusMsg.color = "#c00"
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
                    color: "#333"
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
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

                // --- Diagram placement ---
                Label {
                    text: "DIAGRAM PLACEMENT"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#333"
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
                    color: "#666"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

                // --- Export ---
                Label {
                    text: "EXPORT VOICINGS"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#333"
                    Layout.fillWidth: true
                }

                Label {
                    text: "Save current library to a file:"
                    font.pixelSize: 11
                    color: "#555"
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
                        onClicked: exportFileDialog.open()
                    }
                }

                Button {
                    text: "Export"
                    onClicked: doExport()
                }

                // --- Divider ---
                Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

                // --- Import ---
                Label {
                    text: "IMPORT VOICINGS"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#333"
                    Layout.fillWidth: true
                }

                Label {
                    text: "Merge voicings from a JSON file (duplicates skipped):"
                    font.pixelSize: 11
                    color: "#555"
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
                        onClicked: importFileDialog.open()
                    }
                }

                Button {
                    text: "Import & Merge"
                    onClicked: doImport()
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
                model: ["All Contexts", "CM6", "CM7", "CV6", "CV7"]
                Layout.fillWidth: true
                onCurrentTextChanged: {
                    filterContext = currentText === "All Contexts" ? "" : currentText
                    applyFilters()
                }
            }
            ComboBox {
                model: ["All Types", "shell", "drop2", "drop3", "extended", "altered", "quartal"]
                Layout.fillWidth: true
                onCurrentTextChanged: {
                    filterCategory = currentText === "All Types" ? "" : currentText
                    applyFilters()
                }
            }
        }

        ComboBox {
            visible: !showSettings
            model: ["All Qualities", "maj7", "dom7", "min7", "min7b5", "maj6", "min6", "dim7",
                    "dom7b9", "dom7sharp5", "dom7alt", "dom9", "sus4"]
            Layout.fillWidth: true
            onCurrentTextChanged: {
                filterQuality = currentText === "All Qualities" ? "" : currentText
                applyFilters()
            }
        }

        Label {
            visible: !showSettings
            text: filteredData.length + " of " + voicingsData.length + " voicings"
            font.pixelSize: 11
            color: "#666"
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
                height: 68
                radius: 4
                color: ma.containsMouse ? "#d0d0d0" : "#f0f0f0"
                border.color: "#bbb"
                border.width: 1

                property var v: filteredData[index] || {}

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onDoubleClicked: insertVoicing(v)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Label {
                        text: v.name || ""
                        font.pixelSize: 13
                        font.bold: true
                        color: "#111"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: (v.intervals || []).join(" ") + "  |  " + (v.context || "") + "  |  Fret " + (v.fret_number || "?")
                        font.pixelSize: 11
                        color: "#444"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: (v.tags || []).join(", ")
                        font.pixelSize: 10
                        color: "#777"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Label {
            id: statusMsg
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 10
            color: "#666"
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
