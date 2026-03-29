import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.3
import Qt.labs.settings 1.0
import MuseScore 3.0
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

    // === Settings (persisted between sessions) ===
    Settings {
        id: persistedSettings
        category: "ChordLibrary"
        property string voicingUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"
        property string diagramPlacement: "above"  // "above" or "below"
        property string lastExportPath: ""
        property string lastImportPath: ""
    }

    property string jsonUrl: persistedSettings.voicingUrl
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
        if (!dataLoaded) {
            fetchVoicings()
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
                        applyFilters()
                        statusMsg.text = "Loaded " + voicingsData.length + " voicings"
                        statusMsg.color = "#060"
                        console.log("Loaded " + voicingsData.length + " voicings from " + jsonUrl)
                    } catch (e) {
                        console.error("Failed to parse voicings JSON: " + e)
                        statusMsg.text = "Failed to parse voicings: " + e
                        statusMsg.color = "#c00"
                    }
                } else if (xhr.status === 0) {
                    // Likely a local file:// URL or network error
                    statusMsg.text = "Could not reach URL. Check your connection or URL."
                    statusMsg.color = "#c00"
                } else {
                    console.error("Failed to fetch voicings: HTTP " + xhr.status)
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
        if (persistedSettings.diagramPlacement === "below") {
            fd.placement = Placement.BELOW
        } else {
            fd.placement = Placement.ABOVE
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
            + " (" + persistedSettings.diagramPlacement + " staff)"
        statusMsg.color = "#060"
    }

    // === Export/Import ===

    function exportVoicings(fileUrl) {
        var path = fileUrl.toString().replace("file://", "")
        var data = JSON.stringify({ voicings: voicingsData }, null, 2)
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", fileUrl)
        xhr.send(data)
        persistedSettings.lastExportPath = fileUrl.toString()
        statusMsg.text = "Exported " + voicingsData.length + " voicings"
        statusMsg.color = "#060"
    }

    function importVoicings(fileUrl) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    var data = JSON.parse(xhr.responseText)
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
                        console.error("Import validation errors: " + errors.join("; "))
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
                    persistedSettings.lastImportPath = fileUrl.toString()
                    statusMsg.text = "Imported " + added + " voicings"
                        + (skipped > 0 ? " (" + skipped + " duplicates skipped)" : "")
                    statusMsg.color = "#060"
                } catch (e) {
                    statusMsg.text = "Import failed: invalid JSON — " + e
                    statusMsg.color = "#c00"
                }
            }
        }
        xhr.open("GET", fileUrl)
        xhr.send()
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
                errors.push("Voicing " + v.id + " has root '" + v.root + "' — all voicings must have root C")
            }
        }
        return errors
    }

    // === File dialogs ===

    FileDialog {
        id: exportDialog
        title: "Export Voicings"
        selectExisting: false
        nameFilters: ["JSON files (*.json)"]
        onAccepted: exportVoicings(fileUrl)
    }

    FileDialog {
        id: importDialog
        title: "Import Voicings"
        selectExisting: true
        nameFilters: ["JSON files (*.json)"]
        onAccepted: importVoicings(fileUrl)
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
        ColumnLayout {
            visible: showSettings
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: settingsContent.implicitHeight + 16
                radius: 4
                color: "#f8f8f0"
                border.color: "#ddd"

                ColumnLayout {
                    id: settingsContent
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    // --- Source URL ---
                    Label {
                        text: "Voicing Source URL"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    TextField {
                        id: urlField
                        Layout.fillWidth: true
                        text: persistedSettings.voicingUrl
                        font.pixelSize: 11
                        placeholderText: "https://..."
                        selectByMouse: true
                    }

                    RowLayout {
                        spacing: 4

                        Button {
                            text: "Apply URL"
                            font.pixelSize: 11
                            onClicked: {
                                persistedSettings.voicingUrl = urlField.text
                                jsonUrl = urlField.text
                                dataLoaded = false
                                fetchVoicings()
                            }
                        }

                        Button {
                            text: "Reset to Default"
                            font.pixelSize: 11
                            onClicked: {
                                var defaultUrl = "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"
                                urlField.text = defaultUrl
                                persistedSettings.voicingUrl = defaultUrl
                                jsonUrl = defaultUrl
                                dataLoaded = false
                                fetchVoicings()
                            }
                        }
                    }

                    // --- Diagram placement ---
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#ddd"
                    }

                    Label {
                        text: "Diagram Placement"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        RadioButton {
                            id: placementAbove
                            text: "Above staff"
                            checked: persistedSettings.diagramPlacement === "above"
                            onCheckedChanged: {
                                if (checked) persistedSettings.diagramPlacement = "above"
                            }
                        }

                        RadioButton {
                            text: "Below staff"
                            checked: persistedSettings.diagramPlacement === "below"
                            onCheckedChanged: {
                                if (checked) persistedSettings.diagramPlacement = "below"
                            }
                        }
                    }

                    Label {
                        text: "Tip: MuseScore can also show all chord diagrams at the top of the first page via Format > Style > Fretboard Diagrams."
                        font.pixelSize: 10
                        color: "#888"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // --- Export / Import ---
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#ddd"
                    }

                    Label {
                        text: "Library Management"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 4

                        Button {
                            text: "Export Voicings"
                            font.pixelSize: 11
                            onClicked: exportDialog.open()
                        }

                        Button {
                            text: "Import Voicings"
                            font.pixelSize: 11
                            onClicked: importDialog.open()
                        }
                    }

                    Label {
                        text: "Export saves the current library to a JSON file. Import merges a JSON file into the current library (duplicates are skipped by ID)."
                        font.pixelSize: 10
                        color: "#888"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // === Main panel (hidden when settings are open) ===
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
}
