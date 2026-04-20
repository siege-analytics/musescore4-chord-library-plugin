import QtQuick 2.15
import "ChordSelector.js" as ChordSelector
import "MelodyEngine.js" as MelodyEngine
import "Transposer.js" as Transposer
import "DiagramEngine.js" as DiagramEngine
import "ChordScales.js" as ChordScales
import "FingeringEngine.js" as FingeringEngine

// BatchEngine.qml — Walkthrough/batch voicing state machine.
// Extracted from ChordLibrary.qml (B1, #100).
//
// Manages: chord symbol scanning, voicing selection, alternative browsing,
// bass string grouping, revoicing, voice-2 writing, clipboard XML generation.
//
// Requires MuseScore API context (curScore, Element types, newElement) —
// must be instantiated inside a MuseScore plugin, not as .pragma library.

Item {
    id: batchEngine

    // === External dependencies (wired from parent) ===

    // MuseScore plugin root — needed for newElement() and Element.* constants
    property var pluginRef: null

    // MuseScore API — parent passes these; null when no score is open
    property var curScore: null
    property var tempDiagramFile: null   // FileIO for paste-clipboard.xml
    property string clipboardXmlPath: "" // Qt.resolvedUrl("paste-clipboard.xml")

    // Voicing data + filter state (read from parent bindings)
    property var voicingsData: []
    property string filterContext: ""
    property string filterCategory: ""
    property int tuningMaxStrings: 6
    property var contextStringCounts: ({})
    property var tuningMidi: ({})
    property bool usingTuningVoicings: false
    property int tuningOffset: 0

    // Melody/bass preferences
    property bool melodyOnTop: false
    property int melodyStaffIdx: -1
    property bool writeVoice2: false
    property string melodyOverrideText: ""  // from LibraryPanel's melodyOverrideField

    // Mode axis (#164) — parent passes activeMode id + resolved modeConfig object
    property string activeMode: "chord-melody"
    property var modeConfig: null
    // Section resolver (#167) — parent callback: (chordIdx) -> modeId
    // When set, overrides activeMode per-chord based on score sections.
    property var modeIdResolverFn: null
    // Section resolver (#167) — parent callback: (chordIdx) -> modeConfig object
    property var modeConfigResolverFn: null

    // === Batch state (managed internally, exposed for WalkthroughPanel) ===

    property var batchQueue: []
    property int batchTotal: 0
    property var batchChords: []     // [{text, root, quality, voicing, melodyMidi, bassMidi, tick, ambiguous}, ...]
    property int batchIndex: 0       // 1-indexed after batchShowNext increments
    property var lastInsertedVoicing: null

    // Alternative voicing state — grouped by bass string
    property var altVoicings: []
    property int altCount: 0
    property int altIndex: 0
    property var bassStringGroups: ({})
    property var bassStringList: []
    property int selectedBassString: -1

    // === Signals (handled by parent) ===

    signal statusMessage(string text, string colorName)
    signal showWalkthrough(string title, string content)
    signal walkthroughComplete(int total)
    signal walkthroughDataChanged()  // batchChords updated, parent should refresh WalkthroughPanel
    signal insertDiagramRequested(var voicing)  // single voicing insertion (Voice Here)

    // === Internal state ===

    property bool _melodyLocked: false
    property bool _bassLocked: false

    // === Public API ===

    function parseChordSymbol(text) {
        return ChordSelector.parseChordSymbol(text)
    }

    function _selectorOpts(melodyMidi, bassMidi, chordIdx) {
        // Section-aware mode resolution (#167). If resolver callbacks are wired,
        // use them to pick the mode for this chord index; otherwise fall back to
        // the score-level activeMode + modeConfig.
        var effectiveModeId = activeMode
        var effectiveModeConfig = modeConfig
        if (typeof chordIdx === "number" && modeIdResolverFn && modeConfigResolverFn) {
            effectiveModeId = modeIdResolverFn(chordIdx) || activeMode
            effectiveModeConfig = modeConfigResolverFn(chordIdx) || modeConfig
        }
        return {
            maxStrings: tuningMaxStrings,
            filterContext: filterContext,
            contextStringCounts: contextStringCounts,
            filterCategory: filterCategory,
            melodyMidi: melodyMidi,
            bassMidi: bassMidi,
            melodyLocked: _melodyLocked || melodyOnTop,
            bassLocked: _bassLocked,
            lastInsertedVoicing: lastInsertedVoicing,
            topNoteFn: MelodyEngine.voicingTopNoteSemitone,
            bassNoteFn: MelodyEngine.voicingBassNoteSemitone,
            distanceFn: MelodyEngine.voicingDistance,
            difficultyFn: FingeringEngine.computeDifficulty,
            semitoneMap: Transposer.SEMITONE_MAP,
            profileCategoryWeightFn: ChordScales.getProfileCategoryWeight,
            profileQualityBoostFn: ChordScales.getProfileQualityBoost,
            modeConfig: effectiveModeConfig,
            modeId: effectiveModeId
        }
    }

    function findBestVoicing(targetRoot, quality, melodyMidi, bassMidi, chordIdx) {
        return ChordSelector.findBestVoicing(voicingsData, targetRoot, quality,
            _selectorOpts(melodyMidi, bassMidi, chordIdx))
    }

    function findAllVoicings(targetRoot, quality, melodyMidi, bassMidi, chordIdx) {
        return ChordSelector.findAllVoicings(voicingsData, targetRoot, quality,
            _selectorOpts(melodyMidi, bassMidi, chordIdx))
    }

    function _diagramOpts() {
        return { usingTuningVoicings: usingTuningVoicings, tuningOffset: tuningOffset, semitoneOffsetFn: Transposer.semitoneOffset }
    }

    function generateXmlForVoicing(voicing, targetRoot) {
        return DiagramEngine.generateXmlForVoicing(voicing, targetRoot, _diagramOpts())
    }

    function computeVoicingMidiPitches(voicing, targetRoot) {
        var opts = _diagramOpts()
        opts.tuningMidi = tuningMidi
        return DiagramEngine.computeVoicingMidiPitches(voicing, targetRoot, opts)
    }

    function melodyOverrideMidi() {
        if (!melodyOnTop) return -1
        return MelodyEngine.parseNoteToSemitone(melodyOverrideText || "", Transposer.SEMITONE_MAP)
    }

    // --- Bass string navigation ---

    function buildBassStringGroups() {
        var result = ChordSelector.buildBassStringGroups(altVoicings)
        bassStringGroups = result.groups
        bassStringList = result.list
    }

    // Filtered group for current bass string (melody-filtered when locked)
    property var _currentGroup: []

    function selectBassString(bassStr) {
        selectedBassString = bassStr
        var group = bassStringGroups[bassStr] || []

        // When melody is locked, filter group to only melody-matching voicings
        var item = batchChords[batchIndex - 1]
        if (item && item.melodyMidi >= 0 && (_melodyLocked || melodyOnTop) && group.length > 0) {
            var melodyTarget = item.melodyMidi % 12
            var filtered = []
            for (var gi = 0; gi < group.length; gi++) {
                var topSemi = MelodyEngine.voicingTopNoteSemitone(group[gi], item.root, Transposer.SEMITONE_MAP)
                if (topSemi === melodyTarget) {
                    filtered.push(group[gi])
                }
            }
            _currentGroup = filtered.length > 0 ? filtered : group  // fallback if no match
        } else {
            _currentGroup = group
        }

        if (_currentGroup.length > 0) {
            applyAlternativeVoicing(_currentGroup[0])
            altIndex = 0
        }
        altCount = _currentGroup.length
    }

    function selectAlternativeVoicing(index) {
        if (index < 0 || index >= _currentGroup.length) return
        altIndex = index
        applyAlternativeVoicing(_currentGroup[index])
    }

    function applyAlternativeVoicing(voicing) {
        var item = batchChords[batchIndex - 1]
        if (!item) return
        item.voicing = voicing

        // Update clipboard
        var xml = generateXmlForVoicing(voicing, item.root)
        if (tempDiagramFile) {
            tempDiagramFile.source = clipboardXmlPath
            try { tempDiagramFile.write(xml) } catch (e) {}
        }

        // Refresh display
        batchEngine.walkthroughDataChanged()
    }

    // --- Voice a single chord at cursor ---

    function voiceAtCursor() {
        if (!curScore) {
            batchEngine.statusMessage("No score open", "error")
            return
        }

        var sel = curScore.selection
        if (!sel || !sel.elements || sel.elements.length === 0) {
            batchEngine.statusMessage("Select a note or rest at a chord symbol", "error")
            return
        }

        var elem = sel.elements[0]
        var seg = null
        if (elem.type === Element.NOTE && elem.parent)
            seg = elem.parent.parent
        else if (elem.type === Element.REST || elem.type === Element.CHORD)
            seg = elem.parent

        if (!seg || !seg.annotations) {
            batchEngine.statusMessage("No chord symbol at selection", "error")
            return
        }

        var chordText = null
        for (var a = 0; a < seg.annotations.length; a++) {
            if (seg.annotations[a].type === Element.HARMONY) {
                chordText = seg.annotations[a].text
                break
            }
        }

        if (!chordText) {
            batchEngine.statusMessage("No chord symbol at selection", "error")
            return
        }

        var parsed = parseChordSymbol(chordText)
        if (!parsed) {
            batchEngine.statusMessage("Could not parse: " + chordText, "error")
            return
        }

        var melodyMidi = melodyOverrideMidi()
        if (melodyMidi < 0 && melodyOnTop) {
            var chordElem = null
            if (elem.type === Element.NOTE && elem.parent)
                chordElem = elem.parent
            else if (elem.type === Element.CHORD)
                chordElem = elem
            if (chordElem && chordElem.notes) {
                for (var n = 0; n < chordElem.notes.length; n++) {
                    if (chordElem.notes[n].pitch > melodyMidi)
                        melodyMidi = chordElem.notes[n].pitch
                }
            }
        }

        var bassMidi = parsed.slashBass
            ? Transposer.SEMITONE_MAP[parsed.slashBass]
            : undefined

        var voicing = findBestVoicing(parsed.root, parsed.quality, melodyMidi, bassMidi)
        if (!voicing) {
            batchEngine.statusMessage("No voicing found for " + chordText, "error")
            return
        }

        batchEngine.insertDiagramRequested(voicing)
    }

    // --- Batch insert (Voice All) ---

    function batchInsert() {
        if (!curScore) {
            batchEngine.statusMessage("No score open", "error")
            return
        }

        var chords = []
        var lastMelodyMidi = -1
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)

        var melodyCursor = null
        if (melodyStaffIdx >= 0 && melodyOnTop) {
            melodyCursor = curScore.newCursor()
            melodyCursor.staffIdx = melodyStaffIdx
            melodyCursor.voice = 0
            melodyCursor.rewind(0)
        }

        while (cursor.segment) {
            if (cursor.segment.annotations) {
                for (var a = 0; a < cursor.segment.annotations.length; a++) {
                    if (cursor.segment.annotations[a].type === Element.HARMONY) {
                        var text = cursor.segment.annotations[a].text
                        var parsed = parseChordSymbol(text)
                        if (parsed) {
                            var melodyMidi = melodyOverrideMidi()

                            if (melodyMidi < 0 && melodyOnTop && melodyCursor) {
                                while (melodyCursor.segment && melodyCursor.tick < cursor.tick) {
                                    melodyCursor.next()
                                }
                                if (melodyCursor.segment && melodyCursor.tick === cursor.tick) {
                                    if (melodyCursor.element && melodyCursor.element.type === Element.CHORD) {
                                        var melNotes = melodyCursor.element.notes
                                        for (var mn = 0; mn < melNotes.length; mn++) {
                                            if (melNotes[mn].pitch > melodyMidi)
                                                melodyMidi = melNotes[mn].pitch
                                        }
                                    }
                                }
                            }

                            if (melodyMidi < 0 && melodyOnTop) {
                                if (cursor.element && cursor.element.type === Element.CHORD) {
                                    var notes0 = cursor.element.notes
                                    for (var n0 = 0; n0 < notes0.length; n0++) {
                                        if (notes0[n0].pitch > melodyMidi) melodyMidi = notes0[n0].pitch
                                    }
                                }
                                if (melodyMidi < 0 && cursor.segment && cursor.segment.elementAt) {
                                    for (var voice = 0; voice < 4 && melodyMidi < 0; voice++) {
                                        var el = cursor.segment.elementAt(voice)
                                        if (el && el.type === Element.CHORD && el.notes) {
                                            for (var nv = 0; nv < el.notes.length; nv++) {
                                                if (el.notes[nv].pitch > melodyMidi)
                                                    melodyMidi = el.notes[nv].pitch
                                            }
                                        }
                                    }
                                }
                            }

                            if (melodyOnTop && melodyMidi < 0 && lastMelodyMidi >= 0) {
                                melodyMidi = lastMelodyMidi
                            }
                            if (melodyMidi >= 0) lastMelodyMidi = melodyMidi

                            var bassMidi
                            if (parsed.slashBass) {
                                bassMidi = Transposer.SEMITONE_MAP[parsed.slashBass]
                                if (bassMidi === undefined) bassMidi = MelodyEngine.suggestBassNote(parsed.root, parsed.quality, Transposer.SEMITONE_MAP)
                            } else {
                                bassMidi = MelodyEngine.suggestBassNote(parsed.root, parsed.quality, Transposer.SEMITONE_MAP)
                            }

                            // Pass the about-to-be-assigned chord index so section-aware
                            // mode resolution (#167) picks the right mode for each chord.
                            var voicing = findBestVoicing(parsed.root, parsed.quality, melodyMidi, bassMidi, chords.length)
                            if (voicing) {
                                chords.push({
                                    text: text,
                                    root: parsed.root,
                                    quality: parsed.quality,
                                    voicing: voicing,
                                    melodyMidi: melodyMidi,
                                    bassMidi: bassMidi,
                                    tick: cursor.tick,
                                    ambiguous: parsed.ambiguous || false,
                                })
                            }
                        }
                    }
                }
            }
            cursor.next()
        }

        if (chords.length === 0) {
            batchEngine.statusMessage("No matching chord symbols found", "error")
            return
        }

        batchChords = chords
        batchIndex = 0
        batchTotal = chords.length
        batchQueue = [1]

        batchShowNext()
    }

    property int _lastShownIndex: -1  // tracks which chord was last displayed

    function batchShowNext() {
        // Only reset locks when advancing to a NEW chord (not re-displaying after revoice)
        if (batchIndex !== _lastShownIndex) {
            _melodyLocked = false
            _bassLocked = false
        }

        if (batchIndex >= batchChords.length) {
            batchQueue = []
            batchEngine.walkthroughComplete(batchTotal)
            return
        }

        var item = batchChords[batchIndex]
        var nameParts = item.voicing.name.split(" — ")
        var shape = nameParts.length > 1 ? nameParts.slice(1).join(" — ") : item.voicing.category

        // Load alternatives and group by bass string
        altVoicings = findAllVoicings(item.root, item.quality, item.melodyMidi, item.bassMidi)
        buildBassStringGroups()

        // Auto-select the bass string group containing the current voicing
        selectedBassString = -1
        for (var bsi = 0; bsi < bassStringList.length; bsi++) {
            var bsGroup = bassStringGroups[bassStringList[bsi]] || []
            for (var bvi = 0; bvi < bsGroup.length; bvi++) {
                if (bsGroup[bvi].id === item.voicing.id) {
                    selectedBassString = bassStringList[bsi]
                    altIndex = bvi
                    break
                }
            }
            if (selectedBassString >= 0) break
        }
        if (selectedBassString < 0 && bassStringList.length > 0) {
            selectedBassString = bassStringList[0]
            altIndex = 0
        }
        altCount = (bassStringGroups[selectedBassString] || []).length

        // Write clipboard XML
        var xml = generateXmlForVoicing(item.voicing, item.root)
        if (tempDiagramFile) {
            tempDiagramFile.source = clipboardXmlPath
            try {
                tempDiagramFile.write(xml)
            } catch (e) {
                batchEngine.statusMessage("Failed to write clipboard: " + e, "error")
                return
            }
        }

        // Write voice 2 if enabled
        if (writeVoice2 && item.tick !== undefined && curScore) {
            curScore.startCmd()
            writeVoicingToVoice2(item.voicing, item.root, item.tick)
            curScore.endCmd()
        }

        // Build step text
        var stepText = "▸ " + item.text + " — " + shape
        if (item.ambiguous) {
            stepText += "\n  ⚠ \"" + item.text + "\" is ambiguous — defaulting to " + item.root + "7."
            stepText += "\n     Use the chips above to change quality."
        }
        if (melodyOnTop && item.melodyMidi >= 0) {
            stepText += "\n  Melody: " + MelodyEngine.melodyNoteName(item.melodyMidi)
        }
        if (item.bassMidi >= 0) {
            stepText += "\n  Bass: " + MelodyEngine.melodyNoteName(item.bassMidi)
        }
        if (item._warnings && item._warnings.length > 0) {
            stepText += "\n"
            for (var w = 0; w < item._warnings.length; w++) {
                stepText += "\n  ⚠ " + item._warnings[w]
            }
        }

        // Scales are shown as clickable chips in WalkthroughPanel — not duplicated in text

        var remaining = batchChords.length - batchIndex
        stepText += "\n"
        stepText += "\n  1. Click the note/rest at the " + item.text + " chord symbol"
        stepText += "\n  2. Press ⌘V to paste the fretboard diagram"
        stepText += "\n  3. Click 'Next →' when ready"

        if (remaining > 1) {
            stepText += "\n\n" + (remaining - 1) + " chord" + (remaining > 2 ? "s" : "") + " remaining"
        }

        _lastShownIndex = batchIndex
        batchIndex++
        batchEngine.showWalkthrough("Voice Score — " + item.text, stepText)
    }

    // --- Revoice current step ---

    function revoiceCurrentStepWith(melodyNoteText, melodyLocked, bassNoteText, bassLocked, categoryOverride) {
        var idx = batchIndex - 1
        if (idx < 0 || idx >= batchChords.length) return

        var item = batchChords[idx]

        var newMidi = MelodyEngine.parseNoteToSemitone(melodyNoteText, Transposer.SEMITONE_MAP)
        if (newMidi < 0) newMidi = item.melodyMidi
        item.melodyMidi = newMidi

        var newBass = MelodyEngine.parseNoteToSemitone(bassNoteText, Transposer.SEMITONE_MAP)
        if (newBass < 0) newBass = MelodyEngine.suggestBassNote(item.root, item.quality, Transposer.SEMITONE_MAP)
        item.bassMidi = newBass

        _melodyLocked = melodyLocked || false
        _bassLocked = bassLocked || false

        var savedCategory = filterCategory
        filterCategory = categoryOverride

        // batchIndex is 1-based after the increment in batchShowNext; use idx-1.
        var newVoicing = findBestVoicing(item.root, item.quality, newMidi, newBass, Math.max(0, batchIndex - 1))

        filterCategory = savedCategory

        if (!newVoicing) {
            batchEngine.showWalkthrough("Voice Score — " + item.text,
                "No voicing found for " + item.text
                + " with these settings.\n\nTry changing the Type, Bass note,"
                + " or adjust Voicing Constraints in Score Tools.")
            return
        }

        // Track unfulfilled requests
        var warnings = []
        var userRequestedBass = MelodyEngine.parseNoteToSemitone(bassNoteText, Transposer.SEMITONE_MAP)
        if (userRequestedBass >= 0) {
            var actualBass = MelodyEngine.voicingBassNoteSemitone(newVoicing, item.root, Transposer.SEMITONE_MAP)
            if (actualBass >= 0 && actualBass !== userRequestedBass) {
                warnings.push("No playable " + item.text + " with "
                    + MelodyEngine.NOTE_NAMES[userRequestedBass] + " in bass on this tuning."
                    + "\n     Offering alternative: " + MelodyEngine.NOTE_NAMES[actualBass]
                    + " in bass. Try adjusting stretch or mute limits in Score Tools.")
            }
        }

        var userRequestedMelody = MelodyEngine.parseNoteToSemitone(melodyNoteText, Transposer.SEMITONE_MAP)
        if (userRequestedMelody >= 0) {
            var actualTop = MelodyEngine.voicingTopNoteSemitone(newVoicing, item.root, Transposer.SEMITONE_MAP)
            if (actualTop >= 0 && actualTop !== userRequestedMelody) {
                warnings.push("No playable " + item.text + " with "
                    + MelodyEngine.NOTE_NAMES[userRequestedMelody] + " on top on this tuning."
                    + "\n     Offering alternative: " + MelodyEngine.NOTE_NAMES[actualTop]
                    + " on top.")
            }
        }

        item._warnings = warnings
        item.voicing = newVoicing

        // Regenerate clipboard XML
        var xml = generateXmlForVoicing(newVoicing, item.root)
        if (tempDiagramFile) {
            tempDiagramFile.source = clipboardXmlPath
            try { tempDiagramFile.write(xml) } catch (e) {}
        }

        // Lock states persist until next chord (batchShowNext) —
        // so bass string selection respects the user's lock preference

        // Rewind and re-show
        batchIndex = idx
        batchShowNext()
    }

    // --- Reharmonization (called from WalkthroughPanel reharmSelected signal) ---

    function applyReharm(newRoot, newQuality) {
        var idx = batchIndex - 1
        if (idx < 0 || idx >= batchChords.length) return
        var item = batchChords[idx]
        item.root = newRoot
        item.quality = newQuality
        item.ambiguous = false

        item.text = newRoot + (newQuality === "dom7" ? "7" : newQuality === "min7" ? "m7" : newQuality === "maj7" ? "maj7" : newQuality === "dim7" ? "dim7" : newQuality === "min6" ? "m6" : newQuality === "sus4" ? "sus4" : newQuality === "maj6" ? "6" : newQuality === "maj" ? "" : newQuality)
        item.bassMidi = MelodyEngine.suggestBassNote(newRoot, newQuality, Transposer.SEMITONE_MAP)

        var voicing = findBestVoicing(newRoot, newQuality, item.melodyMidi, item.bassMidi, Math.max(0, batchIndex - 1))
        if (voicing) {
            item.voicing = voicing
            var xml = generateXmlForVoicing(voicing, newRoot)
            if (tempDiagramFile) {
                tempDiagramFile.source = clipboardXmlPath
                try { tempDiagramFile.write(xml) } catch (e) {}
            }
        }

        batchIndex = idx
        batchShowNext()
    }

    // --- Voice 2 writing ---

    function writeVoicingToVoice2(voicing, targetRoot, targetTick) {
        if (!curScore) return false
        var pitches = computeVoicingMidiPitches(voicing, targetRoot)
        if (pitches.length === 0) return false

        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 1
        cursor.rewind(0)

        while (cursor.segment && cursor.tick < targetTick) {
            cursor.next()
        }

        if (!cursor.segment || cursor.tick !== targetTick) {
            console.log("Voice2 export: could not find tick " + targetTick)
            return false
        }

        var v1cursor = curScore.newCursor()
        v1cursor.staffIdx = 0
        v1cursor.voice = 0
        v1cursor.rewind(0)
        while (v1cursor.segment && v1cursor.tick < targetTick) v1cursor.next()
        if (v1cursor.element && v1cursor.element.duration) {
            cursor.setDuration(v1cursor.element.duration.numerator, v1cursor.element.duration.denominator)
        }

        cursor.addNote(pitches[0])

        cursor.prev()
        if (cursor.element && cursor.element.type === Element.CHORD) {
            for (var i = 1; i < pitches.length; i++) {
                var note = pluginRef.newElement(Element.NOTE)
                note.pitch = pitches[i]
                note.tpc1 = DiagramEngine.pitchToTpc(pitches[i])
                note.tpc2 = note.tpc1
                cursor.element.add(note)
            }
        }

        return true
    }
}
