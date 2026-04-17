.pragma library
// IRealParser.js — Parse iReal Pro URLs into chord charts.
// Decodes the obfuscated URL format and extracts chord symbols,
// bar lines, section marks, and time signatures.
//
// Reference: pianosnake/ireal-reader, infojunkie/ireal-musicxml
// .pragma library: safe — no QML callbacks received.

// iReal Pro quality string → plugin quality ID mapping
var QUALITY_MAP = {
    "":       "dom7",    // bare note in iReal defaults to dominant
    "^7":     "maj7",
    "^":      "maj7",
    "-7":     "min7",
    "-":      "min7",
    "7":      "dom7",
    "h7":     "min7b5",  // half-diminished
    "h":      "min7b5",
    "o7":     "dim7",
    "o":      "dim7",
    "7b9":    "dom7b9",
    "7#9":    "dom7sharp9",
    "7#11":   "dom7sharp11",
    "7b13":   "dom7b13",
    "7alt":   "dom7alt",
    "9":      "dom9",
    "^9":     "maj9",
    "-9":     "min9",
    "13":     "dom13",
    "6":      "maj6",
    "-6":     "min6",
    "sus":    "sus4",
    "7sus4":  "sus4",
    "+7":     "aug7",
    "+":      "aug7",
    "-^7":    "min-maj7",
    "add9":   "dom9",
    "69":     "maj6",
}

// Decode the iReal Pro obfuscation (obfusc50 algorithm).
// The encoded string has 50-character segments with internal char swaps.
function deobfuscate(encoded) {
    // Remove URL encoding
    var str = decodeURIComponent(encoded)

    // The obfusc50 algorithm: take 50-char chunks and scramble them
    var result = []
    for (var i = 0; i < str.length; i += 50) {
        var chunk = str.substring(i, Math.min(i + 50, str.length))
        if (chunk.length === 50) {
            // Swap segments: [0-4][5-9][10-24][25-49] → [25-49][10-24][5-9][0-4]
            // Then reverse the last 25 chars
            var a = chunk.substring(0, 5)
            var b = chunk.substring(5, 10)
            var c = chunk.substring(10, 24)
            var d = chunk.substring(24, 50)
            // Reverse the swapped parts
            chunk = d.split("").reverse().join("")
                  + c.split("").reverse().join("")
                  + b.split("").reverse().join("")
                  + a.split("").reverse().join("")
        }
        result.push(chunk)
    }
    return result.join("")
}

// Token substitution: replace iReal tokens with readable equivalents
function substituteTokens(raw) {
    var s = raw
    s = s.replace(/LZ/g, "|")       // bar line
    s = s.replace(/Kcl/g, "|")      // repeat close
    s = s.replace(/XyQ/g, " ")      // space
    s = s.replace(/\{/g, "")        // section open
    s = s.replace(/\}/g, "")        // section close
    s = s.replace(/\[/g, "")        // alt section open
    s = s.replace(/\]/g, "")        // alt section close
    s = s.replace(/Z/g, "")         // end marker
    s = s.replace(/Y/g, "")         // newline marker
    s = s.replace(/N/g, "")         // newline
    s = s.replace(/U/g, "")         // end section
    s = s.replace(/S/g, "")         // segno
    s = s.replace(/Q/g, "")         // coda
    s = s.replace(/f/g, "")         // fermata
    s = s.replace(/\*/g, "")        // section markers (*A, *B, etc.)
    s = s.replace(/T\d{2}/g, "")    // time signature
    s = s.replace(/n/g, "")         // no chord
    return s
}

// Extract the root note from an iReal chord token
function extractRoot(token) {
    if (!token || token.length === 0) return null
    var first = token[0]
    if (first < "A" || first > "G") return null
    if (token.length > 1 && (token[1] === "b" || token[1] === "#")) {
        return first + token[1]
    }
    return first
}

// Parse a single iReal chord token into { root, quality }
function parseChord(token) {
    if (!token || token.length === 0) return null
    token = token.trim()
    if (token === "x" || token === "X" || token === "W" || token === "p") return null

    // Handle slash chords: "C/E" → take the part before /
    var slashBass = null
    var slashIdx = token.indexOf("/")
    if (slashIdx > 0) {
        var bassStr = token.substring(slashIdx + 1)
        slashBass = extractRoot(bassStr)
        token = token.substring(0, slashIdx)
    }

    var root = extractRoot(token)
    if (!root) return null
    var suffix = token.substring(root.length)

    // Map to plugin quality
    var quality = QUALITY_MAP[suffix]
    if (!quality) {
        // Try partial matches
        if (suffix.indexOf("^7") >= 0 || suffix.indexOf("maj7") >= 0) quality = "maj7"
        else if (suffix.indexOf("-7b5") >= 0 || suffix.indexOf("h") >= 0) quality = "min7b5"
        else if (suffix.indexOf("-7") >= 0 || suffix.indexOf("mi7") >= 0) quality = "min7"
        else if (suffix.indexOf("o") >= 0 || suffix.indexOf("dim") >= 0) quality = "dim7"
        else if (suffix.indexOf("7") >= 0) quality = "dom7"
        else if (suffix.indexOf("-") >= 0 || suffix.indexOf("mi") >= 0) quality = "min7"
        else quality = "dom7"
    }

    var result = { root: root, quality: quality, text: root + suffix }
    if (slashBass) {
        result.slashBass = slashBass
        result.text = root + suffix + "/" + slashBass
    }
    return result
}

// Parse an iReal Pro URL into a chord chart.
// Returns { title, composer, style, key, chords: [{text, root, quality, slashBass?}] }
function parseUrl(url) {
    // Extract the data portion from the URL
    // Format: irealb://[title]=[composer]=[style]=[key]=[n]=[encoded_chords]
    // OR: irealbook://[title]=[composer]=[style]=[key]=[n]=[encoded_chords]
    var match = url.match(/irealb(?:ook)?:\/\/(.+)/)
    if (!match) return null

    // iReal URL format: title=composer==style=key==encoded_chart==trailing
    // Split on single = first, then reconstruct from known structure
    var raw_data = match[1]

    // Extract title (before first =)
    var firstEq = raw_data.indexOf("=")
    if (firstEq < 0) return null
    var title = raw_data.substring(0, firstEq)
    var rest = raw_data.substring(firstEq + 1)

    // Extract composer (before next =)
    var secondEq = rest.indexOf("=")
    if (secondEq < 0) return null
    var composer = rest.substring(0, secondEq)
    rest = rest.substring(secondEq + 1)

    // Skip empty field (the == delimiter leaves an empty string)
    if (rest.charAt(0) === "=") rest = rest.substring(1)

    // Extract style (before next =)
    var thirdEq = rest.indexOf("=")
    var style = ""
    if (thirdEq >= 0) {
        style = rest.substring(0, thirdEq)
        rest = rest.substring(thirdEq + 1)
    }

    // Extract key (before next =)
    var fourthEq = rest.indexOf("=")
    var key = ""
    if (fourthEq >= 0) {
        key = rest.substring(0, fourthEq)
        rest = rest.substring(fourthEq + 1)
    }

    // Skip empty field again (==)
    if (rest.charAt(0) === "=") rest = rest.substring(1)

    // The remaining content up to the trailing ==0=0 is the encoded chart
    var encoded = rest.replace(/==?\d+=?\d*$/, "")

    try {
        title = decodeURIComponent(title)
        composer = decodeURIComponent(composer)
        style = decodeURIComponent(style)
        key = decodeURIComponent(key)
    } catch(e) {}

    // Deobfuscate
    var raw = deobfuscate(encoded)

    // Substitute tokens
    var cleaned = substituteTokens(raw)

    // Split on bar lines and extract chords
    var bars = cleaned.split("|")
    var chords = []

    for (var i = 0; i < bars.length; i++) {
        var bar = bars[i].trim()
        if (!bar) continue

        // Split bar contents by spaces to get individual chords
        var tokens = bar.split(/\s+/)
        for (var t = 0; t < tokens.length; t++) {
            var parsed = parseChord(tokens[t])
            if (parsed) {
                chords.push(parsed)
            }
        }
    }

    return {
        title: title,
        composer: composer,
        style: style,
        key: key,
        chords: chords
    }
}

// Parse a plain text chord chart (one chord per line or space-separated).
// Simpler fallback when not using iReal Pro URLs.
function parsePlainText(text) {
    var chords = []
    var lines = text.split(/[\n,]+/)
    for (var i = 0; i < lines.length; i++) {
        var tokens = lines[i].trim().split(/[\s|]+/)
        for (var t = 0; t < tokens.length; t++) {
            var parsed = parseChord(tokens[t])
            if (parsed) chords.push(parsed)
        }
    }
    return chords
}
