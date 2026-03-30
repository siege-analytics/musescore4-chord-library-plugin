// ms-audio: Play a chord voicing as MIDI notes.
// Usage: ms-audio <json-file>
// JSON format: {"notes": [60, 64, 67, 70], "duration": 1.5, "mode": "chord"}
// Modes: "chord" (all at once), "arp" (low to high, strum-like)

import Foundation
import AVFoundation

class ChordPlayer {
    let engine = AVAudioEngine()
    let sampler = AVAudioUnitSampler()

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        try? engine.start()
    }

    func playChord(notes: [UInt8], velocity: UInt8 = 80, duration: Double = 1.5) {
        for note in notes {
            sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        }
        Thread.sleep(forTimeInterval: duration)
        for note in notes {
            sampler.stopNote(note, onChannel: 0)
        }
        Thread.sleep(forTimeInterval: 0.2)
    }

    func playArpeggio(notes: [UInt8], velocity: UInt8 = 80, noteDelay: Double = 0.12, holdDuration: Double = 1.5) {
        // Sort low to high (like strumming from bass string up)
        let sorted = notes.sorted()

        // Strum: start each note with a slight delay, let them ring
        for note in sorted {
            sampler.startNote(note, withVelocity: velocity, onChannel: 0)
            Thread.sleep(forTimeInterval: noteDelay)
        }

        // Hold all notes ringing
        Thread.sleep(forTimeInterval: holdDuration)

        // Stop all
        for note in sorted {
            sampler.stopNote(note, onChannel: 0)
        }
        Thread.sleep(forTimeInterval: 0.2)
    }

    func stop() {
        engine.stop()
    }
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: ms-audio <json-file>\n", stderr)
    exit(1)
}

let path = CommandLine.arguments[1]
guard let data = FileManager.default.contents(atPath: path),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let noteNumbers = json["notes"] as? [Int] else {
    fputs("Error: cannot read or parse \(path)\n", stderr)
    exit(1)
}

let duration = (json["duration"] as? Double) ?? 1.5
let mode = (json["mode"] as? String) ?? "chord"
let notes = noteNumbers.map { UInt8(max(0, min(127, $0))) }

let player = ChordPlayer()
if mode == "arp" {
    player.playArpeggio(notes: notes, holdDuration: duration)
} else {
    player.playChord(notes: notes, duration: duration)
}
player.stop()
