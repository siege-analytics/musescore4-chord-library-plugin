// ms-audio: Play a chord voicing as MIDI notes.
// Usage: ms-audio <json-file>
// JSON format: {"notes": [60, 64, 67, 70], "duration": 1.5}
// Notes are MIDI note numbers. Duration in seconds.

import Foundation
import AVFoundation
import CoreMIDI

// Simple MIDI note player using AVAudioEngine + AVAudioUnitSampler
class ChordPlayer {
    let engine = AVAudioEngine()
    let sampler = AVAudioUnitSampler()

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        try? engine.start()
    }

    func playChord(notes: [UInt8], velocity: UInt8 = 80, duration: Double = 1.5) {
        // Start all notes
        for note in notes {
            sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        }

        // Hold for duration
        Thread.sleep(forTimeInterval: duration)

        // Stop all notes
        for note in notes {
            sampler.stopNote(note, onChannel: 0)
        }

        // Brief tail
        Thread.sleep(forTimeInterval: 0.2)
    }

    func stop() {
        engine.stop()
    }
}

// Read input
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
let notes = noteNumbers.map { UInt8(max(0, min(127, $0))) }

let player = ChordPlayer()
player.playChord(notes: notes, duration: duration)
player.stop()
