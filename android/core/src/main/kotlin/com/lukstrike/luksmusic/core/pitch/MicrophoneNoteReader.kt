// MicrophoneNoteReader.kt — port of MicrophoneNoteReader in iOS Services/Audio/PitchDetection.swift. Turns microphone
// audio into played notes, apart from the audio input so it can be tested with synthetic tones.
package com.lukstrike.luksmusic.core.pitch

/**
 * Slices microphone audio into short hops and reports each key struck, once.
 *
 * When the exercise says which note it wants, that note's own harmonics are watched too, so its strike is caught
 * even in a room full of ringing notes; a strike is then read by what it added to the sound ([StrikeAnalyzer]).
 * Without an expected note (Modo Estudo), a soft note heard without a strike is still read by its pitch.
 *
 * Not thread safe: use it from one thread (the microphone's).
 */
class MicrophoneNoteReader(val sampleRate: Double) {

    /** RMS level of the last hop. */
    var level = 0f
        private set

    /** The notes the exercise wants now: one note is listened for by itself, several must sound together. */
    var expectedNotes: Set<Int>? = null
        set(value) {
            if (value == field) return
            field = value
            chordCountdown = null
            watchHistory.clear()
        }

    /** How many strikes didn't have every note of the expected chord. */
    var missedChords = 0
        private set

    private val expectedChord: Set<Int>? get() = expectedNotes?.takeIf { it.size > 1 }
    private val expectedNote: Int? get() = expectedNotes?.takeIf { it.size == 1 }?.first()

    private val hopSize = 1024
    private val windowSize = 4096
    /** Enough to tell apart notes a semitone from each other, read once the attack has passed. */
    private val chordWindowSize = 8192
    private val chordWaitHops = 9
    /** Hops after a strike before reading it, so the window holds only sound from after the hammer. */
    private val settleHops = 4
    /** A new strike counts this many hops after the last one at the earliest. */
    private val refractoryHops = 5
    /** The expected note's energy rising this many times over its recent low is its strike. */
    private val watchRise = 4f
    private val watchWindowSize = 2048
    /** Pitch readings less periodic than this are noise, or several notes at once. */
    private val minimumClarity = 0.7
    /** Hops a different pitch must hold, with no strike heard, to count as a new note. */
    private val changeFrames = 4

    private var pending = FloatArray(hopSize * 8)
    private var pendingCount = 0
    private val hop = FloatArray(hopSize)
    /** The last [chordWindowSize] samples at most, oldest first. */
    private val window = FloatArray(chordWindowSize)
    private var windowCount = 0
    private var lastSample = 0f
    private val tracker = NoteOnsetTracker()
    private var chordCountdown: Int? = null
    private var hopsSinceStrike = 1_000

    /** A strike waiting to be read: the sound before it, and how it was noticed. */
    private class Strike(val before: FloatArray, var hops: Int, val byWatch: Boolean)

    private var strike: Strike? = null
    private val watchHistory = ArrayList<Float>()
    /** The last note reported, while it still sounds. */
    private var soundingNote: Int? = null
    private var candidate: Int? = null
    private var candidateFrames = 0

    fun reset() {
        pendingCount = 0
        windowCount = 0
        lastSample = 0f
        tracker.reset()
        chordCountdown = null
        hopsSinceStrike = 1_000
        strike = null
        watchHistory.clear()
        soundingNote = null
        candidate = null
        candidateFrames = 0
        level = 0f
    }

    /** Takes the next [count] samples of [samples] (any length) and returns the notes struck in them, in order. */
    fun read(samples: FloatArray, offset: Int = 0, count: Int = samples.size - offset): List<Int> {
        if (pendingCount + count > pending.size) pending = pending.copyOf(maxOf(pending.size * 2, pendingCount + count))
        System.arraycopy(samples, offset, pending, pendingCount, count)
        pendingCount += count
        val notes = ArrayList<Int>(0)
        var start = 0
        while (pendingCount - start >= hopSize) {
            System.arraycopy(pending, start, hop, 0, hopSize)
            start += hopSize
            notes += process(hop)
        }
        System.arraycopy(pending, start, pending, 0, pendingCount - start)
        pendingCount -= start
        return notes
    }

    private fun windowSuffix(count: Int) = Dsp.suffix(window, windowCount, count)

    private fun process(hop: FloatArray): List<Int> {
        val rms = Dsp.rms(hop)
        level = rms
        val brightness = brightness(hop, lastSample)
        lastSample = hop[hop.size - 1]
        val before = if (strike == null) windowSuffix(windowSize) else null
        appendToWindow(hop)
        hopsSinceStrike += 1

        var struck = tracker.isStrike(NoteOnsetTracker.Frame(rms, brightness))
        val isLoud = rms >= tracker.noiseGate
        var byWatch = false
        val expected = expectedNote
        if (expected != null && windowCount >= watchWindowSize) {
            val energy = StrikeAnalyzer.energy(expected, windowSuffix(watchWindowSize), sampleRate)
            if (!struck && isLoud && watchHistory.size >= 3) {
                val low = watchHistory.takeLast(6).min()
                if (energy > low * watchRise && energy > 1e-6f) {
                    struck = true
                    byWatch = true
                }
            }
            watchHistory.add(energy)
            if (watchHistory.size > 12) watchHistory.removeAt(0)
        }

        expectedChord?.let { return readChord(it, struck) }

        if (struck && strike == null && hopsSinceStrike >= refractoryHops) {
            hopsSinceStrike = 0
            // Padded with silence in front while the window is still filling up
            val sound = before ?: FloatArray(0)
            strike = Strike(Dsp.paddedSuffix(sound, sound.size, windowSize), hops = 0, byWatch = byWatch)
            return emptyList()
        }
        strike?.let { waiting ->
            waiting.hops += 1
            if (waiting.hops < settleHops) return emptyList()
            strike = null
            var note = StrikeAnalyzer.struckNote(
                before = StrikeAnalyzer.spectrum(waiting.before, sampleRate),
                after = StrikeAnalyzer.spectrum(windowSuffix(windowSize), sampleRate),
                expected = expected,
            )
            // The watch only listens for the expected note
            if (waiting.byWatch && note != expected) note = null
            if (note == null) return emptyList()
            soundingNote = note
            candidate = null
            candidateFrames = 0
            return listOf(note)
        }

        if (!isLoud) {
            if (tracker.envelope < tracker.noiseGate) soundingNote = null
            candidate = null
            candidateFrames = 0
            return emptyList()
        }
        val estimate = if (expected == null && windowCount >= windowSize) {
            PitchDetector.estimate(windowSuffix(windowSize), sampleRate)
        } else {
            null
        }
        if (estimate == null || estimate.clarity < minimumClarity || estimate.midiNote !in 21..108 ||
            estimate.midiNote == soundingNote
        ) {
            candidate = null
            candidateFrames = 0
            return emptyList()
        }
        // No note expected: a soft note over a loud one, heard by its pitch without a strike
        val note = estimate.midiNote
        if (note == candidate) {
            candidateFrames += 1
        } else {
            candidate = note
            candidateFrames = 1
        }
        if (candidateFrames < changeFrames) return emptyList()
        candidate = null
        candidateFrames = 0
        soundingNote = note
        return listOf(note)
    }

    /** Waits for the attack of a strike to pass, then checks that every expected note is sounding. */
    private fun readChord(chord: Set<Int>, struck: Boolean): List<Int> {
        if (struck) {
            chordCountdown = chordWaitHops
            return emptyList()
        }
        val countdown = chordCountdown ?: return emptyList()
        if (countdown > 1) {
            chordCountdown = countdown - 1
            return emptyList()
        }
        chordCountdown = null
        if (ChordMatcher.matches(windowSuffix(windowCount), sampleRate, chord)) return chord.sorted()
        missedChords += 1
        return emptyList()
    }

    private fun appendToWindow(hop: FloatArray) {
        val overflow = windowCount + hop.size - chordWindowSize
        if (overflow > 0) {
            System.arraycopy(window, overflow, window, 0, windowCount - overflow)
            windowCount -= overflow
        }
        System.arraycopy(hop, 0, window, windowCount, hop.size)
        windowCount += hop.size
    }

    /** The level of the hop's first difference: high frequencies, where a hammer's attack shows. */
    private fun brightness(hop: FloatArray, previous: Float): Float {
        var sum = 0f
        var last = previous
        for (sample in hop) {
            val difference = sample - last
            sum += difference * difference
            last = sample
        }
        return kotlin.math.sqrt(sum / maxOf(1, hop.size))
    }
}
