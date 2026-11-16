// MetronomeService.swift
// luksMusic
//
// A metronome for the screens where the player keeps the time (Modo Estudo): it clicks the beats of a measure, the
// first one accented, at a tempo that can change while it runs. The click is AudioEngineService's, the score player's
// sound. It ticks on its own queue, so a busy screen never makes it limp, and reports each beat on the main thread.

import Foundation

final class MetronomeService {

    /// One beat: its place in the measure (1 is the first, accented) and whether its click was left out.
    struct Beat {
        let number: Int
        let isSilent: Bool
    }

    /// Called on the main thread at each beat. Set and read on the main thread only.
    var onBeat: ((Beat) -> Void)?

    // Main thread only. `run` changes on every start and stop, so a beat still on its way to the main thread
    // after a stop is dropped.
    private(set) var isRunning = false
    private var run = 0

    private let queue = DispatchQueue(label: "com.luksMusic.metronome", qos: .userInteractive)
    // Owned by `queue`
    private var timer: DispatchSourceTimer?
    private var secondsPerBeat = 0.5
    private var beatsPerMeasure = 4
    private var nextBeat = 1
    private var lastClick: DispatchTime?
    private var silentWithoutHeadphones = false

    deinit {
        // Queue blocks hold the service weakly, so none is running here
        timer?.cancel()
    }

    /// Starts on beat 1 of a measure of `beatsPerMeasure` beats.
    func start(bpm: Int, beatsPerMeasure: Int) {
        guard !isRunning else { return }
        isRunning = true
        run += 1
        let run = self.run
        let interval = Self.beatLength(bpm: bpm)
        let beats = max(1, beatsPerMeasure)
        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.secondsPerBeat = interval
            self.beatsPerMeasure = beats
            self.nextBeat = 1
            // Strict, so the system keeps to the 1 ms leeway instead of grouping the clicks with other timers
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: self.queue)
            timer.setEventHandler { [weak self] in
                self?.click(run: run)
            }
            timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        run += 1
        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.lastClick = nil
        }
    }

    /// A new tempo applies at once: the next click comes one new beat after the last (at once if that has passed),
    /// keeping the place in the measure.
    func setTempo(bpm: Int) {
        let interval = Self.beatLength(bpm: bpm)
        queue.async { [weak self] in
            guard let self, interval != self.secondsPerBeat else { return }
            self.secondsPerBeat = interval
            guard let timer = self.timer else { return }
            // Never in the past: a timer fires at once for a past deadline but keeps its grid, so the click after
            // would come early
            let now = DispatchTime.now()
            let next = max(now, (self.lastClick ?? now) + interval)
            timer.schedule(deadline: next, repeating: interval, leeway: .milliseconds(1))
        }
    }

    /// While the microphone listens, a click it would hear from the speaker is left out (it would take it for a
    /// note); the beat is still reported. Checked at every beat, so plugging headphones in brings the sound back.
    func setSilentWithoutHeadphones(_ silent: Bool) {
        queue.async { [weak self] in
            self?.silentWithoutHeadphones = silent
        }
    }

    // MARK: - Private

    /// On `queue`.
    private func click(run: Int) {
        let number = nextBeat
        nextBeat = number % beatsPerMeasure + 1
        lastClick = DispatchTime.now()
        let isSilent = silentWithoutHeadphones && !AudioEngineService.hasHeadphones
        if !isSilent {
            AudioEngineService.shared.playClick(accent: number == 1)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.run == run else { return }
            self.onBeat?(Beat(number: number, isSilent: isSilent))
        }
    }

    private static func beatLength(bpm: Int) -> Double {
        60.0 / Double(max(1, bpm))
    }
}
