import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// MastersPanel.qml — Tab 6 "Masters" — browse curated principles from
// canonical guitar masters (#220).
//
// Two-pane layout: left = master list, right = principle list for the
// selected master, with inline detail expanded for the focused principle.
//
// Input: mastersStore (parsed via MastersStore.parseStore)
// No outbound signals; this is a reference surface, not workflow.

ColumnLayout {
    id: mastersPanel
    spacing: 8

    property var mastersStore: ({ version: "v1", masters: [] })

    property string selectedMasterId: ""
    property string focusedPrincipleId: ""

    // Default-select the first master when the store loads.
    onMastersStoreChanged: {
        if (!selectedMasterId && mastersStore && mastersStore.masters
                && mastersStore.masters.length > 0) {
            selectedMasterId = mastersStore.masters[0].id
        }
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        Label {
            text: "Masters' Lessons"
            font.pixelSize: 14
            font.bold: true
        }
        Item { Layout.fillWidth: true }
        Label {
            text: {
                if (!mastersPanel.mastersStore || !mastersPanel.mastersStore.masters) return ""
                var nm = mastersPanel.mastersStore.masters.length
                var np = 0
                for (var i = 0; i < mastersPanel.mastersStore.masters.length; i++) {
                    np += (mastersPanel.mastersStore.masters[i].principles || []).length
                }
                return nm + " masters · " + np + " principles"
            }
            font.pixelSize: 9
            color: theme.textMuted
        }
    }

    Label {
        text: "Curated principles informing voicing choice. Each master's entry lists rules of thumb, references, and tags that map to the voicingStyle / playStyle taxonomy. Engine integration (auto-apply principles when a master's style is selected) is a future feature."
        font.pixelSize: 10
        color: theme.textSecondary
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

    // Two-pane body
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        // === Left pane: master list ===
        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            color: theme.consoleBg
            radius: 4
            border.color: theme.divider

            Flickable {
                anchors.fill: parent
                anchors.margins: 4
                contentHeight: masterListColumn.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: masterListColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: (mastersPanel.mastersStore && mastersPanel.mastersStore.masters) || []

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: masterRowCol.implicitHeight + 8
                            radius: 3
                            color: modelData.id === mastersPanel.selectedMasterId
                                   ? (theme.chipActiveBackground || theme.successText)
                                   : (masterMouse.containsMouse
                                        ? (theme.chipHover || theme.cardHover)
                                        : theme.cardBackground)
                            border.color: theme.cardBorder

                            MouseArea {
                                id: masterMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    mastersPanel.selectedMasterId = modelData.id
                                    mastersPanel.focusedPrincipleId = ""
                                }
                            }

                            ColumnLayout {
                                id: masterRowCol
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 1

                                Label {
                                    text: modelData.name
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: modelData.id === mastersPanel.selectedMasterId
                                           ? (theme.chipActiveText || "white")
                                           : theme.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: (modelData.traditions || []).join(" · ")
                                    font.pixelSize: 8
                                    color: modelData.id === mastersPanel.selectedMasterId
                                           ? (theme.chipActiveText || "white")
                                           : theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: (modelData.principles || []).length + " principle"
                                          + ((modelData.principles || []).length === 1 ? "" : "s")
                                    font.pixelSize: 8
                                    color: modelData.id === mastersPanel.selectedMasterId
                                           ? (theme.chipActiveText || "white")
                                           : theme.textFaint
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // === Right pane: principle list + detail ===
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: theme.consoleBg
            radius: 4
            border.color: theme.divider

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentHeight: detailColumn.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // Resolve the selected master object once.
                property var _currentMaster: {
                    if (!mastersPanel.mastersStore || !mastersPanel.mastersStore.masters) return null
                    for (var i = 0; i < mastersPanel.mastersStore.masters.length; i++) {
                        if (mastersPanel.mastersStore.masters[i].id === mastersPanel.selectedMasterId)
                            return mastersPanel.mastersStore.masters[i]
                    }
                    return null
                }

                ColumnLayout {
                    id: detailColumn
                    width: parent.width
                    spacing: 8

                    Label {
                        text: parent.parent._currentMaster
                              ? parent.parent._currentMaster.name
                              : "(no master selected)"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Label {
                        visible: parent.parent._currentMaster && parent.parent._currentMaster.lived
                        text: parent.parent._currentMaster
                              ? (parent.parent._currentMaster.lived || "")
                                + " · " + (parent.parent._currentMaster.instrument || "")
                              : ""
                        font.pixelSize: 10
                        color: theme.textMuted
                    }
                    Label {
                        visible: parent.parent._currentMaster && parent.parent._currentMaster.biography
                        text: parent.parent._currentMaster
                              ? (parent.parent._currentMaster.biography || "")
                              : ""
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: parent.parent._currentMaster && parent.parent._currentMaster.site
                        text: parent.parent._currentMaster
                              ? "Site: " + (parent.parent._currentMaster.site || "")
                              : ""
                        font.pixelSize: 9
                        color: theme.textSecondary
                    }

                    Rectangle {
                        visible: parent.parent._currentMaster
                        Layout.fillWidth: true
                        height: 1
                        color: theme.divider
                    }

                    Label {
                        visible: parent.parent._currentMaster
                        text: "PRINCIPLES"
                        font.pixelSize: 10
                        font.bold: true
                        color: theme.textSecondary
                    }

                    // Principle cards
                    Repeater {
                        model: parent.parent._currentMaster
                               ? (parent.parent._currentMaster.principles || [])
                               : []

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pCol.implicitHeight + 12
                            radius: 4
                            color: theme.cardBackground
                            border.color: theme.cardBorder

                            property var p: modelData
                            property bool expanded: p.id === mastersPanel.focusedPrincipleId

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mastersPanel.focusedPrincipleId = (parent.expanded ? "" : parent.p.id)
                            }

                            ColumnLayout {
                                id: pCol
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: (parent.parent.expanded ? "▼ " : "▶ ") + (parent.parent.p.name || parent.parent.p.id)
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    // Tag chips
                                    Repeater {
                                        model: parent.parent.p.voicingStyleTags || []
                                        Rectangle {
                                            radius: 8
                                            color: theme.chipBackground
                                            border.color: theme.chipBorder
                                            implicitWidth: tagLabel.implicitWidth + 8
                                            implicitHeight: tagLabel.implicitHeight + 4
                                            Label {
                                                id: tagLabel
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: 8
                                                color: theme.textSecondary
                                            }
                                        }
                                    }
                                }

                                Label {
                                    text: parent.parent.p.summary || ""
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                // Expanded detail
                                ColumnLayout {
                                    visible: parent.parent.expanded
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        visible: (parent.parent.parent.p.playStyleTags || []).length > 0
                                        text: "Play style: " + (parent.parent.parent.p.playStyleTags || []).join(", ")
                                        font.pixelSize: 9
                                        color: theme.textSecondary
                                    }
                                    Label {
                                        visible: (parent.parent.parent.p.applies_to_modes || []).length > 0
                                        text: "Modes: " + (parent.parent.parent.p.applies_to_modes || []).join(", ")
                                        font.pixelSize: 9
                                        color: theme.textSecondary
                                    }
                                    Label {
                                        visible: (parent.parent.parent.p.applies_to_tunings || []).length > 0
                                        text: "Tunings: " + (parent.parent.parent.p.applies_to_tunings || []).join(", ")
                                        font.pixelSize: 9
                                        color: theme.textSecondary
                                    }
                                    Label {
                                        visible: {
                                            var th = parent.parent.parent.p.tolerance_hints || {}
                                            return Object.keys(th).length > 0
                                        }
                                        text: {
                                            var th = parent.parent.parent.p.tolerance_hints || {}
                                            var parts = []
                                            for (var k in th) parts.push(k + "=" + th[k])
                                            return "Tolerance hints: " + parts.join(", ")
                                        }
                                        font.pixelSize: 9
                                        color: theme.textSecondary
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        visible: (parent.parent.parent.p.references || []).length > 0
                                        text: "References:"
                                        font.pixelSize: 9
                                        color: theme.textSecondary
                                    }
                                    Repeater {
                                        model: parent.parent.parent.p.references || []
                                        Label {
                                            text: "• " + (modelData.citation || modelData.source || modelData.url || "")
                                            font.pixelSize: 9
                                            color: theme.textMuted
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 8
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
