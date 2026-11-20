// PracticeViewModel.kt — Modo Estudo's screen state (port of ViewModels/PracticeViewModel.swift). The rules (expected
// notes, judging, moving on) are core/practice/PracticeEngine; this class drives it: the timed modes' clock, the
// inputs (screen keyboard, MIDI keyboard, microphone), the sound, the metronome, the falling notes and the keyboard's
// lights, and saving the session.
package com.lukstrike.luksmusic.feature.practice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.audio.Metronome
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.musicxml.MusicXMLExporter
import com.lukstrike.luksmusic.core.model.PracticeSession
import com.lukstrike.luksmusic.core.practice.FallingHits
import com.lukstrike.luksmusic.core.practice.PianoKeys
import com.lukstrike.luksmusic.core.practice.PracticeEngine
import com.lukstrike.luksmusic.ui.components.PianoKeyboardState
import com.lukstrike.luksmusic.ui.theme.LuksColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** What the screen shows (the falling notes and the keyboard have their own state classes, redrawn every frame). */
data class PracticeUiState(
    val isLoaded: Boolean = false,
    /** The score is gone from the library: the screen closes. */
    val isMissing: Boolean = false,
    val title: String = "",
    val measureCount: Int = 1,
    val musicXml: String = "",
    val mode: PracticeMode = PracticeMode.GUIDED,
    val tempoBpm: Int = 120,
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val measureIndex: Int = 0,
    val cursorBeat: Double = 1.0,
    val accuracy: Double = 0.0,
    val currentStreak: Int = 0,
    val isMicrophoneEnabled: Boolean = false,
    /** The last key the microphone heard (shown as "Microphone: C4"). */
    val detectedNote: Int? = null,
    /** The microphone expected a chord and did not hear all of it. */
    val chordMissed: Boolean = false,
    val isMetronomeOn: Boolean = false,
    /** The microphone is on without headphones, so the metronome only shows the beat. */
    val isMetronomeSilent: Boolean = false,
    /** The summary sheet, when shown. */
    val stats: PracticeSession? = null,
) {
    val isPlaying: Boolean get() = isRunning && !isPaused
}

/** A metronome beat, so the button can flash; apart from [PracticeUiState] so a beat redraws only the button. */
data class MetronomeTick(val count: Int = 0, val isAccent: Boolean = false)

class PracticeViewModel(
    private val container: AppContainer,
    context: Context,
    private val scoreId: String,
    private val initialMode: PracticeMode,
) : ViewModel() {

    /** The keyboard's lights; the screen's PianoKeyboard draws it. */
    val keyboard = PianoKeyboardState()
    /** Falling notes above the keyboard, kept on the practice position (one instance, so redraws don't restart them). */
    val fallingNotes = FallingNotesState()

    private val _ui = MutableStateFlow(PracticeUiState(mode = initialMode))
    val ui: StateFlow<PracticeUiState> = _ui.asStateFlow()

    private val _metronomeTick = MutableStateFlow(MetronomeTick())
    val metronomeTick: StateFlow<MetronomeTick> = _metronomeTick.asStateFlow()

    private val audio = container.audio
    private val microphone = container.microphone
    private val metronome = Metronome(audio)
    private val appContext = context.applicationContext
    private val headphones = Headphones(appContext)

    private var engine: PracticeEngine? = null
    private var practiceTimer: Job? = null
    private var sessionStartTime = System.currentTimeMillis()
    /** The session saved when practice stopped (the summary's rating updates it). */
    private var latestSession: PracticeSession? = null

    // Visual feedback on the keyboard, a moment after each note
    private val correctFeedback = mutableSetOf<Int>()
    private val incorrectFeedback = mutableSetOf<Int>()
    private var chordMissedJob: Job? = null

    /** Whether the screen is showing (the microphone and the metronome run only then). */
    private var isOnScreen = false

    init {
        metronome.onBeat = { beat -> _metronomeTick.update { MetronomeTick(it.count + 1, beat.isAccent) } }
        fallingNotes.onHitsChanged = ::lightHitKeys
        headphones.watch { updateMetronomeSilence() }
        viewModelScope.launch { load() }
        listenToInstruments()
    }

    private suspend fun load() {
        val scores = container.scores
        scores.isLoaded.first { it }
        val score = scores.get(scoreId)
        if (score == null) {
            _ui.update { it.copy(isMissing = true) }
            return
        }
        // The strip shows the score as the app reads it (exported from its measures, as on iOS), so the measure and
        // beat of a tapped note are the ones practice uses, even where the original file differs (repeats, pickups)
        val musicXml = withContext(Dispatchers.Default) { MusicXMLExporter.export(score) }
        val practice = PracticeEngine(score, initialMode)
        val range = PianoKeys.practiceRange(score.measures.flatMap { m -> m.notes.filter { !it.isRest }.map { it.midiNote } })
        keyboard.rangeStart = range.first
        keyboard.rangeEnd = range.last
        fallingNotes.keyboardRangeStart = range.first
        fallingNotes.keyboardRangeEnd = range.last
        fallingNotes.beatsPerMeasure = practice.beatsPerMeasure
        fallingNotes.setNotes(practice.fallingNotes)
        engine = practice
        val metronomeOn = container.settings.get(METRONOME_KEY, false)
        _ui.update {
            it.copy(
                isLoaded = true, title = score.title, measureCount = maxOf(1, score.measureCount), musicXml = musicXml,
                isMetronomeOn = metronomeOn,
            )
        }
        publish()
        if (isOnScreen) startMetronomeIfOn()
    }

    /** MIDI keyboard and microphone notes count while practice runs (a real instrument makes its own sound). */
    private fun listenToInstruments() {
        viewModelScope.launch {
            container.midi.noteOn.collect { note ->
                if (_ui.value.isPlaying) notePlayed(note.note, fromInstrument = true)
            }
        }
        viewModelScope.launch {
            container.midi.sustainPedal.collect { down -> keyboard.isSustainActive = down }
        }
        viewModelScope.launch {
            microphone.notesDetected.collect { note ->
                val state = _ui.value
                if (!state.isMicrophoneEnabled) return@collect
                _ui.update { it.copy(detectedNote = note) }
                if (state.isPlaying) notePlayed(note, fromInstrument = true)
            }
        }
        viewModelScope.launch {
            microphone.chordMissed.collect {
                val state = _ui.value
                if (!state.isMicrophoneEnabled || !state.isPlaying) return@collect
                _ui.update { it.copy(chordMissed = true) }
                chordMissedJob?.cancel()
                chordMissedJob = viewModelScope.launch { delay(2_500); _ui.update { it.copy(chordMissed = false) } }
            }
        }
    }

    // MARK: - Screen lifecycle

    /** The screen is showing: the metronome, if it was left on, and the microphone, if it was on, start again. */
    fun onScreenStarted() {
        isOnScreen = true
        startMetronomeIfOn()
        if (_ui.value.isMicrophoneEnabled) {
            if (hasMicrophonePermission()) microphone.startListening() else setMicrophone(false)
        }
    }

    /** The screen went away (another app, screen off): practice pauses, the metronome and the microphone stop. */
    fun onScreenStopped() {
        isOnScreen = false
        metronome.stop()
        if (_ui.value.isPlaying) pausePractice()
        if (_ui.value.isMicrophoneEnabled) microphone.stopListening()
    }

    // MARK: - Practice lifecycle

    fun startPractice() {
        val engine = engine ?: return
        if (engine.isRunning) return
        engine.start()
        sessionStartTime = System.currentTimeMillis()
        latestSession = null
        startPracticeTimer()
        publish()
    }

    fun pausePractice() {
        val engine = engine ?: return
        engine.pause()
        stopPracticeTimer()
        audio.stopAllNotes()
        publish()
    }

    fun resumePractice() {
        val engine = engine ?: return
        if (!engine.resume()) return
        startPracticeTimer()
        publish()
    }

    /** The play button: start, pause or resume. */
    fun togglePlay() {
        val state = _ui.value
        when {
            !state.isRunning -> startPractice()
            state.isPaused -> resumePractice()
            else -> pausePractice()
        }
    }

    /**
     * Stops practice and saves the session if notes were played, then shows its summary unless [showSummary] is false
     * (closing the screen with "Done").
     */
    fun stopPractice(showSummary: Boolean = true) {
        val engine = engine ?: return
        engine.stop()
        stopPracticeTimer()
        audio.stopAllNotes()
        if (_ui.value.isMicrophoneEnabled) {
            // So the microphone button, and the metronome's silence, don't show a microphone that stopped listening
            setMicrophone(false)
        }
        // Not again when nothing was played since the last save (Stop, then Done)
        val alreadySaved = latestSession?.totalNotesPlayed == engine.tally.totalNotesPlayed
        if (engine.tally.totalNotesPlayed > 0 && !alreadySaved) {
            val session = engine.session(sessionStartTime, System.currentTimeMillis())
            latestSession = session
            save(session, markPracticed = true)
            if (showSummary) _ui.update { it.copy(stats = session) }
        }
        publish()
    }

    /** "Practice summary" in the menu: the session so far, or the one just saved. */
    fun showSummary() {
        val engine = engine ?: return
        _ui.update { it.copy(stats = latestSession ?: engine.session(sessionStartTime, System.currentTimeMillis())) }
    }

    fun dismissSummary() {
        _ui.update { it.copy(stats = null) }
    }

    /** The summary's stars, kept with the saved session. */
    fun rateSession(stars: Int) {
        val session = latestSession ?: return
        if (_ui.value.stats?.id != session.id) return
        val rated = session.copy(difficultyRating = stars)
        latestSession = rated
        _ui.update { it.copy(stats = rated) }
        save(rated, markPracticed = false)
    }

    private fun save(session: PracticeSession, markPracticed: Boolean) {
        // The screen may close right away: the save must finish anyway
        viewModelScope.launch {
            withContext(NonCancellable) {
                container.practice.save(session)
                if (markPracticed) container.scores.update(scoreId) { it.copy(lastPracticed = session.endTime) }
            }
        }
    }

    // MARK: - Settings

    fun setMode(mode: PracticeMode) {
        val engine = engine ?: return
        if (mode == engine.mode) return
        engine.changeSettings(mode = mode)
        practiceSettingsChanged()
    }

    fun setTempo(bpm: Int) {
        val engine = engine ?: return
        if (bpm == engine.tempoBpm) return
        engine.changeSettings(tempoBpm = bpm)
        practiceSettingsChanged()
    }

    /** Restarts the timer after the mode or tempo changes; the metronome takes the new tempo at once. */
    private fun practiceSettingsChanged() {
        val engine = engine ?: return
        stopPracticeTimer()
        if (engine.isPlaying) startPracticeTimer()
        metronome.setTempo(engine.tempoBpm)
        publish()
    }

    /** Moves practice to a note tapped on the engraved score. */
    fun seek(measureIndex: Int, beat: Double) {
        engine?.seek(measureIndex, beat) ?: return
        publish()
    }

    // MARK: - Note evaluation

    /** A key touched on the screen keyboard, which sounds through the app. */
    fun screenKeyPressed(midiNote: Int) = notePlayed(midiNote, fromInstrument = false)

    fun screenKeyReleased(midiNote: Int) {
        audio.stopNote(midiNote)
    }

    /** Evaluates a note played by the user (screen keyboard, external MIDI, or acoustic piano via microphone). */
    private fun notePlayed(midiNote: Int, fromInstrument: Boolean) {
        val engine = engine ?: return
        // A real instrument makes its own sound
        if (!fromInstrument) {
            audio.playNote(midiNote, velocity = 85)
            // The phone's speaker must not count as the piano
            if (_ui.value.isMicrophoneEnabled) microphone.ignoreInput(0.5)
        }
        val isCorrect = engine.notePlayed(midiNote)
        flash(midiNote, if (isCorrect) correctFeedback else incorrectFeedback)
        publish()
    }

    private fun flash(midiNote: Int, keys: MutableSet<Int>) {
        keys += midiNote
        showFeedback()
        viewModelScope.launch {
            delay(350)
            keys -= midiNote
            showFeedback()
        }
    }

    private fun showFeedback() {
        keyboard.correctKeys = correctFeedback.toSet()
        keyboard.incorrectKeys = incorrectFeedback.toSet()
    }

    // MARK: - Timing & progression

    /** The timed modes move on a sixteenth at a time, on a drift-free schedule. Guided mode waits for the notes. */
    private fun startPracticeTimer() {
        val engine = engine ?: return
        if (!engine.isTimed) return
        practiceTimer?.cancel()
        practiceTimer = viewModelScope.launch {
            val stepNanos = (engine.timerStepSeconds * 1_000_000_000).toLong()
            var next = System.nanoTime() + stepNanos
            while (isActive) {
                delay(maxOf(0L, (next - System.nanoTime()) / 1_000_000))
                engine.advanceTimedStep()
                publish()
                next += stepNanos
            }
        }
    }

    private fun stopPracticeTimer() {
        practiceTimer?.cancel()
        practiceTimer = null
    }

    /** Shows the engine's state: the screen, the keyboard's targets, the falling notes and the microphone's hint. */
    private fun publish() {
        val engine = engine ?: return
        if (keyboard.targetNoteKeys != engine.targets) keyboard.targetNoteKeys = engine.targets
        syncFallingNotes(engine)
        if (_ui.value.isMicrophoneEnabled) microphone.expect(engine.targets.takeIf { it.isNotEmpty() })
        _ui.update {
            it.copy(
                mode = engine.mode,
                tempoBpm = engine.tempoBpm,
                isRunning = engine.isRunning,
                isPaused = engine.isPaused,
                measureIndex = engine.currentMeasureIndex,
                cursorBeat = engine.cursorBeat,
                accuracy = engine.tally.accuracy,
                currentStreak = engine.tally.currentStreak,
            )
        }
    }

    /** Keeps the falling notes on the practice position (see PracticeEngine.fallingSync). */
    private fun syncFallingNotes(engine: PracticeEngine) {
        val sync = engine.fallingSync(fallingNotes.currentBeat)
        fallingNotes.isPlaying = sync.isPlaying
        fallingNotes.tempo = engine.tempoBpm.toDouble()
        fallingNotes.holdBeat = sync.holdBeat
        sync.seekTo?.let(fallingNotes::seek)
    }

    /** The bars at the hit line light their keys in their beat colors. */
    private fun lightHitKeys(hits: FallingHits) {
        keyboard.midiActiveKeys = hits.active
        keyboard.bassActiveKeys = hits.bass
        keyboard.trebleActiveKeys = hits.treble
        keyboard.keyColorsByNote = hits.startBeats.mapValues { (_, start) ->
            LuksColors.colorForBeat(start, fallingNotes.beatsPerMeasure)
        }
    }

    // MARK: - Microphone

    /** Turns the microphone on or off. The screen asks for the permission first. */
    fun setMicrophone(on: Boolean) {
        if (on == _ui.value.isMicrophoneEnabled) return
        _ui.update { it.copy(isMicrophoneEnabled = on, detectedNote = null, chordMissed = false) }
        if (on) {
            microphone.startListening()
            microphone.expect(engine?.targets?.takeIf { it.isNotEmpty() })
        } else {
            microphone.stopListening()
            microphone.expect(null)
        }
        updateMetronomeSilence()
    }

    private fun hasMicrophonePermission() =
        ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    // MARK: - Metronome

    fun toggleMetronome() {
        val on = !_ui.value.isMetronomeOn
        _ui.update { it.copy(isMetronomeOn = on) }
        viewModelScope.launch { container.settings.set(METRONOME_KEY, on) }
        if (on) startMetronomeIfOn() else metronome.stop()
        updateMetronomeSilence()
    }

    /** Starts the metronome when the screen shows, if it was left on. */
    private fun startMetronomeIfOn() {
        val engine = engine ?: return
        if (!_ui.value.isMetronomeOn || metronome.isRunning) return
        updateMetronomeSilence()
        metronome.start(engine.tempoBpm, engine.beatsPerMeasure)
    }

    /** Silent (it only flashes) while the microphone listens without headphones, so its clicks don't count as notes. */
    private fun updateMetronomeSilence() {
        val state = _ui.value
        val silent = state.isMetronomeOn && state.isMicrophoneEnabled && !headphones.areConnected
        metronome.isMuted = state.isMicrophoneEnabled && !headphones.areConnected
        if (silent != state.isMetronomeSilent) _ui.update { it.copy(isMetronomeSilent = silent) }
    }

    override fun onCleared() {
        stopPracticeTimer()
        metronome.stop()
        metronome.onBeat = null
        headphones.stop()
        fallingNotes.onHitsChanged = null
        audio.stopAllNotes()
        if (_ui.value.isMicrophoneEnabled) {
            microphone.stopListening()
            microphone.expect(null)
        }
    }

    companion object {
        /** Remembers whether the metronome was on (iOS "practice.metronome"). */
        private val METRONOME_KEY = booleanPreferencesKey("practice.metronome")

        fun factory(container: AppContainer, context: Context, scoreId: String, mode: PracticeMode) = viewModelFactory {
            initializer { PracticeViewModel(container, context.applicationContext, scoreId, mode) }
        }
    }
}
