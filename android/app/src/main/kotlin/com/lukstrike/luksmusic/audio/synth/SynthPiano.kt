// SynthPiano.kt — a piano synthesized in real time (the iOS app plays Apple's built-in sampler piano; no SoundFont is
// bundled, so Android makes its own). Additive (modal) synthesis of one string set:
//  - partials stretched by the string's stiffness (inharmonicity B rising from bass to treble), each with its own
//    decay, the upper ones dying faster, and a weaker fundamental in the low bass, as on a real piano;
//  - the first partials doubled by a second, slightly detuned string, whose slow beating gives the warm "chorus" of
//    a piano's unison strings;
//  - a two-stage decay (the fast "prompt" sound, then the long "aftersound");
//  - velocity changes loudness and brightness (a harder blow excites more upper partials), plus a short filtered
//    noise burst for the hammer's knock, and a faster attack;
//  - the damper ends the note quickly on release, except in the top octave and a half, which has no dampers.
package com.lukstrike.luksmusic.audio.synth

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

internal class SynthPiano : PianoSound {
    override fun createVoice(sampleRate: Int): PianoVoice = SynthPianoVoice(sampleRate)
}

private class SynthPianoVoice(private val sampleRate: Int) : PianoVoice {

    // Partials as decaying rotating phasors: z ← z · d·e^{iω} each sample, the sound being Im(z)
    private val real = DoubleArray(MAX_OSCILLATORS)
    private val imaginary = DoubleArray(MAX_OSCILLATORS)
    private val stepCos = DoubleArray(MAX_OSCILLATORS)
    private val stepSin = DoubleArray(MAX_OSCILLATORS)
    private var oscillators = 0
    private val mono = FloatArray(PianoRenderer.MAX_BLOCK_FRAMES)

    private var gain = 0f
    private var leftGain = 0f
    private var rightGain = 0f

    /** Rises from 0 to 1 at the hammer's blow (a fraction of a millisecond to a few). */
    private var attack = 0.0
    private var attackCoefficient = 0.0
    /** Two-stage decay: (1 - promptMix) + promptMix · prompt, prompt falling from 1 to 0. */
    private var prompt = 0.0
    private var promptCoefficient = 0.0
    private var promptMix = 0.0
    /** 1 while the key is down, then falling once the damper touches the strings (or the voice is stolen). */
    private var damper = 1.0
    private var damperCoefficient = 1.0
    private var midi = 60

    // Hammer knock: white noise, low-passed, dying in a few milliseconds
    private var noiseLevel = 0.0
    private var noiseCoefficient = 0.0
    private var noiseAlpha = 0.0
    private var noiseState = 0.0
    private var random = 0x2545F491

    override var isActive = false
        private set
    override var loudness = 0f
        private set

    override fun start(midi: Int, frequency: Double, velocity: Int, pan: Float) {
        this.midi = midi
        val rate = sampleRate.toDouble()
        val v = velocity.coerceIn(1, 127) / 127.0
        val key = ((midi - 21).coerceIn(0, 87)) / 87.0 // 0 low A … 1 top C
        val stiffness = 0.00003 * exp(0.068 * (midi.coerceIn(21, 108) - 21))
        // The fundamental's aftersound decay rate (1/s), from measured pianos: about 35 s to fade (60 dB) at the low A,
        // 17 s at middle C, 4 s two octaves up and about a second at the top C
        val clamped = midi.coerceIn(21, 108)
        val baseDecay = if (clamped <= 60) 0.19 * 2.0.pow((clamped - 21) / 36.0) else 0.4 * 2.0.pow((clamped - 60) / 12.0)
        // Harder blows excite more upper partials; the treble is darker
        val rolloff = 0.62 - 0.45 * v.pow(0.8) + 0.1 * key
        val partialLimit = (22 - 14 * key).toInt()
        val nyquistGuard = 0.45 * rate

        oscillators = 0
        var energy = 0.0
        for (n in 1..partialLimit) {
            val partial = n * frequency * sqrt(1 + stiffness * n * n)
            if (partial >= nyquistGuard) break
            var amplitude = exp(-(n - 1) * rolloff) / sqrt(n.toDouble())
            // The hammer strikes about 1/7 along the string, which mutes the partials with a node there
            amplitude *= 0.35 + 0.65 * abs(sin(PI * n / 7.3))
            // The low bass's fundamental is weak: most of its sound is in the harmonics
            if (n == 1 && midi < 45) amplitude *= 0.35 + 0.65 * (midi - 21).coerceAtLeast(0) / 24.0
            val decay = baseDecay * (1 + 0.3 * (n - 1)) + partial / 4000.0
            // Unison strings: the lowest partials as two slightly detuned strings beating slowly
            if (n <= 3 && midi < 92 && oscillators + 2 <= MAX_OSCILLATORS) {
                val detune = 2.0.pow((0.5 + 0.6 * key) / 1200.0)
                addOscillator(partial * detune, amplitude * 0.5, decay, rate)
                addOscillator(partial / detune, amplitude * 0.5, decay * 1.15, rate)
            } else if (oscillators < MAX_OSCILLATORS) {
                addOscillator(partial, amplitude, decay, rate)
            }
            energy += amplitude * amplitude
        }

        // Every key about as loud for the same velocity; the velocity curve is close to a real piano's
        val loudnessCurve = 0.06 + 0.94 * v.pow(1.8)
        gain = (VOICE_LEVEL * loudnessCurve * (1 - 0.4 * key) / sqrt(maxOf(energy, 1e-9))).toFloat()
        val angle = (pan.coerceIn(-1f, 1f) + 1) * PI / 4 // constant power
        leftGain = cos(angle).toFloat()
        rightGain = sin(angle).toFloat()

        attack = 0.0
        attackCoefficient = exp(-1 / ((0.0025 - 0.0017 * v) * rate))
        prompt = 1.0
        // The prompt sound: most of the energy goes in the first second, then the long aftersound
        promptMix = 0.6
        promptCoefficient = exp(-(baseDecay * 4 + 2.0) / rate)
        damper = 1.0
        damperCoefficient = 1.0
        noiseLevel = VOICE_LEVEL * 0.12 * v.pow(1.5) * (1 - 0.5 * key)
        noiseCoefficient = exp(-1 / ((0.004 + 0.004 * (1 - key)) * rate))
        noiseAlpha = 1 - exp(-2 * PI * (1200 + 5000 * v + 2000 * key) / rate)
        noiseState = 0.0
        isActive = true
        loudness = gain
    }

    private fun addOscillator(frequency: Double, amplitude: Double, decay: Double, rate: Double) {
        val omega = 2 * PI * frequency / rate
        val perSample = exp(-decay / rate)
        // A random starting phase keeps the partials from all peaking together
        random = random xor (random shl 13); random = random xor (random ushr 17); random = random xor (random shl 5)
        val phase = (random and 0xFFFF) / 65536.0 * 2 * PI
        real[oscillators] = amplitude * cos(phase)
        imaginary[oscillators] = amplitude * sin(phase)
        stepCos[oscillators] = perSample * cos(omega)
        stepSin[oscillators] = perSample * sin(omega)
        oscillators += 1
    }

    override fun release() {
        // Dampers end the note in a few tenths of a second (longer in the bass); the top keys have none and ring on
        val seconds = if (midi >= 89) 1.2 else 0.16 - 0.1 * ((midi - 21).coerceIn(0, 67) / 67.0)
        damperCoefficient = minOf(damperCoefficient, exp(-1 / (seconds * sampleRate)))
    }

    override fun fadeOut() {
        damperCoefficient = minOf(damperCoefficient, exp(-1 / (0.004 * sampleRate)))
    }

    override fun render(left: FloatArray, right: FloatArray, frames: Int) {
        if (!isActive) return
        val out = mono
        java.util.Arrays.fill(out, 0, frames, 0f)
        for (p in 0 until oscillators) {
            var r = real[p]
            var i = imaginary[p]
            val c = stepCos[p]
            val s = stepSin[p]
            for (f in 0 until frames) {
                out[f] += i.toFloat()
                val next = r * c - i * s
                i = r * s + i * c
                r = next
            }
            real[p] = r
            imaginary[p] = i
        }

        var a = attack
        var pr = prompt
        var d = damper
        var noise = noiseLevel
        var state = noiseState
        var seed = random
        val mix = promptMix
        val baseGain = gain.toDouble()
        for (f in 0 until frames) {
            a = 1 - (1 - a) * attackCoefficient
            pr *= promptCoefficient
            d *= damperCoefficient
            seed = seed xor (seed shl 13); seed = seed xor (seed ushr 17); seed = seed xor (seed shl 5)
            val white = seed / 2147483648.0
            state += noiseAlpha * (white - state)
            val envelope = a * ((1 - mix) + mix * pr) * d
            val sample = (out[f] * envelope * baseGain + state * noise * d).toFloat()
            noise *= noiseCoefficient
            left[f] += sample * leftGain
            right[f] += sample * rightGain
        }
        attack = a
        prompt = pr
        damper = d
        noiseLevel = noise
        noiseState = state
        random = seed

        // Drop the partials that have died away (the upper ones go first), and the voice once all is silent
        while (oscillators > 0 && magnitude(oscillators - 1) < 1e-6) oscillators -= 1
        var sum = 0.0
        for (p in 0 until oscillators) sum += magnitude(p)
        val level = (sum * ((1 - mix) + mix * pr) * d * baseGain).toFloat()
        loudness = level
        if (level < SILENCE && noise * d < SILENCE) isActive = false
    }

    private fun magnitude(index: Int): Double = abs(real[index]) + abs(imaginary[index])

    private companion object {
        const val MAX_OSCILLATORS = 26
        /** One voice's peak level at full velocity, before the mixer's limiter (leaves headroom for chords). */
        const val VOICE_LEVEL = 0.45
        /** About -90 dB. */
        const val SILENCE = 0.00003f
    }
}
