// NoteOnsetTracker.kt — port of NoteOnsetTracker in iOS Services/Audio/PitchDetection.swift.
package com.lukstrike.luksmusic.core.pitch

/**
 * Finds the moment a key is struck: the level jumps, or (a softer key over notes still ringing) the hammer's bright
 * attack stands out in the hop's first difference while the level still rises a little.
 */
class NoteOnsetTracker {

    /** One hop of audio. [brightness] is the level of the hop's first difference, which a hammer's attack raises far
     *  more than a ringing note. */
    data class Frame(val level: Float, val brightness: Float = 0f)

    /** Never treat as sound anything quieter than this. */
    var minimumGate = 0.001f
    /** Below this the room is treated as silence: a few times the room's own noise, which is followed as it changes. */
    val noiseGate: Float get() = maxOf(minimumGate, noiseFloor * 3)
    /** A strike raises the level at least this much above the notes still ringing. */
    var attackRatio = 1.45f
    /** Or raises the brightness this much while the level rises at least [softRise]. */
    var brightAttackRatio = 1.5f
    var softRise = 1.1f
    /** How fast the remembered levels fall per hop: a piano note fades slowly, its bright attack quickly. */
    var envelopeDecay = 0.94f
    var brightnessDecay = 0.85f

    var envelope = 0f
        private set
    private var brightEnvelope = 0f
    /** The quietest level heard lately: falls at once, rises slowly while sound goes on. */
    private var noiseFloor = 0.002f

    /** Forgets everything heard so far (after the app played something, or when listening restarts). */
    fun reset() {
        envelope = 0f
        brightEnvelope = 0f
        noiseFloor = 0.002f
    }

    /** Takes the next hop and says whether a key was struck in it. */
    fun isStrike(frame: Frame): Boolean {
        noiseFloor = if (frame.level < noiseFloor) maxOf(frame.level, 0.0001f) else noiseFloor * 1.0015f
        val isLoud = frame.level >= noiseGate
        val strong = isLoud && frame.level > maxOf(envelope, noiseGate * 0.5f) * attackRatio
        val soft = isLoud && !strong && frame.brightness > brightEnvelope * brightAttackRatio &&
            frame.level > envelope * softRise
        envelope = maxOf(frame.level, envelope * envelopeDecay)
        brightEnvelope = maxOf(frame.brightness, brightEnvelope * brightnessDecay)
        return strong || soft
    }
}
