// DrillController.kt — the sight-reading drill on the desktop (the Android ReadingTrainerViewModel without Android):
// a few notes of one hand, or both, at a time; each key pressed on the MIDI keyboard is checked against the note
// being read, marked right or wrong, and the drill moves through the piece in order or at random. Where the piece was
// being read in order is remembered per score, hand and notes. The rules are core's ReadingDrill.
package com.lukstrike.luksmusic.desktop.drill

import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.core.lessons.ReadingOrder
import com.lukstrike.luksmusic.core.lessons.ReadingPress
import com.lukstrike.luksmusic.core.lessons.ReadingSegmentState
import com.lukstrike.luksmusic.core.lessons.ReadingStep
import com.lukstrike.luksmusic.core.lessons.ReadingStepResult
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.desktop.audio.NotePlayer
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlin.math.roundToLong
import kotlin.random.Random

/** What the line under the staff says. */
sealed interface DrillFeedback {
    data class Prompt(val chord: Int) : DrillFeedback
    data class Correct(val name: String) : DrillFeedback
    data class Wrong(val name: String) : DrillFeedback
    data class Revealed(val name: String) : DrillFeedback
    data class SegmentDone(val clean: Int, val total: Int) : DrillFeedback
    data object NoNotes : DrillFeedback
}

data class DrillState(
    val title: String = "",
    val keySignature: Int = 0,
    val hand: ReadingHand = ReadingHand.RIGHT,
    val notes: ReadingNotes = ReadingNotes.ONE,
    val order: ReadingOrder = ReadingOrder.SEQUENTIAL,
    val segmentSize: Int = 4,
    val advancesAutomatically: Boolean = true,
    val segmentSteps: List<ReadingStep> = emptyList(),
    val results: List<ReadingStepResult> = emptyList(),
    val current: Int = 0,
    val isSegmentComplete: Boolean = false,
    val accidentals: List<List<Accidental?>> = emptyList(),
    val feedback: DrillFeedback = DrillFeedback.NoNotes,
    val wrongPitch: Pitch? = null,
    val listeningStep: Int? = null,
    val segmentNumber: Int = 1,
    val segmentCount: Int = 0,
    /** First and last measure numbers of the passage, null without notes. */
    val measures: Pair<Int, Int>? = null,
    val canGoBack: Boolean = false,
    val answered: Int = 0,
    val answeredClean: Int = 0,
    val streak: Int = 0,
    val bestStreak: Int = 0,
    /** The keys the strip shows, and its lights. */
    val keyRange: IntRange = 48..72,
    val targetKeys: Set<Int> = emptySet(),
    val correctKeys: Set<Int> = emptySet(),
    val incorrectKeys: Set<Int> = emptySet(),
)

class DrillController(
    private val score: Score,
    private val player: NotePlayer,
    private val settings: SettingsStore,
    private val scope: CoroutineScope,
    private val usesLetters: Boolean,
    private val random: Random = Random.Default,
) {
    private val _state = MutableStateFlow(DrillState())
    val state: StateFlow<DrillState> = _state

    private val measures = score.measures
    private val keySignature = score.keySignatureValue
    private val timeSignatureTop = maxOf(1, score.timeSignatureTop)
    private val beatUnit = maxOf(1, score.timeSignatureBottom)
    private val tempo = maxOf(20, score.tempo)

    private var hand = ReadingHand.fromRaw(settings.value.drillHand) ?: ReadingHand.RIGHT
    private var notes = ReadingNotes.fromRaw(settings.value.drillNotes) ?: ReadingNotes.ONE
    private var order = ReadingOrder.fromRaw(settings.value.drillOrder) ?: ReadingOrder.SEQUENTIAL
    private var segmentSize = settings.value.drillSegmentSize.takeIf { it in SEGMENT_SIZES } ?: 4
    private var advancesAutomatically = settings.value.drillAutoAdvance

    private var steps: List<ReadingStep> = emptyList()
    private var segmentStart = 0
    private var segment = ReadingSegmentState(emptyList())
    private var accidentals: List<List<Accidental?>> = emptyList()
    private var feedback: DrillFeedback = DrillFeedback.NoNotes
    private var wrongPitch: Pitch? = null
    private var listeningStep: Int? = null
    private var handRange: IntRange? = null
    private var keyRange: IntRange = 48..72
    private var targetKeys = emptySet<Int>()
    private val correctKeys = mutableSetOf<Int>()
    private val incorrectKeys = mutableSetOf<Int>()

    private var answered = 0
    private var answeredClean = 0
    private var streak = 0
    private var bestStreak = 0

    private var feedbackJob: Job? = null
    private var advanceJob: Job? = null
    private var listenJob: Job? = null

    init {
        loadSteps()
    }

    // ---- Settings

    fun setHand(newHand: ReadingHand) {
        if (newHand == hand) return
        hand = newHand
        settings.update { it.copy(drillHand = newHand.raw) }
        loadSteps()
    }

    fun setNotes(newNotes: ReadingNotes) {
        if (newNotes == notes) return
        notes = newNotes
        settings.update { it.copy(drillNotes = newNotes.raw) }
        loadSteps()
    }

    /** One, two, full, and around again (the N key). */
    fun cycleNotes() = setNotes(ReadingNotes.entries[(notes.ordinal + 1) % ReadingNotes.entries.size])

    fun setOrder(newOrder: ReadingOrder) {
        if (newOrder == order) return
        order = newOrder
        settings.update { it.copy(drillOrder = newOrder.raw) }
        showSegment(if (newOrder == ReadingOrder.RANDOM) randomStart() else savedStart())
    }

    fun toggleOrder() = setOrder(if (order == ReadingOrder.SEQUENTIAL) ReadingOrder.RANDOM else ReadingOrder.SEQUENTIAL)

    fun setSegmentSize(size: Int) {
        if (size == segmentSize || size <= 0) return
        segmentSize = size
        settings.update { it.copy(drillSegmentSize = size) }
        showSegment(
            if (order == ReadingOrder.SEQUENTIAL) DrillNavigation.aligned(segmentStart, size)
            else minOf(segmentStart, maxOf(0, steps.size - size)),
        )
    }

    fun setAdvancesAutomatically(value: Boolean) {
        advancesAutomatically = value
        settings.update { it.copy(drillAutoAdvance = value) }
        publish()
    }

    // ---- Moving through the piece

    fun nextSegment() {
        if (steps.isEmpty()) return
        showSegment(if (order == ReadingOrder.RANDOM) randomStart() else DrillNavigation.next(segmentStart, segmentSize, steps.size))
    }

    fun previousSegment() {
        if (order != ReadingOrder.SEQUENTIAL || segmentStart <= 0) return
        showSegment(DrillNavigation.previous(segmentStart, segmentSize))
    }

    fun repeatSegment() = showSegment(segmentStart)

    fun restartPiece() = showSegment(0)

    // ---- Keys

    /** A key of the MIDI keyboard went down ([sounds]: the app plays it, for a keyboard without speakers). */
    fun keyPressed(midi: Int, velocity: Int = 85, sounds: Boolean = true) {
        if (sounds) player.playNote(midi, velocity)
        val step = segment.currentStep ?: return
        when (val press = segment.press(midi)) {
            ReadingPress.Ignored -> return
            is ReadingPress.Correct -> {
                flash(midi, correct = true)
                wrongPitch = null
                if (press.stepDone) {
                    targetKeys = emptySet()
                    finishStep(step)
                } else {
                    val result = segment.result(segment.current)
                    targetKeys = if (result.revealed) step.midiNotes - result.played else emptySet()
                    setFeedback(DrillFeedback.Prompt(step.midiNotes.size - result.played.size))
                }
            }
            ReadingPress.Wrong -> {
                flash(midi, correct = false)
                val pitch = ReadingDrill.spelledPitch(midi, keySignature)
                wrongPitch = pitch
                setFeedback(DrillFeedback.Wrong(ReadingDrill.name(pitch, usesLetters)), clearsAfter = 1.6)
                if (segment.result(segment.current).mistakes >= MISTAKES_BEFORE_HINT) {
                    reveal()
                    return
                }
            }
        }
        publish()
    }

    fun keyReleased(midi: Int) = player.stopNote(midi)

    /** Shows the current step's keys on the strip and its name. */
    fun reveal() {
        val step = segment.currentStep ?: return
        segment.reveal()
        targetKeys = step.midiNotes - segment.result(segment.current).played
        setFeedback(DrillFeedback.Revealed(ReadingDrill.name(step, usesLetters)))
        publish()
    }

    /** Plays the passage at the score's tempo, lighting each step as it sounds. */
    fun listen() {
        listenJob?.cancel()
        val shown = segment.steps
        val first = shown.firstOrNull() ?: return
        val secondsPerBeat = 60.0 / tempo
        listenJob = scope.launch {
            var previousBeat = first.globalBeat
            for ((index, step) in shown.withIndex()) {
                // Long rests in this hand are shortened so the notes stay together
                val wait = minOf(2.0, (step.globalBeat - previousBeat) * secondsPerBeat)
                previousBeat = step.globalBeat
                if (wait > 0) delay((wait * 1000).roundToLong())
                listeningStep = index
                publish()
                val length = (step.heldBeats * secondsPerBeat).coerceIn(0.25, 1.6)
                for (midi in step.midiNotes) player.playNote(midi, 80, length)
            }
            delay(((shown.last().heldBeats * secondsPerBeat).coerceIn(0.25, 1.6) * 1000).roundToLong())
            listeningStep = null
            publish()
        }
    }

    fun close() {
        listenJob?.cancel()
        advanceJob?.cancel()
        feedbackJob?.cancel()
        player.stopAllNotes()
    }

    // ---- Private

    private fun loadSteps() {
        listenJob?.cancel()
        steps = ReadingDrill.steps(measures, hand, timeSignatureTop, beatUnit, notes)
        val midiNotes = steps.flatMap { it.midiNotes }
        handRange = midiNotes.minOrNull()?.let { it..midiNotes.max() }
        keyRange = 48..72
        if (steps.isEmpty()) {
            segment = ReadingSegmentState(emptyList())
            accidentals = emptyList()
            feedback = DrillFeedback.NoNotes
            publish()
            return
        }
        showSegment(if (order == ReadingOrder.RANDOM) randomStart() else savedStart())
    }

    private fun savedStart(): Int {
        val saved = settings.value.drillPositions[positionKey()] ?: 0
        return DrillNavigation.aligned(if (saved < steps.size) saved else 0, segmentSize)
    }

    private fun showSegment(start: Int) {
        listenJob?.cancel()
        advanceJob?.cancel()
        listeningStep = null
        player.stopAllNotes()
        val range = ReadingDrill.segment(start, segmentSize, steps.size)
        segmentStart = range.first
        val shown = steps.slice(range)
        segment = ReadingSegmentState(shown)
        accidentals = ReadingDrill.printedAccidentals(shown, keySignature)
        wrongPitch = null
        targetKeys = emptySet()
        correctKeys.clear()
        incorrectKeys.clear()
        setFeedback(if (shown.isEmpty()) DrillFeedback.NoNotes else DrillFeedback.Prompt(shown[0].midiNotes.size))
        if (order == ReadingOrder.SEQUENTIAL && settings.value.drillPositions[positionKey()] != segmentStart) {
            val key = positionKey()
            val position = segmentStart
            settings.update { it.copy(drillPositions = it.drillPositions + (key to position)) }
        }
        updateKeyRange()
        publish()
    }

    private fun finishStep(step: ReadingStep) {
        val result = segment.result(segment.current - 1)
        answered += 1
        if (result.isClean) {
            answeredClean += 1
            streak += 1
            bestStreak = maxOf(bestStreak, streak)
        } else {
            streak = 0
        }
        if (!segment.isComplete) {
            setFeedback(DrillFeedback.Correct(ReadingDrill.name(step, usesLetters)), clearsAfter = 1.2)
            return
        }
        val clean = segment.cleanCount
        setFeedback(DrillFeedback.SegmentDone(clean, segment.steps.size))
        if (advancesAutomatically && clean == segment.playableCount) {
            advanceJob?.cancel()
            advanceJob = scope.launch {
                delay(1100)
                if (segment.isComplete) nextSegment()
            }
        }
    }

    /** Shows [newFeedback]; after [clearsAfter] seconds the line asks for the current step again. */
    private fun setFeedback(newFeedback: DrillFeedback, clearsAfter: Double? = null) {
        feedbackJob?.cancel()
        feedback = newFeedback
        if (clearsAfter == null) return
        feedbackJob = scope.launch {
            delay((clearsAfter * 1000).roundToLong())
            val step = segment.currentStep ?: return@launch
            wrongPitch = null
            feedback = DrillFeedback.Prompt(step.midiNotes.size - segment.result(segment.current).played.size)
            publish()
        }
    }

    private fun flash(midi: Int, correct: Boolean) {
        val keys = if (correct) correctKeys else incorrectKeys
        keys += midi
        scope.launch {
            delay(450)
            keys -= midi
            publish()
        }
    }

    private fun updateKeyRange() {
        val segmentNotes = segment.steps.flatMap { it.midiNotes }
        val low = segmentNotes.minOrNull() ?: return
        keyRange = ReadingDrill.keyboardRange(low..segmentNotes.max(), handRange, STRIP_WHITE_KEYS, keyRange)
    }

    private fun randomStart(): Int = ReadingDrill.randomStart(steps.size, segmentSize, segmentStart, random)

    private fun positionKey() = "${score.id}/${hand.raw}/${notes.raw}"

    private fun publish() {
        _state.value = DrillState(
            title = score.title,
            keySignature = keySignature,
            hand = hand,
            notes = notes,
            order = order,
            segmentSize = segmentSize,
            advancesAutomatically = advancesAutomatically,
            segmentSteps = segment.steps,
            results = segment.results,
            current = segment.current,
            isSegmentComplete = segment.isComplete,
            accidentals = accidentals,
            feedback = feedback,
            wrongPitch = wrongPitch,
            listeningStep = listeningStep,
            segmentNumber = segmentStart / maxOf(1, segmentSize) + 1,
            segmentCount = ReadingDrill.segmentCount(steps.size, segmentSize),
            measures = segment.steps.firstOrNull()?.let { it.measureNumber to segment.steps.last().measureNumber },
            canGoBack = order == ReadingOrder.SEQUENTIAL && segmentStart > 0,
            answered = answered,
            answeredClean = answeredClean,
            streak = streak,
            bestStreak = bestStreak,
            keyRange = keyRange,
            targetKeys = targetKeys,
            correctKeys = correctKeys.toSet(),
            incorrectKeys = incorrectKeys.toSet(),
        )
    }

    companion object {
        val SEGMENT_SIZES = listOf(1, 3, 4, 6, 8)
        /** Wrong keys on one step before its answer is shown. */
        const val MISTAKES_BEFORE_HINT = 3
        /** The strip under the staff: about four octaves. */
        const val STRIP_WHITE_KEYS = 29
    }
}

/** Where the next, previous and resumed passages start, in steps (pure, tested). */
object DrillNavigation {
    /** The start of the passage that holds step [start], for passages of [size] steps. */
    fun aligned(start: Int, size: Int): Int = maxOf(0, start) / maxOf(1, size) * maxOf(1, size)

    /** The next passage in order; after the last one the piece starts again. */
    fun next(start: Int, size: Int, stepCount: Int): Int {
        val next = start + maxOf(1, size)
        return if (next < stepCount) next else 0
    }

    fun previous(start: Int, size: Int): Int = maxOf(0, start - maxOf(1, size))
}
