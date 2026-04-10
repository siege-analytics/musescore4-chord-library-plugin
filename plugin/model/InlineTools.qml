import QtQuick 2.15
import "ChordSelector.js" as ChordSelector
import "MelodyEngine.js" as MelodyEngine
import "Transposer.js" as Transposer
import "FingeringEngine.js" as FingeringEngine

// InlineTools.qml — Score analysis tools (pure QML, no Python).
// Extracted from ChordLibrary.qml (B2, #101).
//
// Contains: collectScoreChords, analyzeCurrentScore, runVoiceLeading,
// voiceEntireScore, suggestFingerings, computeFingeringString,
// fingeringFromDiagram, addFingeringsToScore, exportFingeringSheet

Item {
    id: inlineTools

    // === External dependencies ===
    property var curScore: null
    property var voicingsData: []
    property string filterContext: ""
    property string filterCategory: ""
    property bool skipDiagramPositions: false
    property string diagramPlacement: "above"

    // Callback functions from parent
    property var findBestVoicingFn: function(root, quality) { return null }
    property var parseChordSymbolFn: function(text) { return null }
    property var showResultFn: function(title, msg, ok) {}
    property var openSaveDialogFn: function(title, filter, path, cb) {}
    property var launchExportFn: function(cmd) {}
    property var extractChordsToFileFn: function() { return null }
    property var homePath: ""
    property string selectedContext: ""
    property string selectedCategory: ""

    // === Signals ===
    signal statusMessage(string text, string colorType)

    // === Public API ===

    function collectScoreChords() {
        if (!curScore) return []
        var chords = []
        var seen = {}
        var cursor = curScore.newCursor()
        cursor.staffIdx = 0
        cursor.voice = 0
        cursor.rewind(0)
        while (cursor.segment) {
            var seg = cursor.segment
            if (seg.annotations) {
                for (var a = 0; a < seg.annotations.length; a++) {
                    if (seg.annotations[a].type === Element.HARMONY) {
                        var text = seg.annotations[a].text
                        if (!seen[text]) {
                            seen[text] = true
                            chords.push(text)
                        }
                    }
                }
            }
            cursor.next()
        }
        return chords
    }

    function analyzeCurrentScore() {
        if (!curScore) {
            inlineTools.statusMessage("Open a score with chord symbols first.", "error")
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            inlineTools.statusMessage("No chord symbols found in the score.", "error")
            return
        }

        var ctx = filterContext || "all"
        var cat = filterCategory || "all"

        var lines = []
        var covered = 0
        var gaps = 0
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbolFn(chords[i])
            if (!parsed) {
                lines.push("  ✗  " + chords[i] + " — could not parse")
                gaps++
                continue
            }
            var matches = voicingsData.filter(function(v) {
                if (v.chord_quality !== parsed.quality && v.chord_quality !== "quartal") return false
                if (ctx !== "all" && v.context !== ctx) return false
                if (cat !== "all" && v.category !== cat) return false
                return true
            })
            if (matches.length > 0) {
                var cats = {}
                for (var m = 0; m < matches.length; m++) cats[matches[m].category] = (cats[matches[m].category] || 0) + 1
                var catStr = Object.keys(cats).map(function(c) { return c + "(" + cats[c] + ")" }).join(", ")
                lines.push("  ✓  " + chords[i] + " — " + matches.length + " voicings: " + catStr)
                covered++
            } else {
                lines.push("  ✗  " + chords[i] + " — NO VOICINGS")
                gaps++
            }
        }

        var pct = Math.round(covered / chords.length * 100)
        var header = "Coverage: " + covered + "/" + chords.length + " (" + pct + "%)"
        if (gaps > 0) header += " — " + gaps + " gap(s)"
        else header += " — full coverage!"
        header += "\nContext: " + (ctx === "all" ? "All" : ctx) + "  |  Type: " + (cat === "all" ? "All" : cat)

        showResultFn("Score Analysis", header + "\n\n" + lines.join("\n"), true)
    }

    function runVoiceLeading() {
        if (!curScore) {
            inlineTools.statusMessage("Open a score with chord symbols first.", "error")
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            inlineTools.statusMessage("No chord symbols found in the score.", "error")
            return
        }

        var lines = []
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbolFn(chords[i])
            if (!parsed) {
                lines.push("  " + chords[i] + " — ?")
                continue
            }
            var voicing = findBestVoicingFn(parsed.root, parsed.quality)
            if (voicing) {
                var nameParts = voicing.name.split(" — ")
                var shape = nameParts.length > 1 ? nameParts[1] : voicing.category
                var topNote = nameParts.length > 2 ? nameParts[2] : ""
                lines.push("  " + chords[i] + "  →  " + shape + (topNote ? " — " + topNote : ""))
            } else {
                lines.push("  " + chords[i] + "  →  no match")
            }
        }

        var ctx = filterContext || "all"
        var cat = filterCategory || "all"
        var header = "Voice leading path (" + chords.length + " chords)"
        header += "\nContext: " + (ctx === "all" ? "All" : ctx) + "  |  Type: " + (cat === "all" ? "All" : cat)

        showResultFn("Voice Leading", header + "\n\n" + lines.join("\n"), true)
    }

    function suggestFingerings() {
        if (!curScore) {
            inlineTools.statusMessage("Open a score with chord symbols first.", "error")
            return
        }
        var chords = collectScoreChords()
        if (chords.length === 0) {
            inlineTools.statusMessage("No chord symbols found.", "error")
            return
        }

        var lines = []
        for (var i = 0; i < chords.length; i++) {
            var parsed = parseChordSymbolFn(chords[i])
            if (!parsed) continue
            var voicing = findBestVoicingFn(parsed.root, parsed.quality)
            if (voicing) {
                var fg = computeFingeringString(voicing)
                var nameParts = voicing.name.split(" — ")
                var shape = nameParts.length > 1 ? nameParts[1] : voicing.category
                lines.push("  " + chords[i] + "  →  " + shape + "\n     Fingering: " + fg)
            } else {
                lines.push("  " + chords[i] + "  →  no voicing found")
            }
        }

        showResultFn("Fingering Suggestions", "Fingerings for " + chords.length + " chords:\n\n" + lines.join("\n\n"), true)
    }

    function computeFingeringString(voicing) {
        return FingeringEngine.computeFingeringString(voicing)
    }

    function fingeringFromDiagram(diagram) {
        try {
            var numStrings = diagram.strings || 6
            var fretOffset = (diagram.fretOffset || 0) + 1
            var dots = []
            var mutes = []
            var opens = []

            for (var s = 0; s < numStrings; s++) {
                var msString = numStrings - s
                var marker = diagram.marker(s)
                var dot = diagram.dot(s)

                if (marker === 1) {
                    mutes.push(msString)
                } else if (marker === 2) {
                    opens.push(msString)
                } else if (dot && dot > 0) {
                    dots.push({ string: msString, fret: dot })
                }
            }

            if (dots.length === 0 && opens.length === 0) return null

            var pseudoVoicing = {
                dots: dots,
                mutes: mutes,
                open: opens,
                strings: numStrings,
                fret_number: fretOffset,
            }
            return computeFingeringString(pseudoVoicing)
        } catch (e) {
            console.log("[InlineTools] Could not read diagram: " + e)
            return null
        }
    }

    function addFingeringsToScore() {
        if (!curScore) {
            showResultFn("No Score", "Open a score with chord symbols first.", false)
            return
        }

        var chordPositions = []
        var scanCursor = curScore.newCursor()
        scanCursor.staffIdx = 0
        scanCursor.voice = 0
        scanCursor.rewind(0)

        var skippedDiagram = 0
        var usedDiagram = 0
        while (scanCursor.segment) {
            var seg = scanCursor.segment
            var currentTick = scanCursor.tick
            if (seg.annotations) {
                var existingDiagram = null
                for (var c = 0; c < seg.annotations.length; c++) {
                    if (seg.annotations[c].type === Element.FRET_DIAGRAM) {
                        existingDiagram = seg.annotations[c]
                        break
                    }
                }

                for (var a = 0; a < seg.annotations.length; a++) {
                    if (seg.annotations[a].type === Element.HARMONY) {
                        var chordText = seg.annotations[a].text

                        if (existingDiagram) {
                            if (skipDiagramPositions) {
                                skippedDiagram++
                                continue
                            }
                            var diagramFinger = fingeringFromDiagram(existingDiagram)
                            if (diagramFinger) {
                                chordPositions.push({
                                    tick: currentTick,
                                    fingering: diagramFinger,
                                    chord: chordText,
                                })
                                usedDiagram++
                                continue
                            }
                        }

                        var parsed = parseChordSymbolFn(chordText)
                        if (parsed) {
                            var voicing = findBestVoicingFn(parsed.root, parsed.quality)
                            if (voicing) {
                                var fingerStr = computeFingeringString(voicing)
                                if (fingerStr) {
                                    chordPositions.push({
                                        tick: currentTick,
                                        fingering: fingerStr,
                                        chord: chordText,
                                    })
                                }
                            }
                        }
                    }
                }
            }
            scanCursor.next()
        }

        if (chordPositions.length === 0) {
            showResultFn("No Chords Found", "The score has no chord symbols to annotate.", false)
            return
        }

        var added = 0
        var errors = []

        curScore.startCmd()

        for (var i = 0; i < chordPositions.length; i++) {
            var pos = chordPositions[i]
            try {
                var cursor = curScore.newCursor()
                cursor.staffIdx = 0
                cursor.voice = 0
                cursor.rewind(0)

                while (cursor.segment && cursor.tick < pos.tick) {
                    cursor.next()
                }

                if (cursor.segment) {
                    var staffText = newElement(Element.STAFF_TEXT)
                    staffText.text = pos.fingering
                    cursor.add(staffText)
                    added++
                }
            } catch (e) {
                errors.push(pos.chord + ": " + e)
            }
        }

        curScore.endCmd()

        var msg = "Added staff text annotations to " + added + " of " + chordPositions.length + " chord positions."
        if (usedDiagram > 0) {
            msg += "\n" + usedDiagram + " annotation(s) derived from existing fretboard diagrams."
        }
        if (skippedDiagram > 0) {
            msg += "\nSkipped " + skippedDiagram + " position(s) with existing fretboard diagrams."
        }
        if (errors.length > 0) {
            msg += "\n\nErrors:\n" + errors.join("\n")
        }
        msg += "\n\nNotation format: 1=index, 2=middle, 3=ring, 4=pinky, X=muted, O=open"
        showResultFn("Staff Text", msg, errors.length === 0)
    }

    function exportFingeringSheet() {
        if (!curScore) {
            showResultFn("No Score", "Open a score first, then try again.", false)
            return
        }
        var chordsFile = extractChordsToFileFn()
        if (!chordsFile) return

        var scoreName = (curScore.scoreName || curScore.title || "fingerings").replace(/[^a-zA-Z0-9-_ ]/g, "")
        var defaultPath = homePath + "/Documents/" + scoreName + "-fingerings.pdf"

        openSaveDialogFn("Save Fingering Sheet", "PDF files (*.pdf)", defaultPath, function(outPath) {
            var ctx = selectedContext && selectedContext !== "All Contexts" ? selectedContext : "CV6"
            var catArg = selectedCategory && selectedCategory !== "All Types" ? " --category " + selectedCategory : ""
            var title = curScore.scoreName || curScore.title || "Fingering Reference"
            var pluginDir = Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/$/, "")

            launchExportFn('cd "' + pluginDir + '"; python3 "' + pluginDir
                + '/scripts/generate_fingering_sheet.py" --chords "' + chordsFile
                + '" --context ' + ctx + catArg + ' --title "' + title
                + '" --data "' + pluginDir + '/data/voicings.json" -o "' + outPath
                + '" 2>&1; open "' + outPath + '"')
        })
    }

    function suggestFingering(voicing) {
        return FingeringEngine.suggestFingering(voicing)
    }

    function computeDifficulty(voicing) {
        return FingeringEngine.computeDifficulty(voicing)
    }
}
