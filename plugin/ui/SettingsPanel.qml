import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// SettingsPanel.qml — Settings tab UI (Tab 5) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A5, #98). Redesigned with sub-tabs (#142).
//
// Sub-tabs: General | Tuning | Scales | Contexts
//
// Input state groups: tuning, theme
// Input properties: diagramPlacement, builtInTunings
// Signals: placementChanged(placement), editTuningRequested(slug),
//          deleteTuningRequested(slug), moveTuningRequested(slug, direction),
//          createContextRequested(code, name, strings),
//          scaleAdded(jsonData), scaleUpdated(jsonData), scaleDeleted(scaleId),
//          chordScaleMappingChanged(quality, scaleIdsJson),
//          customQualityAdded(qualityName), customQualityRemoved(qualityName)

Item {
    id: settingsPanel

    // --- Input properties (state groups) ---
    property var tuning     // { selectedTuning, tuningLabels, tuningList }
    property var theme      // colors

    // --- Input properties (scalar) ---
    property string diagramPlacement: "above"
    property var builtInTunings: []

    // --- Scale data from parent ---
    property var scalesData: []          // Array of scale objects from scales.json
    property var chordScaleMap: ({})     // quality -> [scaleId, ...]
    property var customQualities: []     // Array of custom quality name strings

    // --- Status feedback from parent ---
    property string tuningStatus: ""
    property color tuningStatusColor: "black"

    // --- Tuning edit bridge (set by TuningManager.editTuning) ---
    property string tuningNameValue: ""
    property string tuningPitchesValue: ""
    property int tuningStringCountValue: 6

    // --- Output signals ---
    signal placementChanged(string placement)
    signal editTuningRequested(string slug)
    signal deleteTuningRequested(string slug)
    signal moveTuningRequested(string slug, int direction)
    signal createTuningRequested(string name, string pitches, int numStrings)
    signal importTuningRequested(string path)
    signal createContextRequested(string code, string name, int strings, string linkedTuning)

    // --- Scale signals ---
    signal scaleAdded(string jsonData)
    signal scaleUpdated(string jsonData)
    signal scaleDeleted(string scaleId)
    signal chordScaleMappingChanged(string quality, string scaleIdsJson)
    signal customQualityAdded(string qualityName)
    signal customQualityRemoved(string qualityName)

    // --- Context creation status ---
    property string contextStatus: ""
    property color contextStatusColor: "black"

    // --- Scale status ---
    property string scaleStatus: ""
    property color scaleStatusColor: "black"

    // --- Sub-tab state ---
    property int currentSubTab: 0

    Layout.fillWidth: true
    Layout.fillHeight: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // === Inner TabBar ===
        TabBar {
            id: settingsTabBar
            Layout.fillWidth: true
            currentIndex: settingsPanel.currentSubTab
            onCurrentIndexChanged: settingsPanel.currentSubTab = currentIndex

            TabButton { text: "General"; font.pixelSize: 10 }
            TabButton { text: "Tuning"; font.pixelSize: 10 }
            TabButton { text: "Scales"; font.pixelSize: 10 }
            TabButton { text: "Contexts"; font.pixelSize: 10 }
        }

        // === Sub-tab content ===
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: settingsPanel.currentSubTab

            // ──────────────────────────────────────────
            // SUB-TAB 0: General (Diagram Placement + About)
            // ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: generalColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: generalColumn
                    width: parent.width - 16
                    spacing: 12

                    // --- Diagram placement ---
                    Label {
                        text: "DIAGRAM PLACEMENT"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    ComboBox {
                        id: placementCombo
                        model: ["Above staff (default)", "Below staff"]
                        Layout.fillWidth: true
                        currentIndex: settingsPanel.diagramPlacement === "below" ? 1 : 0
                        onActivated: {
                            var p = currentIndex === 1 ? "below" : "above"
                            settingsPanel.placementChanged(p)
                        }
                    }

                    Label {
                        text: "You can also show all diagrams at the top of the first page:\nFormat > Style > Fretboard Diagrams"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // --- Divider ---
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                    // --- About ---
                    Label {
                        text: "ABOUT"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Siege Analytics Chord Library v1.5.0"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Label {
                        text: "Author: Dheeraj Chand"
                        font.pixelSize: 11
                    }

                    Label {
                        text: '<a href="https://github.com/siege-analytics/musescore4-chord-library-plugin">GitHub Repository</a>'
                        font.pixelSize: 11
                        onLinkActivated: Qt.openUrlExternally(link)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }
                    }

                    Label {
                        text: '<a href="https://siegeanalytics.com">Siege Analytics</a>'
                        font.pixelSize: 11
                        onLinkActivated: Qt.openUrlExternally(link)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }
                    }

                    Label {
                        text: '<a href="https://creativecommons.org/licenses/by/4.0/">Licensed under CC BY 4.0</a>'
                        font.pixelSize: 10
                        onLinkActivated: Qt.openUrlExternally(link)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }
                    }

                    Label {
                        text: '<a href="https://github.com/siege-analytics/musescore4-chord-library-plugin/blob/main/DEVELOPMENT.md">Documentation</a>'
                        font.pixelSize: 11
                        onLinkActivated: Qt.openUrlExternally(link)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }

            // ──────────────────────────────────────────
            // SUB-TAB 1: Tuning (Current tuning with management buttons)
            // ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: tuningColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: tuningColumn
                    width: parent.width - 16
                    spacing: 12

                    // --- Tuning list (#148) ---
                    Label {
                        text: "TUNINGS (" + tuning.tuningList.length + ")"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Click Edit to modify a tuning, or scroll down to create a new one."
                        font.pixelSize: 9
                        color: theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Label {
                        visible: settingsPanel.tuningStatus.length > 0
                        text: settingsPanel.tuningStatus
                        color: settingsPanel.tuningStatusColor
                        font.pixelSize: 10
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: tuning.tuningList

                        Rectangle {
                            Layout.fillWidth: true
                            height: tuningItemRow.implicitHeight + 8
                            radius: 4
                            color: modelData === tuning.selectedTuning
                                ? Qt.rgba(theme.successText.r, theme.successText.g, theme.successText.b, 0.1)
                                : theme.cardBackground
                            border.color: modelData === tuning.selectedTuning ? theme.successText : theme.cardBorder
                            border.width: 1

                            RowLayout {
                                id: tuningItemRow
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                Label {
                                    text: (tuning.tuningLabels[modelData] || modelData)
                                        + (modelData === tuning.selectedTuning ? " (active)" : "")
                                    font.pixelSize: 11
                                    font.bold: modelData === tuning.selectedTuning
                                    color: theme.textPrimary
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: "Edit"
                                    font.pixelSize: 9
                                    implicitWidth: 36
                                    onClicked: {
                                        settingsPanel.tuningNameValue = tuning.tuningLabels[modelData] || modelData
                                        settingsPanel.editTuningRequested(modelData)
                                    }
                                }

                                Button {
                                    text: "Del"
                                    font.pixelSize: 9
                                    implicitWidth: 30
                                    enabled: settingsPanel.builtInTunings.indexOf(modelData) < 0
                                    ToolTip.visible: hovered
                                    ToolTip.text: settingsPanel.builtInTunings.indexOf(modelData) >= 0
                                        ? "Built-in tunings cannot be deleted"
                                        : "Delete this tuning"
                                    onClicked: settingsPanel.deleteTuningRequested(modelData)
                                }

                                Button {
                                    text: "\u25B2"
                                    font.pixelSize: 9
                                    implicitWidth: 24
                                    enabled: tuning.tuningList.indexOf(modelData) > 0
                                    onClicked: settingsPanel.moveTuningRequested(modelData, -1)
                                }

                                Button {
                                    text: "\u25BC"
                                    font.pixelSize: 9
                                    implicitWidth: 24
                                    enabled: tuning.tuningList.indexOf(modelData) < tuning.tuningList.length - 1
                                    onClicked: settingsPanel.moveTuningRequested(modelData, 1)
                                }
                            }
                        }
                    }

                    // --- Divider ---
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                    // --- Inline tuning edit/create form ---
                    Label {
                        text: settingsPanel.tuningNameValue.length > 0 ? "EDIT TUNING" : "CREATE TUNING"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        TextField {
                            id: tuningEditNameField
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            placeholderText: "Name (e.g. Open G)"
                            selectByMouse: true
                            text: settingsPanel.tuningNameValue
                            onTextChanged: settingsPanel.tuningNameValue = text
                        }

                        SpinBox {
                            id: tuningEditStringsCount
                            from: 4
                            to: 12
                            value: settingsPanel.tuningStringCountValue
                            implicitWidth: 80
                            onValueChanged: settingsPanel.tuningStringCountValue = value
                        }
                    }

                    Label {
                        text: "String pitches (high to low, note names or MIDI):"
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: tuningEditPitchesField
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        placeholderText: "E4, B3, G3, D3, A2, E2"
                        selectByMouse: true
                        text: settingsPanel.tuningPitchesValue
                        onTextChanged: settingsPanel.tuningPitchesValue = text
                    }

                    RowLayout {
                        spacing: 6

                        Button {
                            text: "Save Tuning"
                            font.pixelSize: 10
                            onClicked: settingsPanel.createTuningRequested(
                                tuningEditNameField.text.trim(),
                                tuningEditPitchesField.text.trim(),
                                tuningEditStringsCount.value)
                        }

                        Button {
                            text: "Clear"
                            font.pixelSize: 10
                            onClicked: {
                                settingsPanel.tuningNameValue = ""
                                settingsPanel.tuningPitchesValue = "E4, B3, G3, D3, A2, E2"
                                settingsPanel.tuningStringCountValue = 6
                            }
                        }
                    }

                    // Inline tuning status (visible near the Save button)
                    Label {
                        visible: settingsPanel.tuningStatus.length > 0
                        text: settingsPanel.tuningStatus
                        color: settingsPanel.tuningStatusColor
                        font.pixelSize: 10
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // --- Import tuning ---
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                    Label {
                        text: "IMPORT TUNING"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        TextField {
                            id: tuningImportPathField
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            placeholderText: "/path/to/tuning.json"
                            selectByMouse: true
                        }

                        Button {
                            text: "Import"
                            font.pixelSize: 10
                            onClicked: settingsPanel.importTuningRequested(tuningImportPathField.text.trim())
                        }
                    }
                }
            }

            // ──────────────────────────────────────────
            // SUB-TAB 2: Scales (#142 — Scale list, create/edit, mappings, quality CRUD)
            // ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: scalesColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: scalesColumn
                    width: parent.width - 16
                    spacing: 12

                    // --- Local state for scale editing ---
                    property bool editing: false
                    property string editId: ""
                    property string editName: ""
                    property string editAliases: ""
                    property string editIntervals: ""
                    property string editCategory: "custom"
                    property bool editBuiltin: false

                    // Categories for the ComboBox
                    property var categoryOptions: ["mode", "minor", "symmetric", "pentatonic", "blues", "bebop", "custom"]

                    // --- Local state for delete confirmation ---
                    property bool showDeleteConfirm: false
                    property string deleteConfirmId: ""
                    property string deleteConfirmName: ""

                    // --- Local state for mapping editor ---
                    property bool showMappingEditor: false
                    property string mappingQuality: ""
                    property string mappingScaleNames: ""

                    // === Status feedback ===
                    Label {
                        visible: settingsPanel.scaleStatus.length > 0
                        text: settingsPanel.scaleStatus
                        color: settingsPanel.scaleStatusColor
                        font.pixelSize: 10
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // ─────────────────────────────────
                    // SECTION: Scale List
                    // ─────────────────────────────────
                    Label {
                        text: "SCALES (" + settingsPanel.scalesData.length + ")"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    // Scale list
                    Repeater {
                        model: settingsPanel.scalesData

                        Rectangle {
                            Layout.fillWidth: true
                            height: scaleItemRow.implicitHeight + 8
                            color: scaleItemMouse.containsMouse ? theme.cardHover : theme.cardBackground
                            border.color: theme.cardBorder
                            border.width: 1
                            radius: 4

                            MouseArea {
                                id: scaleItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                id: scaleItemRow
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: modelData.name + (modelData.builtin ? " (built-in)" : "")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: theme.textPrimary
                                    }

                                    Label {
                                        visible: modelData.aliases.length > 0
                                        text: "aka: " + modelData.aliases.join(", ")
                                        font.pixelSize: 9
                                        color: theme.textMuted
                                    }

                                    Label {
                                        text: "[" + modelData.intervals.join(", ") + "]  (" + modelData.category + ")"
                                        font.pixelSize: 9
                                        color: theme.textSecondary
                                    }
                                }

                                Button {
                                    text: "Edit"
                                    font.pixelSize: 9
                                    implicitWidth: 36
                                    onClicked: {
                                        scalesColumn.editing = true
                                        scalesColumn.editId = modelData.id
                                        scalesColumn.editName = modelData.name
                                        scalesColumn.editAliases = modelData.aliases.join(", ")
                                        scalesColumn.editIntervals = modelData.intervals.join(", ")
                                        scalesColumn.editCategory = modelData.category
                                        scalesColumn.editBuiltin = modelData.builtin
                                    }
                                }

                                Button {
                                    text: "Dup"
                                    font.pixelSize: 9
                                    implicitWidth: 34
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Duplicate this scale as a starting point for a new one"
                                    onClicked: {
                                        scalesColumn.editing = false
                                        scalesColumn.editId = ""
                                        scalesColumn.editName = modelData.name + " (copy)"
                                        scalesColumn.editAliases = ""
                                        scalesColumn.editIntervals = modelData.intervals.join(", ")
                                        scalesColumn.editCategory = modelData.category
                                        scalesColumn.editBuiltin = false
                                    }
                                }

                                Button {
                                    text: "Del"
                                    font.pixelSize: 9
                                    implicitWidth: 34
                                    enabled: !modelData.builtin
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.builtin ? "Built-in scales cannot be deleted" : "Delete this custom scale"
                                    onClicked: {
                                        scalesColumn.deleteConfirmId = modelData.id
                                        scalesColumn.deleteConfirmName = modelData.name
                                        scalesColumn.showDeleteConfirm = true
                                    }
                                }
                            }
                        }
                    }

                    // --- Delete confirmation (#147) ---
                    Rectangle {
                        visible: scalesColumn.showDeleteConfirm
                        Layout.fillWidth: true
                        height: confirmCol.implicitHeight + 12
                        radius: 6
                        color: Qt.rgba(theme.errorText.r, theme.errorText.g, theme.errorText.b, 0.1)
                        border.color: theme.errorText
                        border.width: 1

                        ColumnLayout {
                            id: confirmCol
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Label {
                                text: "Delete \"" + scalesColumn.deleteConfirmName + "\"? This cannot be undone."
                                font.pixelSize: 10
                                font.bold: true
                                color: theme.errorText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6
                                Button {
                                    text: "Yes, delete"
                                    font.pixelSize: 10
                                    onClicked: {
                                        settingsPanel.scaleDeleted(scalesColumn.deleteConfirmId)
                                        scalesColumn.showDeleteConfirm = false
                                        scalesColumn.deleteConfirmId = ""
                                        scalesColumn.deleteConfirmName = ""
                                    }
                                }
                                Button {
                                    text: "Cancel"
                                    font.pixelSize: 10
                                    onClicked: {
                                        scalesColumn.showDeleteConfirm = false
                                        scalesColumn.deleteConfirmId = ""
                                        scalesColumn.deleteConfirmName = ""
                                    }
                                }
                            }
                        }
                    }

                    // ─────────────────────────────────
                    // SECTION: Create / Edit Scale
                    // ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                    Label {
                        text: scalesColumn.editing ? "EDIT SCALE" : "CREATE SCALE"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        visible: scalesColumn.editBuiltin && scalesColumn.editing
                        text: "Built-in scale: only name, aliases, and category can be changed."
                        font.pixelSize: 9
                        color: theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        TextField {
                            id: scaleNameField
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            placeholderText: "Scale name (e.g. Bebop Major)"
                            selectByMouse: true
                            text: scalesColumn.editName
                            onTextChanged: scalesColumn.editName = text
                        }

                        ComboBox {
                            id: scaleCategoryCombo
                            model: scalesColumn.categoryOptions
                            implicitWidth: 100
                            font.pixelSize: 10
                            currentIndex: {
                                var idx = scalesColumn.categoryOptions.indexOf(scalesColumn.editCategory)
                                return idx >= 0 ? idx : 6  // default to "custom"
                            }
                            onActivated: scalesColumn.editCategory = currentText
                        }
                    }

                    Label {
                        text: "Aliases (comma-separated):"
                        font.pixelSize: 9
                    }

                    TextField {
                        id: scaleAliasesField
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        placeholderText: "e.g. Major, Ionic"
                        selectByMouse: true
                        text: scalesColumn.editAliases
                        onTextChanged: scalesColumn.editAliases = text
                    }

                    Label {
                        text: "Intervals (semitones from root, comma-separated, must start with 0):"
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: scaleIntervalsField
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        placeholderText: "e.g. 0, 2, 4, 5, 7, 9, 11"
                        selectByMouse: true
                        text: scalesColumn.editIntervals
                        onTextChanged: scalesColumn.editIntervals = text
                        enabled: !scalesColumn.editBuiltin || !scalesColumn.editing
                    }

                    // --- Live preview of scale notes ---
                    Label {
                        id: scalePreviewLabel
                        visible: scaleIntervalsField.text.trim().length > 0
                        font.pixelSize: 10
                        color: theme.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        text: {
                            var raw = scaleIntervalsField.text.trim()
                            if (!raw) return ""
                            var parts = raw.split(",")
                            var noteNames = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"]
                            var notes = []
                            for (var i = 0; i < parts.length; i++) {
                                var v = parseInt(parts[i].trim())
                                if (isNaN(v) || v < 0 || v > 11) return "Invalid interval: " + parts[i].trim()
                                notes.push(noteNames[v])
                            }
                            return "Preview (C root): " + notes.join(" - ") + "  (" + notes.length + " notes)"
                        }
                    }

                    RowLayout {
                        spacing: 6

                        Button {
                            text: scalesColumn.editing ? "Save Changes" : "Add Scale"
                            font.pixelSize: 10
                            onClicked: {
                                // Parse intervals
                                var parts = scaleIntervalsField.text.trim().split(",")
                                var intervals = []
                                for (var i = 0; i < parts.length; i++) {
                                    var v = parseInt(parts[i].trim())
                                    if (!isNaN(v)) intervals.push(v)
                                }
                                // Parse aliases
                                var aliases = []
                                if (scaleAliasesField.text.trim().length > 0) {
                                    var aliasParts = scaleAliasesField.text.trim().split(",")
                                    for (var j = 0; j < aliasParts.length; j++) {
                                        var a = aliasParts[j].trim()
                                        if (a.length > 0) aliases.push(a)
                                    }
                                }

                                var data = {
                                    id: scalesColumn.editId,
                                    name: scaleNameField.text.trim(),
                                    intervals: intervals,
                                    category: scalesColumn.editCategory,
                                    aliases: aliases
                                }

                                if (scalesColumn.editing) {
                                    settingsPanel.scaleUpdated(JSON.stringify(data))
                                } else {
                                    settingsPanel.scaleAdded(JSON.stringify(data))
                                }
                            }
                        }

                        Button {
                            text: "Clear"
                            font.pixelSize: 10
                            onClicked: {
                                scalesColumn.editing = false
                                scalesColumn.editId = ""
                                scalesColumn.editName = ""
                                scalesColumn.editAliases = ""
                                scalesColumn.editIntervals = ""
                                scalesColumn.editCategory = "custom"
                                scalesColumn.editBuiltin = false
                            }
                        }
                    }

                    // ─────────────────────────────────
                    // SECTION: Chord-Scale Mappings
                    // ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                    Label {
                        text: "CHORD-SCALE MAPPINGS"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Click a quality to edit which scales are suggested for it."
                        font.pixelSize: 9
                        color: theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Quality chips (clickable)
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: {
                                var keys = []
                                var csm = settingsPanel.chordScaleMap
                                if (csm) {
                                    for (var q in csm) keys.push(q)
                                }
                                return keys.sort()
                            }

                            Rectangle {
                                width: qualityChipLabel.implicitWidth + 12
                                height: qualityChipLabel.implicitHeight + 6
                                radius: 3
                                color: scalesColumn.mappingQuality === modelData ? theme.chipHover : theme.chipBackground
                                border.color: theme.chipBorder
                                border.width: 1

                                Label {
                                    id: qualityChipLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 10
                                    color: theme.textPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (scalesColumn.mappingQuality === modelData) {
                                            scalesColumn.showMappingEditor = false
                                            scalesColumn.mappingQuality = ""
                                            scalesColumn.mappingScaleNames = ""
                                        } else {
                                            scalesColumn.mappingQuality = modelData
                                            var csm = settingsPanel.chordScaleMap
                                            scalesColumn.mappingScaleNames = (csm[modelData] || []).join(", ")
                                            scalesColumn.showMappingEditor = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Mapping editor (shown when a quality is selected)
                    ColumnLayout {
                        visible: scalesColumn.showMappingEditor
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            text: "Scales for \"" + scalesColumn.mappingQuality + "\" (comma-separated names, in preference order):"
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        TextField {
                            id: mappingScalesField
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            selectByMouse: true
                            text: scalesColumn.mappingScaleNames
                            onTextChanged: scalesColumn.mappingScaleNames = text
                        }

                        Button {
                            text: "Save Mapping"
                            font.pixelSize: 10
                            onClicked: {
                                var parts = mappingScalesField.text.trim().split(",")
                                var names = []
                                for (var i = 0; i < parts.length; i++) {
                                    var n = parts[i].trim()
                                    if (n.length > 0) names.push(n)
                                }
                                settingsPanel.chordScaleMappingChanged(
                                    scalesColumn.mappingQuality,
                                    JSON.stringify(names)
                                )
                            }
                        }

                        // Inline status for mapping save
                        Label {
                            visible: settingsPanel.scaleStatus.length > 0
                            text: settingsPanel.scaleStatus
                            color: settingsPanel.scaleStatusColor
                            font.pixelSize: 9
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // ─────────────────────────────────
                    // SECTION: Custom Chord Qualities
                    // ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                    Label {
                        text: "CUSTOM CHORD QUALITIES"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Add custom quality names (e.g. dom7#9#5, minMaj9) to map scales to."
                        font.pixelSize: 9
                        color: theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Existing custom qualities
                    Repeater {
                        model: settingsPanel.customQualities

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: modelData
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                color: theme.textPrimary
                            }

                            Button {
                                text: "Remove"
                                font.pixelSize: 9
                                implicitWidth: 55
                                onClicked: settingsPanel.customQualityRemoved(modelData)
                            }
                        }
                    }

                    // Add new quality
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        TextField {
                            id: newQualityField
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            placeholderText: "New quality name"
                            selectByMouse: true
                        }

                        Button {
                            text: "Add"
                            font.pixelSize: 10
                            onClicked: {
                                var name = newQualityField.text.trim()
                                if (name) {
                                    settingsPanel.customQualityAdded(name)
                                    newQualityField.text = ""
                                }
                            }
                        }
                    }
                }
            }

            // ──────────────────────────────────────────
            // SUB-TAB 3: Contexts (Custom contexts)
            // ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: contextsColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: contextsColumn
                    width: parent.width - 16
                    spacing: 12

                    Label {
                        text: "CUSTOM CONTEXTS"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Create a voicing context (e.g. Solo Guitar, Bass Duo):"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        ComboBox {
                            id: contextTypeCombo
                            model: ["CM", "CV"]
                            implicitWidth: 60
                            font.pixelSize: 10
                        }

                        SpinBox {
                            id: contextStringsSpin
                            from: 4
                            to: 12
                            value: 7
                            implicitWidth: 75
                            font.pixelSize: 10
                        }

                        TextField {
                            id: contextNameField
                            Layout.fillWidth: true
                            font.pixelSize: 10
                            placeholderText: "Display name (e.g. Solo Guitar)"
                            selectByMouse: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label {
                            text: "Link tuning:"
                            font.pixelSize: 9
                            color: theme.textMuted
                        }

                        ComboBox {
                            id: contextTuningCombo
                            model: {
                                var items = ["(none)"]
                                if (tuning && tuning.tuningList) {
                                    for (var i = 0; i < tuning.tuningList.length; i++) {
                                        items.push(tuning.tuningLabels[tuning.tuningList[i]] || tuning.tuningList[i])
                                    }
                                }
                                return items
                            }
                            Layout.fillWidth: true
                            font.pixelSize: 10
                        }
                    }

                    RowLayout {
                        spacing: 6

                        Button {
                            text: "Create Context"
                            font.pixelSize: 10
                            onClicked: {
                                var code = contextTypeCombo.currentText + contextStringsSpin.value
                                var name = contextNameField.text.trim()
                                if (!name) name = contextTypeCombo.currentText + " " + contextStringsSpin.value + "-str"
                                var linkedTuning = ""
                                if (contextTuningCombo.currentIndex > 0 && tuning.tuningList) {
                                    linkedTuning = tuning.tuningList[contextTuningCombo.currentIndex - 1] || ""
                                }
                                settingsPanel.createContextRequested(code, name, contextStringsSpin.value, linkedTuning)
                            }
                        }

                        Label {
                            text: "Code: " + contextTypeCombo.currentText + contextStringsSpin.value
                            font.pixelSize: 9
                            color: "#888"
                        }
                    }

                    Label {
                        visible: settingsPanel.contextStatus.length > 0
                        text: settingsPanel.contextStatus
                        color: settingsPanel.contextStatusColor
                        font.pixelSize: 10
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
