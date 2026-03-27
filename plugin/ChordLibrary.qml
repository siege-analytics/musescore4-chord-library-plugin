import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import "ui"
import "model"
import "model/Transposer.js" as Transposer

MuseScore {
    id: chordLibrary
    title: "Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "0.3.0"
    pluginType: "dialog"
    requiresScore: true
    categoryCode: "composing-arranging-tools"

    width: 400
    height: 700

    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"
    property var voicingsData: []
    property var filteredData: []
    property bool dataLoaded: false

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

    function fetchVoicings() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        voicingsData = data.voicings || []
                        dataLoaded = true
                        applyFilters()
                        console.log("Loaded " + voicingsData.length + " voicings")
                    } catch (e) {
                        console.error("Failed to parse voicings JSON: " + e)
                        statusMsg.text = "Failed to load voicings: " + e
                        statusMsg.color = "#c00"
                    }
                } else {
                    console.error("Failed to fetch voicings: HTTP " + xhr.status)
                    statusMsg.text = "Failed to fetch voicings: HTTP " + xhr.status
                    statusMsg.color = "#c00"
                }
            }
        }
        xhr.open("GET", jsonUrl)
        xhr.send()
    }

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

        // Find the segment for the selected element
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

        // Search for chord symbol
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

        // Get the tick of the selected element before starting the command
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

        // Walk cursor from beginning of score to the target tick
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)  // start of score

        while (cursor.segment && cursor.tick < targetTick) {
            cursor.next()
        }

        cursor.add(fd)

        curScore.endCmd()

        statusMsg.text = "Inserted " + voicing.name + " → " + targetRoot
            + " at tick " + targetTick + " (grid only — dots pending #32798)"
        statusMsg.color = "#060"
    }

    // === UI ===

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Label {
            text: "Chord Library"
            font.pixelSize: 16
            font.bold: true
        }

        TextField {
            id: searchField
            placeholderText: "Search voicings..."
            Layout.fillWidth: true
            onTextChanged: {
                searchText = text
                applyFilters()
            }
        }

        RowLayout {
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
            model: ["All Qualities", "maj7", "dom7", "min7", "min7b5", "maj6", "min6", "dim7"]
            Layout.fillWidth: true
            onCurrentTextChanged: {
                filterQuality = currentText === "All Qualities" ? "" : currentText
                applyFilters()
            }
        }

        Label {
            text: filteredData.length + " of " + voicingsData.length + " voicings"
            font.pixelSize: 11
            color: "#666"
        }

        ListView {
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
