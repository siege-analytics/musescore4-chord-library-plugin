import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ComparisonTrayPanel — side-by-side voicing comparison (#196).
// Renders the current `compareVoicings` array (max 3). Embedded by both
// LibraryPanel and WalkthroughPanel so the tray is visible in both contexts.

Rectangle {
    id: trayPanel

    property var compareVoicings: []
    property var suggestFingeringFn: function(v) { return [] }

    signal removeRequested(int index)
    signal clearRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: 100
    color: theme.consoleBg
    radius: 4
    border.color: theme.divider
    visible: compareVoicings && compareVoicings.length > 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        Repeater {
            model: trayPanel.compareVoicings.length

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: theme.cardBackground
                border.color: theme.cardBorder

                property var cv: trayPanel.compareVoicings[index] || {}

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    Label {
                        text: cv.name || ""
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: (cv.intervals || []).join(" ")
                        font.pixelSize: 9
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "Fret " + (cv.fret_number || "?") + "  |  " + (cv.notes || []).join(" ")
                        font.pixelSize: 9
                        color: theme.textMuted
                        Layout.fillWidth: true
                    }
                    Label {
                        text: {
                            var f = trayPanel.suggestFingeringFn(cv)
                            if (!f || f.length === 0) return ""
                            var parts = []
                            for (var i = 0; i < f.length; i++) parts.push("S" + f[i].string + ":" + f[i].finger)
                            return "Fingering: " + parts.join(" ")
                        }
                        font.pixelSize: 8
                        color: theme.textFaint
                        Layout.fillWidth: true
                    }
                }

                // Per-entry remove button (#196 X-button on tray)
                Button {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 2
                    text: "×"
                    font.pixelSize: 11
                    implicitWidth: 18
                    implicitHeight: 16
                    ToolTip.visible: hovered
                    ToolTip.text: "Remove from comparison"
                    onClicked: trayPanel.removeRequested(index)
                }
            }
        }

        Button {
            text: "Clear"
            font.pixelSize: 9
            implicitWidth: 40
            onClicked: trayPanel.clearRequested()
        }
    }
}
