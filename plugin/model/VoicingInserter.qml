import QtQuick 2.15
import "Transposer.js" as Transposer

QtObject {
    id: inserter

    // Must be set by parent to the root MuseScore plugin object
    property var pluginRoot: null

    // Generate .mscx XML for a FretDiagram element
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

    // Insert a voicing at the current cursor position
    // pluginRef: the root MuseScore plugin object (has newElement, curScore, etc.)
    function insertAtCursor(voicing, pluginRef) {
        var score = pluginRef ? pluginRef.curScore : null
        if (!score) {
            return { success: false, message: "No score is open" }
        }

        var selection = score.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            return { success: false, message: "Select a note or rest first." }
        }

        // Find the segment for the selected element (works for notes AND rests)
        var targetRoot = null
        var selectedElement = selection.elements[0]
        var segment = null

        if (selectedElement.type === Element.NOTE) {
            // Note → parent is Chord → parent is Segment
            var chord = selectedElement.parent
            if (chord) segment = chord.parent
        } else if (selectedElement.type === Element.REST) {
            // Rest → parent is Segment directly
            segment = selectedElement.parent
        } else if (selectedElement.type === Element.CHORD) {
            segment = selectedElement.parent
        }

        // Search the segment's annotations for a chord symbol (Harmony)
        if (segment && segment.annotations) {
            for (var a = 0; a < segment.annotations.length; a++) {
                if (segment.annotations[a].type === Element.HARMONY) {
                    var harmonyText = segment.annotations[a].text
                    targetRoot = Transposer.extractRoot(harmonyText)
                    break
                }
            }
        }

        if (!targetRoot) {
            targetRoot = voicing.root
            console.log("No chord symbol found — inserting in original key (" + targetRoot + ")")
        }

        var xml = generateMscxSnippet(voicing, targetRoot)
        console.log("Generated .mscx snippet for " + voicing.name + " → " + targetRoot + ":")
        console.log(xml)

        // Create FretDiagram element via the plugin root's newElement
        try {
            score.startCmd()

            var fd = pluginRef.newElement(Element.FRET_DIAGRAM)

            // Set grid properties (these ARE exposed in the plugin API)
            fd.fretStrings = voicing.strings || 6
            fd.fretFrets = voicing.visible_frets || 4
            var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
            fd.fretOffset = voicing.fret_number + offset - 1

            // Position cursor at selection and add element
            var cursor = score.newCursor()
            cursor.rewind(1)  // 1 = SELECTION_START
            cursor.add(fd)

            score.endCmd()

            return {
                success: true,
                message: "Inserted diagram for " + voicing.name + " → " + targetRoot
                    + "\n(Empty grid — dots pending API extension #32798)"
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
