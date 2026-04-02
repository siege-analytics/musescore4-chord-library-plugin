import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../model/MelodyEngine.js" as MelodyEngine
import "../model/Transposer.js" as Transposer

// Voice Score walkthrough overlay panel.
// Displays the guided per-chord voicing workflow with melody/category overrides.
// Extracted from ChordLibrary.qml for maintainability.

ColumnLayout {
    id: walkthroughPanel
    spacing: 8

    // === Properties (bound from parent) ===
    property var batchChords: []      // Array of {text, root, quality, voicing, melodyMidi}
    property int batchIndex: 0        // Current step (1-indexed after batchShowNext increments)
    property int batchTotal: 0        // Total chords in batch
    property bool batchActive: false  // True when walkthrough is in progress
    property string resultsTitle: ""
    property string resultsContent: ""

    // === Signals (handled by parent) ===
    signal prevClicked()
    signal nextClicked()
    signal stopClicked()
    signal revoiceRequested(string melodyNote, string bassNote, string category)

    // Convenience: current item (read-only)
    readonly property var currentItem: {
        if (batchActive && batchIndex > 0 && batchIndex <= batchChords.length)
            return batchChords[batchIndex - 1]
        return null
    }

    // Header row with title and nav buttons
    RowLayout {
        Layout.fillWidth: true

        Label {
            text: resultsTitle
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }

        Button {
            text: "← Prev"
            visible: batchActive && batchIndex > 1
            onClicked: walkthroughPanel.prevClicked()
        }

        Button {
            text: "Next →"
            visible: batchActive && batchIndex < batchChords.length
            onClicked: walkthroughPanel.nextClicked()
        }

        Button {
            text: batchActive ? "Stop" : "Back to Library"
            onClicked: walkthroughPanel.stopClicked()
        }
    }

    // Progress bar (only during walkthrough)
    ColumnLayout {
        visible: batchActive
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Step " + Math.min(batchIndex, batchTotal) + " of " + batchTotal
                font.pixelSize: 11
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Label {
                text: Math.round(Math.min(batchIndex, batchTotal) / Math.max(batchTotal, 1) * 100) + "%"
                font.pixelSize: 11
                color: theme.textMuted
            }
        }

        // Progress bar track
        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: theme.isDark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)

            Rectangle {
                width: parent.width * Math.min(batchIndex, batchTotal) / Math.max(batchTotal, 1)
                height: parent.height
                radius: 3
                color: theme.successText

                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: theme.divider
    }

    // Mini fretboard preview with voicing info
    RowLayout {
        visible: batchActive && currentItem !== null
        Layout.fillWidth: true
        spacing: 12

        Canvas {
            id: batchPreviewCanvas
            Layout.preferredWidth: 70
            Layout.preferredHeight: 90

            property var previewVoicing: currentItem ? currentItem.voicing : null

            onPreviewVoicingChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var v = previewVoicing
                if (!v || !v.dots) return

                var ns = v.strings || 6
                var nf = v.visible_frets || 4
                var mg = 6, tm = 14
                var ss = (width - 2 * mg) / (ns - 1)
                var fs = (height - tm - mg) / nf

                var isDark = theme.isDark
                var gridColor = isDark ? Qt.rgba(0.85, 0.85, 0.85, 0.7) : Qt.rgba(0.4, 0.4, 0.4, 0.6)
                var textColor = isDark ? Qt.rgba(0.8, 0.8, 0.8, 0.8) : Qt.rgba(0.4, 0.4, 0.4, 0.8)
                var muteColor = isDark ? Qt.rgba(0.7, 0.7, 0.7, 0.8) : Qt.rgba(0.5, 0.5, 0.5, 0.7)

                // Strings
                ctx.strokeStyle = gridColor
                ctx.lineWidth = 0.5
                for (var s = 0; s < ns; s++) {
                    ctx.beginPath()
                    ctx.moveTo(mg + s * ss, tm)
                    ctx.lineTo(mg + s * ss, height - mg)
                    ctx.stroke()
                }

                // Frets
                for (var f = 0; f <= nf; f++) {
                    ctx.lineWidth = (f === 0 && (v.fret_number || 1) <= 1) ? 2.5 : 0.5
                    ctx.beginPath()
                    ctx.moveTo(mg, tm + f * fs)
                    ctx.lineTo(width - mg, tm + f * fs)
                    ctx.stroke()
                }

                // Fret number
                if ((v.fret_number || 0) > 1) {
                    ctx.fillStyle = textColor
                    ctx.font = "9px sans-serif"
                    ctx.textAlign = "right"
                    ctx.fillText(v.fret_number, mg - 2, tm + fs * 0.6)
                }

                // Dots with interval coloring
                var dots = v.dots || []
                var ivs = v.intervals || []
                for (var d = 0; d < dots.length; d++) {
                    var iv = (d < ivs.length) ? ivs[d] : ""
                    if (iv === "1") ctx.fillStyle = theme.dotRoot
                    else if (iv === "3" || iv === "b3") ctx.fillStyle = theme.dotThird
                    else if (iv === "5" || iv === "b5" || iv === "#5") ctx.fillStyle = theme.dotFifth
                    else if (iv === "7" || iv === "b7" || iv === "bb7") ctx.fillStyle = theme.dotSeventh
                    else if (iv === "6" || iv === "13" || iv === "b13") ctx.fillStyle = theme.dotSixth
                    else if (iv === "9" || iv === "b9" || iv === "#9" || iv === "2") ctx.fillStyle = theme.dotNinth
                    else if (iv === "4" || iv === "11" || iv === "#11") ctx.fillStyle = theme.dotFourth
                    else ctx.fillStyle = theme.dotDefault

                    ctx.beginPath()
                    ctx.arc(mg + (ns - dots[d].string) * ss, tm + (dots[d].fret - 0.5) * fs, 4, 0, 2 * Math.PI)
                    ctx.fill()
                }

                // Mutes
                ctx.fillStyle = muteColor
                ctx.font = "10px sans-serif"
                ctx.textAlign = "center"
                var mutes = v.mutes || []
                for (var m = 0; m < mutes.length; m++) {
                    ctx.fillText("×", mg + (ns - mutes[m]) * ss, tm - 2)
                }

                // Opens
                ctx.strokeStyle = muteColor
                ctx.lineWidth = 1
                var opens = v.open || []
                for (var o = 0; o < opens.length; o++) {
                    ctx.beginPath()
                    ctx.arc(mg + (ns - opens[o]) * ss, tm - 6, 3, 0, 2 * Math.PI)
                    ctx.stroke()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Label {
                visible: currentItem !== null
                text: currentItem ? Transposer.transposeName(currentItem.voicing.name || currentItem.text, currentItem.voicing.root || "C", currentItem.root) : ""
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Label {
                visible: currentItem !== null
                text: currentItem ? ((currentItem.voicing.intervals || []).join(" ") + "  |  Fret " + (currentItem.voicing.fret_number || "?")) : ""
                font.pixelSize: 10
                color: theme.textSecondary
                Layout.fillWidth: true
            }
        }
    }

    // Per-chord voicing controls (melody + bass + category override)
    RowLayout {
        visible: batchActive
        Layout.fillWidth: true
        spacing: 6

        Label {
            text: "Melody:"
            font.pixelSize: 10
        }

        TextField {
            id: stepMelodyField
            implicitWidth: 40
            font.pixelSize: 10
            placeholderText: "auto"
            selectByMouse: true
            text: currentItem && currentItem.melodyMidi >= 0
                ? MelodyEngine.melodyNoteName(currentItem.melodyMidi)
                : ""
            onAccepted: emitRevoice()
        }

        Label {
            text: "Bass:"
            font.pixelSize: 10
        }

        TextField {
            id: stepBassField
            implicitWidth: 40
            font.pixelSize: 10
            placeholderText: "root"
            selectByMouse: true
            text: currentItem && currentItem.bassMidi >= 0
                ? MelodyEngine.melodyNoteName(currentItem.bassMidi)
                : ""
            onAccepted: emitRevoice()
        }

        Label {
            text: "Type:"
            font.pixelSize: 10
        }

        ComboBox {
            id: stepCategoryCombo
            implicitWidth: 90
            font.pixelSize: 10
            model: ["Any", "Shell", "Drop 2", "Drop 3", "Extended", "Altered", "Quartal"]
            property var categoryMap: ({"Any":"", "Shell":"shell", "Drop 2":"drop2", "Drop 3":"drop3", "Extended":"extended", "Altered":"altered", "Quartal":"quartal"})
            property int lastStepIndex: -1
            function syncToStep() {
                if (!currentItem) return
                var cat = currentItem.voicing.category || ""
                var values = ["","shell","drop2","drop3","extended","altered","quartal"]
                var idx = values.indexOf(cat)
                currentIndex = idx >= 0 ? idx : 0
            }
            Connections {
                target: walkthroughPanel
                function onBatchIndexChanged() {
                    stepCategoryCombo.syncToStep()
                }
            }
            Component.onCompleted: syncToStep()
        }

        Button {
            text: "Re-voice"
            font.pixelSize: 10
            ToolTip.visible: hovered
            ToolTip.text: "Re-select voicing with melody, bass note, and/or category override"
            onClicked: emitRevoice()
        }
    }

    // Helper to emit revoice signal with all current overrides
    function emitRevoice() {
        revoiceRequested(
            stepMelodyField.text,
            stepBassField.text,
            stepCategoryCombo.categoryMap[stepCategoryCombo.currentText] || ""
        )
    }

    // Keyboard shortcut hint
    Rectangle {
        visible: batchActive
        Layout.fillWidth: true
        height: pasteHintRow.implicitHeight + 12
        radius: 4
        color: theme.consoleBg

        RowLayout {
            id: pasteHintRow
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            Label {
                text: "⌘V"
                font.pixelSize: 16
                font.bold: true
            }

            Label {
                text: "to paste diagram after clicking the target note"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    // Content area (step instructions or general results)
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: toolResultsLabel.implicitHeight + 20
        clip: true
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        boundsBehavior: Flickable.StopAtBounds

        Label {
            id: toolResultsLabel
            text: resultsContent
            width: parent.width - 16
            font.pixelSize: 11
            font.family: "Menlo, Monaco, monospace"
            wrapMode: Text.WordWrap
            padding: 8
        }
    }
}
