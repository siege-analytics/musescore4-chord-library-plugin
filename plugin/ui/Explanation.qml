import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Explanation block — "Why this voicing?" text surfaced next to every voicing
// in the Walkthrough panel (full mode) and Library card (compact + tap-expand).
//
// #586. Renders the structured output of ExplanationFormatter.format(...).
//
// Properties:
//   formatted     — output object from ExplanationFormatter.format(); null hides the component
//   theme         — theme object with .textMuted, .textPrimary, .cardBackground, .cardBorder, .divider
//   displayMode   — "full" (Walkthrough side-panel) or "compact" (Library card; tap-to-expand)
//   enabled       — false hides the component (driven by DataCache.enableExplanationText setting)
//
// Compact mode: single-line elided summary + tap chevron; tap opens the Popup with the full block.
// Full mode: title + body_full + citation/polarity/falsifier (where present).

Item {
    id: root

    property var formatted: null
    property var theme: null
    property string displayMode: "full"  // "full" or "compact"
    property bool enabledSurface: true

    // Hide the component entirely when there's nothing to render OR the user disabled the setting.
    visible: enabledSurface && formatted !== null && formatted !== undefined
    height: visible ? (displayMode === "compact" ? compactRow.implicitHeight : fullCol.implicitHeight) : 0

    // ---------- COMPACT (Library card) ----------
    RowLayout {
        id: compactRow
        visible: root.displayMode === "compact" && root.visible
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        Label {
            Layout.fillWidth: true
            text: root.formatted ? (root.formatted.title + " — " + (root.formatted.body_compact || "")) : ""
            font.pixelSize: 9
            font.italic: true
            color: root.theme ? root.theme.textMuted : "#888"
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Label {
            text: "▸"
            font.pixelSize: 9
            color: root.theme ? root.theme.textMuted : "#888"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: expandPopup.open()
            }
        }
    }

    // ---------- FULL (Walkthrough) ----------
    ColumnLayout {
        id: fullCol
        visible: root.displayMode === "full" && root.visible
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2

        Label {
            text: root.formatted ? ("Why this voicing? " + root.formatted.title) : ""
            font.pixelSize: 10
            font.bold: true
            color: root.theme ? root.theme.textPrimary : "#222"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Label {
            text: root.formatted ? (root.formatted.body_full || "") : ""
            font.pixelSize: 10
            color: root.theme ? root.theme.textMuted : "#666"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        Label {
            text: root.formatted ? (root.formatted.citation || "") : ""
            font.pixelSize: 9
            font.italic: true
            color: root.theme ? root.theme.textMuted : "#888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        Label {
            text: root.formatted && root.formatted.polarity_phrase ? root.formatted.polarity_phrase : ""
            font.pixelSize: 9
            color: root.theme ? root.theme.textMuted : "#888"
            visible: text.length > 0
        }

        Label {
            text: root.formatted && root.formatted.falsifier ? ("Doesn't apply: " + root.formatted.falsifier) : ""
            font.pixelSize: 9
            font.italic: true
            color: root.theme ? root.theme.textMuted : "#888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }
    }

    // ---------- POPUP (tap-expand from compact) ----------
    Popup {
        id: expandPopup
        modal: false
        focus: true
        width: Math.min(380, root.parent ? root.parent.width - 20 : 360)
        // Reuse the FULL layout inside the popup.

        background: Rectangle {
            color: root.theme ? root.theme.cardBackground : "#fafafa"
            border.color: root.theme ? root.theme.cardBorder : "#ccc"
            border.width: 1
            radius: 4
        }

        contentItem: ColumnLayout {
            spacing: 4

            Label {
                text: root.formatted ? ("Why this voicing? " + root.formatted.title) : ""
                font.pixelSize: 11
                font.bold: true
                color: root.theme ? root.theme.textPrimary : "#222"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Label {
                text: root.formatted ? (root.formatted.body_full || "") : ""
                font.pixelSize: 10
                color: root.theme ? root.theme.textMuted : "#666"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }

            Label {
                text: root.formatted ? (root.formatted.citation || "") : ""
                font.pixelSize: 9
                font.italic: true
                color: root.theme ? root.theme.textMuted : "#888"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }

            Label {
                text: root.formatted && root.formatted.polarity_phrase ? root.formatted.polarity_phrase : ""
                font.pixelSize: 9
                color: root.theme ? root.theme.textMuted : "#888"
                visible: text.length > 0
            }

            Label {
                text: root.formatted && root.formatted.falsifier ? ("Doesn't apply: " + root.formatted.falsifier) : ""
                font.pixelSize: 9
                font.italic: true
                color: root.theme ? root.theme.textMuted : "#888"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }
        }
    }
}
