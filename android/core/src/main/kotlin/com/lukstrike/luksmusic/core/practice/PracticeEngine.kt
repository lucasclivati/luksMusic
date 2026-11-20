// PracticeEngine.kt — the rules of Modo Estudo, apart from the screen (the logic of ViewModels/PracticeViewModel.swift):
// where practice is in the score, which notes it expects, how a note played is judged and how practice moves on.
// The app's PracticeViewModel drives it (timer, sound, inputs) and shows its state.
//
// Modes: guided waits on each note (or chord) until it is played; free, slow and hands separate move on by
// themselves at the tempo, a sixteenth at a time; the hands-separate modes only expect one hand's notes.
package com.lukstrike.luksmusic.core.practice

import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.model.PracticeSession
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class PracticeEngine(val score: Score, mode: PracticeMode = PracticeMode.GUIDED) {

    /** The score's measures, read once (the practice clock reads them every step). */
    val measures: List<Measure> = score.measures
    val beatsPerMeasure: Int = max(1, score.timeSignatureTop)

    /** Beats from the start of the piece to each measure (a pickup counts only its own beats); one past the last. */
    private val beatsBefore: DoubleArray = DoubleArray(measures.size + 1).also { sums ->
        for (i in measures.indices) sums[i + 1] = sums[i] + measures[i].beats(score.timeSignatureTop)
    }

    var mode: PracticeMode = mode
        private set
    var tempoBpm: Int = if (mode == PracticeMode.SLOW_PRACTICE) max(40, (score.tempo * 0.7).toInt()) else score.tempo
        private set

    var isRunning = false
        private set
    var isPaused = false
        private set
    var currentMeasureIndex = 0
        private set
    /** 1-based within the current measure. */
    var currentBeat = 1.0
        private set

    var tally = PracticeTally()
        private set

    // Looping / section practice (1-based, inclusive)
    var practiceStartMeasure = 1
        private set
    var practiceEndMeasure = max(1, measures.size)
        private set

    /** The notes to play now and their keys. */
    var expectedNotes: List<Note> = emptyList()
        private set
    var targets: Set<Int> = emptySet()
        private set
    /** Onset of the expected notes in the current measure (drives the engraved score's cursor). */
    var cursorBeat = 1.0
        private set

    // Keys of the expected chord already played (guided mode waits for all of them)
    private var playedTargetNotes = mutableSetOf<Int>()

    /** Score notes as falling bars: beats count from 1 at the first measure, lengths in the time signature's beat. */
    val fallingNotes: List<FallingNote> = measures.flatMapIndexed { index, measure ->
        // The held end of a tie is part of the bar of the note it continues
        measure.notes.filter { !it.isRest && it.isTieContinuation != true }.map { note ->
            FallingNote(
                midiNote = note.midiNote,
                startBeat = beatsBefore[index] + note.beat,
                durationBeats = note.heldBeats(score.timeSignatureBottom),
                hand = if (note.staff == Staff.TREBLE) Hand.RIGHT else Hand.LEFT,
            )
        }
    }

    init {
        updateExpectedNotes()
    }

    /** Whether practice moves on by itself (all modes but guided, which waits for the notes). */
    val isTimed: Boolean get() = mode != PracticeMode.GUIDED

    /** The practice clock's step: a sixteenth at the tempo. */
    val timerStepSeconds: Double get() = 60.0 / tempoBpm / 4.0

    /** The practice position in beats from the start of the piece (the falling notes' clock). */
    val absoluteBeat: Double get() = beatsBefore[min(currentMeasureIndex, measures.size)] + currentBeat

    val isPlaying: Boolean get() = isRunning && !isPaused

    // MARK: - Lifecycle

    fun start() {
        if (isRunning) return
        isRunning = true
        isPaused = false
        tally = PracticeTally()
        currentMeasureIndex = max(0, practiceStartMeasure - 1)
        currentBeat = 1.0
        updateExpectedNotes()
    }

    fun pause() {
        isPaused = true
    }

    /** Returns false when there was nothing to resume. */
    fun resume(): Boolean {
        if (!isRunning || !isPaused) return false
        isPaused = false
        return true
    }

    fun stop() {
        isRunning = false
        isPaused = false
    }

    /** Changes the mode or the tempo; re-targets the expected notes (hand filter, guided stepping). */
    fun changeSettings(mode: PracticeMode = this.mode, tempoBpm: Int = this.tempoBpm) {
        this.mode = mode
        this.tempoBpm = tempoBpm.coerceIn(MIN_TEMPO, MAX_TEMPO)
        updateExpectedNotes()
    }

    // MARK: - Note evaluation

    /**
     * Judges a note played (screen keyboard, MIDI keyboard or microphone): right when it is one of the expected
     * keys. In guided mode, once every note of the expected chord is played, practice moves on to the next note.
     */
    fun notePlayed(midiNote: Int): Boolean {
        val isCorrect = midiNote in targets
        tally = tally.recording(isCorrect)
        if (isCorrect && mode == PracticeMode.GUIDED) {
            playedTargetNotes += midiNote
            if (playedTargetNotes.containsAll(targets)) advanceToNextNote()
        }
        return isCorrect
    }

    // MARK: - Timing & progression

    /** One step of the timed modes' clock. */
    fun advanceTimedStep(step: Double = 0.25) {
        currentBeat += step
        // Beats count from 1, so the measure's last beat ends at its length + 1
        val measureBeats = measures.getOrNull(currentMeasureIndex)?.beats(score.timeSignatureTop)
            ?: score.timeSignatureTop.toDouble()
        if (currentBeat >= measureBeats + 1.0) {
            currentBeat = 1.0
            currentMeasureIndex = if (currentMeasureIndex + 1 < practiceEndMeasure) {
                currentMeasureIndex + 1
            } else {
                // Completed looped section or piece
                max(0, practiceStartMeasure - 1)
            }
        }
        updateExpectedNotes()
    }

    /** Guided mode: steps past the expected notes; [updateExpectedNotes] lands on the next onset. */
    private fun advanceToNextNote() {
        currentBeat += 0.01
        updateExpectedNotes()
    }

    /** Moves practice to a note tapped on the engraved score. */
    fun seek(measureIndex: Int, beat: Double) {
        if (measureIndex !in measures.indices) return
        currentMeasureIndex = measureIndex
        currentBeat = beat
        updateExpectedNotes()
    }

    private fun updateExpectedNotes() {
        playedTargetNotes = mutableSetOf()
        // Guided mode waits on the next note to play, even when it is a few measures ahead
        if (mode == PracticeMode.GUIDED) {
            nextNoteOnset(currentMeasureIndex, currentBeat)?.let { (measure, beat) ->
                currentMeasureIndex = measure
                currentBeat = beat
            }
        }

        val currentMeasure = measures.getOrNull(currentMeasureIndex)
        if (currentMeasure == null) {
            expectedNotes = emptyList()
            targets = emptySet()
            return
        }
        val candidates = practiceNotes(currentMeasure)

        // The latest onset reached; timed modes accept it one timer step early
        val reach = currentBeat + if (mode == PracticeMode.GUIDED) 0.001 else 0.25
        val onset = candidates.map { it.beat }.filter { it <= reach }.maxOrNull()
        expectedNotes = onset?.let { beat -> candidates.filter { abs(it.beat - beat) < 0.001 } } ?: emptyList()
        targets = expectedNotes.mapTo(mutableSetOf()) { it.midiNote }
        cursorBeat = onset ?: currentMeasure.cursorBeat(currentBeat)
    }

    /** Notes the current mode asks for in [measure] (one hand only in the hands-separate modes). */
    private fun practiceNotes(measure: Measure): List<Note> = measure.notes.filter { note ->
        // The held end of a tie is not played again
        if (note.isRest || note.isTieContinuation == true) return@filter false
        when (mode) {
            PracticeMode.HANDS_SEPARATE_RIGHT -> note.staff == Staff.TREBLE
            PracticeMode.HANDS_SEPARATE_LEFT -> note.staff == Staff.BASS
            else -> true
        }
    }

    /** First onset of a note to practice at or after [beat], moving on through the practice range and back to its start. */
    private fun nextNoteOnset(index: Int, beat: Double): Pair<Int, Double>? {
        val first = max(0, practiceStartMeasure - 1)
        val end = min(practiceEndMeasure, measures.size)
        var measureIndex = index
        var fromBeat = beat
        repeat(max(0, end - first) + 1) {
            if (measureIndex >= measures.size) return null
            val onset = practiceNotes(measures[measureIndex]).map { it.beat }.filter { it >= fromBeat - 0.001 }.minOrNull()
            if (onset != null) return measureIndex to onset
            measureIndex = if (measureIndex + 1 < end) measureIndex + 1 else first
            fromBeat = 0.0
        }
        return null
    }

    // MARK: - Falling notes

    /** How the falling notes should follow practice: where they stop, and a jump when they are off. */
    data class FallingSync(val isPlaying: Boolean, val holdBeat: Double?, val seekTo: Double?)

    /**
     * Keeps the falling notes on the practice position, given their clock [fallingBeat]. Guided mode holds them at the
     * expected notes; timed modes let them fall on their own clock and only snap back after a jump (start, loop, a
     * tapped note).
     */
    fun fallingSync(fallingBeat: Double): FallingSync {
        val beat = absoluteBeat
        return if (mode == PracticeMode.GUIDED) {
            // Past the expected notes, or more than a beat behind them (the player got ahead): jump there
            val jump = fallingBeat > beat || fallingBeat < beat - 1.0
            FallingSync(isPlaying, holdBeat = beat, seekTo = beat.takeIf { jump })
        } else {
            FallingSync(isPlaying, holdBeat = null, seekTo = beat.takeIf { abs(fallingBeat - beat) > 0.5 })
        }
    }

    // MARK: - Session record

    fun session(startTime: Long, endTime: Long): PracticeSession = PracticeSession(
        scoreId = score.id,
        scoreTitle = score.title,
        startTime = startTime,
        endTime = endTime,
        totalNotesPlayed = tally.totalNotesPlayed,
        correctNotes = tally.correctNotes,
        incorrectNotes = tally.incorrectNotes,
        missedNotes = tally.missedNotes,
        tempoUsed = tempoBpm,
        sectionsCompleted = currentMeasureIndex + 1,
        longestStreak = tally.longestStreak,
        practiceMode = mode,
    )

    companion object {
        /** The tempo slider's range and step. */
        const val MIN_TEMPO = 40
        const val MAX_TEMPO = 200
        const val TEMPO_STEP = 5
    }
}
