// ReadingTrainerViewModel.kt — port of luksMusic/ViewModels/ReadingTrainerViewModel.swift.
//
// The sight-reading drill: shows a few notes of one hand (or both) at a time, checks the keys pressed on the screen's
// keyboard (or a MIDI keyboard), marks each note right or wrong, and moves through the piece in order or at random.
// The position in the piece is remembered per score and hand, so learning a piece can continue on another day.
package com.lukstrike.luksmusic.feature.learn

import android.app.Application
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingKeyLabels
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.core.lessons.ReadingOrder
import com.lukstrike.luksmusic.core.lessons.ReadingPress
import com.lukstrike.luksmusic.core.lessons.ReadingSegmentState
import com.lukstrike.luksmusic.core.lessons.ReadingStep
import com.lukstrike.luksmusic.core.lessons.ReadingStepResult
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Clef
import com.lukstrike.luksmusic.core.model.ClefChoice
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.ui.AppLanguage
import com.lukstrike.luksmusic.ui.components.KeyLabelStyle
import com.lukstrike.luksmusic.ui.components.PianoKeyboardState
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.random.Random

/** What the line under the staff says. */
sealed interface ReadingFeedback {
    data class Prompt(val chord: Int) : ReadingFeedback
    data class Correct(val name: String) : ReadingFeedback
    data class Wrong(val name: String) : ReadingFeedback
    data class Revealed(val name: String) : ReadingFeedback
    data class SegmentDone(val clean: Int, val total: Int) : ReadingFeedback
    data object NoNotes : ReadingFeedback
}

@Immutable
data class ReadingUiState(
    val isLoaded: Boolean = false,
    /** The score is gone from the library */
    val isMissing: Boolean = false,
    val title: String = "",
    val keySignature: Int = 0,
    val hand: ReadingHand = ReadingHand.RIGHT,
    /** How many of the notes struck together are asked for */
    val notes: ReadingNotes = ReadingNotes.ALL,
    val order: ReadingOrder = ReadingOrder.SEQUENTIAL,
    /** Whether the screen shows its keyboard (hidden when playing on a real piano or a MIDI keyboard) */
    val showsKeyboard: Boolean = true,
    val segmentSize: Int = 3,
    val advancesAutomatically: Boolean = true,
    val keyLabels: ReadingKeyLabels = ReadingKeyLabels.SOLFEGE,
    val clefChoice: ClefChoice = ClefChoice.SCORE,
    val automaticUsesAlto: Boolean = true,
    val clef: Clef = Clef.TREBLE,
    val hasSteps: Boolean = false,
    val segmentSteps: List<ReadingStep> = emptyList(),
    val results: List<ReadingStepResult> = emptyList(),
    val current: Int = 0,
    val isSegmentComplete: Boolean = false,
    val accidentals: List<List<Accidental?>> = emptyList(),
    val feedback: ReadingFeedback = ReadingFeedback.NoNotes,
    val wrongPitch: Pitch? = null,
    val listeningStep: Int? = null,
    val segmentNumber: Int = 1,
    val segmentCount: Int = 0,
    /** First and last measure numbers of the segment (0 = pickup), null without notes */
    val measures: Pair<Int, Int>? = null,
    val canGoBack: Boolean = false,
    val answered: Int = 0,
    val answeredClean: Int = 0,
    val streak: Int = 0,
    val bestStreak: Int = 0,
) {
    val cleanPercentage: Int get() = if (answered == 0) 0 else (answeredClean.toDouble() / answered * 100).roundToInt()
}

class ReadingTrainerViewModel(
    private val scoreId: String,
    private val app: Application,
    private val container: AppContainer,
) : ViewModel() {

    private val audio = container.audio
    private val settings = container.settings

    /** The on-screen keyboard (range, key labels, right and wrong flashes, hints) */
    val keyboard = PianoKeyboardState()

    private val _haptics = MutableSharedFlow<LearnHaptic>(extraBufferCapacity = 8)
    val haptics: SharedFlow<LearnHaptic> = _haptics

    private val _state = MutableStateFlow(ReadingUiState())
    val state: StateFlow<ReadingUiState> = _state.asStateFlow()

    // The piece
    private var title = ""
    private var measures: List<Measure> = emptyList()
    private var keySignature = 0
    private var timeSignatureTop = 4
    private var beatUnit = 4
    private var tempo = 120

    // Choices
    private var hand = ReadingHand.RIGHT
    private var notes = ReadingNotes.ALL
    private var order = ReadingOrder.SEQUENTIAL
    private var showsKeyboard = true
    private var segmentSize = 3
    private var advancesAutomatically = true
    private var keyLabels = ReadingKeyLabels.SOLFEGE
    private var clefChoice = ClefChoice.SCORE
    private var automaticUsesAlto = true

    // Reading
    private var steps: List<ReadingStep> = emptyList()
    private var segmentStart = 0
    private var segment = ReadingSegmentState(emptyList())
    private var accidentals: List<List<Accidental?>> = emptyList()
    private var feedback: ReadingFeedback = ReadingFeedback.NoNotes
    private var wrongPitch: Pitch? = null
    private var listeningStep: Int? = null
    private var savedPosition: Int? = null

    // Session results
    private var answered = 0
    private var answeredClean = 0
    private var streak = 0
    private var bestStreak = 0

    private var whiteKeys = 15
    private var handRange: IntRange? = null
    private val random = Random.Default
    private var feedbackJob: Job? = null
    private var advanceJob: Job? = null
    private var listenJob: Job? = null
    private var isLoaded = false

    private val usesLetters get() = AppLanguage.usesLetterNames(app)

    init {
        viewModelScope.launch { load() }
        // A MIDI keyboard makes its own sound; its keys light on the screen's keyboard while held
        viewModelScope.launch {
            container.midi.noteOn.collect { event ->
                keyboard.midiActiveKeys += event.note
                keyPressed(event.note, fromInstrument = true)
            }
        }
        viewModelScope.launch { container.midi.noteOff.collect { keyboard.midiActiveKeys -= it } }
    }

    private suspend fun load() {
        container.scores.isLoaded.first { it }
        val score: Score = container.scores.get(scoreId) ?: run {
            _state.value = ReadingUiState(isLoaded = true, isMissing = true)
            return
        }
        title = score.title
        measures = score.measures
        keySignature = score.keySignatureValue
        timeSignatureTop = maxOf(1, score.timeSignatureTop)
        beatUnit = maxOf(1, score.timeSignatureBottom)
        tempo = maxOf(20, score.tempo)

        hand = ReadingHand.fromRaw(settings.get(LearnKeys.DRILL_HAND, "")) ?: ReadingHand.RIGHT
        notes = ReadingNotes.fromRaw(settings.get(NOTES_KEY, "")) ?: ReadingNotes.ALL
        showsKeyboard = settings.get(SHOWS_KEYBOARD_KEY, true)
        clefChoice = storedClefChoice(hand)
        automaticUsesAlto = settings.get(LearnKeys.AUTOMATIC_USES_ALTO, true)
        order = ReadingOrder.fromRaw(settings.get(LearnKeys.DRILL_ORDER, "")) ?: ReadingOrder.SEQUENTIAL
        val size = settings.get(LearnKeys.DRILL_SEGMENT_SIZE, 0)
        segmentSize = if (size in SEGMENT_SIZES) size else 3
        advancesAutomatically = settings.get(LearnKeys.DRILL_AUTO_ADVANCE, true)
        // Until chosen, the keys are named the app's way: letters in English, solfège in Portuguese
        keyLabels = ReadingKeyLabels.fromRaw(settings.get(LearnKeys.DRILL_KEY_LABELS, ""))
            ?: if (usesLetters) ReadingKeyLabels.LETTERS else ReadingKeyLabels.SOLFEGE

        isLoaded = true
        applyKeyLabels()
        loadSteps(resume = true)
    }

    // ---- Settings

    fun setHand(newHand: ReadingHand) {
        if (newHand == hand || !isLoaded) return
        hand = newHand
        save { settings.set(LearnKeys.DRILL_HAND, newHand.raw) }
        viewModelScope.launch {
            clefChoice = storedClefChoice(newHand)
            loadSteps(resume = true)
        }
    }

    fun setNotes(newNotes: ReadingNotes) {
        if (newNotes == notes || !isLoaded) return
        notes = newNotes
        save { settings.set(NOTES_KEY, newNotes.raw) }
        viewModelScope.launch { loadSteps(resume = true) }
    }

    fun setShowsKeyboard(value: Boolean) {
        showsKeyboard = value
        save { settings.set(SHOWS_KEYBOARD_KEY, value) }
        publish()
    }

    fun setClefChoice(choice: ClefChoice) {
        clefChoice = choice
        save { settings.set(clefKey(hand), choice.raw) }
        publish()
    }

    fun setAutomaticUsesAlto(value: Boolean) {
        automaticUsesAlto = value
        save { settings.set(LearnKeys.AUTOMATIC_USES_ALTO, value) }
        publish()
    }

    /**
     * The clef the staff shows: the chosen one, or for "Automática" the one that writes this segment with the
     * fewest ledger lines. "Original" is the hand's usual clef, sol for the right and fá for the left.
     */
    private val clef: Clef
        get() {
            val usual = Clef.of(hand.staff)
            clefChoice.fixedClef?.let { return it }
            if (clefChoice != ClefChoice.AUTOMATIC) return usual
            val pitches = segment.steps.flatMap { it.notes }.filter { !it.isRest }.map { it.pitch }
            return Clef.fewestLedgerLines(pitches, usual, automaticUsesAlto)
        }

    /** Each hand's clef is remembered apart, under the keys the score player uses too. */
    private fun clefKey(hand: ReadingHand) = if (hand == ReadingHand.RIGHT) LearnKeys.CLEF_RIGHT else LearnKeys.CLEF_LEFT

    private suspend fun storedClefChoice(hand: ReadingHand): ClefChoice = ClefChoice.fromRaw(settings.get(clefKey(hand), ""))

    fun setOrder(newOrder: ReadingOrder) {
        if (newOrder == order || !isLoaded) return
        order = newOrder
        save { settings.set(LearnKeys.DRILL_ORDER, newOrder.raw) }
        if (newOrder == ReadingOrder.RANDOM) {
            showSegment(randomStart())
        } else {
            // Back to where the piece was being read in order
            viewModelScope.launch {
                val saved = settings.get(positionKey(), 0)
                showSegment(alignedStart(if (saved < steps.size) saved else 0))
            }
        }
    }

    fun setSegmentSize(size: Int) {
        if (size == segmentSize || size <= 0) return
        segmentSize = size
        save { settings.set(LearnKeys.DRILL_SEGMENT_SIZE, size) }
        showSegment(if (order == ReadingOrder.SEQUENTIAL) alignedStart(segmentStart) else minOf(segmentStart, maxOf(0, steps.size - size)))
    }

    fun setAdvancesAutomatically(value: Boolean) {
        advancesAutomatically = value
        save { settings.set(LearnKeys.DRILL_AUTO_ADVANCE, value) }
        publish()
    }

    fun setKeyLabels(labels: ReadingKeyLabels) {
        keyLabels = labels
        save { settings.set(LearnKeys.DRILL_KEY_LABELS, labels.raw) }
        applyKeyLabels()
        publish()
    }

    /** Called with the white keys that fit the screen's width. */
    fun setWhiteKeyCount(count: Int) {
        if (count == whiteKeys) return
        whiteKeys = count
        updateKeyboardRange()
    }

    // ---- Progress Through the Piece

    fun nextSegment() {
        if (steps.isEmpty()) return
        if (order == ReadingOrder.RANDOM) {
            showSegment(randomStart())
        } else {
            val next = segmentStart + segmentSize
            showSegment(if (next < steps.size) next else 0)
        }
    }

    fun previousSegment() {
        if (order != ReadingOrder.SEQUENTIAL || segmentStart <= 0) return
        showSegment(maxOf(0, segmentStart - segmentSize))
    }

    fun repeatSegment() = showSegment(segmentStart)

    fun restartPiece() = showSegment(0)

    // ---- Keys

    fun keyPressed(midi: Int, fromInstrument: Boolean = false) {
        // A real instrument makes its own sound
        if (!fromInstrument) audio.playNote(midi, 85)
        val step = segment.currentStep ?: return

        when (val press = segment.press(midi)) {
            ReadingPress.Ignored -> return
            is ReadingPress.Correct -> {
                flash(midi, correct = true)
                wrongPitch = null
                if (press.stepDone) {
                    keyboard.targetNoteKeys = emptySet()
                    finishStep(step)
                } else {
                    // A chord's remaining keys stay lit when its answer was shown
                    val result = segment.result(segment.current)
                    keyboard.targetNoteKeys = if (result.revealed) step.midiNotes - result.played else emptySet()
                    setFeedback(ReadingFeedback.Prompt(step.midiNotes.size - result.played.size))
                }
            }
            ReadingPress.Wrong -> {
                flash(midi, correct = false)
                val pitch = ReadingDrill.spelledPitch(midi, keySignature)
                wrongPitch = pitch
                setFeedback(ReadingFeedback.Wrong(ReadingDrill.name(pitch, usesLetters)), clearsAfter = 1.6)
                if (segment.result(segment.current).mistakes >= MISTAKES_BEFORE_HINT) reveal()
            }
        }
        publish()
    }

    fun keyReleased(midi: Int) = audio.stopNote(midi)

    /** Shows the current step's keys on the keyboard and its name. */
    fun reveal() {
        val step = segment.currentStep ?: return
        segment.reveal()
        keyboard.targetNoteKeys = step.midiNotes - segment.result(segment.current).played
        setFeedback(ReadingFeedback.Revealed(ReadingDrill.name(step, usesLetters)))
        publish()
    }

    /** Plays the segment at the score's tempo, lighting each step as it sounds. */
    fun listen() {
        listenJob?.cancel()
        val steps = segment.steps
        val first = steps.firstOrNull() ?: return
        val secondsPerBeat = 60.0 / tempo
        listenJob = viewModelScope.launch {
            var previousBeat = first.globalBeat
            for ((index, step) in steps.withIndex()) {
                // Long rests in this hand are shortened so the notes stay together
                val wait = minOf(2.0, (step.globalBeat - previousBeat) * secondsPerBeat)
                previousBeat = step.globalBeat
                if (wait > 0) delay((wait * 1000).roundToLong())
                listeningStep = index
                publish()
                val length = (step.heldBeats * secondsPerBeat).coerceIn(0.25, 1.6)
                for (midi in step.midiNotes) audio.playNote(midi, 80, length)
            }
            val last = (steps.last().heldBeats * secondsPerBeat).coerceIn(0.25, 1.6)
            delay((last * 1000).roundToLong())
            listeningStep = null
            publish()
        }
    }

    fun stop() {
        listenJob?.cancel()
        advanceJob?.cancel()
        listeningStep = null
        audio.stopAllNotes()
        publish()
    }

    override fun onCleared() {
        listenJob?.cancel()
        advanceJob?.cancel()
        audio.stopAllNotes()
    }

    // ---- Private

    private suspend fun loadSteps(resume: Boolean) {
        stop()
        steps = ReadingDrill.steps(measures, hand, timeSignatureTop, beatUnit, notes)
        val midiNotes = steps.flatMap { it.midiNotes }
        handRange = midiNotes.minOrNull()?.let { it..midiNotes.max() }
        keyboard.rangeStart = 0
        keyboard.rangeEnd = 0
        if (steps.isEmpty()) {
            segment = ReadingSegmentState(emptyList())
            accidentals = emptyList()
            feedback = ReadingFeedback.NoNotes
            keyboard.rangeStart = 48
            keyboard.rangeEnd = 72
            publish()
            return
        }
        val saved = settings.get(positionKey(), 0)
        savedPosition = saved
        if (order == ReadingOrder.RANDOM) {
            showSegment(randomStart())
        } else {
            val start = if (resume) saved else 0
            showSegment(alignedStart(if (start < steps.size) start else 0))
        }
    }

    private fun showSegment(start: Int) {
        if (!isLoaded) return
        listenJob?.cancel()
        advanceJob?.cancel()
        listeningStep = null
        audio.stopAllNotes()
        val range = ReadingDrill.segment(start, segmentSize, steps.size)
        segmentStart = range.first
        val shown = steps.slice(range)
        segment = ReadingSegmentState(shown)
        accidentals = ReadingDrill.printedAccidentals(shown, keySignature)
        wrongPitch = null
        keyboard.targetNoteKeys = emptySet()
        keyboard.correctKeys = emptySet()
        keyboard.incorrectKeys = emptySet()
        setFeedback(if (shown.isEmpty()) ReadingFeedback.NoNotes else ReadingFeedback.Prompt(shown[0].midiNotes.size))
        // Saved only when it moves
        if (order == ReadingOrder.SEQUENTIAL && savedPosition != segmentStart) {
            savedPosition = segmentStart
            val key = positionKey()
            val position = segmentStart
            save { settings.set(key, position) }
        }
        updateKeyboardRange()
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
            setFeedback(ReadingFeedback.Correct(ReadingDrill.name(step, usesLetters)), clearsAfter = 1.2)
            return
        }

        val clean = segment.cleanCount
        setFeedback(ReadingFeedback.SegmentDone(clean, segment.steps.size))
        _haptics.tryEmit(LearnHaptic.STEP_DONE)
        if (advancesAutomatically && clean == segment.steps.size) {
            advanceJob?.cancel()
            advanceJob = viewModelScope.launch {
                delay(1100)
                if (segment.isComplete) nextSegment()
            }
        }
    }

    /** Shows [newFeedback]; after [clearsAfter] seconds the line goes back to asking for the current step. */
    private fun setFeedback(newFeedback: ReadingFeedback, clearsAfter: Double? = null) {
        feedbackJob?.cancel()
        feedback = newFeedback
        if (clearsAfter == null) return
        feedbackJob = viewModelScope.launch {
            delay((clearsAfter * 1000).roundToLong())
            val step = segment.currentStep ?: return@launch
            wrongPitch = null
            feedback = ReadingFeedback.Prompt(step.midiNotes.size - segment.result(segment.current).played.size)
            publish()
        }
    }

    private fun flash(midi: Int, correct: Boolean) {
        if (correct) keyboard.correctKeys += midi else keyboard.incorrectKeys += midi
        _haptics.tryEmit(if (correct) LearnHaptic.CORRECT else LearnHaptic.WRONG)
        viewModelScope.launch {
            delay(450)
            if (correct) keyboard.correctKeys -= midi else keyboard.incorrectKeys -= midi
        }
    }

    private fun updateKeyboardRange() {
        // Every key of the segment stays on screen, so the keyboard doesn't move while it is read
        val notes = segment.steps.flatMap { it.midiNotes }
        val low = notes.minOrNull() ?: return
        val current = if (keyboard.rangeEnd > keyboard.rangeStart) keyboard.rangeStart..keyboard.rangeEnd else null
        val range = ReadingDrill.keyboardRange(low..notes.max(), handRange, whiteKeys, current)
        if (range.first != keyboard.rangeStart || range.last != keyboard.rangeEnd) {
            keyboard.rangeStart = range.first
            keyboard.rangeEnd = range.last
        }
    }

    private fun applyKeyLabels() {
        keyboard.labelStyle = when (keyLabels) {
            ReadingKeyLabels.SOLFEGE -> KeyLabelStyle.SOLFEGE
            ReadingKeyLabels.LETTERS -> KeyLabelStyle.LETTER
            ReadingKeyLabels.OCTAVES_ONLY, ReadingKeyLabels.HIDDEN -> KeyLabelStyle.HIDDEN
        }
        keyboard.marksOctaves = keyLabels != ReadingKeyLabels.HIDDEN
    }

    private fun alignedStart(start: Int): Int = maxOf(0, start) / maxOf(1, segmentSize) * maxOf(1, segmentSize)

    private fun randomStart(): Int = ReadingDrill.randomStart(steps.size, segmentSize, segmentStart, random)

    /**
     * Remembered per score, hand and notes kept (every note keeps the key it always had, the same as iOS), since
     * each choice reads a different number of steps.
     */
    private fun positionKey() = LearnKeys.drillPosition(scoreId, if (notes == ReadingNotes.ALL) hand.raw else "${hand.raw}.${notes.raw}")

    private fun save(block: suspend () -> Unit) {
        viewModelScope.launch { block() }
    }

    private fun publish() {
        _state.value = ReadingUiState(
            isLoaded = isLoaded,
            title = title,
            keySignature = keySignature,
            hand = hand,
            notes = notes,
            order = order,
            showsKeyboard = showsKeyboard,
            segmentSize = segmentSize,
            advancesAutomatically = advancesAutomatically,
            keyLabels = keyLabels,
            clefChoice = clefChoice,
            automaticUsesAlto = automaticUsesAlto,
            clef = clef,
            hasSteps = steps.isNotEmpty(),
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
        )
    }

    companion object {
        val SEGMENT_SIZES = listOf(1, 3, 4, 6, 8)
        /** Wrong keys on one step before its answer is shown */
        private const val MISTAKES_BEFORE_HINT = 3
        // Same keys as iOS (UserDefaults)
        private val NOTES_KEY = stringPreferencesKey("readingTrainer.notes")
        private val SHOWS_KEYBOARD_KEY = booleanPreferencesKey("readingTrainer.showsKeyboard")
    }
}
