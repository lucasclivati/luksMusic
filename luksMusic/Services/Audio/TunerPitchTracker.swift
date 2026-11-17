// TunerPitchTracker.swift
// luksMusic
//
// The tuner's ear: a steady pitch from the microphone, hop after hop. Unlike the practice screens, which want the
// moment a key is struck, the tuner follows a note while it rings. The audio is low-passed (room hiss scattered
// the period of a fading low string by tens of cents), each window is read with YIN, quiet hops are ignored, and the
// pitch shown is the median of the last few readings, eased toward, so one stray reading (an octave error, the
// pluck's scrape) never moves the needle.

import Foundation

struct TunerPitchTracker {

    struct Settings: Equatable {
        /// The pitches listened for, in hertz
        var lowest: Double
        var highest: Double

        init(lowest: Double, highest: Double) {
            self.lowest = lowest
            self.highest = highest
        }

        init(mode: TunerMode) {
            self.init(lowest: mode.lowestFrequency, highest: mode.highestFrequency)
        }
    }

    let sampleRate: Double
    let settings: Settings
    /// Samples read at once: about four periods of the lowest pitch (4096 for the guitar, 8192 for the piano at 48 kHz)
    let windowSize: Int

    /// Never treat as sound anything quieter than this (RMS)
    var minimumGate: Float = 0.002
    /// A reading this clear or better is a pitch; below it, noise or a chord
    var minimumClarity = 0.75
    /// How far the shown pitch moves toward each new median, while the note stays the same
    var easing = 0.35
    /// How long the last pitch stays on screen after the sound stops
    var holdSeconds = 1.2

    /// Level of the last hop (RMS)
    private(set) var level: Float = 0
    /// The pitch shown, nil before the first note and after the hold
    private(set) var frequency: Double?

    private var window: [Float]
    private var filled = 0
    private var filter: LowPass
    private var noiseFloor: Float = 0.002
    /// Recent readings, as log2 of the frequency
    private var recent: [Double] = []
    private var shown: Double?
    private var quietSeconds = 0.0

    private static let recentCount = 5
    /// Readings needed before a new note is shown
    private static let readingsToShow = 3
    /// A median this far from the shown pitch is a new note: jump to it instead of easing
    private static let newNoteCents = 40.0

    init(sampleRate: Double, settings: Settings) {
        self.sampleRate = sampleRate
        self.settings = settings
        let periods = 4 * sampleRate / max(settings.lowest, 1)
        windowSize = max(1024, 1 << Int(ceil(log2(periods))))
        window = [Float](repeating: 0, count: windowSize)
        // Well above the highest pitch listened for, so its own level is untouched
        filter = LowPass(cutoff: min(settings.highest * 1.1, sampleRate * 0.4), sampleRate: sampleRate)
    }

    /// Forgets everything heard (when listening restarts, or after the app played a reference tone).
    mutating func reset() {
        window = [Float](repeating: 0, count: windowSize)
        filled = 0
        filter.reset()
        recent.removeAll()
        shown = nil
        frequency = nil
        quietSeconds = 0
        level = 0
    }

    /// Takes the next hop of audio and returns the pitch to show (nil when nothing is heard).
    @discardableResult
    mutating func process<Samples: Collection>(_ samples: Samples) -> Double? where Samples.Element == Float {
        guard !samples.isEmpty else { return frequency }
        var sumOfSquares: Float = 0
        var hop = [Float]()
        hop.reserveCapacity(samples.count)
        for sample in samples {
            sumOfSquares += sample * sample
            hop.append(filter.process(sample))
        }
        level = (sumOfSquares / Float(samples.count)).squareRoot()
        // The quietest level heard lately: falls at once, rises slowly while sound goes on
        noiseFloor = level < noiseFloor ? max(level, 0.0001) : noiseFloor * 1.0015

        if hop.count >= windowSize {
            window = Array(hop.suffix(windowSize))
        } else {
            window.removeFirst(hop.count)
            window.append(contentsOf: hop)
        }
        filled = min(windowSize, filled + hop.count)

        let hopSeconds = Double(samples.count) / sampleRate
        let gate = max(minimumGate, noiseFloor * 3)
        guard filled >= windowSize, level >= gate,
              let estimate = PitchDetector.estimate(samples: window, sampleRate: sampleRate,
                                                    lowest: settings.lowest, highest: settings.highest),
              estimate.clarity >= minimumClarity,
              estimate.frequency >= settings.lowest * 0.97, estimate.frequency <= settings.highest * 1.03
        else {
            return heardNothing(for: hopSeconds)
        }

        quietSeconds = 0
        recent.append(log2(estimate.frequency))
        if recent.count > Self.recentCount {
            recent.removeFirst(recent.count - Self.recentCount)
        }
        guard recent.count >= Self.readingsToShow else { return frequency }

        let median = recent.sorted()[recent.count / 2]
        if let current = shown, abs(median - current) * 1200 < Self.newNoteCents {
            shown = current + easing * (median - current)
        } else {
            shown = median
        }
        frequency = shown.map { pow(2, $0) }
        return frequency
    }

    private mutating func heardNothing(for seconds: Double) -> Double? {
        quietSeconds += seconds
        // A gap ends the note: the next one starts from fresh readings
        if quietSeconds > 0.15 {
            recent.removeAll()
        }
        if quietSeconds > holdSeconds {
            shown = nil
            frequency = nil
        }
        return frequency
    }
}

/// Two second-order Butterworth low-pass sections (24 dB per octave).
private struct LowPass {
    private struct Section {
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    }

    private let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    private var first = Section()
    private var second = Section()

    init(cutoff: Double, sampleRate: Double) {
        let omega = 2 * Double.pi * cutoff / sampleRate
        let alpha = sin(omega) / (2 * (0.5).squareRoot())
        let cosine = cos(omega)
        let a0 = 1 + alpha
        b0 = (1 - cosine) / 2 / a0
        b1 = (1 - cosine) / a0
        b2 = b0
        a1 = -2 * cosine / a0
        a2 = (1 - alpha) / a0
    }

    mutating func reset() {
        first = Section()
        second = Section()
    }

    mutating func process(_ sample: Float) -> Float {
        let middle = run(Double(sample), through: &first)
        return Float(run(middle, through: &second))
    }

    private func run(_ value: Double, through section: inout Section) -> Double {
        let output = b0 * value + b1 * section.x1 + b2 * section.x2 - a1 * section.y1 - a2 * section.y2
        section.x2 = section.x1
        section.x1 = value
        section.y2 = section.y1
        section.y1 = output
        return output
    }
}
