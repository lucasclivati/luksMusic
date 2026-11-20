// SyntheticAudio.kt — the seeded noise both iOS test files use (SeededNoise / TunerNoise), bit for bit, so the
// synthetic signals here are the same ones the iOS tests hear.
package com.lukstrike.luksmusic.core.pitch

internal class SeededNoise(private var state: Long) {
    fun next(): Float {
        state = state * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
        return (state ushr 32).toInt().toFloat() / Int.MAX_VALUE.toFloat()
    }
}
