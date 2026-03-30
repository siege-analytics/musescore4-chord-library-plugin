// ms-clipboard: Write MuseScore element XML to the macOS pasteboard.
// Usage: echo "<EngravingItem>...</EngravingItem>" | ms-clipboard
import AppKit
import Foundation

let data: Data
if CommandLine.arguments.count > 1 {
    // Read from file argument
    let path = CommandLine.arguments[1]
    guard let fileData = FileManager.default.contents(atPath: path) else {
        fputs("Error: cannot read \(path)\n", stderr)
        exit(1)
    }
    data = fileData
} else {
    // Read from stdin
    data = FileHandle.standardInput.readDataToEndOfFile()
}

if data.isEmpty {
    fputs("Error: no input data\n", stderr)
    exit(1)
}

let pb = NSPasteboard.general
let pasteType = NSPasteboard.PasteboardType("com.trolltech.anymime.application--musescore--symbol")
pb.clearContents()
pb.setData(data, forType: pasteType)

let count = data.count
fputs("Wrote \(count) bytes to pasteboard as MuseScore symbol\n", stderr)
