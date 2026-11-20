// ScoreViewModel.kt — port of luksMusic/ViewModels/ScoreViewModel.swift: the score player's playback, cursor and
// mixer. A 50 Hz clock measures the real time between ticks (so it never drifts), moves the cursor with
// PlaybackClock and strikes the notes each tick crosses on the app's AudioEngine; the metronome clicks come from the
// same clock, so they stay locked to the notes.
package com.lukstrike.luksmusic.feature.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.musicxml.MusicXMLExporter
import com.lukstrike.luksmusic.core.playback.CursorNotes
import com.lukstrike.luksmusic.core.playback.HandsMixer
import com.lukstrike.luksmusic.core.playback.LoopMode
import com.lukstrike.luksmusic.core.playback.PlaybackClock
import com.lukstrike.luksmusic.core.playback.ScorePlayback
import com.lukstrike.luksmusic.core.playback.StruckNote
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.floor
import kotlin.math.min

/** Where the cursor stands: the measure and the beat (1-based) the clock is at. */
data class PlayerPosition(val measure: Int = 0, val beat: Double = 1.0)

class ScoreViewModel(private val container: AppContainer, val scoreId: String) : ViewModel() {

    private val audio = container.audio
    val settings = PlayerSettings(container.settings)

    // MARK: State

    private val _score = MutableStateFlow<Score?>(null)
    val score: StateFlow<Score?> = _score.asStateFlow()

    /** False once the library is loaded and the score is not in it (deleted meanwhile). */
    private val _found = MutableStateFlow(true)
    val found: StateFlow<Boolean> = _found.asStateFlow()

    /** The engraved score's source: the file the score was read from, else its measures exported; null while loading. */
    private val _musicXml = MutableStateFlow<String?>(null)
    val musicXml: StateFlow<String?> = _musicXml.asStateFlow()

    /** Display settings, null until read (so the engraving is drawn once, with the remembered choices). */
    val display: StateFlow<PlayerDisplay?> = settings.display
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val _position = MutableStateFlow(PlayerPosition())
    val position: StateFlow<PlayerPosition> = _position.asStateFlow()

    /** Position in seconds at the written tempo (changes on every tick while playing). */
    private val _elapsedSeconds = MutableStateFlow(0.0)
    val elapsedSeconds: StateFlow<Double> = _elapsedSeconds.asStateFlow()

    /** Keys under the playback cursor, by hand, and the onset the engraved cursor rests on (kept while paused). */
    private val _cursorNotes = MutableStateFlow(CursorNotes())
    val cursorNotes: StateFlow<CursorNotes> = _cursorNotes.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _playbackSpeed = MutableStateFlow(1.0)
    val playbackSpeed: StateFlow<Double> = _playbackSpeed.asStateFlow()

    /** Transposition in semitones (0 = original key). */
    private val _transposition = MutableStateFlow(0)
    val transposition: StateFlow<Int> = _transposition.asStateFlow()

    private val _mixer = MutableStateFlow(HandsMixer())
    val mixer: StateFlow<HandsMixer> = _mixer.asStateFlow()

    private val _loopMode = MutableStateFlow(LoopMode.OFF)
    val loopMode: StateFlow<LoopMode> = _loopMode.asStateFlow()

    /** Metronome: a click on every beat while the piece plays, accented on the first beat of each measure. */
    private val _isMetronomeOn = MutableStateFlow(false)
    val isMetronomeOn: StateFlow<Boolean> = _isMetronomeOn.asStateFlow()

    /** Each click (true on a first beat), so the dock can flash its light. */
    private val _metronomeClicks = MutableSharedFlow<Boolean>(extraBufferCapacity = 8)
    val metronomeClicks: SharedFlow<Boolean> = _metronomeClicks

    /** Note names follow the language on screen (letters in English, solfège in Portuguese); set by the screen. */
    private var usesLetters = false

    private var playback: ScorePlayback? = null
    private var loadedModified: Long? = null
    private var clockJob: Job? = null
    private val playedNoteIds = mutableSetOf<String>()

    val totalSeconds: Double get() = playback?.totalSeconds ?: 0.0
    val measureCount: Int get() = playback?.measureCount ?: 0

    /** The major and relative minor key after transposition ("D, b"). */
    val transpositionKeyText: String
        get() = ScorePlayback.keyText(_score.value?.keySignatureValue ?: 0, _transposition.value)

    init {
        viewModelScope.launch {
            _isMetronomeOn.value = settings.metronome()
            _playbackSpeed.value = settings.speed()
        }
        viewModelScope.launch {
            container.scores.isLoaded.first { it }
            container.scores.scores
                .map { list -> list.firstOrNull { it.id == scoreId } }
                .distinctUntilChanged()
                .collect { onScore(it) }
        }
    }

    /** A new or edited score: the playback is rebuilt and the engraving's source read again when the notes changed. */
    private suspend fun onScore(score: Score?) {
        if (score == null) {
            pause()
            _found.value = false
            return
        }
        _score.value = score
        if (score.lastModified == loadedModified) return // only the favorite changed
        loadedModified = score.lastModified
        val newPlayback = ScorePlayback(score)
        playback = newPlayback
        val position = _position.value
        if (position.measure >= newPlayback.measureCount) {
            pause()
            _position.value = PlayerPosition()
        }
        playedNoteIds.clear()
        refreshActiveNotes()
        _musicXml.value = withContext(Dispatchers.IO) {
            (if (score.hasMusicXml) container.scores.musicXml(score.id) else null) ?: MusicXMLExporter.export(score)
        }
    }

    // MARK: Settings the dock and the sheets change

    fun setUsesLetterNames(letters: Boolean) {
        if (letters == usesLetters) return
        usesLetters = letters
        _cursorNotes.value = CursorNotes() // names are rebuilt below
        refreshActiveNotes()
    }

    fun setTransposition(semitones: Int) {
        _transposition.value = semitones
        refreshActiveNotes()
    }

    fun setPlaybackSpeed(speed: Double) {
        _playbackSpeed.value = speed
        viewModelScope.launch { settings.setSpeed(speed) }
    }

    fun toggleMetronome() {
        val on = !_isMetronomeOn.value
        _isMetronomeOn.value = on
        viewModelScope.launch { settings.setMetronome(on) }
    }

    fun cycleLoopMode() {
        _loopMode.value = _loopMode.value.next
    }

    fun setMixer(mixer: HandsMixer) {
        _mixer.value = mixer
    }

    /** Saves a display setting (the engraving and the dock follow [display]). */
    fun updateSettings(change: suspend PlayerSettings.() -> Unit) {
        viewModelScope.launch { settings.change() }
    }

    fun toggleFavorite() {
        viewModelScope.launch { container.scores.update(scoreId) { it.copy(isFavorite = !it.isFavorite) } }
    }

    // MARK: Playback controls

    fun togglePlayback() = if (_isPlaying.value) pause() else play()

    fun play() {
        if (_isPlaying.value || playback == null) return
        _isPlaying.value = true
        playedNoteIds.clear()

        // Immediately strike the notes on the starting beat
        val beat = _position.value.beat
        triggerNotesAround(beat)
        // Starting on a beat clicks it; otherwise the next beat crossed does
        if (beat - floor(beat) < 0.02) clickMetronome(floor(beat).toInt())

        // 50 Hz clock for a smooth cursor and exact note timing; each tick advances by the real time elapsed
        clockJob = viewModelScope.launch {
            var last = System.nanoTime()
            while (isActive) {
                delay(TICK_MILLIS)
                val now = System.nanoTime()
                // The main thread can stall for a moment (a heavy layout); playback resumes where it stopped, since a
                // jump past barlines would strike every skipped measure's notes at once
                val dt = min((now - last) / 1e9, 0.25)
                last = now
                tick(dt)
            }
        }
    }

    fun pause() {
        _isPlaying.value = false
        clockJob?.cancel()
        clockJob = null
        playedNoteIds.clear()
        audio.stopAllNotes()
    }

    fun stop() {
        pause()
        // A repeated measure is where the loop starts; otherwise the piece starts over
        val measure = if (_loopMode.value == LoopMode.MEASURE) _position.value.measure else 0
        moveTo(measure, 1.0)
    }

    /** Moves the cursor to the note closest to [beat] in measure [index], striking it (tapping a note plays it). */
    fun seek(index: Int, beat: Double) {
        val playback = playback ?: return
        if (index !in 0 until playback.measureCount) return
        moveTo(index, playback.measures[index].nearestOnset(beat))
        playedNoteIds.clear()
        triggerNotesAround(_position.value.beat)
    }

    /** Moves the cursor to the next note or rest, crossing into the next measure after the last one. */
    fun stepForward() {
        val playback = playback ?: return
        val measure = _position.value.measure
        if (measure >= playback.measureCount) return
        val cursor = _cursorNotes.value.cursorBeat
        val next = playback.onsets(measure).firstOrNull { it > cursor + 0.001 }
        when {
            next != null -> seek(measure, next)
            measure + 1 < playback.measureCount -> seek(measure + 1, playback.onsets(measure + 1).firstOrNull() ?: 1.0)
        }
    }

    /** Moves the cursor to the previous note or rest, back into the previous measure from the first one. */
    fun stepBackward() {
        val playback = playback ?: return
        val measure = _position.value.measure
        if (measure >= playback.measureCount) return
        val cursor = _cursorNotes.value.cursorBeat
        val previous = playback.onsets(measure).lastOrNull { it < cursor - 0.001 }
        when {
            previous != null -> seek(measure, previous)
            measure > 0 -> seek(measure - 1, playback.onsets(measure - 1).lastOrNull() ?: 1.0)
        }
    }

    /** Back to the first note of the piece, or of the measure being repeated. */
    fun restart() {
        seek(if (_loopMode.value == LoopMode.MEASURE) _position.value.measure else 0, 1.0)
    }

    // MARK: The clock

    private fun tick(dt: Double) {
        val playback = playback ?: return
        if (!_isPlaying.value) return
        val bpm = playback.score.tempo * _playbackSpeed.value
        val position = _position.value
        val step = PlaybackClock.step(
            measure = position.measure,
            beat = position.beat,
            beats = dt * bpm / 60,
            measureLength = playback.measureLength(position.measure),
            measureCount = playback.measureCount,
            loopMode = _loopMode.value,
        )
        if (step == null) {
            stop()
            return
        }
        moveTo(step.measure, step.beat)
        if (step.crossedBarline) {
            // A new measure, or the repeated one again: its notes sound afresh from the first beat to the clock
            playedNoteIds.clear()
            triggerNotesBetween(0.95, step.beat)
        } else {
            triggerNotesBetween(position.beat, step.beat)
        }
        step.clickBeat?.let(::clickMetronome)
    }

    private fun moveTo(measure: Int, beat: Double) {
        _position.value = PlayerPosition(measure, beat)
        _elapsedSeconds.value = playback?.elapsedSeconds(measure, beat) ?: 0.0
        refreshActiveNotes()
    }

    /** Recomputes the keys under the cursor; called after anything that moves the cursor or changes transposition. */
    private fun refreshActiveNotes() {
        val playback = playback ?: return
        val position = _position.value
        // StateFlow skips equal values, so the dock only redraws when the keys change
        _cursorNotes.value = playback.cursorNotes(position.measure, position.beat, _transposition.value, usesLetters)
    }

    /** Beat 1 is the first of the measure and gets the accented click. */
    private fun clickMetronome(beat: Int) {
        if (!_isMetronomeOn.value) return
        audio.playClick(accent = beat == 1)
        _metronomeClicks.tryEmit(beat == 1)
    }

    private fun triggerNotesBetween(startBeat: Double, endBeat: Double) {
        val playback = playback ?: return
        strike(playback.notesBetween(_position.value.measure, startBeat, endBeat, _mixer.value, _transposition.value, bpm(playback)))
    }

    private fun triggerNotesAround(beat: Double) {
        val playback = playback ?: return
        strike(playback.notesAround(_position.value.measure, beat, _mixer.value, _transposition.value, bpm(playback)))
    }

    private fun bpm(playback: ScorePlayback) = playback.score.tempo * _playbackSpeed.value

    private fun strike(notes: List<StruckNote>) {
        for (note in notes) {
            if (playedNoteIds.add(note.noteId)) {
                audio.playNote(note.midi, note.velocity, note.durationSeconds)
            }
        }
    }

    override fun onCleared() {
        pause()
    }

    private companion object {
        const val TICK_MILLIS = 20L
    }
}
