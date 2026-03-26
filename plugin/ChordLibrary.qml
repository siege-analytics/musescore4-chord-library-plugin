import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0

MuseScore {
    id: chordLibrary
    title: "Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "0.1.0"
    pluginType: "dock"
    dockArea: "right"

    width: 340
    height: 600

    property var voicings: []
    property var filteredVoicings: []
    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"

    // Filter state
    property string filterContext: ""
    property string filterCategory: ""
    property string filterQuality: ""
    property string searchText: ""

    Component.onCompleted: {
        fetchVoicings()
    }

    function fetchVoicings() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        voicings = data.voicings || []
                        applyFilters()
                        console.log("Loaded " + voicings.length + " voicings")
                    } catch (e) {
                        console.error("Failed to parse voicings JSON: " + e)
                    }
                } else {
                    console.error("Failed to fetch voicings: HTTP " + xhr.status)
                    loadLocalFallback()
                }
            }
        }
        xhr.open("GET", jsonUrl)
        xhr.send()
    }

    function loadLocalFallback() {
        // TODO: load from local cache if network fetch fails
        console.log("Local fallback not yet implemented")
    }

    function applyFilters() {
        var result = []
        for (var i = 0; i < voicings.length; i++) {
            var v = voicings[i]
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
        filteredVoicings = result
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header
        Label {
            text: "Chord Library"
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }

        // Search bar
        TextField {
            id: searchField
            placeholderText: "Search voicings..."
            Layout.fillWidth: true
            onTextChanged: {
                searchText = text
                applyFilters()
            }
        }

        // Filter row
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: contextFilter
                model: ["All Contexts", "CM6", "CM7", "CV6", "CV7"]
                Layout.fillWidth: true
                onCurrentTextChanged: {
                    filterContext = currentText === "All Contexts" ? "" : currentText
                    applyFilters()
                }
            }

            ComboBox {
                id: categoryFilter
                model: ["All Types", "shell", "drop2", "drop3", "extended", "altered", "quartal"]
                Layout.fillWidth: true
                onCurrentTextChanged: {
                    filterCategory = currentText === "All Types" ? "" : currentText
                    applyFilters()
                }
            }
        }

        // Quality filter
        ComboBox {
            id: qualityFilter
            model: ["All Qualities", "maj7", "dom7", "min7", "min7b5", "maj6", "min6", "dim7"]
            Layout.fillWidth: true
            onCurrentTextChanged: {
                filterQuality = currentText === "All Qualities" ? "" : currentText
                applyFilters()
            }
        }

        // Status line
        Label {
            text: filteredVoicings.length + " of " + voicings.length + " voicings"
            font.pixelSize: 11
            color: "#666"
        }

        // Voicing list
        ListView {
            id: voicingList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4

            model: filteredVoicings.length

            delegate: Rectangle {
                width: voicingList.width
                height: 64
                radius: 4
                color: mouseArea.containsMouse ? "#e8e8e8" : "#f5f5f5"
                border.color: "#ddd"
                border.width: 1

                property var voicing: filteredVoicings[index] || {}

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onDoubleClicked: {
                        insertVoicing(voicing)
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Label {
                        text: voicing.name || ""
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Label {
                        text: (voicing.intervals || []).join(" ") + "  |  " + (voicing.context || "")
                        font.pixelSize: 11
                        color: "#666"
                        Layout.fillWidth: true
                    }

                    Label {
                        text: (voicing.tags || []).join(", ")
                        font.pixelSize: 10
                        color: "#999"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    function insertVoicing(voicing) {
        // Phase 4: read chord symbol from selected note, calculate transposition, insert diagram
        console.log("Insert voicing: " + voicing.name + " (not yet implemented)")

        // TODO: Phase 4 implementation
        // 1. Get the currently selected note/chord symbol
        // 2. Determine target root from chord symbol
        // 3. Calculate semitone offset from C
        // 4. Adjust fret_number by offset
        // 5. Insert fretboard diagram with adjusted positions
    }
}
