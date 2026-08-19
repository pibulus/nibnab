import Foundation
import AVFoundation

// ===================================================================
// 🪶 WEIGHTLESS — procedural UI audio. 0kb assets.
//
// A Swift port of ~/Projects/active/experiments/weightless
// (@softstack/weightless). Same voices, cues, envelopes and jitter as the
// JS engine, so NibNab sounds like the rest of the family.
//
// Every play re-synthesises with fresh detune / timing / pan jitter — a
// sampled blip on a sound that fires this often turns into ear fatigue.
// ===================================================================

enum WeightlessWave {
    case sine, triangle

    @inline(__always)
    func sample(_ phase: Float) -> Float {
        switch self {
        case .sine:
            return sinf(2 * .pi * phase)
        case .triangle:
            // -1...1 triangle from a 0...1 phase.
            return 4 * abs(phase - floorf(phase + 0.5)) - 1
        }
    }
}

struct WeightlessPartial {
    let ratio: Float
    let gain: Float
    let wave: WeightlessWave
}

struct WeightlessVoice {
    let wave: WeightlessWave
    let lowpass: Float
    let attack: Float
    var q: Float = 0.7
    var bendCents: Float = 0
    var partials: [WeightlessPartial] = []
}

struct WeightlessNote {
    let frequency: Float
    var offset: Float = 0
    let duration: Float
    let gain: Float
    let voice: String
}

struct WeightlessCue {
    var cooldown: TimeInterval = 0
    var detuneCents: Float = 0
    /// Re-pitch to a random degree of the scale on every play. For the cues
    /// heard dozens of times a day, so they never wear a groove.
    var randomRoot: Bool = false
    let variants: [[WeightlessNote]]
}

// MARK: - NibNab's palette
// The engine above is the port; these voices and cues are NibNab's own
// personality, which is exactly what the JS library invites you to bring.
// Warm comes from the closed filter, not from pitching everything down —
// low-and-heavy reads as sad. Intervals rise and are always major or perfect.

enum Weightless {
    static let voices: [String: WeightlessVoice] = [
        // Round and quick. The 18ms attack still swells rather than taps, and
        // the half-ratio partial adds body without weight.
        "warm": WeightlessVoice(
            wave: .sine, lowpass: 1300, attack: 0.018, q: 0.5, bendCents: 8,
            partials: [WeightlessPartial(ratio: 0.5, gain: 0.06, wave: .sine)]
        ),
        // Darker and a touch slower, for anything that falls.
        "warmLow": WeightlessVoice(
            wave: .sine, lowpass: 800, attack: 0.022, q: 0.5, bendCents: -10,
            partials: [WeightlessPartial(ratio: 0.5, gain: 0.10, wave: .sine)]
        )
    ]

    // MARK: - Cues (gesture)

    static let cues: [String: WeightlessCue] = [
        // Copy / open / colour switch. One short round tick. Colour switching
        // passes its own transpose, so this is the note the five colours play.
        "select": WeightlessCue(cooldown: 0.045, detuneCents: 6, variants: [
            [WeightlessNote(frequency: 587.33, duration: 0.085, gain: 0.026, voice: "warm")]
        ]),

        // Capture — heard more than anything else in the app, so it moves:
        // two shapes, and a random degree of the pentatonic every single play.
        "notify": WeightlessCue(cooldown: 0.120, detuneCents: 7, randomRoot: true, variants: [
            [   // rising fifth
                WeightlessNote(frequency: 466.16, duration: 0.09, gain: 0.030, voice: "warm"),
                WeightlessNote(frequency: 699.24, offset: 0.040, duration: 0.13, gain: 0.024, voice: "warm")
            ],
            [   // rising fourth
                WeightlessNote(frequency: 466.16, duration: 0.09, gain: 0.030, voice: "warm"),
                WeightlessNote(frequency: 622.25, offset: 0.040, duration: 0.13, gain: 0.024, voice: "warm")
            ]
        ]),

        "toggleOn": WeightlessCue(cooldown: 0.080, detuneCents: 5, variants: [
            [
                WeightlessNote(frequency: 466.16, duration: 0.075, gain: 0.026, voice: "warm"),
                WeightlessNote(frequency: 622.25, offset: 0.038, duration: 0.11, gain: 0.022, voice: "warm")
            ]
        ]),

        "toggleOff": WeightlessCue(cooldown: 0.080, detuneCents: 5, variants: [
            [
                WeightlessNote(frequency: 622.25, duration: 0.075, gain: 0.026, voice: "warm"),
                WeightlessNote(frequency: 466.16, offset: 0.038, duration: 0.12, gain: 0.022, voice: "warmLow")
            ]
        ]),

        // First clip in a colour: root, fifth, octave.
        "success": WeightlessCue(cooldown: 0.200, detuneCents: 8, randomRoot: true, variants: [
            [
                WeightlessNote(frequency: 466.16, duration: 0.08, gain: 0.028, voice: "warm"),
                WeightlessNote(frequency: 699.24, offset: 0.060, duration: 0.10, gain: 0.024, voice: "warm"),
                WeightlessNote(frequency: 932.33, offset: 0.120, duration: 0.16, gain: 0.020, voice: "warm")
            ]
        ]),

        // Soft and falling. A warning shouldn't be a punishment.
        "error": WeightlessCue(cooldown: 0.150, variants: [
            [
                WeightlessNote(frequency: 349.23, duration: 0.11, gain: 0.028, voice: "warmLow"),
                WeightlessNote(frequency: 261.63, offset: 0.060, duration: 0.16, gain: 0.024, voice: "warmLow")
            ]
        ])
    ]

    /// The scale as ratios inside one octave. Picking one at random moves a
    /// cue somewhere new without it ever landing on a sour note.
    static let transposes: [Float] = [1.0, 1.122, 1.335, 1.498, 1.682]

    static let sampleRate: Float = 44_100
    static let minGain: Float = 0.0001
    /// The JS engine mixes for a browser at ~0.01 peak. A menubar app needs to
    /// be audible over whatever else is playing, so lift the whole bus.
    static let masterLevel: Float = 14.0
    static let panWidth: Float = 0.15
    static let humanizeSeconds: Float = 0.005
}

// MARK: - Synthesis
// Kept a pure function of (cue, voices, jitter) so it can be rendered to a
// file for auditioning and exercised by the test harness without AVFoundation.

enum WeightlessSynth {

    @inline(__always)
    static func centsToRatio(_ cents: Float) -> Float { powf(2, cents / 1200) }

    /// Web Audio's exponentialRampToValueAtTime, normalised to t in 0...1.
    @inline(__always)
    static func expRamp(_ from: Float, _ to: Float, _ t: Float) -> Float {
        from * powf(to / from, min(max(t, 0), 1))
    }

    struct Biquad {
        var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

        init(lowpass cutoff: Float, q: Float, sampleRate: Float) {
            let w0 = 2 * Float.pi * min(cutoff, sampleRate * 0.45) / sampleRate
            let alpha = sinf(w0) / (2 * q)
            let cosw = cosf(w0)
            let a0 = 1 + alpha
            b0 = ((1 - cosw) / 2) / a0
            b1 = (1 - cosw) / a0
            b2 = b0
            a1 = (-2 * cosw) / a0
            a2 = (1 - alpha) / a0
        }

        @inline(__always)
        mutating func process(_ x: Float) -> Float {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            return y
        }
    }

    /// Renders one cue to a stereo pair of sample buffers.
    /// `jitter` returns a value in -1...1; pass a constant 0 for a repeatable render.
    static func render(
        cue: WeightlessCue,
        voices: [String: WeightlessVoice] = Weightless.voices,
        transpose: Float = 1,
        jitter: () -> Float = { Float.random(in: -1...1) }
    ) -> (left: [Float], right: [Float]) {
        let sr = Weightless.sampleRate
        // Variant choice runs through the jitter source too, so a fixed jitter
        // gives a byte-identical render — otherwise nothing is reproducible.
        guard !cue.variants.isEmpty else { return ([], []) }
        let pick = Int((jitter() + 1) / 2 * Float(cue.variants.count))
        let variant = cue.variants[min(max(pick, 0), cue.variants.count - 1)]
        guard !variant.isEmpty else { return ([], []) }

        // Each note gets its own timing jitter, so work them out up front to
        // size the buffer correctly.
        let offsets = variant.map { note -> Float in
            max(0, note.offset + jitter() * Weightless.humanizeSeconds)
        }
        let tail: Float = 0.02
        let totalSeconds = zip(variant, offsets).map { $0.duration + $1 }.max()! + tail
        let frameCount = Int(totalSeconds * sr)
        guard frameCount > 0 else { return ([], []) }

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)

        for (note, offset) in zip(variant, offsets) {
            guard let voice = voices[note.voice] else { continue }

            let detune = centsToRatio(jitter() * cue.detuneCents)
            let baseFreq = note.frequency * transpose * detune
            let gain = max(Weightless.minGain, note.gain * (1 + jitter() * 0.1))

            let startFrame = Int(offset * sr)
            let noteFrames = Int(note.duration * sr)
            guard noteFrames > 0 else { continue }

            let attack = min(voice.attack, note.duration * 0.5)
            let decaySeconds = max(note.duration - attack, 0.0001)

            var filter = Biquad(lowpass: voice.lowpass, q: voice.q, sampleRate: sr)

            // Fundamental first, then any overtones.
            var partials = [WeightlessPartial(ratio: 1, gain: 1, wave: voice.wave)]
            partials.append(contentsOf: voice.partials)
            var phases = [Float](repeating: 0, count: partials.count)

            let bendRatio = voice.bendCents == 0 ? 1 : centsToRatio(voice.bendCents)

            let pan = jitter() * Weightless.panWidth
            let panAngle = (pan + 1) * .pi / 4
            let gainL = cosf(panAngle)
            let gainR = sinf(panAngle)

            for i in 0..<noteFrames {
                let frame = startFrame + i
                if frame >= frameCount { break }

                let t = Float(i) / sr
                let progress = t / note.duration

                let envelope: Float = t < attack
                    ? expRamp(Weightless.minGain, gain, t / attack)
                    : expRamp(gain, Weightless.minGain, (t - attack) / decaySeconds)

                // Pitch bend is an exponential glide across the note.
                let freq = bendRatio == 1 ? baseFreq : baseFreq * powf(bendRatio, progress)

                var sample: Float = 0
                for (index, partial) in partials.enumerated() {
                    phases[index] += (freq * partial.ratio) / sr
                    if phases[index] >= 1 { phases[index] -= floorf(phases[index]) }
                    sample += partial.wave.sample(phases[index]) * partial.gain
                }

                let filtered = filter.process(sample) * envelope
                left[frame] += filtered * gainL
                right[frame] += filtered * gainR
            }
        }

        // Master bus: lift, then soft-clip so a stacked cue can't crackle.
        for i in 0..<frameCount {
            left[i] = tanhf(left[i] * Weightless.masterLevel)
            right[i] = tanhf(right[i] * Weightless.masterLevel)
        }
        return (left, right)
    }
}

// MARK: - Playback

/// Renders each cue on demand and hands it to AVAudioEngine. Nothing is
/// cached — the point is that no two plays are identical.
final class WeightlessPlayer {
    static let shared = WeightlessPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Double(Weightless.sampleRate),
                                       channels: 2)!
    private var started = false
    private var lastPlayed: [String: Date] = [:]

    private init() {}

    private func ensureRunning() -> Bool {
        if !started {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            started = true
        }
        // Output device changes (headphones in/out) stop the engine.
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return false
            }
        }
        if !player.isPlaying { player.play() }
        return true
    }

    func play(cue name: String, transpose: Float = 1) {
        guard let cue = Weightless.cues[name] else { return }

        // Rapid-fire captures shouldn't machine-gun.
        if cue.cooldown > 0, let last = lastPlayed[name],
           Date().timeIntervalSince(last) < cue.cooldown {
            return
        }
        lastPlayed[name] = Date()

        let root = cue.randomRoot && transpose == 1
            ? (Weightless.transposes.randomElement() ?? 1)
            : transpose
        let (left, right) = WeightlessSynth.render(cue: cue, transpose: root)
        guard !left.isEmpty, ensureRunning() else { return }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(left.count)),
              let channels = buffer.floatChannelData else { return }
        buffer.frameLength = AVAudioFrameCount(left.count)
        left.withUnsafeBufferPointer { channels[0].update(from: $0.baseAddress!, count: left.count) }
        right.withUnsafeBufferPointer { channels[1].update(from: $0.baseAddress!, count: right.count) }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}
