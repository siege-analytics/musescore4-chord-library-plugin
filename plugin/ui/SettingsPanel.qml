import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// SettingsPanel.qml — Settings tab UI (Tab 5) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A5, #98).
//
// Input state groups: tuning, theme
// Input properties: diagramPlacement, builtInTunings, lastAuditResults,
//                   hygieneIgnoreList, homePath
// Signals: placementChanged(placement), editTuningRequested(slug),
//          deleteTuningRequested(slug), moveTuningRequested(slug, direction),
//          importTuningRequested(path), createTuningRequested(name, pitches, numStrings),
//          captureRequested, saveVoicingRequested(quality, category, context, fret, strings, dots, mutes),
//          auditRequested(reportPath), dismissRequested(key), fixDuplicatesRequested,
//          clearDismissalsRequested, browseAuditRequested(targetField)

Flickable {
    id: settingsPanel

    // --- Input properties (state groups) ---
    property var tuning     // { selectedTuning, tuningLabels, tuningList }
    property var theme      // colors

    // --- Input properties (scalar) ---
    property string diagramPlacement: "above"
    property var builtInTunings: []
    property var lastAuditResults: []
    property var hygieneIgnoreList: []
    property string homePath: "~"

    // --- Status feedback from parent ---
    property string tuningStatus: ""
    property color tuningStatusColor: "black"
    property string saveStatus: ""
    property color saveStatusColor: "black"
    property string hygieneStatus: ""
    property color hygieneStatusColor: "black"

    // --- Editable fields (parent can set via editTuning/captureFromScore) ---
    property string tuningNameValue: ""
    property string tuningPitchesValue: "E4, B3, G3, D3, A2, E2"
    property int tuningStringCountValue: 6
    property string saveFretValue: ""
    property int saveStringsCountValue: 6

    // --- Output signals ---
    signal placementChanged(string placement)
    signal editTuningRequested(string slug)
    signal deleteTuningRequested(string slug)
    signal moveTuningRequested(string slug, int direction)
    signal importTuningRequested(string path)
    signal createTuningRequested(string name, string pitches, int numStrings)
    signal captureRequested()
    signal saveVoicingRequested(string quality, string category, string context, string fret, int strings, string dots, string mutes)
    signal auditRequested(string reportPath)
    signal dismissRequested(string key)
    signal fixDuplicatesRequested()
    signal clearDismissalsRequested()
    signal browseAuditRequested(var targetField)

    // --- Flickable setup ---
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
            currentIndex: settingsPanel.diagramPlacement === "below" ? 1 : 0
            onCurrentIndexChanged: {
                var p = currentIndex === 1 ? "below" : "above"
                settingsPanel.placementChanged(p)
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
                text: "Active: " + (tuning.tuningLabels[tuning.selectedTuning] || tuning.selectedTuning)
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            Button {
                text: "Edit"
                font.pixelSize: 10
                ToolTip.visible: hovered
                ToolTip.text: "Load this tuning into the form below for editing"
                onClicked: settingsPanel.editTuningRequested(tuning.selectedTuning)
            }

            Button {
                text: "Delete"
                font.pixelSize: 10
                enabled: settingsPanel.builtInTunings.indexOf(tuning.selectedTuning) < 0
                ToolTip.visible: hovered
                ToolTip.text: settingsPanel.builtInTunings.indexOf(tuning.selectedTuning) >= 0
                    ? "Built-in tunings cannot be deleted"
                    : "Delete this custom tuning"
                onClicked: settingsPanel.deleteTuningRequested(tuning.selectedTuning)
            }

            Button {
                text: "▲"
                font.pixelSize: 10
                implicitWidth: 28
                enabled: tuning.tuningList.indexOf(tuning.selectedTuning) > 0
                ToolTip.visible: hovered
                ToolTip.text: "Move this tuning up in the list"
                onClicked: settingsPanel.moveTuningRequested(tuning.selectedTuning, -1)
            }

            Button {
                text: "▼"
                font.pixelSize: 10
                implicitWidth: 28
                enabled: tuning.tuningList.indexOf(tuning.selectedTuning) < tuning.tuningList.length - 1
                ToolTip.visible: hovered
                ToolTip.text: "Move this tuning down in the list"
                onClicked: settingsPanel.moveTuningRequested(tuning.selectedTuning, 1)
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
                onClicked: settingsPanel.importTuningRequested(tuningImportPath.text.trim())
            }
        }

        Label {
            visible: settingsPanel.tuningStatus.length > 0
            text: settingsPanel.tuningStatus
            color: settingsPanel.tuningStatusColor
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
                text: settingsPanel.tuningNameValue
                onTextChanged: settingsPanel.tuningNameValue = text
            }

            SpinBox {
                id: tuningStringCount
                from: 4
                to: 12
                value: settingsPanel.tuningStringCountValue
                implicitWidth: 80
                onValueChanged: settingsPanel.tuningStringCountValue = value
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
            text: settingsPanel.tuningPitchesValue
            onTextChanged: settingsPanel.tuningPitchesValue = text
        }

        Button {
            text: "Save Tuning"
            font.pixelSize: 10
            ToolTip.visible: hovered
            ToolTip.text: "Create a new tuning or save changes to an existing one"
            onClicked: settingsPanel.createTuningRequested(tuningNameField.text.trim(), tuningPitchesField.text.trim(), tuningStringCount.value)
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
            onClicked: settingsPanel.captureRequested()
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
                text: settingsPanel.saveFretValue
                onTextChanged: settingsPanel.saveFretValue = text
            }

            SpinBox {
                id: saveStringsCount
                from: 4; to: 12
                value: settingsPanel.saveStringsCountValue
                implicitWidth: 75
                onValueChanged: settingsPanel.saveStringsCountValue = value
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
            onClicked: settingsPanel.saveVoicingRequested(
                saveQualityCombo.currentText, saveCategoryCombo.currentText,
                saveContextCombo.currentText, saveFretField.text.trim(),
                saveStringsCount.value, saveDotsField.text.trim(), saveMutesField.text.trim())
        }

        Label {
            visible: settingsPanel.saveStatus.length > 0
            text: settingsPanel.saveStatus
            color: settingsPanel.saveStatusColor
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
                text: settingsPanel.homePath + "/Documents/chord-library-audit.txt"
                selectByMouse: true
            }

            Button {
                text: "Browse"
                font.pixelSize: 10
                onClicked: settingsPanel.browseAuditRequested(auditReportPath)
            }
        }

        Button {
            text: "Run Audit"
            font.pixelSize: 10
            onClicked: settingsPanel.auditRequested(auditReportPath.text)
        }

        Label {
            visible: settingsPanel.hygieneStatus.length > 0
            text: settingsPanel.hygieneStatus
            color: settingsPanel.hygieneStatusColor
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Dismiss / Fix actions ---
        Label {
            visible: settingsPanel.lastAuditResults.length > 0
            text: "Paste a DISMISS KEY from the report to suppress it:"
            font.pixelSize: 9
        }

        RowLayout {
            visible: settingsPanel.lastAuditResults.length > 0
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
                        settingsPanel.dismissRequested(key)
                        dismissKeyField.text = ""
                    }
                }
            }
        }

        RowLayout {
            visible: settingsPanel.lastAuditResults.length > 0 || settingsPanel.hygieneIgnoreList.length > 0
            Layout.fillWidth: true
            spacing: 4

            Button {
                text: "Fix Duplicates"
                font.pixelSize: 10
                visible: settingsPanel.lastAuditResults.some(function(r) { return r.indexOf("DUP:") === 0 })
                onClicked: settingsPanel.fixDuplicatesRequested()
            }

            Button {
                text: "Reset All Dismissed"
                font.pixelSize: 10
                visible: settingsPanel.hygieneIgnoreList.length > 0
                onClicked: settingsPanel.clearDismissalsRequested()
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
