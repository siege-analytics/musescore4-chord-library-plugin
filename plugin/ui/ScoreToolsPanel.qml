import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ScoreToolsPanel.qml — Score Tools tab UI (Tab 1) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A4, #97).
//
// Input state groups: calc, theme
// Input properties: usingTuningVoicings, skipDiagramPositions, toolStatusText
// Signals: analyzeRequested, voiceLeadingRequested, fingeringsRequested,
//          constraintChanged(key, value), annotateRequested,
//          fingeringSheetRequested, skipDiagramsChanged(checked)

Flickable {
    id: scoreToolsPanel

    // --- Input properties (state groups) ---
    property var calc       // { maxFret, maxStretch, minNotes, maxMuted, maxPerQuality, allowOpen, rootInBass }
    property var theme      // colors

    // --- Input properties (scalar) ---
    property bool usingTuningVoicings: false
    property bool skipDiagramPositions: false
    property string toolStatusText: ""

    // --- Output signals ---
    signal analyzeRequested()
    signal voiceLeadingRequested()
    signal fingeringsRequested()
    signal constraintChanged(string key, var value)
    signal annotateRequested()
    signal fingeringSheetRequested()
    signal skipDiagramsChanged(bool checked)

    // --- Flickable setup ---
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
                onClicked: scoreToolsPanel.analyzeRequested()
            }

            Button {
                text: "Voice Leading"
                font.pixelSize: 10
                onClicked: scoreToolsPanel.voiceLeadingRequested()
            }

            Button {
                text: "Suggest Fingerings"
                font.pixelSize: 10
                onClicked: scoreToolsPanel.fingeringsRequested()
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
                from: 7; to: 24; value: calc.maxFret
                implicitWidth: 70
                onValueChanged: {
                    if (value !== calc.maxFret) scoreToolsPanel.constraintChanged("calcMaxFret", value)
                }
            }

            Label { text: "Max stretch:"; font.pixelSize: 10 }
            SpinBox {
                from: 2; to: 7; value: calc.maxStretch
                implicitWidth: 70
                onValueChanged: {
                    if (value !== calc.maxStretch) scoreToolsPanel.constraintChanged("calcMaxStretch", value)
                }
            }

            Label { text: "Min notes:"; font.pixelSize: 10 }
            SpinBox {
                from: 2; to: 6; value: calc.minNotes
                implicitWidth: 70
                onValueChanged: {
                    if (value !== calc.minNotes) scoreToolsPanel.constraintChanged("calcMinNotes", value)
                }
            }

            Label { text: "Max muted:"; font.pixelSize: 10 }
            SpinBox {
                from: 0; to: 4; value: calc.maxMuted
                implicitWidth: 70
                onValueChanged: {
                    if (value !== calc.maxMuted) scoreToolsPanel.constraintChanged("calcMaxMuted", value)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label { text: "Max per quality:"; font.pixelSize: 10 }
            SpinBox {
                from: 0; to: 999; value: calc.maxPerQuality
                implicitWidth: 80
                ToolTip.visible: hovered
                ToolTip.text: "0 = unlimited (Ted Greene mode). Higher = fewer voicings, faster."
                onValueChanged: {
                    if (value !== calc.maxPerQuality) scoreToolsPanel.constraintChanged("calcMaxPerQuality", value)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            CheckBox {
                text: "Open strings"
                font.pixelSize: 10
                checked: calc.allowOpen
                onCheckedChanged: scoreToolsPanel.constraintChanged("calcAllowOpen", checked)
            }

            CheckBox {
                text: "Root in bass"
                font.pixelSize: 10
                checked: calc.rootInBass
                onCheckedChanged: scoreToolsPanel.constraintChanged("calcRootInBass", checked)
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
                onClicked: scoreToolsPanel.annotateRequested()
                ToolTip.visible: hovered
                ToolTip.text: "Adds fret notation as staff text — reads existing diagrams when present"
            }

            Button {
                text: "Fingering Sheet (PDF)"
                font.pixelSize: 10
                onClicked: scoreToolsPanel.fingeringSheetRequested()
            }

            CheckBox {
                text: "Skip diagrams"
                font.pixelSize: 9
                checked: scoreToolsPanel.skipDiagramPositions
                onCheckedChanged: scoreToolsPanel.skipDiagramsChanged(checked)
                ToolTip.visible: hovered
                ToolTip.text: "When checked, skip positions that already have a fretboard diagram"
            }
        }

        Label {
            id: toolStatus
            visible: scoreToolsPanel.toolStatusText.length > 0
            text: scoreToolsPanel.toolStatusText
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
