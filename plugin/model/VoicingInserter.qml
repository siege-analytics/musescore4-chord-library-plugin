import QtQuick 2.15
import "Transposer.js" as Transposer

QtObject {
    id: inserter

    // Must be set by parent to the root MuseScore plugin object
    property var pluginRoot: null

    // Cached result of setDot() availability check (null = not yet tested)
    property var _hasSetDot: null

    // Check whether the plugin API exposes setDot() on FretDiagram elements.
    // This is cached after the first call. Returns true if setDot() is available,
    // false if we need the clipboard workaround.
    function hasSetDotApi(pluginRef) {
        if (_hasSetDot !== null) return _hasSetDot

        try {
            var fd = pluginRef.newElement(Element.FRET_DIAGRAM)
            _hasSetDot = (typeof fd.setDot === "function")
            if (_hasSetDot) {
                console.log("setDot() API detected — using direct insertion")
            } else {
                console.log("setDot() not available — using clipboard workaround")
            }
        } catch (e) {
            console.log("Could not probe setDot(): " + e)
            _hasSetDot = false
        }
        return _hasSetDot
    }

    // Generate .mscx XML for a FretDiagram element (clipboard workaround path)
    function generateMscxSnippet(voicing, targetRoot) {
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
        var transposedFret = voicing.fret_number + offset
        var numStrings = voicing.strings || 6
        var numFrets = voicing.visible_frets || 4

        var stringData = {}

        var dots = voicing.dots || []
        for (var d = 0; d < dots.length; d++) {
            var msStr = numStrings - dots[d].string
            if (!stringData[msStr]) stringData[msStr] = {}
            stringData[msStr].dot = dots[d].fret
        }

        var mutes = voicing.mutes || []
        for (var m = 0; m < mutes.length; m++) {
            var msMute = numStrings - mutes[m]
            if (!stringData[msMute]) stringData[msMute] = {}
            stringData[msMute].marker = "cross"
        }

        var opens = voicing.open || []
        for (var o = 0; o < opens.length; o++) {
            var msOpen = numStrings - opens[o]
            if (!stringData[msOpen]) stringData[msOpen] = {}
            stringData[msOpen].marker = "circle"
        }

        var xml = '<FretDiagram>\n'
        xml += '  <fretOffset>' + transposedFret + '</fretOffset>\n'
        xml += '  <frets>' + numFrets + '</frets>\n'
        xml += '  <strings>' + numStrings + '</strings>\n'
        xml += '  <fretDiagram>\n'

        var sortedKeys = Object.keys(stringData).sort(function(a, b) { return a - b })
        for (var k = 0; k < sortedKeys.length; k++) {
            var sn = sortedKeys[k]
            var sd = stringData[sn]
            xml += '    <string no="' + sn + '">\n'
            if (sd.marker) {
                xml += '      <marker>' + sd.marker + '</marker>\n'
            }
            if (sd.dot !== undefined) {
                xml += '      <dot fret="' + sd.dot + '">normal</dot>\n'
            }
            xml += '    </string>\n'
        }

        xml += '  </fretDiagram>\n'
        xml += '</FretDiagram>'
        return xml
    }

    // Insert a voicing via setDot() API (direct, no clipboard needed).
    // Returns {success, message} or null if setDot() is not available.
    function insertDirect(voicing, pluginRef) {
        var score = pluginRef ? pluginRef.curScore : null
        if (!score) {
            return { success: false, message: "No score is open" }
        }

        if (!hasSetDotApi(pluginRef)) return null

        var selection = score.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            return { success: false, message: "Select a note or rest first." }
        }

        var targetRoot = resolveTargetRoot(voicing, score)
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
        var numStrings = voicing.strings || 6

        try {
            score.startCmd()

            var fd = pluginRef.newElement(Element.FRET_DIAGRAM)
            fd.fretStrings = numStrings
            fd.fretFrets = voicing.visible_frets || 4
            fd.fretOffset = voicing.fret_number + offset - 1

            // Set dots via the API
            var dots = voicing.dots || []
            for (var d = 0; d < dots.length; d++) {
                // setDot(string, fret, fingerNumber)
                // MuseScore uses 0-based string index (0 = leftmost in diagram)
                var msStr = numStrings - dots[d].string
                fd.setDot(msStr, dots[d].fret, 0)
            }

            // Set mutes (fret 0 with marker type)
            var mutes = voicing.mutes || []
            for (var m = 0; m < mutes.length; m++) {
                var msMute = numStrings - mutes[m]
                fd.setMarker(msMute, 1)  // 1 = cross/muted
            }

            // Set open strings
            var opens = voicing.open || []
            for (var o = 0; o < opens.length; o++) {
                var msOpen = numStrings - opens[o]
                fd.setMarker(msOpen, 2)  // 2 = circle/open
            }

            // Position cursor at selection and add element
            var cursor = score.newCursor()
            cursor.rewind(1)  // SELECTION_START
            cursor.add(fd)

            score.endCmd()

            var transposed = Transposer.transposeVoicing(voicing, targetRoot)
            return {
                success: true,
                message: "Inserted " + transposed.name
                    + " [" + transposed.notes.join(" ") + "]"
            }
        } catch (e) {
            try { score.endCmd() } catch (ignore) {}
            // If setDot/setMarker threw, the API might differ from expected.
            // Clear cache so next attempt retries or falls back.
            _hasSetDot = null
            return {
                success: false,
                message: "Direct insert failed: " + e + " — falling back to clipboard"
            }
        }
    }

    // Resolve the target root from the score selection's chord symbol,
    // falling back to the voicing's own root.
    function resolveTargetRoot(voicing, score) {
        var selection = score.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            return voicing.root
        }

        var selectedElement = selection.elements[0]
        var segment = null

        if (selectedElement.type === Element.NOTE) {
            var chord = selectedElement.parent
            if (chord) segment = chord.parent
        } else if (selectedElement.type === Element.REST) {
            segment = selectedElement.parent
        } else if (selectedElement.type === Element.CHORD) {
            segment = selectedElement.parent
        }

        if (segment && segment.annotations) {
            for (var a = 0; a < segment.annotations.length; a++) {
                if (segment.annotations[a].type === Element.HARMONY) {
                    var harmonyText = segment.annotations[a].text
                    var root = Transposer.extractRoot(harmonyText)
                    if (root) return root
                }
            }
        }

        console.log("No chord symbol found — inserting in original key (" + voicing.root + ")")
        return voicing.root
    }

    // Insert a voicing at the current cursor position.
    // Tries setDot() API first; returns null if clipboard workaround is needed.
    // pluginRef: the root MuseScore plugin object (has newElement, curScore, etc.)
    function insertAtCursor(voicing, pluginRef) {
        var score = pluginRef ? pluginRef.curScore : null
        if (!score) {
            return { success: false, message: "No score is open" }
        }

        // Try direct API first
        var directResult = insertDirect(voicing, pluginRef)
        if (directResult !== null) return directResult

        // Fall back to generating XML for clipboard workaround
        var selection = score.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            return { success: false, message: "Select a note or rest first." }
        }

        var targetRoot = resolveTargetRoot(voicing, score)
        var xml = generateMscxSnippet(voicing, targetRoot)
        console.log("Generated .mscx snippet for " + voicing.name + " → " + targetRoot + ":")
        console.log(xml)

        // Create FretDiagram element via the plugin root's newElement
        try {
            score.startCmd()

            var fd = pluginRef.newElement(Element.FRET_DIAGRAM)
            fd.fretStrings = voicing.strings || 6
            fd.fretFrets = voicing.visible_frets || 4
            var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
            fd.fretOffset = voicing.fret_number + offset - 1

            var cursor = score.newCursor()
            cursor.rewind(1)  // SELECTION_START
            cursor.add(fd)

            score.endCmd()

            return {
                success: true,
                needsClipboard: true,
                message: "Inserted diagram grid — dots via clipboard paste"
            }
        } catch (e) {
            try { score.endCmd() } catch (ignore) {}
            return {
                success: false,
                message: "Insert failed: " + e + "\nXML logged to console."
            }
        }
    }
}
