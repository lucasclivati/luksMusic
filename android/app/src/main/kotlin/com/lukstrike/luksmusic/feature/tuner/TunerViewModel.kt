// TunerViewModel.kt — the tuner tab's state (the logic of iOS Views/Tuner/TunerView.swift): the mode and reference A
// (saved), the string picked by hand, the pitch the microphone hears, and the reading against the nearest note or
// the string being tuned.
package com.lukstrike.luksmusic.feature.tuner

import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.core.model.TunerMode
import com.lukstrike.luksmusic.core.model.Tuning
import com.lukstrike.luksmusic.core.model.TuningReading
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

private val MODE_KEY = stringPreferencesKey("tuner.mode")
private val A4_KEY = doublePreferencesKey("tuner.a4")

data class TunerUiState(
    val mode: TunerMode = TunerMode.GUITAR,
    val a4: Double = Tuning.DEFAULT_A4,
    /** The string picked by hand; null follows the string closest to what is heard. */
    val manualString: Int? = null,
    /** The steady pitch the microphone hears, null in silence. */
    val heardFrequency: Double? = null,
    val inputLevel: Float = 0f,
    val isListening: Boolean = false,
    val errorMessage: String? = null,
) {
    /** The string tuned now: the one picked, or the closest to the pitch heard. */
    val activeString: Int?
        get() = manualString ?: heardFrequency?.let { Tuning.nearestGuitarString(it, a4) }

    val reading: TuningReading?
        get() {
            val frequency = heardFrequency ?: return null
            return when (mode) {
                TunerMode.GUITAR -> activeString?.let { Tuning.reading(frequency, it, a4) }
                TunerMode.PIANO -> Tuning.nearestNote(frequency, a4)
            }
        }
}

class TunerViewModel(private val container: AppContainer) : ViewModel() {

    private val mic = container.microphone
    private val settings = container.settings
    private val manualString = MutableStateFlow<Int?>(null)

    /** Whether this screen turned the microphone on, and so turns it off when it goes away. */
    private var startedListening = false
    private var isVisible = false
    /** The last note read, which the reference button plays in piano mode. */
    private var lastNote: Int? = null

    private val saved = combine(settings.flow(MODE_KEY, TunerMode.GUITAR.key), settings.flow(A4_KEY, Tuning.DEFAULT_A4)) {
        mode, a4 -> TunerMode.fromKey(mode) to a4
    }

    val state: StateFlow<TunerUiState> = combine(
        saved, manualString, mic.tunerFrequency, mic.inputLevel, mic.isListening,
    ) { (mode, a4), manual, frequency, level, listening ->
        TunerUiState(mode, a4, manual, frequency, level, listening)
    }.combine(mic.errorMessage) { state, error -> state.copy(errorMessage = error) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TunerUiState())

    init {
        // Remember the last note read; and the microphone follows the mode's range
        viewModelScope.launch {
            var lastMode: TunerMode? = null
            state.collect { current ->
                current.reading?.midi?.let { lastNote = it }
                if (current.mode != lastMode) {
                    lastMode = current.mode
                    if (isVisible) mic.setTuner(current.mode.lowestFrequency, current.mode.highestFrequency)
                }
            }
        }
    }

    fun setMode(mode: TunerMode) {
        viewModelScope.launch { settings.set(MODE_KEY, mode.key) }
    }

    fun pickString(index: Int?) {
        manualString.value = index
    }

    fun lowerA4() = setA4(Tuning.clampedA4(state.value.a4 - 1))
    fun raiseA4() = setA4(Tuning.clampedA4(state.value.a4 + 1))
    fun resetA4() = setA4(Tuning.DEFAULT_A4)

    private fun setA4(value: Double) {
        viewModelScope.launch { settings.set(A4_KEY, value) }
    }

    /**
     * Plays the string being tuned, or the last note read (A4 before any), at the chosen reference A. The microphone
     * is deaf meanwhile, so the tuner doesn't read its own tone.
     */
    fun playReference() {
        val current = state.value
        val midi = when (current.mode) {
            TunerMode.GUITAR -> Tuning.guitarStrings[current.activeString ?: 0]
            TunerMode.PIANO -> lastNote ?: 69
        }
        val duration = 2.0
        mic.ignoreInput(duration + 0.6)
        container.audio.playReferenceTone(midi, current.a4, duration)
    }

    /** The screen is visible (and the permission granted): listen. */
    fun startListening() {
        isVisible = true
        val mode = state.value.mode
        mic.setTuner(mode.lowestFrequency, mode.highestFrequency)
        if (mic.isListening.value) return
        startedListening = true
        mic.startListening()
    }

    /** The screen went away: stop, unless another screen had the microphone on first. */
    fun stopListening() {
        isVisible = false
        mic.setTuner(null, null)
        if (startedListening) {
            startedListening = false
            mic.stopListening()
        }
    }

    override fun onCleared() {
        if (isVisible) stopListening()
    }
}
