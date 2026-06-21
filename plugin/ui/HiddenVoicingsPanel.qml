import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// HiddenVoicingsPanel — collapsible disclosure listing voicings hidden by
// the exclusion engine (#210 Stage 2). Each row shows the voicing's name,
// chord quality, and the failing-dimension reason chip. "Include" button
// writes a user override that always-includes this signature going forward.
//
// Embedded by LibraryPanel (showing all hidden voicings in the current pool)
// and WalkthroughPanel (showing hidden alts for the current chord).

ColumnLayout {
    id: hiddenPanel

    property var hiddenVoicings: []  // array of voicings with _excludedReason set
    property string titlePrefix: "Hidden"

    signal includeRequested(string signatureKey)
    signal clearAllOverridesRequested()

    visible: hiddenVoicings.length > 0
    spacing: 4
    Layout.fillWidth: true

    // Header / disclosure toggle
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Button {
            id: toggleBtn
            text: (hiddenPanel.expanded ? "▼ " : "▶ ")
                  + hiddenPanel.titlePrefix + " (" + hiddenPanel.hiddenVoicings.length + ")"
            font.pixelSize: 10
            ToolTip.visible: hovered
            ToolTip.text: "Voicings hidden by the current tuning/mode tolerances. " +
                          "Click a voicing's Include button to override."
            onClicked: hiddenPanel.expanded = !hiddenPanel.expanded
        }

        Item { Layout.fillWidth: true }

        Button {
            visible: hiddenPanel.expanded
            text: "Reset overrides"
            font.pixelSize: 9
            ToolTip.visible: hovered
            ToolTip.text: "Clear all 'include' and 'exclude' overrides this user has set."
            onClicked: hiddenPanel.clearAllOverridesRequested()
        }
    }

    property bool expanded: false

    // Hidden-list body
    Repeater {
        model: hiddenPanel.expanded ? hiddenPanel.hiddenVoicings : []

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 3
            color: theme.cardBackground
            border.color: theme.cardBorder
            border.width: 1

            property var v: modelData || {}

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 6

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        text: (v.name || "(no name)") + "  —  " + (v.chord_quality || "?")
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: v._excludedReason ? v._excludedReason.message : ""
                        font.pixelSize: 9
                        color: theme.warningText || theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Button {
                    text: "Include"
                    font.pixelSize: 9
                    ToolTip.visible: hovered
                    ToolTip.text: "Always include this voicing in the visible pool, regardless of tolerances."
                    onClicked: {
                        if (v._signatureKey) {
                            hiddenPanel.includeRequested(v._signatureKey)
                        }
                    }
                }
            }
        }
    }
}
