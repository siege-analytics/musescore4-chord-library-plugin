import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// PracticePanel.qml — Practice (Flash Cards) tab UI (Tab 4) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A3, #96).
//
// Input state groups: practice, theme
// Signals: resetRequested, modeChanged(mode), revealRequested,
//          markCorrectRequested, markWrongRequested, skipRequested

Flickable {
    id: practicePanel

    // --- Input properties (state group) ---
    property var practice   // { voicing, showAnswer, mode, correct, total }
    property var theme      // colors

    // --- Output signals ---
    signal resetRequested()
    signal modeChanged(string mode)
    signal revealRequested()
    signal markCorrectRequested()
    signal markWrongRequested()
    signal skipRequested()

    // --- Flickable setup ---
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentHeight: practiceColumn.implicitHeight
    clip: true
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: practiceColumn
        width: parent.width - 16
        spacing: 12

        // Score display
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Score: " + practice.correct + " / " + practice.total
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
            }

            Label {
                text: practice.total > 0
                    ? Math.round(practice.correct / practice.total * 100) + "% correct"
                    : ""
                font.pixelSize: 11
                color: theme.textMuted
            }

            Button {
                text: "Reset"
                font.pixelSize: 10
                onClicked: practicePanel.resetRequested()
            }
        }

        // Mode selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Mode:"
                font.pixelSize: 11
            }

            Button {
                text: "Name the Chord"
                font.pixelSize: 10
                highlighted: practice.mode === "name"
                onClicked: practicePanel.modeChanged("name")
            }

            Button {
                text: "Find the Shape"
                font.pixelSize: 10
                highlighted: practice.mode === "shape"
                onClicked: practicePanel.modeChanged("shape")
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // Flash card area
        Rectangle {
            Layout.fillWidth: true
            height: 220
            radius: 8
            color: theme.cardBackground
            border.color: theme.cardBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // "Name the Chord" mode: show fretboard, hide name
                Label {
                    visible: practice.mode === "name" && !practice.showAnswer
                    text: "What chord is this voicing?"
                    font.pixelSize: 12
                    color: theme.textSecondary
                    Layout.alignment: Qt.AlignHCenter
                }

                // "Find the Shape" mode: show chord name, hide fretboard
                Label {
                    visible: practice.mode === "shape"
                    text: practice.voicing ? practice.voicing.name || "" : ""
                    font.pixelSize: 16
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    visible: practice.mode === "shape" && !practice.showAnswer
                    text: "Visualize the fretboard shape, then reveal"
                    font.pixelSize: 11
                    color: theme.textMuted
                    Layout.alignment: Qt.AlignHCenter
                }

                // Fretboard preview (hidden in "shape" mode until revealed)
                Canvas {
                    id: practiceCanvas
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 140
                    Layout.alignment: Qt.AlignHCenter
                    visible: practice.mode === "name" || practice.showAnswer

                    property var pv: practice.voicing

                    onPvChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var v = pv
                        if (!v || !v.dots) return

                        var ns = v.strings || 6
                        var nf = v.visible_frets || 4
                        var mg = 10, tm = 18
                        var ss = (width - 2 * mg) / (ns - 1)
                        var fs = (height - tm - mg) / nf

                        var isDark = theme.isDark
                        var gridColor = isDark ? Qt.rgba(0.85, 0.85, 0.85, 0.7) : Qt.rgba(0.4, 0.4, 0.4, 0.6)
                        var textColor = isDark ? Qt.rgba(0.8, 0.8, 0.8, 0.8) : Qt.rgba(0.4, 0.4, 0.4, 0.8)
                        var muteColor = isDark ? Qt.rgba(0.7, 0.7, 0.7, 0.8) : Qt.rgba(0.5, 0.5, 0.5, 0.7)

                        ctx.strokeStyle = gridColor
                        ctx.lineWidth = 0.5
                        for (var s = 0; s < ns; s++) {
                            ctx.beginPath()
                            ctx.moveTo(mg + s * ss, tm)
                            ctx.lineTo(mg + s * ss, height - mg)
                            ctx.stroke()
                        }
                        for (var f = 0; f <= nf; f++) {
                            ctx.lineWidth = (f === 0 && (v.fret_number || 1) <= 1) ? 2.5 : 0.5
                            ctx.beginPath()
                            ctx.moveTo(mg, tm + f * fs)
                            ctx.lineTo(width - mg, tm + f * fs)
                            ctx.stroke()
                        }
                        if ((v.fret_number || 0) > 1) {
                            ctx.fillStyle = textColor
                            ctx.font = "10px sans-serif"
                            ctx.textAlign = "right"
                            ctx.fillText(v.fret_number, mg - 3, tm + fs * 0.6)
                        }
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
                            ctx.arc(mg + (ns - dots[d].string) * ss, tm + (dots[d].fret - 0.5) * fs, 5, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                        ctx.fillStyle = muteColor
                        ctx.font = "11px sans-serif"
                        ctx.textAlign = "center"
                        var mutes = v.mutes || []
                        for (var m = 0; m < mutes.length; m++) {
                            ctx.fillText("×", mg + (ns - mutes[m]) * ss, tm - 3)
                        }
                        ctx.strokeStyle = muteColor
                        ctx.lineWidth = 1
                        var opens = v.open || []
                        for (var o = 0; o < opens.length; o++) {
                            ctx.beginPath()
                            ctx.arc(mg + (ns - opens[o]) * ss, tm - 7, 3.5, 0, 2 * Math.PI)
                            ctx.stroke()
                        }
                    }
                }

                // Answer (chord name + details)
                Label {
                    visible: practice.showAnswer && practice.mode === "name"
                    text: practice.voicing ? practice.voicing.name || "" : ""
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    visible: practice.showAnswer
                    text: practice.voicing
                        ? (practice.voicing.intervals || []).join(" ")
                            + "  |  Fret " + (practice.voicing.fret_number || "?")
                            + "  |  " + (practice.voicing.category || "")
                        : ""
                    font.pixelSize: 10
                    color: theme.textSecondary
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Button {
                visible: !practice.showAnswer
                text: "Reveal Answer"
                font.pixelSize: 12
                onClicked: practicePanel.revealRequested()
            }

            Button {
                visible: practice.showAnswer
                text: "✓ Got it"
                font.pixelSize: 12
                onClicked: practicePanel.markCorrectRequested()
            }

            Button {
                visible: practice.showAnswer
                text: "✗ Missed"
                font.pixelSize: 12
                onClicked: practicePanel.markWrongRequested()
            }

            Button {
                text: "Skip"
                font.pixelSize: 10
                onClicked: practicePanel.skipRequested()
            }
        }
    }
}
