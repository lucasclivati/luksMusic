// PianoVoice.kt — the seam between the mixer and the piano sound. The mixer (PianoRenderer) decides which voice plays
// which key, when a key's damper falls (key up, sustain pedal) and which voice to steal; a PianoSound only makes the
// sound of one string set. Today the sound is synthesized (SynthPiano); a sampled piano can replace it by implementing
// these two interfaces, with no change to AudioEngine or the mixer.
package com.lukstrike.luksmusic.audio.synth

/** Makes voices of one piano sound. Called once per voice slot, before the audio starts. */
internal interface PianoSound {
    fun createVoice(sampleRate: Int): PianoVoice
}

/** One sounding key. Every method runs on the audio render thread: no allocation, no locks, no I/O. */
internal interface PianoVoice {
    /** Whether the voice still makes sound; the mixer reuses it once false. */
    val isActive: Boolean

    /** Roughly how loud the voice is now (linear amplitude), to steal the quietest voice when all are busy. */
    val loudness: Float

    /** The hammer strikes: [frequency] in Hz (any tuning), [velocity] 1–127, [pan] -1 (left) to 1 (right). */
    fun start(midi: Int, frequency: Double, velocity: Int, pan: Float)

    /** The damper falls on the strings (key released with the pedal up): the sound dies away quickly. */
    fun release()

    /** Fades out within a few milliseconds, without a click, so the voice can be reused (voice stealing). */
    fun fadeOut()

    /** Adds the next [frames] samples into [left] and [right], from index 0. */
    fun render(left: FloatArray, right: FloatArray, frames: Int)
}
