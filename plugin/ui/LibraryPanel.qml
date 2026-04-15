import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// LibraryPanel.qml — Library tab UI (Tab 0) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A6, #99).
//
// Input state groups: library, tuning, theme
// Input properties: (many — see property declarations below)
// Signals: searchChanged(text), contextFilterChanged(code), categoryFilterChanged(text),
//          qualityFilterChanged(text), tuningSelected(slug),
//          voiceHereRequested, batchInsertRequested, batchStopRequested,
//          sortToggled, melodyToggled, voice2Toggled, melodyStaffChanged(idx),
//          copyTuningRequested, openVoicingRequested(voicing),
//          playVoicingRequested(voicing, mode), compareRequested(voicing),
//          clearComparisonRequested
//
// NOTE: statusMsg remains in ChordLibrary.qml (global status bar, 96 references).
// Will be migrated to property in Phase C (#104).

Item {
    id: libraryPanel

    // --- Input properties (data) ---
    property var filteredData: []
    property var voicingsData: []
    property var contextDisplayList: []
    property var contextList: []
    property var categoryList: []
    property var qualityList: []
    property var filteredTuningDisplayList: []
    property var filteredTuningList: []
    property string selectedTuning: "standard"
    property string filterContext: ""
    property var theme: null

    // --- Input properties (toolbar state) ---
    property bool batchActive: false
    property bool sortByProximity: false
    property bool melodyOnTop: false
    property int melodyStaffIdx: -1
    property bool writeVoice2: false

    // --- Input properties (comparison) ---
    property bool showComparison: false
    property var compareVoicings: []

    // --- Callback functions (passed from parent for delegate use) ---
    property var computeNotesForTuningFn: function(v) { return [] }
    property var suggestFingeringFn: function(v) { return [] }
    property var fingeringStringFn: function(v) { return "" }
    property var matchingScalesFn: function(v) { return [] }

    // --- Scale filter ---
    property var scaleFilterList: ["All Scales"]

    // --- Output signals ---
    signal searchChanged(string text)
    signal contextFilterChanged(string code)
    signal categoryFilterChanged(string text)
    signal qualityFilterChanged(string text)
    signal tuningSelected(string slug)
    signal voiceHereRequested()
    signal batchInsertRequested()
    signal batchStopRequested()
    signal sortToggled()
    signal melodyToggled()
    signal voice2Toggled()
    signal melodyStaffChanged(int idx)
    signal copyTuningRequested()
    signal openVoicingRequested(var voicing)
    signal playVoicingRequested(var voicing, string mode)
    signal compareRequested(var voicing)
    signal clearComparisonRequested()
    signal scaleFilterChanged(string scaleName)

    // --- Save to Library signals (moved from Settings, #144) ---
    signal captureRequested()
    signal saveVoicingRequested(string quality, string category, string context, string fret, int strings, string dots, string mutes)

    // --- Library Health signals (moved from Settings, #144) ---
    signal auditRequested(string reportPath)
    signal dismissRequested(string key)
    signal fixDuplicatesRequested()
    signal clearDismissalsRequested()
    signal browseAuditRequested(var targetField)

    // --- Save/Audit properties (moved from Settings, #144) ---
    property string homePath: "~"
    property string saveStatus: ""
    property color saveStatusColor: "black"
    property string saveFretValue: ""
    property int saveStringsCountValue: 6
    property string hygieneStatus: ""
    property color hygieneStatusColor: "black"
    property var lastAuditResults: []
    property var hygieneIgnoreList: []

    // --- Collapsible sections state ---
    property bool showLibraryTools: false

    // --- Layout ---
    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        TextField {
            id: searchField
            placeholderText: "Search voicings..."
            Layout.fillWidth: true
            onTextChanged: libraryPanel.searchChanged(text)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: contextCombo
                model: libraryPanel.contextDisplayList
                Layout.fillWidth: true
                currentIndex: Math.max(0, libraryPanel.contextList.indexOf(libraryPanel.filterContext || "All Contexts"))
                onActivated: {
                    if (currentIndex >= 0 && currentIndex < libraryPanel.contextList.length) {
                        var code = libraryPanel.contextList[currentIndex]
                        libraryPanel.contextFilterChanged(code === "All Contexts" ? "" : code)
                    }
                }
            }
            ComboBox {
                id: categoryCombo
                model: libraryPanel.categoryList
                Layout.fillWidth: true
                onActivated: {
                    libraryPanel.categoryFilterChanged(currentText === "All Types" ? "" : currentText)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: qualityCombo
                model: libraryPanel.qualityList
                Layout.fillWidth: true
                onActivated: {
                    libraryPanel.qualityFilterChanged(currentText === "All Qualities" ? "" : currentText)
                }
            }

            ComboBox {
                id: scaleFilterCombo
                model: libraryPanel.scaleFilterList
                Layout.fillWidth: true
                onActivated: {
                    libraryPanel.scaleFilterChanged(currentText === "All Scales" ? "" : currentText)
                }
            }
        }

        // Tuning selector row
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            ComboBox {
                id: tuningMainCombo
                model: libraryPanel.filteredTuningDisplayList
                Layout.fillWidth: true
                currentIndex: Math.max(0, libraryPanel.filteredTuningList.indexOf(libraryPanel.selectedTuning))
                onActivated: {
                    if (currentIndex >= 0 && currentIndex < libraryPanel.filteredTuningList.length) {
                        var newTuning = libraryPanel.filteredTuningList[currentIndex]
                        if (newTuning && newTuning !== libraryPanel.selectedTuning) {
                            libraryPanel.tuningSelected(newTuning)
                        }
                    }
                }
            }

            Label {
                text: libraryPanel.filteredData.length + " of " + libraryPanel.voicingsData.length
                font.pixelSize: 11
            }

            Button {
                visible: libraryPanel.selectedTuning !== "standard"
                text: "Copy Tuning"
                font.pixelSize: 9
                implicitHeight: 22
                ToolTip.visible: hovered
                ToolTip.text: "Copy tuning info to clipboard.\nPaste into a Subtitle (Add > Text > Subtitle)"
                onClicked: libraryPanel.copyTuningRequested()
            }
        }

        // Action buttons (wrapping flow to avoid overflow)
        Flow {
            Layout.fillWidth: true
            spacing: 4

            Button {
                text: "Voice Here"
                font.pixelSize: 10
                ToolTip.visible: hovered
                ToolTip.text: "Suggest a voicing for the chord at the current cursor position"
                onClicked: libraryPanel.voiceHereRequested()
            }

            Button {
                text: libraryPanel.batchActive ? "Stop" : "Voice All"
                font.pixelSize: 10
                ToolTip.visible: hovered
                ToolTip.text: "Voice all chord symbols in the score"
                onClicked: {
                    if (libraryPanel.batchActive) libraryPanel.batchStopRequested()
                    else libraryPanel.batchInsertRequested()
                }
            }

            Button {
                text: libraryPanel.sortByProximity ? "Nearest" : "Default"
                font.pixelSize: 10
                onClicked: libraryPanel.sortToggled()
            }

            Button {
                text: libraryPanel.melodyOnTop ? "🔒 Melody" : "Melody"
                font.pixelSize: 10
                highlighted: libraryPanel.melodyOnTop
                ToolTip.visible: hovered
                ToolTip.text: libraryPanel.melodyOnTop
                    ? "Melody LOCKED — voicings must have melody note on top.\nVoice All will match melody for every chord."
                    : "Lock voicings to melody note on top (from score or override field)"
                onClicked: libraryPanel.melodyToggled()
            }

            TextField {
                id: melodyOverrideField
                visible: libraryPanel.melodyOnTop
                width: 36
                font.pixelSize: 10
                placeholderText: "auto"
                selectByMouse: true
                ToolTip.visible: hovered
                ToolTip.text: "Override melody note (e.g. E, Bb, F#). Leave blank for auto-detect."
            }

            ComboBox {
                visible: libraryPanel.melodyOnTop
                width: 80
                font.pixelSize: 10
                model: ["Same staff", "Staff 1", "Staff 2", "Staff 3"]
                currentIndex: libraryPanel.melodyStaffIdx + 1
                onCurrentIndexChanged: {
                    libraryPanel.melodyStaffChanged(currentIndex - 1)
                }
                ToolTip.visible: hovered
                ToolTip.text: "Which staff to read the melody from"
            }

            Button {
                text: libraryPanel.writeVoice2 ? "Voice 2 ✓" : "Voice 2"
                font.pixelSize: 10
                ToolTip.visible: hovered
                ToolTip.text: "Write voicing pitches as notes on Voice 2 during walkthrough"
                onClicked: libraryPanel.voice2Toggled()
            }
        }

        // Color legend for fretboard dot intervals
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: theme.legendColors

                Row {
                    spacing: 2
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: modelData.label
                        font.pixelSize: 9
                    }
                }
            }
        }

        ListView {
            id: voicingList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: libraryPanel.filteredData.length

            delegate: Rectangle {
                width: voicingList.width
                height: 80
                radius: 4
                color: ma.containsMouse ? theme.chipHover : theme.chipBackground
                border.color: theme.divider
                border.width: 1

                property var v: libraryPanel.filteredData[index] || {}

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onDoubleClicked: libraryPanel.openVoicingRequested(v)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    // Fretboard thumbnail
                    Canvas {
                        id: fretCanvas
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 66

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            if (!v || !v.dots) return

                            var ns = v.strings || 6
                            var nf = v.visible_frets || 4
                            var mg = 5, tm = 12
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
                                var fy = tm + f * fs
                                ctx.beginPath()
                                ctx.moveTo(mg, fy)
                                ctx.lineTo(width - mg, fy)
                                ctx.stroke()
                            }

                            if ((v.fret_number || 0) > 1) {
                                ctx.fillStyle = textColor
                                ctx.font = "7px sans-serif"
                                ctx.textAlign = "right"
                                ctx.fillText(v.fret_number, mg - 1, tm + fs * 0.6)
                            }

                            var dots = v.dots || []
                            var ivs = v.intervals || []
                            for (var d = 0; d < dots.length; d++) {
                                var iv = (d < ivs.length) ? ivs[d] : ""
                                if (iv === "1")
                                    ctx.fillStyle = theme.dotRoot
                                else if (iv === "3" || iv === "b3")
                                    ctx.fillStyle = theme.dotThird
                                else if (iv === "5" || iv === "b5" || iv === "#5")
                                    ctx.fillStyle = theme.dotFifth
                                else if (iv === "7" || iv === "b7" || iv === "bb7")
                                    ctx.fillStyle = theme.dotSeventh
                                else if (iv === "6" || iv === "13" || iv === "b13")
                                    ctx.fillStyle = theme.dotSixth
                                else if (iv === "9" || iv === "b9" || iv === "#9" || iv === "2")
                                    ctx.fillStyle = theme.dotNinth
                                else if (iv === "4" || iv === "11" || iv === "#11")
                                    ctx.fillStyle = theme.dotFourth
                                else
                                    ctx.fillStyle = theme.dotDefault

                                var dx = mg + (ns - dots[d].string) * ss
                                var dy = tm + (dots[d].fret - 0.5) * fs
                                ctx.beginPath()
                                ctx.arc(dx, dy, 3.5, 0, 2 * Math.PI)
                                ctx.fill()
                            }

                            ctx.fillStyle = muteColor
                            ctx.font = "9px sans-serif"
                            ctx.textAlign = "center"
                            var mutes = v.mutes || []
                            for (var m = 0; m < mutes.length; m++) {
                                ctx.fillText("×", mg + (ns - mutes[m]) * ss, tm - 2)
                            }

                            ctx.strokeStyle = muteColor
                            ctx.lineWidth = 1
                            var opens = v.open || []
                            for (var o = 0; o < opens.length; o++) {
                                ctx.beginPath()
                                ctx.arc(mg + (ns - opens[o]) * ss, tm - 5, 3, 0, 2 * Math.PI)
                                ctx.stroke()
                            }
                        }

                        Component.onCompleted: requestPaint()
                    }

                    // Text info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: v.name || ""
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                var topInterval = ""
                                if (v.dots && v.dots.length > 0 && v.intervals) {
                                    var minStr = 99
                                    var topIdx = -1
                                    for (var ti = 0; ti < v.dots.length; ti++) {
                                        if (v.dots[ti].string < minStr) {
                                            minStr = v.dots[ti].string
                                            topIdx = ti
                                        }
                                    }
                                    var opens = v.open || []
                                    for (var oi = 0; oi < opens.length; oi++) {
                                        if (opens[oi] < minStr) {
                                            minStr = opens[oi]
                                            topIdx = -2
                                        }
                                    }
                                    if (topIdx >= 0 && topIdx < v.intervals.length) {
                                        var iv = v.intervals[topIdx]
                                        var ivLabels = {"1":"root","3":"3rd","b3":"b3","5":"5th","b5":"b5","#5":"#5",
                                            "7":"7th","b7":"b7","bb7":"bb7","9":"9th","b9":"b9","#9":"#9",
                                            "4":"4th","11":"11th","#11":"#11","6":"6th","13":"13th","b13":"b13"}
                                        topInterval = ivLabels[iv] || iv
                                    }
                                }
                                var info = (v.intervals || []).join(" ") + "  |  Fret " + (v.fret_number || "?")
                                if (topInterval) info += "  |  " + topInterval + " on top"
                                return info
                            }
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        Label {
                            text: libraryPanel.computeNotesForTuningFn(v).join(" ")
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                var fg = libraryPanel.fingeringStringFn(v)
                                return fg ? fg : ""
                            }
                            visible: text.length > 0
                            font.pixelSize: 8
                            font.family: "Menlo, Monaco, monospace"
                            color: "#999"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                var scales = libraryPanel.matchingScalesFn(v)
                                if (!scales || scales.length === 0) return ""
                                return "Fits: " + scales.join(", ")
                            }
                            visible: text.length > 0
                            font.pixelSize: 8
                            color: theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        spacing: 2

                        Button {
                            text: "Open"
                            font.pixelSize: 9
                            implicitWidth: 44
                            onClicked: libraryPanel.openVoicingRequested(v)
                        }

                        RowLayout {
                            spacing: 1

                            Button {
                                text: "\u266B"
                                font.pixelSize: 11
                                implicitWidth: 22
                                onClicked: libraryPanel.playVoicingRequested(v, "chord")
                            }

                            Button {
                                text: "\u2191"
                                font.pixelSize: 11
                                implicitWidth: 22
                                onClicked: libraryPanel.playVoicingRequested(v, "arp")
                            }

                            Button {
                                text: "\u21CB"
                                font.pixelSize: 11
                                implicitWidth: 22
                                ToolTip.visible: hovered
                                ToolTip.text: "Compare"
                                onClicked: libraryPanel.compareRequested(v)
                            }
                        }
                    }
                }
            }
        }

        // Comparison panel
        Rectangle {
            visible: libraryPanel.showComparison
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: theme.consoleBg
            radius: 4
            border.color: theme.divider

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Repeater {
                    model: libraryPanel.compareVoicings.length

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 4
                        color: theme.cardBackground
                        border.color: theme.cardBorder

                        property var cv: libraryPanel.compareVoicings[index] || {}

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
                                    var f = libraryPanel.suggestFingeringFn(cv)
                                    if (f.length === 0) return ""
                                    var parts = []
                                    for (var i = 0; i < f.length; i++) parts.push("S" + f[i].string + ":" + f[i].finger)
                                    return "Fingering: " + parts.join(" ")
                                }
                                font.pixelSize: 8
                                color: theme.textFaint
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                Button {
                    text: "Clear"
                    font.pixelSize: 9
                    implicitWidth: 40
                    onClicked: libraryPanel.clearComparisonRequested()
                }
            }
        }

        // ─────────────────────────────────────────────
        // Library Tools toggle (Save to Library + Health, moved from Settings #144)
        // ─────────────────────────────────────────────
        Button {
            text: libraryPanel.showLibraryTools ? "\u25BC Library Tools" : "\u25B6 Library Tools"
            font.pixelSize: 10
            Layout.fillWidth: true
            onClicked: libraryPanel.showLibraryTools = !libraryPanel.showLibraryTools
        }

        ColumnLayout {
            visible: libraryPanel.showLibraryTools
            Layout.fillWidth: true
            spacing: 12

            // --- Save to Library ---
            Label {
                text: "SAVE TO LIBRARY"
                font.pixelSize: 11
                font.bold: true
                Layout.fillWidth: true
            }

            Label {
                text: "Enter a voicing or capture from the score."
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Button {
                text: "Capture from Score"
                font.pixelSize: 10
                onClicked: libraryPanel.captureRequested()
            }

            Label {
                text: "Dots: string:fret pairs (e.g. 6:1,4:1,3:2)"
                font.pixelSize: 9
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                ComboBox {
                    id: saveQualityCombo
                    model: ["dom7","maj7","min7","min7b5","dim7","maj6","min6",
                            "dom7b9","dom7sharp5","dom7alt","dom9","dom13",
                            "sus4","sus2","aug7","min-maj7","augMaj7"]
                    Layout.fillWidth: true
                }

                ComboBox {
                    id: saveCategoryCombo
                    model: ["shell","drop2","drop3","extended","altered","quartal"]
                    implicitWidth: 90
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                ComboBox {
                    id: saveContextCombo
                    model: ["CV6","CV7","CM6","CM7"]
                    implicitWidth: 70
                }

                TextField {
                    id: saveFretField
                    placeholderText: "Fret#"
                    implicitWidth: 50
                    font.pixelSize: 11
                    selectByMouse: true
                    text: libraryPanel.saveFretValue
                    onTextChanged: libraryPanel.saveFretValue = text
                }

                SpinBox {
                    id: saveStringsCount
                    from: 4; to: 12
                    value: libraryPanel.saveStringsCountValue
                    implicitWidth: 75
                    onValueChanged: libraryPanel.saveStringsCountValue = value
                }
            }

            TextField {
                id: saveDotsField
                Layout.fillWidth: true
                font.pixelSize: 11
                placeholderText: "Dots: 6:1, 4:1, 3:2"
                selectByMouse: true
            }

            TextField {
                id: saveMutesField
                Layout.fillWidth: true
                font.pixelSize: 11
                placeholderText: "Mutes: 5, 2, 1"
                selectByMouse: true
            }

            Label {
                text: "Enter positions as played. The plugin will reproject to C."
                font.pixelSize: 9
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Button {
                text: "Save Voicing"
                font.pixelSize: 10
                onClicked: libraryPanel.saveVoicingRequested(
                    saveQualityCombo.currentText, saveCategoryCombo.currentText,
                    saveContextCombo.currentText, saveFretField.text.trim(),
                    saveStringsCount.value, saveDotsField.text.trim(), saveMutesField.text.trim())
            }

            Label {
                visible: libraryPanel.saveStatus.length > 0
                text: libraryPanel.saveStatus
                color: libraryPanel.saveStatusColor
                font.pixelSize: 11
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // --- Divider ---
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

            // --- Library Health ---
            Label {
                text: "LIBRARY HEALTH"
                font.pixelSize: 11
                font.bold: true
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                TextField {
                    id: auditReportPath
                    Layout.fillWidth: true
                    font.pixelSize: 10
                    text: libraryPanel.homePath + "/Documents/chord-library-audit.txt"
                    selectByMouse: true
                }

                Button {
                    text: "Browse"
                    font.pixelSize: 10
                    onClicked: libraryPanel.browseAuditRequested(auditReportPath)
                }
            }

            Button {
                text: "Run Audit"
                font.pixelSize: 10
                onClicked: libraryPanel.auditRequested(auditReportPath.text)
            }

            Label {
                visible: libraryPanel.hygieneStatus.length > 0
                text: libraryPanel.hygieneStatus
                color: libraryPanel.hygieneStatusColor
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                visible: libraryPanel.lastAuditResults.length > 0
                text: "Paste a DISMISS KEY from the report to suppress it:"
                font.pixelSize: 9
            }

            RowLayout {
                visible: libraryPanel.lastAuditResults.length > 0
                Layout.fillWidth: true
                spacing: 4

                TextField {
                    id: dismissKeyField
                    Layout.fillWidth: true
                    font.pixelSize: 10
                    placeholderText: "e.g. ENH:0,4,9,11"
                    selectByMouse: true
                }

                Button {
                    text: "Dismiss"
                    font.pixelSize: 10
                    onClicked: {
                        var key = dismissKeyField.text.trim()
                        if (key) {
                            libraryPanel.dismissRequested(key)
                            dismissKeyField.text = ""
                        }
                    }
                }
            }

            RowLayout {
                visible: libraryPanel.lastAuditResults.length > 0 || libraryPanel.hygieneIgnoreList.length > 0
                Layout.fillWidth: true
                spacing: 4

                Button {
                    text: "Fix Duplicates"
                    font.pixelSize: 10
                    visible: libraryPanel.lastAuditResults.some(function(r) { return r.indexOf("DUP:") === 0 })
                    onClicked: libraryPanel.fixDuplicatesRequested()
                }

                Button {
                    text: "Reset All Dismissed"
                    font.pixelSize: 10
                    visible: libraryPanel.hygieneIgnoreList.length > 0
                    onClicked: libraryPanel.clearDismissalsRequested()
                }
            }
        }
    }
}
