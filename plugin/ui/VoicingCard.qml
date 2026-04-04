import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: card
    height: 80
    radius: 4
    color: mouseArea.containsMouse ? theme.cardHover : theme.cardBackground
    border.color: theme.cardBorder
    border.width: 1

    property var voicing: ({})
    signal doubleClicked(var voicing)
    signal compareClicked(var voicing)

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onDoubleClicked: card.doubleClicked(card.voicing)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Fretboard thumbnail
        Canvas {
            id: fretCanvas
            Layout.preferredWidth: 48
            Layout.preferredHeight: 64

            onPaint: {
                var ctx = getContext("2d")
                drawFretDiagram(ctx)
            }

            Component.onCompleted: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            function drawFretDiagram(ctx) {
                var w = width
                var h = height
                ctx.clearRect(0, 0, w, h)

                if (!voicing || !voicing.dots) return

                var numStrings = voicing.strings || 6
                var numFrets = voicing.visible_frets || 4
                var margin = 4
                var topMargin = 10
                var stringSpacing = (w - 2 * margin) / (numStrings - 1)
                var fretSpacing = (h - topMargin - margin) / numFrets

                // Draw strings
                ctx.strokeStyle = theme.fretGrid
                ctx.lineWidth = 0.5
                for (var s = 0; s < numStrings; s++) {
                    var x = margin + s * stringSpacing
                    ctx.beginPath()
                    ctx.moveTo(x, topMargin)
                    ctx.lineTo(x, h - margin)
                    ctx.stroke()
                }

                // Draw frets
                for (var f = 0; f <= numFrets; f++) {
                    var y = topMargin + f * fretSpacing
                    ctx.lineWidth = (f === 0) ? 2 : 0.5
                    ctx.beginPath()
                    ctx.moveTo(margin, y)
                    ctx.lineTo(w - margin, y)
                    ctx.stroke()
                }

                // Draw dots
                ctx.fillStyle = theme.fretDot
                var dots = voicing.dots || []
                for (var d = 0; d < dots.length; d++) {
                    // Convert string number (1=high e) to x position (left=low)
                    var strIdx = numStrings - dots[d].string
                    var dotX = margin + strIdx * stringSpacing
                    var dotY = topMargin + (dots[d].fret - 0.5) * fretSpacing
                    ctx.beginPath()
                    ctx.arc(dotX, dotY, 3, 0, 2 * Math.PI)
                    ctx.fill()
                }

                // Draw mute markers
                var mutes = voicing.mutes || []
                ctx.fillStyle = theme.fretMute
                ctx.font = "8px sans-serif"
                ctx.textAlign = "center"
                for (var m = 0; m < mutes.length; m++) {
                    var muteIdx = numStrings - mutes[m]
                    var muteX = margin + muteIdx * stringSpacing
                    ctx.fillText("×", muteX, topMargin - 2)
                }

                // Draw open markers
                var opens = voicing.open || []
                for (var o = 0; o < opens.length; o++) {
                    var openIdx = numStrings - opens[o]
                    var openX = margin + openIdx * stringSpacing
                    ctx.beginPath()
                    ctx.arc(openX, topMargin - 5, 3, 0, 2 * Math.PI)
                    ctx.strokeStyle = theme.fretGrid
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }
        }

        // Text info
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: voicing.name || ""
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Label {
                text: (voicing.intervals || []).join(" ") + "  |  " + (voicing.context || "")
                font.pixelSize: 11
                color: theme.textSecondary
                Layout.fillWidth: true
            }

            Label {
                text: "Fret " + (voicing.fret_number || "?") + "  |  " + (voicing.notes || []).join(" ")
                font.pixelSize: 10
                color: theme.textMuted
                Layout.fillWidth: true
            }

            Label {
                text: (voicing.tags || []).join(", ")
                font.pixelSize: 9
                color: theme.textFaint
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // Compare button (visible on hover)
    Button {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 2
        text: "⇔"
        font.pixelSize: 10
        implicitWidth: 22
        implicitHeight: 18
        visible: mouseArea.containsMouse
        ToolTip.visible: hovered
        ToolTip.text: "Add to comparison"
        onClicked: card.compareClicked(card.voicing)
    }

    Connections {
        target: card
        function onVoicingChanged() {
            fretCanvas.requestPaint()
        }
    }
}
