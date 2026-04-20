import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ImportPanel.qml — Import tab UI (Tab 3) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A2, #95).
//
// Input state groups: library, tuning, theme
// Input properties: jsonUrl, hasBatchChords
// Signals: rebuildRequested, resetRequested, urlApplyRequested(url),
//          urlResetRequested, refreshRequested, importMergeRequested(path),
//          browseImportRequested(targetField), importIRealRequested(text),
//          presetSaveRequested(path), presetLoadRequested(path)

Flickable {
    id: importPanel

    // --- Input properties (state groups from parent) ---
    property var library    // { voicingsData, dataLoaded }
    property var tuning     // { selectedTuning, tuningLabels }
    property var theme      // colors

    // --- Input properties (scalar) ---
    property string jsonUrl: ""
    property bool hasBatchChords: false

    // --- Status feedback from parent (set after signal handling) ---
    property string rebuildStatus: ""
    property color rebuildStatusColor: "black"
    property string importMergeStatus: ""
    property color importMergeStatusColor: "black"

    // --- Output signals ---
    signal rebuildRequested()
    signal resetRequested()
    signal urlApplyRequested(string url)
    signal urlResetRequested()
    signal refreshRequested()
    signal importMergeRequested(string path)
    signal browseImportRequested(var targetField)
    signal importIRealRequested(string text)
    signal presetSaveRequested(string path)
    signal presetLoadRequested(string path)
    signal loadIRealFileRequested(string path)

    // --- Tuning import/create properties (moved from Settings, #144) ---
    property string tuningNameValue: ""
    property string tuningPitchesValue: "E4, B3, G3, D3, A2, E2"
    property int tuningStringCountValue: 6
    property string tuningStatus: ""
    property color tuningStatusColor: "black"

    // --- Tuning import/create signals (moved from Settings, #144) ---
    signal importTuningRequested(string path)
    signal createTuningRequested(string name, string pitches, int numStrings)

    // --- Internal state ---
    property bool _rebuildInProgress: false
    property string _presetStatus: ""
    property color _presetStatusColor: "black"

    // --- Confirmation state ---
    property bool _showMergeConfirm: false
    property string _mergeConfirmPath: ""
    property bool _showIRealConfirm: false
    property string _irealConfirmText: ""
    property bool _showTuningImportConfirm: false
    property string _tuningImportConfirmPath: ""

    // --- Flickable setup ---
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

        // --- Initialize / Rebuild Voicings ---
        Label {
            text: "VOICING DATA"
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
        }

        Label {
            text: "Current tuning: " + (tuning.tuningLabels[tuning.selectedTuning] || tuning.selectedTuning) + " (" + library.voicingsData.length + " voicings loaded)"
            font.pixelSize: 11
            Layout.fillWidth: true
        }

        Label {
            text: "If voicings aren't showing or you changed your tuning, click Rebuild to regenerate them."
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: theme.textSecondary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Button {
                id: initButton
                text: "Rebuild Voicings"
                enabled: !importPanel._rebuildInProgress
                onClicked: {
                    importPanel._rebuildInProgress = true
                    importPanel.rebuildStatus = "Calculating voicings for " + (tuning.tuningLabels[tuning.selectedTuning] || tuning.selectedTuning) + "..."
                    importPanel.rebuildStatusColor = theme.textSecondary
                    initTimer.running = true
                }
            }

            Button {
                text: "Reset All Data"
                onClicked: importPanel.resetRequested()
            }
        }

        Timer {
            id: initTimer
            interval: 50
            repeat: false
            onTriggered: importPanel.rebuildRequested()
        }

        Label {
            id: initStatusLabel
            visible: importPanel.rebuildStatus.length > 0
            text: importPanel.rebuildStatus
            color: importPanel.rebuildStatusColor
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Divider ---
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

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
            text: importPanel.jsonUrl
            font.pixelSize: 11
            selectByMouse: true
        }

        RowLayout {
            spacing: 6

            Button {
                text: "Apply URL"
                onClicked: importPanel.urlApplyRequested(urlField.text)
            }

            Button {
                text: "Reset Default"
                onClicked: {
                    var defaultUrl = "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/plugin/data/voicings.json"
                    urlField.text = defaultUrl
                    importPanel.urlResetRequested()
                }
            }

            Button {
                text: "Refresh"
                onClicked: importPanel.refreshRequested()
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
                onClicked: importPanel.browseImportRequested(importPathField)
            }
        }

        Button {
            text: "Import && Merge"
            onClicked: {
                var path = importPathField.text.trim()
                if (!path) {
                    importPanel.importMergeStatus = "Enter a file path"
                    importPanel.importMergeStatusColor = "#e74c3c"
                    return
                }
                importPanel._mergeConfirmPath = path
                importPanel._showMergeConfirm = true
            }
        }

        // --- Merge confirmation ---
        Rectangle {
            visible: importPanel._showMergeConfirm
            Layout.fillWidth: true
            height: mergeConfirmCol.implicitHeight + 12
            radius: 6
            color: Qt.rgba(0.2, 0.5, 1, 0.08)
            border.color: "#2980b9"
            border.width: 1

            ColumnLayout {
                id: mergeConfirmCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Label {
                    text: "Merge voicings from \"" + importPanel._mergeConfirmPath.split("/").pop() + "\" into your library?"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#2980b9"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6
                    Button {
                        text: "Yes, import"
                        font.pixelSize: 10
                        onClicked: {
                            importPanel.importMergeRequested(importPanel._mergeConfirmPath)
                            importPanel._showMergeConfirm = false
                            importPanel._mergeConfirmPath = ""
                        }
                    }
                    Button {
                        text: "Cancel"
                        font.pixelSize: 10
                        onClicked: {
                            importPanel._showMergeConfirm = false
                            importPanel._mergeConfirmPath = ""
                        }
                    }
                }
            }
        }

        Label {
            id: importMergeStatusLabel
            visible: importPanel.importMergeStatus.length > 0
            text: importPanel.importMergeStatus
            color: importPanel.importMergeStatusColor
            font.pixelSize: 11
            font.bold: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Divider ---
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // --- iReal Pro / Text Import ---
        Label {
            text: "IMPORT CHORD CHART"
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
        }

        Label {
            text: "Paste an iReal Pro URL, type chords, or import from file:"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            TextField {
                id: irealFilePath
                Layout.fillWidth: true
                font.pixelSize: 11
                placeholderText: "/path/to/ireal-export.html"
                selectByMouse: true
            }

            Button {
                text: "Browse"
                font.pixelSize: 10
                onClicked: importPanel.browseImportRequested(irealFilePath)
            }

            Button {
                text: "Load File"
                font.pixelSize: 10
                onClicked: importPanel.loadIRealFileRequested(irealFilePath.text.trim())
            }
        }

        TextArea {
            id: irealInput
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            font.pixelSize: 11
            placeholderText: "irealb://SongTitle=Composer=... or Dm7 G7 Cmaj7 ..."
            wrapMode: TextEdit.Wrap
            selectByMouse: true
        }

        Button {
            text: "Import && Voice"
            onClicked: {
                var text = irealInput.text.trim()
                if (!text) return
                importPanel._irealConfirmText = text
                importPanel._showIRealConfirm = true
            }
        }

        // --- iReal import confirmation ---
        Rectangle {
            visible: importPanel._showIRealConfirm
            Layout.fillWidth: true
            height: irealConfirmCol.implicitHeight + 12
            radius: 6
            color: Qt.rgba(0.2, 0.5, 1, 0.08)
            border.color: "#2980b9"
            border.width: 1

            ColumnLayout {
                id: irealConfirmCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Label {
                    text: importPanel._irealConfirmText.indexOf("irealb") >= 0
                        ? "Import chords from iReal Pro URL and start walkthrough?"
                        : "Import chord chart and start walkthrough?"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#2980b9"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6
                    Button {
                        text: "Yes, import"
                        font.pixelSize: 10
                        onClicked: {
                            importPanel.importIRealRequested(importPanel._irealConfirmText)
                            importPanel._showIRealConfirm = false
                            importPanel._irealConfirmText = ""
                        }
                    }
                    Button {
                        text: "Cancel"
                        font.pixelSize: 10
                        onClicked: {
                            importPanel._showIRealConfirm = false
                            importPanel._irealConfirmText = ""
                        }
                    }
                }
            }
        }

        // --- Divider ---
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // --- Arrangement Presets ---
        Label {
            text: "ARRANGEMENT PRESETS"
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
        }

        Label {
            text: "Save/load walkthrough voicing choices:"
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            TextField {
                id: presetPathField
                Layout.fillWidth: true
                font.pixelSize: 11
                placeholderText: "/path/to/preset.json"
                selectByMouse: true
            }
        }

        RowLayout {
            spacing: 6

            Button {
                text: "Save Preset"
                enabled: importPanel.hasBatchChords
                onClicked: {
                    var path = presetPathField.text.trim()
                    if (!path) {
                        path = Qt.resolvedUrl("preset-" + Date.now() + ".json").toString().replace("file://", "")
                        presetPathField.text = path
                    }
                    importPanel.presetSaveRequested(path)
                }
            }

            Button {
                text: "Load Preset"
                onClicked: {
                    var path = presetPathField.text.trim()
                    if (!path) {
                        importPanel._presetStatus = "Enter a preset file path"
                        importPanel._presetStatusColor = theme.errorText
                        return
                    }
                    importPanel.presetLoadRequested(path)
                }
            }
        }

        Label {
            visible: importPanel._presetStatus.length > 0
            text: importPanel._presetStatus
            color: importPanel._presetStatusColor
            font.pixelSize: 11
            font.bold: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Divider ---
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // --- Import Tuning (moved from Settings, #144) ---
        Label {
            text: "IMPORT TUNING"
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
        }

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
                text: "Browse"
                font.pixelSize: 10
                onClicked: importPanel.browseImportRequested(tuningImportPath)
            }

            Button {
                text: "Import"
                font.pixelSize: 10
                onClicked: {
                    var path = tuningImportPath.text.trim()
                    if (!path) {
                        importPanel.tuningStatus = "Enter a file path"
                        importPanel.tuningStatusColor = "#e74c3c"
                        return
                    }
                    importPanel._tuningImportConfirmPath = path
                    importPanel._showTuningImportConfirm = true
                }
            }
        }

        // --- Tuning import confirmation ---
        Rectangle {
            visible: importPanel._showTuningImportConfirm
            Layout.fillWidth: true
            height: tuningImportConfirmCol.implicitHeight + 12
            radius: 6
            color: Qt.rgba(0.2, 0.5, 1, 0.08)
            border.color: "#2980b9"
            border.width: 1

            ColumnLayout {
                id: tuningImportConfirmCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Label {
                    text: "Import tuning from \"" + importPanel._tuningImportConfirmPath.split("/").pop() + "\"?"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#2980b9"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6
                    Button {
                        text: "Yes, import"
                        font.pixelSize: 10
                        onClicked: {
                            importPanel.importTuningRequested(importPanel._tuningImportConfirmPath)
                            importPanel._showTuningImportConfirm = false
                            importPanel._tuningImportConfirmPath = ""
                        }
                    }
                    Button {
                        text: "Cancel"
                        font.pixelSize: 10
                        onClicked: {
                            importPanel._showTuningImportConfirm = false
                            importPanel._tuningImportConfirmPath = ""
                        }
                    }
                }
            }
        }

        Label {
            visible: importPanel.tuningStatus.length > 0
            text: importPanel.tuningStatus
            color: importPanel.tuningStatusColor
            font.pixelSize: 11
            font.bold: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Divider ---
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // --- Create / Edit Tuning (moved from Settings, #144) ---
        Label {
            text: "CREATE / EDIT TUNING"
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
        }

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
                text: importPanel.tuningNameValue
                onTextChanged: importPanel.tuningNameValue = text
            }

            SpinBox {
                id: tuningStringCount
                editable: true
                from: 4
                to: 12
                value: importPanel.tuningStringCountValue
                implicitWidth: 80
                onValueChanged: importPanel.tuningStringCountValue = value
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
            text: importPanel.tuningPitchesValue
            onTextChanged: importPanel.tuningPitchesValue = text
        }

        Button {
            text: "Save Tuning"
            font.pixelSize: 10
            ToolTip.visible: hovered
            ToolTip.text: "Create a new tuning or save changes to an existing one"
            onClicked: importPanel.createTuningRequested(tuningNameField.text.trim(), tuningPitchesField.text.trim(), tuningStringCount.value)
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
    }
}
