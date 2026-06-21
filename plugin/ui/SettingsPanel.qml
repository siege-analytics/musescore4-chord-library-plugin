import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// SettingsPanel.qml — Settings tab UI (Tab 5) for the Chord Library plugin.
// Extracted from ChordLibrary.qml (A5, #98). Redesigned with sub-tabs (#142).
//
// Sub-tabs: General | Tuning | Scales | Profiles
// (Contexts sub-tab retired in #184 alongside the context axis itself.)
//
// Input state groups: tuning, theme
// Input properties: diagramPlacement, builtInTunings
// Signals: placementChanged(placement), editTuningRequested(slug),
//          deleteTuningRequested(slug), moveTuningRequested(slug, direction),
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
    property var tuningListModel: []   // explicitly set by parent after changes

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
    property string editingTuningSlug: ""  // original slug when editing (#156)

    // --- Tuning save callback (bypasses signal, #154) ---
    property var saveTuningFn: function(name, pitches, numStrings, originalSlug) {}

    // --- Output signals ---
    signal placementChanged(string placement)
    signal editTuningRequested(string slug)
    signal deleteTuningRequested(string slug)
    signal moveTuningRequested(string slug, int direction)
    signal resetBuiltInTuningRequested(string slug)
    signal createTuningRequested(string name, string pitches, int numStrings)
    signal importTuningRequested(string path)
    signal browseTuningRequested(var targetField)
    // createContextRequested retired in #184 (Contexts sub-tab removed)

    // --- Scale signals ---
    signal scaleAdded(string jsonData)
    signal scaleUpdated(string jsonData)
    signal scaleDeleted(string scaleId)
    signal chordScaleMappingChanged(string quality, string scaleIdsJson)
    signal customQualityAdded(string qualityName)
    signal customQualityRemoved(string qualityName)

    // --- Scale status ---
    property string scaleStatus: ""
    property color scaleStatusColor: "black"

    // --- Profile data from parent (#146) ---
    property var profilesData: []        // Array of profile objects from profiles.json
    property string activeProfileId: ""  // Currently active profile ID
    property string profileStatus: ""
    property color profileStatusColor: "black"

    // --- Profile signals ---
    signal profileSelected(string profileId)
    signal profileDeleted(string profileId)
    // Composition save (#170) — emitted when user saves a new composition.
    // Parent handler resolves, writes to styles.json, reloads profilesData.
    signal compositionSaveRequested(var composition)

    // Backup / restore (#172)
    signal backupExportRequested()
    signal backupRestoreRequested()
    // Import from URL (#67)
    signal urlImportRequested(string url)
    // #210 Stage 2 — voicing exclusion engine surface
    signal clearVoicingOverridesRequested()
    property var effectiveVoicingTolerances: ({})
    property int voicingOverrideCount: 0
    // #216 — per-dimension tolerance editor
    property var voicingToleranceMap: ({ modes: {}, tunings: {} })
    property var tuningIdList: []          // ["standard", "baritone", ...]
    property var tuningDisplayList: []     // ["Standard 6-String", "Baritone", ...]
    property var modeIdList: []            // ["chord-melody", ...]
    property var modeDisplayList: []       // ["Chord Melody", ...]
    property string tolEditTuning: ""      // "" = all-tunings (mode default)
    property string tolEditMode: "chord-melody"
    signal voicingToleranceChanged(string tuning, string mode, string dimension, var value)
    signal voicingTolerancesResetRequested(string tuning, string mode)
    property string backupStatus: ""
    property color backupStatusColor: "black"

    // --- Composition form state (#170) ---
    property bool compositionFormVisible: false
    property string compositionName: ""
    property var _compositionWeights: ({})   // styleId -> weight (0..2)
    property var _compositionEnabled: ({})   // styleId -> bool
    property string compositionNumericRule: "weighted-sum"
    property string compositionScaleRule: "union-priority"
    property string compositionResolution: "re-resolve"

    // Composition resolver (#195) — parent passes StyleComposer.resolve as a
    // callback so the live readout doesn't import the model directly.
    property var resolveCompositionFn: function(composition, allStyles) { return null }

    // Build a draft composition from the current form state for live preview.
    function _draftComposition() {
        var enabled = []
        var weights = {}
        var keys = Object.keys(_compositionEnabled)
        for (var i = 0; i < keys.length; i++) {
            if (_compositionEnabled[keys[i]]) {
                enabled.push(keys[i])
                weights[keys[i]] = _compositionWeights[keys[i]] || 1.0
            }
        }
        return {
            id: "_draft",
            name: compositionName,
            composedFrom: enabled,
            composition: {
                numericRule: compositionNumericRule,
                scaleRule: compositionScaleRule,
                weights: weights,
                resolution: compositionResolution
            },
            chordScaleOverrides: {},
            categoryWeights: {},
            qualityBoosts: {}
        }
    }

    // Compact readout: top-N entries by absolute magnitude, formatted "key: ±value".
    function _topByAbsMagnitude(obj, n) {
        if (!obj) return []
        var keys = Object.keys(obj)
        var pairs = []
        for (var i = 0; i < keys.length; i++) {
            pairs.push({ key: keys[i], val: obj[keys[i]] })
        }
        pairs.sort(function(a, b) { return Math.abs(b.val) - Math.abs(a.val) })
        return pairs.slice(0, n).map(function(p) {
            var sign = p.val > 0 ? "+" : ""
            return p.key + ": " + sign + p.val
        })
    }

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
            TabButton { text: "Profiles"; font.pixelSize: 10 }
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

                    // === Backup / Restore (#172) ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.preferredHeight: backupCol.implicitHeight + 16
                        radius: 4
                        color: theme.cardBackground
                        border.color: theme.cardBorder
                        border.width: 1

                        ColumnLayout {
                            id: backupCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Label {
                                text: "BACKUP / RESTORE"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            Label {
                                text: "Export your custom tunings, styles, scales, and settings to a single .json file. Import restores by merging (duplicates by id are updated)."
                                font.pixelSize: 9
                                color: theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Button {
                                    text: "Export Backup…"
                                    font.pixelSize: 10
                                    onClicked: settingsPanel.backupExportRequested()
                                }
                                Button {
                                    text: "Restore from File…"
                                    font.pixelSize: 10
                                    onClicked: settingsPanel.backupRestoreRequested()
                                }
                            }
                            // Import from URL (#67) — pull a tuning or backup pack from a URL
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                TextField {
                                    id: urlImportField
                                    Layout.fillWidth: true
                                    placeholderText: "https://raw.githubusercontent.com/…/baritone-a.json"
                                    font.pixelSize: 10
                                }
                                Button {
                                    text: "Import from URL"
                                    font.pixelSize: 10
                                    onClicked: {
                                        if (urlImportField.text.trim().length > 0) {
                                            settingsPanel.urlImportRequested(urlImportField.text.trim())
                                        }
                                    }
                                }
                            }
                            Label {
                                text: "Example packs: github.com/siege-analytics/chordlibrary-community-packs (paste any raw.githubusercontent.com URL)"
                                font.pixelSize: 8
                                color: theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            Label {
                                visible: settingsPanel.backupStatus.length > 0
                                text: settingsPanel.backupStatus
                                color: settingsPanel.backupStatusColor
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // === Voicing Tolerances (#210 Stage 2 + #216 editor) ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: tolColumn.implicitHeight + 16
                        color: theme.consoleBg
                        radius: 4
                        border.color: theme.divider

                        // Compute the effective tolerances for the (editTuning, editMode)
                        // pair from the merged voicingToleranceMap. When editTuning="",
                        // show the mode-level entry; otherwise the per-tuning entry.
                        function _tolFor(tuning, mode) {
                            var map = settingsPanel.voicingToleranceMap || {}
                            if (tuning && tuning.length > 0) {
                                var t = (map.tunings || {})[tuning]
                                if (t && t[mode]) return t[mode]
                            }
                            return ((map.modes || {})[mode]) || {}
                        }

                        property var _editTol: _tolFor(settingsPanel.tolEditTuning, settingsPanel.tolEditMode)

                        ColumnLayout {
                            id: tolColumn
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Label {
                                text: "VOICING TOLERANCES"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            Label {
                                text: "Edit thresholds per tuning and mode. Empty values fall through to mode-level defaults. Per-signature include/exclude overrides are managed via the 'Hidden voicings' lists in the Library tab and Walkthrough."
                                font.pixelSize: 9
                                color: theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            // Tuning + mode selectors
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Label { text: "Tuning:"; font.pixelSize: 9 }
                                ComboBox {
                                    id: tolTuningCombo
                                    Layout.fillWidth: true
                                    font.pixelSize: 9
                                    model: ["All tunings (mode default)"].concat(settingsPanel.tuningDisplayList)
                                    currentIndex: {
                                        if (!settingsPanel.tolEditTuning) return 0
                                        var i = settingsPanel.tuningIdList.indexOf(settingsPanel.tolEditTuning)
                                        return i >= 0 ? i + 1 : 0
                                    }
                                    onActivated: function(idx) {
                                        if (idx === 0) settingsPanel.tolEditTuning = ""
                                        else settingsPanel.tolEditTuning = settingsPanel.tuningIdList[idx - 1] || ""
                                    }
                                }
                                Label { text: "Mode:"; font.pixelSize: 9 }
                                ComboBox {
                                    id: tolModeCombo
                                    Layout.fillWidth: true
                                    font.pixelSize: 9
                                    model: settingsPanel.modeDisplayList
                                    currentIndex: Math.max(0,
                                        settingsPanel.modeIdList.indexOf(settingsPanel.tolEditMode))
                                    onActivated: function(idx) {
                                        settingsPanel.tolEditMode = settingsPanel.modeIdList[idx] || "chord-melody"
                                    }
                                }
                            }

                            // Numeric SpinBoxes
                            Grid {
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 4
                                Layout.fillWidth: true

                                Label { text: "Max fret:"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                SpinBox {
                                    from: 0; to: 24
                                    value: parent.parent.parent._editTol.maxFret !== undefined ? parent.parent.parent._editTol.maxFret : 12
                                    onValueModified: settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "maxFret", value)
                                }

                                Label { text: "Max stretch (frets):"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                SpinBox {
                                    from: 1; to: 10
                                    value: parent.parent.parent._editTol.maxStretch !== undefined ? parent.parent.parent._editTol.maxStretch : 5
                                    onValueModified: settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "maxStretch", value)
                                }

                                Label { text: "Max muted strings:"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                SpinBox {
                                    from: 0; to: 7
                                    value: parent.parent.parent._editTol.maxMutedStrings !== undefined ? parent.parent.parent._editTol.maxMutedStrings : 3
                                    onValueModified: settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "maxMutedStrings", value)
                                }

                                Label { text: "Min sounding notes:"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                SpinBox {
                                    from: 1; to: 7
                                    value: parent.parent.parent._editTol.minSoundingNotes !== undefined ? parent.parent.parent._editTol.minSoundingNotes : 3
                                    onValueModified: settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "minSoundingNotes", value)
                                }

                                Label { text: "Max difficulty tier:"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                ComboBox {
                                    id: tolDifficultyCombo
                                    model: ["standard", "advanced", "expert"]
                                    font.pixelSize: 9
                                    currentIndex: {
                                        var t = parent.parent.parent._editTol.maxDifficultyTier || "advanced"
                                        return Math.max(0, model.indexOf(t))
                                    }
                                    onActivated: function(idx) {
                                        settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "maxDifficultyTier", model[idx])
                                    }
                                }

                                Label { text: "Require root in bass:"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                CheckBox {
                                    checked: parent.parent.parent._editTol.requireRootInBass === true
                                    onToggled: settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "requireRootInBass", checked)
                                }

                                Label { text: "Allow open strings:"; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignVCenter }
                                CheckBox {
                                    checked: parent.parent.parent._editTol.allowOpenStrings !== false
                                    onToggled: settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "allowOpenStrings", checked)
                                }
                            }

                            // Excluded categories — comma-separated TextField for MVP
                            // (chip-multi-select deferred).
                            Label {
                                text: "Excluded categories (comma-separated, e.g. quartal, extended):"
                                font.pixelSize: 9
                                color: theme.textSecondary
                            }
                            TextField {
                                id: tolExcludedField
                                Layout.fillWidth: true
                                font.pixelSize: 10
                                selectByMouse: true
                                text: ((parent.parent._editTol.excludedCategories) || []).join(", ")
                                onEditingFinished: {
                                    var raw = text.split(",")
                                    var list = []
                                    for (var i = 0; i < raw.length; i++) {
                                        var s = raw[i].trim()
                                        if (s.length > 0) list.push(s)
                                    }
                                    settingsPanel.voicingToleranceChanged(settingsPanel.tolEditTuning, settingsPanel.tolEditMode, "excludedCategories", list)
                                }
                            }

                            // Footer actions
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Label {
                                    text: "User overrides set: " + settingsPanel.voicingOverrideCount
                                    font.pixelSize: 9
                                    color: theme.textSecondary
                                    Layout.fillWidth: true
                                }
                                Button {
                                    text: "Reset this (tuning, mode)"
                                    font.pixelSize: 9
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Revert all dimensions for the selected tuning + mode to file defaults."
                                    onClicked: settingsPanel.voicingTolerancesResetRequested(
                                        settingsPanel.tolEditTuning, settingsPanel.tolEditMode)
                                }
                                Button {
                                    text: "Clear signature overrides"
                                    font.pixelSize: 9
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Clear per-signature include/exclude overrides (the ones from 'Hidden voicings' lists)."
                                    enabled: settingsPanel.voicingOverrideCount > 0
                                    onClicked: settingsPanel.clearVoicingOverridesRequested()
                                }
                            }
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

                    // --- Confirmation state ---
                    property bool showDeleteConfirm: false
                    property string deleteConfirmSlug: ""
                    property string deleteConfirmName: ""
                    property bool showImportConfirm: false
                    property string importConfirmPath: ""

                    // --- Tuning list (#148) ---
                    Label {
                        text: "TUNINGS (" + settingsPanel.tuningListModel.length + ")"
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
                        model: settingsPanel.tuningListModel

                        Rectangle {
                            Layout.fillWidth: true
                            height: tuningItemRow.implicitHeight + 8
                            radius: 4
                            color: (tuning && modelData === tuning.selectedTuning)
                                ? Qt.rgba(theme.successText.r, theme.successText.g, theme.successText.b, 0.1)
                                : theme.cardBackground
                            border.color: (tuning && modelData === tuning.selectedTuning) ? theme.successText : theme.cardBorder
                            border.width: 1

                            RowLayout {
                                id: tuningItemRow
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                Label {
                                    text: (tuning && tuning.tuningLabels ? (tuning.tuningLabels[modelData] || modelData) : modelData)
                                        + (modelData === (tuning ? tuning.selectedTuning : "") ? " (active)" : "")
                                    font.pixelSize: 11
                                    font.bold: modelData === (tuning ? tuning.selectedTuning : "")
                                    color: theme.textPrimary
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: "Edit"
                                    font.pixelSize: 9
                                    implicitWidth: 36
                                    onClicked: {
                                        settingsPanel.editingTuningSlug = modelData
                                        settingsPanel.tuningNameValue = (tuning && tuning.tuningLabels ? tuning.tuningLabels[modelData] : modelData) || modelData
                                        settingsPanel.editTuningRequested(modelData)
                                    }
                                }

                                Button {
                                    text: "Del"
                                    font.pixelSize: 9
                                    implicitWidth: 30
                                    enabled: (settingsPanel.builtInTunings || []).indexOf(modelData) < 0
                                    ToolTip.visible: hovered
                                    ToolTip.text: (settingsPanel.builtInTunings || []).indexOf(modelData) >= 0
                                        ? "Built-in tunings cannot be deleted (use Reset instead)"
                                        : "Delete this tuning"
                                    onClicked: {
                                        tuningColumn.deleteConfirmSlug = modelData
                                        tuningColumn.deleteConfirmName = (tuning && tuning.tuningLabels ? tuning.tuningLabels[modelData] : modelData) || modelData
                                        tuningColumn.showDeleteConfirm = true
                                    }
                                }

                                // Reset built-ins to factory defaults (#167 follow-up)
                                Button {
                                    visible: (settingsPanel.builtInTunings || []).indexOf(modelData) >= 0
                                    text: "Reset"
                                    font.pixelSize: 9
                                    implicitWidth: 40
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Reset this built-in tuning's label and pitches to factory defaults"
                                    onClicked: settingsPanel.resetBuiltInTuningRequested(modelData)
                                }

                                Button {
                                    text: "\u25B2"
                                    font.pixelSize: 9
                                    implicitWidth: 24
                                    enabled: settingsPanel.tuningListModel.indexOf(modelData) > 0
                                    onClicked: settingsPanel.moveTuningRequested(modelData, -1)
                                }

                                Button {
                                    text: "\u25BC"
                                    font.pixelSize: 9
                                    implicitWidth: 24
                                    enabled: settingsPanel.tuningListModel.indexOf(modelData) < settingsPanel.tuningListModel.length - 1
                                    onClicked: settingsPanel.moveTuningRequested(modelData, 1)
                                }
                            }
                        }
                    }

                    // --- Delete tuning confirmation ---
                    Rectangle {
                        visible: tuningColumn.showDeleteConfirm
                        Layout.fillWidth: true
                        height: tuningConfirmCol.implicitHeight + 12
                        radius: 6
                        color: Qt.rgba(1, 0, 0, 0.08)
                        border.color: "#e74c3c"
                        border.width: 1

                        ColumnLayout {
                            id: tuningConfirmCol
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Label {
                                text: "Delete tuning \"" + tuningColumn.deleteConfirmName + "\"? This cannot be undone."
                                font.pixelSize: 10
                                font.bold: true
                                color: "#e74c3c"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6
                                Button {
                                    text: "Yes, delete"
                                    font.pixelSize: 10
                                    onClicked: {
                                        settingsPanel.deleteTuningRequested(tuningColumn.deleteConfirmSlug)
                                        tuningColumn.showDeleteConfirm = false
                                        tuningColumn.deleteConfirmSlug = ""
                                        tuningColumn.deleteConfirmName = ""
                                    }
                                }
                                Button {
                                    text: "Cancel"
                                    font.pixelSize: 10
                                    onClicked: {
                                        tuningColumn.showDeleteConfirm = false
                                        tuningColumn.deleteConfirmSlug = ""
                                        tuningColumn.deleteConfirmName = ""
                                    }
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
                            editable: true
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
                            onClicked: {
                                var name = tuningEditNameField.text.trim()
                                var pitches = tuningEditPitchesField.text.trim()
                                var strings = tuningEditStringsCount.value
                                if (!name) {
                                    settingsPanel.tuningStatus = "Enter a tuning name"
                                    settingsPanel.tuningStatusColor = "#e74c3c"
                                    return
                                }
                                if (!pitches) {
                                    settingsPanel.tuningStatus = "Enter string pitches"
                                    settingsPanel.tuningStatusColor = "#e74c3c"
                                    return
                                }
                                settingsPanel.tuningStatus = "Saving..."
                                settingsPanel.tuningStatusColor = "#888"
                                settingsPanel.saveTuningFn(name, pitches, strings, settingsPanel.editingTuningSlug)
                            }
                        }

                        Button {
                            text: "Clear"
                            font.pixelSize: 10
                            onClicked: {
                                settingsPanel.editingTuningSlug = ""
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
                            text: "Browse"
                            font.pixelSize: 10
                            onClicked: settingsPanel.browseTuningRequested(tuningImportPathField)
                        }

                        Button {
                            text: "Import"
                            font.pixelSize: 10
                            onClicked: {
                                var path = tuningImportPathField.text.trim()
                                if (!path) {
                                    settingsPanel.tuningStatus = "Enter a file path"
                                    settingsPanel.tuningStatusColor = "#e74c3c"
                                    return
                                }
                                tuningColumn.showImportConfirm = true
                                tuningColumn.importConfirmPath = path
                            }
                        }
                    }

                    // --- Import tuning confirmation ---
                    Rectangle {
                        visible: tuningColumn.showImportConfirm
                        Layout.fillWidth: true
                        height: tuningImportConfCol.implicitHeight + 12
                        radius: 6
                        color: Qt.rgba(0.2, 0.5, 1, 0.08)
                        border.color: "#2980b9"
                        border.width: 1

                        ColumnLayout {
                            id: tuningImportConfCol
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Label {
                                text: "Import tuning from \"" + (tuningColumn.importConfirmPath || "").split("/").pop() + "\"?"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#2980b9"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6
                                Button {
                                    text: "Yes, import"
                                    font.pixelSize: 10
                                    onClicked: {
                                        settingsPanel.importTuningRequested(tuningColumn.importConfirmPath)
                                        tuningColumn.showImportConfirm = false
                                        tuningColumn.importConfirmPath = ""
                                    }
                                }
                                Button {
                                    text: "Cancel"
                                    font.pixelSize: 10
                                    onClicked: {
                                        tuningColumn.showImportConfirm = false
                                        tuningColumn.importConfirmPath = ""
                                    }
                                }
                            }
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

                    // --- Local state for quality removal confirmation ---
                    property bool showQualityConfirm: false
                    property string qualityConfirmName: ""

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
                                onClicked: {
                                    scalesColumn.qualityConfirmName = modelData
                                    scalesColumn.showQualityConfirm = true
                                }
                            }
                        }
                    }

                    // --- Remove quality confirmation ---
                    Rectangle {
                        visible: scalesColumn.showQualityConfirm
                        Layout.fillWidth: true
                        height: qualityConfirmCol.implicitHeight + 12
                        radius: 6
                        color: Qt.rgba(1, 0, 0, 0.08)
                        border.color: "#e74c3c"
                        border.width: 1

                        ColumnLayout {
                            id: qualityConfirmCol
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Label {
                                text: "Remove quality \"" + scalesColumn.qualityConfirmName + "\"? Any mappings using it will be lost."
                                font.pixelSize: 10
                                font.bold: true
                                color: "#e74c3c"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6
                                Button {
                                    text: "Yes, remove"
                                    font.pixelSize: 10
                                    onClicked: {
                                        settingsPanel.customQualityRemoved(scalesColumn.qualityConfirmName)
                                        scalesColumn.showQualityConfirm = false
                                        scalesColumn.qualityConfirmName = ""
                                    }
                                }
                                Button {
                                    text: "Cancel"
                                    font.pixelSize: 10
                                    onClicked: {
                                        scalesColumn.showQualityConfirm = false
                                        scalesColumn.qualityConfirmName = ""
                                    }
                                }
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
            // SUB-TAB 3: Profiles (#146 — Style profile management)
            // ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: profilesColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: profilesColumn
                    width: parent.width - 16
                    spacing: 12

                    Label {
                        text: "STYLE PROFILES (" + settingsPanel.profilesData.length + ")"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Style profiles override chord-scale suggestions and voicing ranking. Select a profile in the Library tab."
                        font.pixelSize: 9
                        color: theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // New Composition button (#170)
                    Button {
                        text: settingsPanel.compositionFormVisible ? "Cancel Composition" : "+ New Composition…"
                        font.pixelSize: 10
                        Layout.fillWidth: false
                        onClicked: {
                            if (settingsPanel.compositionFormVisible) {
                                settingsPanel.compositionFormVisible = false
                                settingsPanel.compositionName = ""
                                settingsPanel._compositionWeights = ({})
                                settingsPanel._compositionEnabled = ({})
                            } else {
                                var w = {}
                                var e = {}
                                for (var i = 0; i < settingsPanel.profilesData.length; i++) {
                                    var p = settingsPanel.profilesData[i]
                                    if (p.composedFrom) continue
                                    if (p.id === "default") continue
                                    w[p.id] = 1.0
                                    e[p.id] = false
                                }
                                settingsPanel._compositionWeights = w
                                settingsPanel._compositionEnabled = e
                                settingsPanel.compositionFormVisible = true
                            }
                        }
                    }

                    // Composition form (#170) — visible only while creating
                    Rectangle {
                        visible: settingsPanel.compositionFormVisible
                        Layout.fillWidth: true
                        Layout.preferredHeight: compositionFormCol.implicitHeight + 16
                        radius: 6
                        color: theme.cardBackground
                        border.color: theme.cardBorder
                        border.width: 1

                        ColumnLayout {
                            id: compositionFormCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Label {
                                text: "BLEND STYLES"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: "Name:"; font.pixelSize: 10 }
                                TextField {
                                    id: compositionNameField
                                    Layout.fillWidth: true
                                    placeholderText: "e.g. Django Goes Bebop"
                                    text: settingsPanel.compositionName
                                    onTextChanged: settingsPanel.compositionName = text
                                    font.pixelSize: 10
                                }
                            }

                            Label {
                                text: "Base styles (check to include, drag slider for weight):"
                                font.pixelSize: 9
                                color: theme.textMuted
                            }

                            Repeater {
                                model: settingsPanel.profilesData
                                delegate: RowLayout {
                                    visible: !modelData.composedFrom && modelData.id !== "default"
                                    Layout.fillWidth: true
                                    spacing: 6

                                    CheckBox {
                                        text: modelData.name
                                        font.pixelSize: 10
                                        checked: settingsPanel._compositionEnabled[modelData.id] || false
                                        onToggled: {
                                            var e = Object.assign({}, settingsPanel._compositionEnabled)
                                            e[modelData.id] = checked
                                            settingsPanel._compositionEnabled = e
                                        }
                                    }
                                    Slider {
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 2
                                        stepSize: 0.1
                                        value: settingsPanel._compositionWeights[modelData.id] || 1.0
                                        enabled: settingsPanel._compositionEnabled[modelData.id] || false
                                        onMoved: {
                                            var w = Object.assign({}, settingsPanel._compositionWeights)
                                            w[modelData.id] = value
                                            settingsPanel._compositionWeights = w
                                        }
                                    }
                                    Label {
                                        text: ((settingsPanel._compositionWeights[modelData.id] || 1.0).toFixed(1))
                                        font.pixelSize: 9
                                        font.family: "Menlo, Monaco, monospace"
                                        color: theme.textMuted
                                        Layout.preferredWidth: 24
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: "Numeric rule:"; font.pixelSize: 9 }
                                ComboBox {
                                    Layout.preferredWidth: 140
                                    font.pixelSize: 9
                                    model: ["weighted-sum", "max", "average"]
                                    currentIndex: model.indexOf(settingsPanel.compositionNumericRule)
                                    onActivated: settingsPanel.compositionNumericRule = currentText
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: "Scale rule:"; font.pixelSize: 9 }
                                ComboBox {
                                    Layout.preferredWidth: 140
                                    font.pixelSize: 9
                                    model: ["union-priority", "intersect", "first-only"]
                                    currentIndex: model.indexOf(settingsPanel.compositionScaleRule)
                                    onActivated: settingsPanel.compositionScaleRule = currentText
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: "Resolution:"; font.pixelSize: 9 }
                                ComboBox {
                                    Layout.preferredWidth: 140
                                    font.pixelSize: 9
                                    model: ["re-resolve", "freeze"]
                                    currentIndex: model.indexOf(settingsPanel.compositionResolution)
                                    onActivated: settingsPanel.compositionResolution = currentText
                                }
                            }

                            // Resolved-style readout (#195). Shows what the
                            // current composition draft actually evaluates to,
                            // so users notice when two styles cancel out.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: resolvedReadoutCol.implicitHeight + 12
                                color: theme.cardBackground
                                border.color: theme.cardBorder
                                border.width: 1
                                radius: 4
                                ColumnLayout {
                                    id: resolvedReadoutCol
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 3

                                    property var _resolved: settingsPanel.resolveCompositionFn(
                                        settingsPanel._draftComposition(),
                                        settingsPanel.profilesData
                                    )

                                    Label {
                                        text: "RESOLVED PREVIEW"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: theme.textMuted
                                    }
                                    Label {
                                        property var cw: resolvedReadoutCol._resolved
                                            ? resolvedReadoutCol._resolved.categoryWeights : null
                                        property var top: settingsPanel._topByAbsMagnitude(cw, 5)
                                        visible: top.length > 0
                                        text: "category weights: " + top.join(", ")
                                        font.pixelSize: 9
                                        font.family: "Menlo, Monaco, monospace"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        property var qb: resolvedReadoutCol._resolved
                                            ? resolvedReadoutCol._resolved.qualityBoosts : null
                                        property var top: settingsPanel._topByAbsMagnitude(qb, 5)
                                        visible: top.length > 0
                                        text: "quality boosts: " + top.join(", ")
                                        font.pixelSize: 9
                                        font.family: "Menlo, Monaco, monospace"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        property var cso: resolvedReadoutCol._resolved
                                            ? resolvedReadoutCol._resolved.chordScaleOverrides : null
                                        property string summary: {
                                            if (!cso) return ""
                                            var keys = Object.keys(cso)
                                            if (keys.length === 0) return ""
                                            var parts = []
                                            for (var i = 0; i < Math.min(keys.length, 5); i++) {
                                                parts.push(keys[i] + ": " + (cso[keys[i]] || []).join(", "))
                                            }
                                            return parts.join("  ·  ")
                                        }
                                        visible: summary.length > 0
                                        text: "scales: " + summary
                                        font.pixelSize: 9
                                        font.family: "Menlo, Monaco, monospace"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        property bool empty: {
                                            var r = resolvedReadoutCol._resolved
                                            if (!r) return true
                                            return Object.keys(r.categoryWeights || {}).length === 0
                                                && Object.keys(r.qualityBoosts || {}).length === 0
                                                && Object.keys(r.chordScaleOverrides || {}).length === 0
                                        }
                                        visible: empty
                                        text: "resolved to nothing — select at least 2 styles with non-zero weights"
                                        font.pixelSize: 9
                                        font.italic: true
                                        color: theme.textMuted
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Button {
                                    text: "Save Composition"
                                    font.pixelSize: 10
                                    onClicked: {
                                        if (!settingsPanel.compositionName) {
                                            settingsPanel.profileStatus = "Name required"
                                            settingsPanel.profileStatusColor = theme.errorText
                                            return
                                        }
                                        var enabled = []
                                        var weights = {}
                                        var keys = Object.keys(settingsPanel._compositionEnabled)
                                        for (var i = 0; i < keys.length; i++) {
                                            if (settingsPanel._compositionEnabled[keys[i]]) {
                                                enabled.push(keys[i])
                                                weights[keys[i]] = settingsPanel._compositionWeights[keys[i]] || 1.0
                                            }
                                        }
                                        if (enabled.length < 2) {
                                            settingsPanel.profileStatus = "Select at least 2 base styles"
                                            settingsPanel.profileStatusColor = theme.errorText
                                            return
                                        }
                                        var id = settingsPanel.compositionName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
                                        var composition = {
                                            id: id,
                                            name: settingsPanel.compositionName,
                                            description: "Blend of " + enabled.join(" + "),
                                            builtin: false,
                                            composedFrom: enabled,
                                            composition: {
                                                numericRule: settingsPanel.compositionNumericRule,
                                                scaleRule: settingsPanel.compositionScaleRule,
                                                weights: weights,
                                                resolution: settingsPanel.compositionResolution
                                            },
                                            chordScaleOverrides: {},
                                            categoryWeights: {},
                                            qualityBoosts: {}
                                        }
                                        settingsPanel.compositionSaveRequested(composition)
                                        settingsPanel.compositionFormVisible = false
                                        settingsPanel.compositionName = ""
                                    }
                                }
                                Button {
                                    text: "Cancel"
                                    font.pixelSize: 10
                                    onClicked: settingsPanel.compositionFormVisible = false
                                }
                            }
                        }
                    }

                    Label {
                        visible: settingsPanel.profileStatus.length > 0
                        text: settingsPanel.profileStatus
                        color: settingsPanel.profileStatusColor
                        font.pixelSize: 10
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: settingsPanel.profilesData

                        Rectangle {
                            Layout.fillWidth: true
                            height: profileItemCol.implicitHeight + 12
                            radius: 4
                            color: modelData.id === settingsPanel.activeProfileId
                                ? Qt.rgba(theme.successText.r, theme.successText.g, theme.successText.b, 0.1)
                                : theme.cardBackground
                            border.color: modelData.id === settingsPanel.activeProfileId ? theme.successText : theme.cardBorder
                            border.width: 1

                            ColumnLayout {
                                id: profileItemCol
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Label {
                                        text: modelData.name + (modelData.id === settingsPanel.activeProfileId ? " (active)" : "")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: theme.textPrimary
                                        Layout.fillWidth: true
                                    }

                                    Button {
                                        text: "Activate"
                                        font.pixelSize: 9
                                        implicitWidth: 55
                                        enabled: modelData.id !== settingsPanel.activeProfileId
                                        onClicked: settingsPanel.profileSelected(modelData.id)
                                    }
                                }

                                Label {
                                    text: modelData.description || ""
                                    font.pixelSize: 9
                                    color: theme.textSecondary
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                // Show overrides summary
                                Label {
                                    visible: modelData.chordScaleOverrides && Object.keys(modelData.chordScaleOverrides).length > 0
                                    text: {
                                        if (!modelData.chordScaleOverrides) return ""
                                        var keys = Object.keys(modelData.chordScaleOverrides)
                                        return "Scale overrides: " + keys.join(", ")
                                    }
                                    font.pixelSize: 8
                                    font.italic: true
                                    color: theme.successText
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                // Show weight summary
                                Label {
                                    visible: modelData.categoryWeights && Object.keys(modelData.categoryWeights).length > 0
                                    text: {
                                        if (!modelData.categoryWeights) return ""
                                        var parts = []
                                        for (var cat in modelData.categoryWeights) {
                                            var w = modelData.categoryWeights[cat]
                                            parts.push(cat + (w > 0 ? "+" : "") + w)
                                        }
                                        return "Category weights: " + parts.join(", ")
                                    }
                                    font.pixelSize: 8
                                    color: theme.textMuted
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
