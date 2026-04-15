import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../model/MelodyEngine.js" as MelodyEngine
import "../model/Transposer.js" as Transposer
import "../model/ReharmonizationEngine.js" as Reharm
import "../model/ChordScales.js" as ChordScales

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
    property var availableCategories: ["All Types"]  // dynamic from parent's categoryList
    property string tuningName: ""  // active tuning display name
    property bool calculatedVoicings: false  // true when using runtime-calculated voicings
    property string tuningPitches: ""  // scientific pitch notation (e.g. "A3-E3-C3-G2-D2-A1")
    property int tuningOffset: 0  // semitones from standard tuning (passed from parent)
    property int altCount: 0     // voicings in current bass-string group
    property int altIndex: 0     // index within current group
    property var bassStringList: []       // available bass strings [7, 6, 5, 4]
    property int selectedBassString: -1   // currently selected bass string
    property var bassStringCounts: ({})   // { "7": 45, "6": 32, ... }
    property var difficultyFn: function(v) { return { score: 0, tier: "standard" } }  // FingeringEngine.computeDifficulty
    property var fingeringFn: function(v) { return "" }  // FingeringEngine.computeFingeringString
    property bool melodyLockDefault: false  // from Library tab's Melody Lock button

    // Lock states (readable by parent for bass string selection)
    readonly property bool melodyLocked: typeof melodyLockBtn !== "undefined" && melodyLockBtn ? melodyLockBtn.checked : false
    readonly property bool bassLocked: typeof bassLockBtn !== "undefined" && bassLockBtn ? bassLockBtn.checked : false

    // === Signals (handled by parent) ===
    signal prevClicked()
    signal nextClicked()
    signal stopClicked()
    signal revoiceRequested(string melodyNote, bool melodyLocked, string bassNote, bool bassLocked, string category)
    signal reharmSelected(string newRoot, string newQuality)
    signal altSelected(int index)
    signal bassStringClicked(int bassStr)

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
                    + "  |  " + (tuningName || "Standard")
                    + (calculatedVoicings ? " ⚙" : "")
                    + (tuningPitches ? "\n" + tuningPitches : "")
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

    // Voice leading path — shows melody contour across chords
    Label {
        visible: batchActive && batchChords.length > 1
        Layout.fillWidth: true
        font.pixelSize: 10
        font.family: "Menlo, Monaco, monospace"
        color: theme.textSecondary
        text: MelodyEngine.buildVoiceLeadingPath(batchChords, batchIndex, Transposer.SEMITONE_MAP)
        lineHeight: 1.3
    }

    Rectangle {
        visible: batchActive && batchChords.length > 1
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

                // Fret number (transposed to target root)
                var displayFret = currentItem ? transposedFretNumber(v, currentItem.root) : (v.fret_number || 0)
                if (displayFret > 1) {
                    ctx.fillStyle = textColor
                    ctx.font = "9px sans-serif"
                    ctx.textAlign = "right"
                    ctx.fillText(displayFret, mg - 2, tm + fs * 0.6)
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
                font.pixelSize: 14
                font.bold: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Label {
                visible: currentItem !== null
                text: currentItem ? ((currentItem.voicing.intervals || []).join(" ") + "  |  Fret " + transposedFretNumber(currentItem.voicing, currentItem.root)) : ""
                font.pixelSize: 12
                font.bold: true
                font.family: "Menlo, Monaco, monospace"
                Layout.fillWidth: true
            }

            // Difficulty tier (#106)
            Label {
                visible: currentItem !== null
                text: {
                    if (!currentItem) return ""
                    var d = walkthroughPanel.difficultyFn(currentItem.voicing)
                    var label = d.tier.charAt(0).toUpperCase() + d.tier.slice(1)
                    return label + " (" + d.score + "/100)"
                }
                color: {
                    if (!currentItem) return "black"
                    var d = walkthroughPanel.difficultyFn(currentItem.voicing)
                    if (d.tier === "expert") return "#e74c3c"
                    if (d.tier === "advanced") return "#f39c12"
                    return "#27ae60"
                }
                font.pixelSize: 10
                font.bold: true
            }

            // Fingering suggestion
            Label {
                visible: currentItem !== null
                text: {
                    if (!currentItem) return ""
                    var fg = walkthroughPanel.fingeringFn(currentItem.voicing)
                    return fg ? "Fingering: " + fg : ""
                }
                font.pixelSize: 10
                font.family: "Menlo, Monaco, monospace"
                color: "#aaa"
            }

            // Color legend for fretboard dot intervals
            Flow {
                visible: currentItem !== null
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: theme.legendColors

                    Row {
                        spacing: 2
                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: modelData.label
                            font.pixelSize: 8
                        }
                    }
                }
            }

            // Bass string + voicing navigation — single compact row
            RowLayout {
                visible: currentItem !== null && bassStringList.length > 0
                spacing: 4

                Label {
                    text: "Bass str:"
                    font.pixelSize: 10
                    font.bold: true
                }

                ComboBox {
                    id: bassStringCombo
                    implicitWidth: 90
                    font.pixelSize: 10
                    model: {
                        var items = []
                        for (var i = 0; i < bassStringList.length; i++) {
                            var bs = bassStringList[i]
                            var count = bassStringCounts[String(bs)] || 0
                            items.push("Str " + bs + " (" + count + ")")
                        }
                        return items
                    }
                    currentIndex: Math.max(0, bassStringList.indexOf(selectedBassString))
                    // T-002: use onActivated (user clicks only), not onCurrentIndexChanged
                    // which fires on model rebuilds and causes unwanted voicing switches
                    onActivated: {
                        if (currentIndex >= 0 && currentIndex < bassStringList.length) {
                            walkthroughPanel.bassStringClicked(bassStringList[currentIndex])
                        }
                    }
                }

                Button {
                    text: "◀"
                    font.pixelSize: 10
                    implicitWidth: 24
                    implicitHeight: 22
                    enabled: altIndex > 0
                    onClicked: walkthroughPanel.altSelected(altIndex - 1)
                }

                Label {
                    text: (altIndex + 1) + "/" + altCount
                    font.pixelSize: 10
                    font.bold: true
                }

                Button {
                    text: "▶"
                    font.pixelSize: 10
                    implicitWidth: 24
                    implicitHeight: 22
                    enabled: altIndex < altCount - 1
                    onClicked: walkthroughPanel.altSelected(altIndex + 1)
                }
            }

            Label {
                visible: currentItem !== null
                text: {
                    if (!currentItem) return ""
                    var scales = ChordScales.getScaleNames(currentItem.quality || currentItem.voicing.chord_quality)
                    return scales.length > 0 ? ("Scales: " + scales.join(", ")) : ""
                }
                font.pixelSize: 11
                font.italic: true
                color: theme.successText
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }

    // Quality disambiguation chips — shown when chord symbol is ambiguous (e.g. bare "F")
    Flow {
        visible: batchActive && currentItem !== null && currentItem.ambiguous === true
        Layout.fillWidth: true
        spacing: 4

        Label {
            text: "⚠ \"" + (currentItem ? currentItem.text : "") + "\" — interpret as:"
            font.pixelSize: 9
            font.bold: true
            color: theme.warningText || theme.textSecondary
        }

        Repeater {
            model: {
                if (!currentItem || !currentItem.ambiguous) return []
                var r = currentItem.root
                return [
                    { label: r + "7", quality: "dom7", description: "Dominant 7 (blues/bebop)" },
                    { label: r + "maj7", quality: "maj7", description: "Major 7" },
                    { label: r + " triad", quality: "maj", description: "Major triad" },
                    { label: r + "6", quality: "maj6", description: "Major 6" },
                    { label: r + "m7", quality: "min7", description: "Minor 7" },
                ]
            }

            Rectangle {
                width: disambigLabel.implicitWidth + 12
                height: disambigLabel.implicitHeight + 6
                radius: 10
                color: {
                    if (currentItem && modelData.quality === currentItem.quality)
                        return theme.chipActiveBackground || theme.successText
                    return disambigMouse.containsMouse ? theme.chipHover : theme.chipBackground
                }
                border.color: theme.chipBorder
                border.width: 1

                Label {
                    id: disambigLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 9
                    font.bold: currentItem && modelData.quality === currentItem.quality
                    color: (currentItem && modelData.quality === currentItem.quality)
                        ? (theme.chipActiveText || "white") : theme.textSecondary
                }

                MouseArea {
                    id: disambigMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: walkthroughPanel.reharmSelected(currentItem.root, modelData.quality)
                }

                ToolTip.visible: disambigMouse.containsMouse
                ToolTip.text: modelData.description
            }
        }
    }

    // Reharm suggestion chips
    Flow {
        visible: batchActive && currentItem !== null
        Layout.fillWidth: true
        spacing: 4

        Label {
            text: "Reharm:"
            font.pixelSize: 9
            color: theme.textMuted
        }

        Repeater {
            model: {
                if (!currentItem) return []
                var nextItem = (batchIndex < batchChords.length) ? batchChords[batchIndex] : null
                return Reharm.suggest(
                    currentItem.root,
                    currentItem.quality,
                    nextItem ? nextItem.root : "",
                    nextItem ? nextItem.quality : ""
                )
            }

            Rectangle {
                width: chipLabel.implicitWidth + 12
                height: chipLabel.implicitHeight + 6
                radius: 10
                color: chipMouse.containsMouse ? theme.chipHover : theme.chipBackground
                border.color: theme.chipBorder
                border.width: 1

                Label {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 9
                    color: theme.textSecondary
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: walkthroughPanel.reharmSelected(modelData.root, modelData.quality)
                }

                ToolTip.visible: chipMouse.containsMouse
                ToolTip.text: modelData.description
            }
        }
    }

    // Per-chord voicing controls (melody + bass + category override)
    RowLayout {
        visible: batchActive
        Layout.fillWidth: true
        spacing: 4

        Label {
            text: "Mel:"
            font.pixelSize: 10
        }

        TextField {
            id: stepMelodyField
            implicitWidth: 36
            font.pixelSize: 10
            placeholderText: "auto"
            selectByMouse: true
            text: currentItem && currentItem.melodyMidi >= 0
                ? MelodyEngine.melodyNoteName(currentItem.melodyMidi)
                : ""
            onAccepted: emitRevoice()
        }

        Button {
            id: melodyLockBtn
            text: melodyLockBtn.checked ? "🔒" : "🔓"
            font.pixelSize: 10
            implicitWidth: 24
            implicitHeight: 24
            checkable: true
            checked: walkthroughPanel.melodyLockDefault
            ToolTip.visible: hovered
            ToolTip.text: checked ? "Melody LOCKED — must match this note" : "Melody unlocked — prefer but allow alternatives"
        }

        Label {
            text: "Bass:"
            font.pixelSize: 10
        }

        TextField {
            id: stepBassField
            implicitWidth: 36
            font.pixelSize: 10
            placeholderText: "root"
            selectByMouse: true
            text: currentItem && currentItem.bassMidi >= 0
                ? MelodyEngine.melodyNoteName(currentItem.bassMidi)
                : ""
            onAccepted: emitRevoice()
        }

        Button {
            id: bassLockBtn
            text: bassLockBtn.checked ? "🔒" : "🔓"
            font.pixelSize: 10
            implicitWidth: 24
            implicitHeight: 24
            checkable: true
            checked: false
            ToolTip.visible: hovered
            ToolTip.text: checked ? "Bass LOCKED — must match this note" : "Bass unlocked — prefer but allow alternatives"
        }

        Label {
            text: "Type:"
            font.pixelSize: 10
        }

        ComboBox {
            id: stepCategoryCombo
            implicitWidth: 90
            font.pixelSize: 10
            // Dynamic: uses the same category list as the Library tab
            model: availableCategories
            // Map display names to slug values — "All Types" → ""
            function categoryToSlug(displayName) {
                if (displayName === "All Types") return ""
                return displayName.toLowerCase().replace(/ /g, "")
            }
            property int lastStepIndex: -1
            function syncToStep() {
                if (!currentItem) return
                var cat = currentItem.voicing.category || ""
                for (var i = 0; i < availableCategories.length; i++) {
                    if (categoryToSlug(availableCategories[i]) === cat) {
                        currentIndex = i
                        return
                    }
                }
                currentIndex = 0  // "All Types"
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

    // Compute transposed fret number for preview display (mirrors generateXmlForVoicing logic)
    function transposedFretNumber(voicing, targetRoot) {
        if (!voicing) return 0
        var offset = Transposer.semitoneOffset(voicing.root || "C", targetRoot)
        var effectiveOffset = calculatedVoicings ? 0 : tuningOffset
        var fret = (voicing.fret_number || 0) + offset - effectiveOffset
        if (fret < 0) fret += 12
        return fret
    }

    // Helper to emit revoice signal with all current overrides
    function emitRevoice() {
        revoiceRequested(
            stepMelodyField.text,
            melodyLockBtn.checked,
            stepBassField.text,
            bassLockBtn.checked,
            stepCategoryCombo.categoryToSlug(stepCategoryCombo.currentText)
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
