import QtQuick 2.15
import "Transposer.js" as Transposer

// InsertionEngine.qml — Diagram insertion and voicing playback.
// Extracted from ChordLibrary.qml (B4, #103).
//
// Handles: setDot API probe, direct insertion, clipboard workaround
// fallback, MIDI playback via ms-audio agent.
//
// The clipboard workaround writes XML to paste-clipboard.xml, which a
// launchd agent picks up and writes to the macOS pasteboard. A QML Timer
// in the parent then fires cmd("paste") to insert the diagram.

Item {
    id: insertionEngine

    // === External dependencies ===
    property var curScore: null
    property var tempDiagramFile: null    // FileIO for paste-clipboard.xml
    property var audioFile: null          // FileIO for MIDI playback
    property var pasteTimer: null         // Timer that fires cmd("paste")
    property string diagramPlacement: "above"
    property var tuningMidi: ({})
    property bool sortByProximity: false

    // Callback functions from parent
    property var generateXmlFn: function(voicing, root) { return "" }
    property var applyFiltersFn: function() {}

    // State shared with parent
    property var lastInsertedVoicing: null
    property var _pendingVoicing: null
    property var _hasSetDot: null

    // === Signals ===
    signal statusMessage(string text, string colorType)
    signal voicingInserted(var voicing)  // for proximity sort update

    // === Public API ===

    function insertVoicing(voicing) {
        if (!curScore) {
            insertionEngine.statusMessage("No score open", "error")
            return
        }

        var selection = curScore.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            insertionEngine.statusMessage("Select a note or rest first", "error")
            return
        }

        var targetRoot = null
        var selectedElement = selection.elements[0]
        var segment = null

        if (selectedElement.type === Element.NOTE) {
            var ch = selectedElement.parent
            if (ch) segment = ch.parent
        } else if (selectedElement.type === Element.REST) {
            segment = selectedElement.parent
        } else if (selectedElement.type === Element.CHORD) {
            segment = selectedElement.parent
        }

        if (segment && segment.annotations) {
            for (var a = 0; a < segment.annotations.length; a++) {
                if (segment.annotations[a].type === Element.HARMONY) {
                    targetRoot = Transposer.extractRoot(segment.annotations[a].text)
                    break
                }
            }
        }

        if (!targetRoot) targetRoot = voicing.root

        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)

        var targetTick = -1
        if (segment) {
            targetTick = segment.tick
        } else if (selectedElement.type === Element.NOTE) {
            var parentChord = selectedElement.parent
            if (parentChord && parentChord.parent) {
                targetTick = parentChord.parent.tick
            }
        }

        if (targetTick < 0) {
            insertionEngine.statusMessage("Could not determine position. Select a note or rest.", "error")
            return
        }

        curScore.startCmd()

        var fd = newElement(Element.FRET_DIAGRAM)
        fd.fretStrings = voicing.strings || 6
        fd.fretFrets = voicing.visible_frets || 4
        fd.fretOffset = voicing.fret_number + offset - 1

        if (typeof Placement !== "undefined") {
            if (diagramPlacement === "below") {
                fd.placement = Placement.BELOW
            } else {
                fd.placement = Placement.ABOVE
            }
        }

        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)

        while (cursor.segment && cursor.tick < targetTick) {
            cursor.next()
        }

        cursor.add(fd)
        curScore.endCmd()

        var transposed = Transposer.transposeVoicing(voicing, targetRoot)
        insertionEngine.statusMessage("Inserted " + transposed.name
            + " [" + transposed.notes.join(" ") + "]"
            + " (" + diagramPlacement + " staff)", "success")
    }

    // --- setDot API probe ---

    function hasSetDotApi() {
        if (_hasSetDot !== null) return _hasSetDot
        try {
            var fd = newElement(Element.FRET_DIAGRAM)
            _hasSetDot = (typeof fd.setDot === "function")
            if (_hasSetDot)
                console.log("setDot() API detected — using direct insertion")
            else
                console.log("setDot() not available — using clipboard workaround")
        } catch (e) {
            console.log("Could not probe setDot(): " + e)
            _hasSetDot = false
        }
        return _hasSetDot
    }

    function insertDirect(voicing, targetRoot) {
        if (!hasSetDotApi()) return false
        if (!curScore) return false

        var numStrings = voicing.strings || 6
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)

        try {
            curScore.startCmd()

            var fd = newElement(Element.FRET_DIAGRAM)
            fd.fretStrings = numStrings
            fd.fretFrets = voicing.visible_frets || 4
            fd.fretOffset = voicing.fret_number + offset - 1

            var dots = voicing.dots || []
            for (var d = 0; d < dots.length; d++) {
                var msStr = numStrings - dots[d].string
                fd.setDot(msStr, dots[d].fret, 0)
            }

            var mutes = voicing.mutes || []
            for (var m = 0; m < mutes.length; m++) {
                var msMute = numStrings - mutes[m]
                fd.setMarker(msMute, 1)
            }
            var opens = voicing.open || []
            for (var o = 0; o < opens.length; o++) {
                var msOpen = numStrings - opens[o]
                fd.setMarker(msOpen, 2)
            }

            var cursor = curScore.newCursor()
            cursor.rewind(1)
            cursor.add(fd)

            curScore.endCmd()
            return true
        } catch (e) {
            try { curScore.endCmd() } catch (ignore) {}
            console.log("setDot() insert failed: " + e + " — falling back to clipboard")
            _hasSetDot = null
            return false
        }
    }

    // --- Main entry point: try setDot, fall back to clipboard ---

    function generateDiagramFile(voicing) {
        var targetRoot = voicing.root
        if (curScore) {
            var sel = curScore.selection
            if (sel && sel.elements && sel.elements.length > 0) {
                var elem = sel.elements[0]
                var seg = null
                if (elem.type === Element.NOTE && elem.parent)
                    seg = elem.parent.parent
                else if (elem.type === Element.REST || elem.type === Element.CHORD)
                    seg = elem.parent
                if (seg && seg.annotations) {
                    for (var a = 0; a < seg.annotations.length; a++) {
                        if (seg.annotations[a].type === Element.HARMONY) {
                            var parsed = Transposer.extractRoot(seg.annotations[a].text)
                            if (parsed) targetRoot = parsed
                            break
                        }
                    }
                }
            }
        }

        var transposed = Transposer.transposeVoicing(voicing, targetRoot)
        var displayName = transposed.name

        // Try direct insertion via setDot() API first
        if (insertDirect(voicing, targetRoot)) {
            lastInsertedVoicing = voicing
            insertionEngine.voicingInserted(voicing)
            insertionEngine.statusMessage("Inserted " + displayName
                + " [" + transposed.notes.join(" ") + "]", "success")
            return
        }

        // Fall back to clipboard workaround
        var xml = generateXmlFn(voicing, targetRoot)

        var xmlPath = Qt.resolvedUrl("../paste-clipboard.xml")
        if (tempDiagramFile) {
            tempDiagramFile.source = xmlPath
            try {
                tempDiagramFile.write(xml)
            } catch (e) {
                insertionEngine.statusMessage("Failed to write clipboard XML: " + e, "error")
                return
            }
        }

        _pendingVoicing = voicing
        if (pasteTimer) pasteTimer.start()

        insertionEngine.statusMessage("Pasting " + displayName + " [" + transposed.notes.join(" ") + "]...", "success")
    }

    // --- MIDI playback ---

    function playVoicing(voicing, mode) {
        if (!mode) mode = "chord"

        var midiNotes = []
        var dots = voicing.dots || []
        for (var d = 0; d < dots.length; d++) {
            var strMidi = tuningMidi[String(dots[d].string)]
            if (strMidi !== undefined) {
                var absFret = voicing.fret_number + (dots[d].fret - 1)
                midiNotes.push(strMidi + absFret)
            }
        }
        var opens = voicing.open || []
        for (var o = 0; o < opens.length; o++) {
            var openMidi = tuningMidi[String(opens[o])]
            if (openMidi !== undefined) {
                midiNotes.push(openMidi)
            }
        }

        if (midiNotes.length === 0) return

        var request = JSON.stringify({
            notes: midiNotes,
            duration: 1.5,
            mode: mode,
        })
        try {
            if (audioFile) audioFile.write(request)
        } catch (e) {
            console.log("Audio playback failed: " + e)
        }
    }
}
