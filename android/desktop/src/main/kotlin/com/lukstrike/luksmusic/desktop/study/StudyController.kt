// StudyController.kt — Modo Estudo on the desktop (the Android PracticeViewModel without Android): core's
// PracticeEngine says which notes are expected and judges each key of the MIDI keyboard; this class runs the timed
// modes' clock, the playhead the falling notes and the staff strip are drawn from, the metronome, and the key strip's
// lights. "Wait for me" (guided) holds the music at each note until it is played.
package com.lukstrike.luksmusic.desktop.study

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.setValue
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.practice.FallingHits
import com.lukstrike.luksmusic.core.practice.FallingNoteTrack
import com.lukstrike.luksmusic.core.practice.PianoKeys
import com.lukstrike.luksmusic.core.practice.PracticeEngine
import com.lukstrike.luksmusic.desktop.audio.NotePlayer
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** How Modo Estudo shows the music. */
enum class StudyView(val raw: String) {
    FALLING("falling"), STAFF("staff");

    companion object {
        fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } ?: FALLING
    }
}

/** Starting, stopping and changing the tempo of a metronome (a fake in the tests). */
interface BeatClock {
    val isRunning: Boolean
    fun start(bpm: Int, beatsPerMeasure: Int)
    fun stop()
    fun setTempo(bpm: Int)
}

data class StudyState(
    val title: String = "",
    val mode: PracticeMode = PracticeMode.GUIDED,
    val view: StudyView = StudyView.FALLING,
    val tempoBpm: Int = 120,
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val measureIndex: Int = 0,
    val measureCount: Int = 1,
    val cursorBeat: Double = 1.0,
    val accuracy: Double = 0.0,
    val streak: Int = 0,
    val played: Int = 0,
    val correct: Int = 0,
    val bestStreak: Int = 0,
    val isMetronomeOn: Boolean = false,
    val keyRange: IntRange = 48..84,
    val targets: Set<Int> = emptySet(),
    val correctKeys: Set<Int> = emptySet(),
    val incorrectKeys: Set<Int> = emptySet(),
    /** The bars at the hit line and their beat colors' start beats. */
    val hits: FallingHits = FallingHits(),
    /** The last session's results, shown after Stop. */
    val lastSummary: Triple<Int, Int, Int>? = null,
) {
    val isPlaying: Boolean get() = isRunning && !isPaused
}

class StudyController(
    private val score: Score,
    private val player: NotePlayer,
    private val metronome: BeatClock?,
    private val settings: SettingsStore,
    private val scope: CoroutineScope,
) {
    private val initialMode = runCatching { PracticeMode.valueOf(settings.value.studyMode) }.getOrDefault(PracticeMode.GUIDED)
    val engine = PracticeEngine(score, initialMode)
    val track = FallingNoteTrack(engine.fallingNotes)
    val beatsPerMeasure: Int get() = engine.beatsPerMeasure

    /** Where the music is drawn from, in beats from 1 at the first measure; advanced every frame while playing. */
    var playhead by mutableDoubleStateOf(0.0)
        private set
    private var holdBeat: Double? = null
    private var clockRunning = false

    private val keyRange = PianoKeys.practiceRange(score.measures.flatMap { m -> m.notes.filter { !it.isRest }.map { it.midiNote } })
    private var view = StudyView.fromRaw(settings.value.studyView)
    private var metronomeOn = settings.value.metronome
    private var hits = FallingHits()
    private val correctKeys = mutableSetOf<Int>()
    private val incorrectKeys = mutableSetOf<Int>()
    private var lastSummary: Triple<Int, Int, Int>? = null
    private var timer: Job? = null

    private val _state = MutableStateFlow(StudyState(title = score.title))
    val state: StateFlow<StudyState> = _state

    init {
        publish()
    }

    // ---- Lifecycle

    fun togglePlay() {
        when {
            !engine.isRunning -> start()
            engine.isPaused -> resume()
            else -> pause()
        }
    }

    fun start() {
        if (engine.isRunning) return
        engine.start()
        lastSummary = null
        startTimer()
        if (metronomeOn) metronome?.start(engine.tempoBpm, engine.beatsPerMeasure)
        publish()
    }

    fun pause() {
        engine.pause()
        stopTimer()
        metronome?.stop()
        player.stopAllNotes()
        publish()
    }

    fun resume() {
        if (!engine.resume()) return
        startTimer()
        if (metronomeOn) metronome?.start(engine.tempoBpm, engine.beatsPerMeasure)
        publish()
    }

    /** Stops and shows the session's results; the next start begins at the first measure again. */
    fun stop() {
        if (!engine.isRunning) return
        engine.stop()
        stopTimer()
        metronome?.stop()
        player.stopAllNotes()
        val tally = engine.tally
        if (tally.totalNotesPlayed > 0) lastSummary = Triple(tally.totalNotesPlayed, tally.correctNotes, tally.longestStreak)
        engine.seek(0, 1.0)
        publish()
    }

    fun close() {
        stopTimer()
        metronome?.stop()
        player.stopAllNotes()
    }

    // ---- Settings

    fun setMode(mode: PracticeMode) {
        if (mode == engine.mode) return
        engine.changeSettings(mode = mode)
        settings.update { it.copy(studyMode = mode.name) }
        settingsChanged()
    }

    fun setTempo(bpm: Int) {
        val clamped = bpm.coerceIn(PracticeEngine.MIN_TEMPO, PracticeEngine.MAX_TEMPO)
        if (clamped == engine.tempoBpm) return
        engine.changeSettings(tempoBpm = clamped)
        settingsChanged()
    }

    fun changeTempo(steps: Int) = setTempo(engine.tempoBpm + steps * PracticeEngine.TEMPO_STEP)

    fun setView(newView: StudyView) {
        view = newView
        settings.update { it.copy(studyView = newView.raw) }
        publish()
    }

    fun toggleView() = setView(if (view == StudyView.FALLING) StudyView.STAFF else StudyView.FALLING)

    fun toggleMetronome() {
        metronomeOn = !metronomeOn
        settings.update { it.copy(metronome = metronomeOn) }
        if (metronomeOn && engine.isPlaying) metronome?.start(engine.tempoBpm, engine.beatsPerMeasure) else metronome?.stop()
        publish()
    }

    /** Moves [delta] measures (the arrows and L1/R1), staying in the piece. */
    fun seekMeasure(delta: Int) {
        val target = (engine.currentMeasureIndex + delta).coerceIn(0, maxOf(0, engine.measures.size - 1))
        engine.seek(target, 1.0)
        publish()
    }

    private fun settingsChanged() {
        stopTimer()
        if (engine.isPlaying) startTimer()
        metronome?.setTempo(engine.tempoBpm)
        publish()
    }

    // ---- Keys

    /** A key went down on the MIDI keyboard; it counts while practice runs. */
    fun keyPressed(midi: Int, velocity: Int = 85, sounds: Boolean = true) {
        if (sounds) player.playNote(midi, velocity)
        if (!engine.isPlaying) return
        val correct = engine.notePlayed(midi)
        val keys = if (correct) correctKeys else incorrectKeys
        keys += midi
        scope.launch {
            delay(350)
            keys -= midi
            publish()
        }
        publish()
    }

    fun keyReleased(midi: Int) = player.stopNote(midi)

    // ---- The playhead

    /** One display frame: the playhead falls on at the tempo, held at the expected notes in guided mode. */
    fun frame(deltaSeconds: Double) {
        if (!clockRunning) return
        playhead = FallingNoteTrack.advance(playhead, deltaSeconds, engine.tempoBpm.toDouble(), holdBeat)
        updateHits()
    }

    private fun updateHits() {
        val now = track.hits(playhead)
        if (now != hits) {
            hits = now
            publish(syncPlayhead = false)
        }
    }

    // ---- Private

    /** The timed modes move on a sixteenth at a time, on a drift-free schedule; guided mode waits for the notes. */
    private fun startTimer() {
        if (!engine.isTimed) return
        timer?.cancel()
        timer = scope.launch {
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

    private fun stopTimer() {
        timer?.cancel()
        timer = null
    }

    private fun publish(syncPlayhead: Boolean = true) {
        if (syncPlayhead) {
            val sync = engine.fallingSync(playhead)
            clockRunning = sync.isPlaying
            holdBeat = sync.holdBeat
            sync.seekTo?.let { playhead = it; hits = track.hits(it) }
            // Stopped: the music rests at the practice position
            if (!engine.isRunning) {
                playhead = engine.absoluteBeat
                hits = track.hits(playhead)
            }
        }
        val tally = engine.tally
        _state.value = StudyState(
            title = score.title,
            mode = engine.mode,
            view = view,
            tempoBpm = engine.tempoBpm,
            isRunning = engine.isRunning,
            isPaused = engine.isPaused,
            measureIndex = engine.currentMeasureIndex,
            measureCount = maxOf(1, engine.measures.size),
            cursorBeat = engine.cursorBeat,
            accuracy = tally.accuracy,
            streak = tally.currentStreak,
            played = tally.totalNotesPlayed,
            correct = tally.correctNotes,
            bestStreak = tally.longestStreak,
            isMetronomeOn = metronomeOn,
            keyRange = keyRange,
            targets = engine.targets,
            correctKeys = correctKeys.toSet(),
            incorrectKeys = incorrectKeys.toSet(),
            hits = hits,
            lastSummary = lastSummary,
        )
    }
}
