import QtQuick 2.15
import MuseScore 3.0
import "Transposer.js" as Transposer

QtObject {
    id: inserter

    // Generate .mscx XML for a FretDiagram element
    // voicing: object from voicings.json
    // targetRoot: string like "F", "Bb", etc.
    function generateMscxSnippet(voicing, targetRoot) {
        var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
        var transposedFret = voicing.fret_number + offset
        var numStrings = voicing.strings || 6

        // MuseScore uses 0-indexed strings, bottom-up:
        //   MS string 0 = highest (our string 1 = high e)
        //   MS string 5 = lowest  (our string 6 = low E)
        //   MS string 6 = lowest  (our string 7 = low A, 7-string)
        // Our convention: string 1 = high e, string 6 = low E, string 7 = low A
        // Conversion: msString = numStrings - ourString

        var numFrets = voicing.visible_frets || 4

        // Build per-string data map (MS 0-based string index)
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

        // Generate XML in correct MS4 .mscx format
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

    // Attempt to insert a voicing at the current cursor position
    // Returns: { success: bool, message: string }
    function insertAtCursor(voicing, curScore) {
        if (!curScore) {
            return { success: false, message: "No score is open" }
        }

        // Get current selection
        var selection = curScore.selection
        if (!selection || !selection.elements || selection.elements.length === 0) {
            return { success: false, message: "No note selected. Click a note first." }
        }

        // Try to find a chord symbol on the selected element
        var targetRoot = null
        var selectedElement = selection.elements[0]

        // Walk up to find chord symbol attached to this beat
        if (selectedElement.type === Element.NOTE) {
            var chord = selectedElement.parent
            if (chord && chord.parent) {
                var segment = chord.parent
                var annotations = segment.annotations
                if (annotations) {
                    for (var a = 0; a < annotations.length; a++) {
                        if (annotations[a].type === Element.HARMONY) {
                            var harmonyText = annotations[a].text
                            targetRoot = Transposer.extractRoot(harmonyText)
                            break
                        }
                    }
                }
            }
        }

        if (!targetRoot) {
            // Default to C (no transposition) if no chord symbol found
            targetRoot = voicing.root
            console.log("No chord symbol found — inserting in original key (" + targetRoot + ")")
        }

        var xml = generateMscxSnippet(voicing, targetRoot)

        // Write to temp file for potential manual import
        // (The actual programmatic insertion requires the API extension from musescore/MuseScore#32798)
        console.log("Generated .mscx snippet for " + voicing.name + " transposed to " + targetRoot + ":")
        console.log(xml)

        // Attempt 1: Try creating a FretDiagram element and setting basic properties
        // (This creates an empty diagram — dots/markers cannot be set via current API)
        var cursor = curScore.newCursor()
        cursor.rewindToSelection()

        try {
            var fd = newElement(Element.FRET_DIAGRAM)
            fd.fretStrings = voicing.strings || 6
            fd.fretFrets = voicing.visible_frets || 4
            var offset = Transposer.semitoneOffset(voicing.root, targetRoot)
            fd.fretOffset = voicing.fret_number + offset - 1  // fretOffset is 0-based display offset
            cursor.add(fd)

            return {
                success: true,
                message: "Inserted fretboard grid for " + voicing.name + " → " + targetRoot
                    + "\nNote: Dots and markers require MuseScore API extension (issue #32798)."
                    + "\nThe .mscx XML snippet has been logged to the console for manual use."
            }
        } catch (e) {
            return {
                success: false,
                message: "Could not insert element: " + e
                    + "\nThe .mscx XML snippet has been logged to the console."
            }
        }
    }
}
