// ReharmonizationEngine.js — Suggests chord substitutions for jazz reharmonization.
// Given a chord (root + quality) and optionally the next chord, suggests
// alternatives: tritone subs, backdoor ii-V, diminished passing, modal interchange.

.pragma library

var CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

function noteIndex(name) {
    for (var i = 0; i < CHROMATIC.length; i++) {
        if (CHROMATIC[i] === name) return i
    }
    // Handle enharmonics
    var map = {"C#": 1, "D#": 3, "E#": 5, "Fb": 4, "F#": 6, "G#": 8, "A#": 10, "B#": 0, "Cb": 11}
    return map[name] !== undefined ? map[name] : -1
}

function noteAt(index) {
    return CHROMATIC[((index % 12) + 12) % 12]
}

// Suggest reharmonizations for a chord.
// Returns array of { label, root, quality, description }
//
// @param root      — chord root (e.g. "C", "F")
// @param quality   — chord quality (e.g. "dom7", "min7", "maj7")
// @param nextRoot  — next chord's root (optional, for context)
// @param nextQuality — next chord's quality (optional)
function suggest(root, quality, nextRoot, nextQuality) {
    var suggestions = []
    var ri = noteIndex(root)
    if (ri < 0) return suggestions

    // === Tritone Substitution ===
    // Any dominant 7th can be replaced with the dominant a tritone (6 semitones) away
    if (quality === "dom7" || quality === "dom9" || quality === "dom13" ||
        quality === "dom7b9" || quality === "dom7sharp9") {
        var triRoot = noteAt(ri + 6)
        suggestions.push({
            label: "Tritone sub",
            root: triRoot,
            quality: "dom7",
            description: triRoot + "7 (tritone substitution — same guide tones)"
        })
    }

    // === ii-V Substitution ===
    // A dominant chord resolving down a 5th can be expanded to ii-V
    if (quality === "dom7" && nextRoot) {
        var ni = noteIndex(nextRoot)
        if (ni >= 0) {
            // Check if this is a V chord (resolves down a 5th to next)
            if ((ri - ni + 12) % 12 === 7 || (ri - ni + 12) % 12 === 5) {
                var iiRoot = noteAt(ri - 2)  // ii is a whole step below V
                suggestions.push({
                    label: "ii-V",
                    root: iiRoot,
                    quality: "min7",
                    description: iiRoot + "m7 → " + root + "7 (expand to ii-V)"
                })
            }
        }
    }

    // === Backdoor ii-V ===
    // Instead of ii-V-I, use bVIIm7-bVII7-I (e.g., Bbm7-Eb7-Cmaj7)
    if (quality === "maj7" || quality === "maj9" || quality === "maj6") {
        var bVII = noteAt(ri - 2)  // bVII is a whole step below
        var bVIIii = noteAt(ri - 2 - 7)  // ii of bVII
        suggestions.push({
            label: "Backdoor",
            root: bVII,
            quality: "dom7",
            description: noteAt(ri - 2 - 5) + "m7 → " + bVII + "7 (backdoor ii-V)"
        })
    }

    // === Diminished Passing ===
    // Insert a dim7 a half step above or below the target
    if (nextRoot) {
        var ni2 = noteIndex(nextRoot)
        if (ni2 >= 0) {
            var dimAbove = noteAt(ni2 + 1)
            suggestions.push({
                label: "Dim passing",
                root: dimAbove,
                quality: "dim7",
                description: dimAbove + "dim7 → " + nextRoot + " (chromatic approach from above)"
            })
        }
    }

    // === Modal Interchange ===
    // Minor quality substitutions for major chords
    if (quality === "dom7") {
        // sus4 resolution
        suggestions.push({
            label: "Sus4",
            root: root,
            quality: "sus4",
            description: root + "sus4 → " + root + "7 (suspension adds tension)"
        })
    }
    if (quality === "min7") {
        // Dorian color: minor to min6
        suggestions.push({
            label: "Min6",
            root: root,
            quality: "min6",
            description: root + "m6 (Dorian color — brighter minor)"
        })
    }
    if (quality === "maj7") {
        // Lydian: maj7#11
        suggestions.push({
            label: "Lydian",
            root: root,
            quality: "maj7",  // could be maj7#11 if available
            description: root + "maj7#11 (Lydian color — raised 4th)"
        })
    }

    return suggestions
}
