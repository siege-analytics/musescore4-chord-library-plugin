// DiagramEngine.js — Fretboard diagram XML generation and MIDI pitch computation.
// Extracted from ChordLibrary.qml (Phase 3 decomposition).

// Generate EngravingItem XML for a voicing transposed to targetRoot.
// opts: { usingTuningVoicings, tuningOffset, semitoneOffsetFn(sourceRoot, targetRoot) }
function generateXmlForVoicing(voicing, targetRoot, opts) {
    var offset = opts.semitoneOffsetFn(voicing.root, targetRoot)
    var effectiveOffset = opts.usingTuningVoicings ? 0 : (opts.tuningOffset || 0)
    var transposedFret = voicing.fret_number + offset - effectiveOffset
    if (transposedFret < 0) transposedFret += 12
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

    var fretOffset = transposedFret - 1
    var xml = '<EngravingItem>\n  <FretDiagram>\n'
    if (fretOffset > 0) xml += '    <fretOffset>' + fretOffset + '</fretOffset>\n'
    if (numFrets !== 4) xml += '    <frets>' + numFrets + '</frets>\n'
    if (numStrings !== 6) xml += '    <strings>' + numStrings + '</strings>\n'
    xml += '    <fretDiagram>\n'

    var sortedKeys = Object.keys(stringData).sort(function(a, b) { return a - b })
    for (var k = 0; k < sortedKeys.length; k++) {
        var sn = sortedKeys[k]
        var sd = stringData[sn]
        xml += '      <string no="' + sn + '">\n'
        if (sd.marker) xml += '        <marker>' + sd.marker + '</marker>\n'
        if (sd.dot !== undefined) xml += '        <dot fret="' + sd.dot + '">normal</dot>\n'
        xml += '      </string>\n'
    }
    xml += '    </fretDiagram>\n  </FretDiagram>\n</EngravingItem>'
    return xml
}

// Compute MIDI pitches for all sounding notes in a voicing, transposed to targetRoot.
// Returns array of MIDI pitch integers, sorted low to high.
// opts: { usingTuningVoicings, tuningOffset, tuningMidi, semitoneOffsetFn(sourceRoot, targetRoot) }
function computeVoicingMidiPitches(voicing, targetRoot, opts) {
    var offset = opts.semitoneOffsetFn(voicing.root, targetRoot)
    var effectiveOffset = opts.usingTuningVoicings ? 0 : (opts.tuningOffset || 0)
    var transposedFret = voicing.fret_number + offset - effectiveOffset
    if (transposedFret < 0) transposedFret += 12

    var pitches = []
    var dots = voicing.dots || []
    for (var d = 0; d < dots.length; d++) {
        var strMidi = opts.tuningMidi[String(dots[d].string)]
        if (strMidi !== undefined) {
            var absFret = transposedFret + (dots[d].fret - 1)
            pitches.push(strMidi + absFret)
        }
    }
    var opens = voicing.open || []
    for (var o = 0; o < opens.length; o++) {
        var openMidi = opts.tuningMidi[String(opens[o])]
        if (openMidi !== undefined) {
            pitches.push(openMidi)
        }
    }
    pitches.sort(function(a, b) { return a - b })
    return pitches
}

// Convert MIDI pitch to TPC (tonal pitch class) for MuseScore.
// TPC maps: C=14, D=16, E=18, F=13, G=15, A=17, B=19
function pitchToTpc(midiPitch) {
    var tpcMap = [14, 21, 16, 23, 18, 13, 20, 15, 22, 17, 24, 19]
    return tpcMap[midiPitch % 12]
}
