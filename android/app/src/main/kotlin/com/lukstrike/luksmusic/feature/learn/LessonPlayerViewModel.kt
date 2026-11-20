// LessonPlayerViewModel.kt — port of luksMusic/ViewModels/LessonPlayerViewModel.swift for Android.
//
// The lesson's rules live in core's LessonSession; this class connects it to the phone: the screen's keyboard, a
// USB/Bluetooth MIDI keyboard and the microphone feed it notes, it plays demonstrations and runs the metronome
// of timed steps, and it saves the stars. The microphone is claimed only while the screen is started (one
// listener at a time), and goes deaf while the app is making sound, so it never hears itself.
package com.lukstrike.luksmusic.feature.learn

import android.app.Application
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.core.lessons.Lesson
import com.lukstrike.luksmusic.core.lessons.LessonCatalog
import com.lukstrike.luksmusic.core.lessons.LessonEffects
import com.lukstrike.luksmusic.core.lessons.LessonSession
import com.lukstrike.luksmusic.core.lessons.LessonSession.Feedback
import com.lukstrike.luksmusic.core.lessons.LessonSession.TimedPhase
import com.lukstrike.luksmusic.core.lessons.LessonStep
import com.lukstrike.luksmusic.core.lessons.LessonText
import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingStep
import com.lukstrike.luksmusic.core.lessons.ReadingStepResult
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.ui.AppLanguage
import com.lukstrike.luksmusic.ui.components.KeyLabelStyle
import com.lukstrike.luksmusic.ui.components.PianoKeyboardState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToLong

/** A buzz for the hand: a right key, a wrong one, a finished step. */
enum class LearnHaptic { CORRECT, WRONG, STEP_DONE }

/** Everything the lesson screen shows, as one immutable snapshot. */
@Immutable
data class LessonUiState(
    val lessonTitle: LessonText,
    val step: LessonStep,
    val stepIndex: Int,
    val stepCount: Int,
    val feedback: Feedback,
    val pageNumber: Int,
    val pageCount: Int,
    val visibleSteps: List<ReadingStep>,
    val visibleAccidentals: List<List<Accidental?>>,
    val visibleResults: List<ReadingStepResult>,
    val visibleCurrent: Int,
    val visibleDemoNote: Int?,
    val wrongPitch: Pitch?,
    val hasNotes: Boolean,
    /** The step being played has more than one key */
    val isChord: Boolean,
    val isFinished: Boolean,
    val stars: Int,
    val cleanNotes: Int,
    val totalNotes: Int,
    val progress: Float,
    val nextStepTitle: LessonText?,
    val nextLesson: Lesson?,
    val showsRepeat: Boolean,
    val showsListen: Boolean,
    val isDemonstrating: Boolean,
    val timedPhase: TimedPhase,
    val beatInMeasure: Int?,
    val isSilentForMicrophone: Boolean,
    val usesMicrophone: Boolean,
    val microphoneFailed: Boolean,
    val heardNoteName: String?,
) {
    val isStepDone: Boolean get() = feedback is Feedback.StepDone
}

class LessonPlayerViewModel(
    lessonId: String,
    private val app: Application,
    private val container: AppContainer,
) : ViewModel() {

    private val audio = container.audio
    private val microphone = container.microphone
    private val progressStore = LessonProgressStore(container.settings)

    /** The on-screen keyboard (range, key labels, right and wrong flashes, lit keys) */
    val keyboard = PianoKeyboardState()

    private val _haptics = MutableSharedFlow<LearnHaptic>(extraBufferCapacity = 8)
    val haptics: SharedFlow<LearnHaptic> = _haptics

    /** How loud the microphone hears the room, 0 to 1. */
    val microphoneLevel: StateFlow<Float> = microphone.inputLevel

    /** The USB or Bluetooth keyboard in use, by name. */
    val connectedKeyboardName: StateFlow<String?> = container.midi.connectedDevices
        .map { devices ->
            devices.firstOrNull { val name = it.name.lowercase(); "network" !in name && "session" !in name }?.name
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    private var usesMicrophone = false
    private var microphoneFailed = false
    private var heardNote: Int? = null
    private var microphoneJob: Job? = null
    private var demoJob: Job? = null
    private var timedJob: Job? = null

    private val effects: LessonEffects = object : LessonEffects {
        override fun playNote(midi: Int, velocity: Int, durationSeconds: Double) =
            audio.playNote(midi, velocity, durationSeconds)

        override fun click(accent: Boolean) = audio.playClick(accent)

        override fun expect(notes: Set<Int>?) = microphone.expect(notes)

        override fun ignoreInput(seconds: Double) = microphone.ignoreInput(seconds)

        override fun flash(note: Int, correct: Boolean) {
            if (correct) keyboard.correctKeys += note else keyboard.incorrectKeys += note
            _haptics.tryEmit(if (correct) LearnHaptic.CORRECT else LearnHaptic.WRONG)
            viewModelScope.launch {
                delay(450)
                if (correct) keyboard.correctKeys -= note else keyboard.incorrectKeys -= note
            }
        }

        // Dispatched (not run at once): the session may ask for these while it is still being made
        override fun runDemo(plan: LessonSession.DemoPlan) {
            demoJob?.cancel()
            demoJob = viewModelScope.launch(Dispatchers.Main) { playDemo(plan) }
        }

        override fun runTimed(token: Int) {
            timedJob?.cancel()
            timedJob = viewModelScope.launch(Dispatchers.Main) {
                while (session.timedTick(token)) {
                    publish()
                    delay(15)
                }
                publish()
            }
        }

        override fun lessonFinished(lessonId: String, stars: Int) {
            viewModelScope.launch { withContext(NonCancellable) { progressStore.record(lessonId, stars) } }
        }
    }

    private val session: LessonSession = LessonSession(
        lesson = LessonCatalog.lesson(lessonId) ?: LessonCatalog.allLessons.first(),
        effects = effects,
        usesLetters = { AppLanguage.usesLetterNames(app) },
    )

    private val _state = MutableStateFlow(snapshot())
    val state: StateFlow<LessonUiState> = _state.asStateFlow()

    init {
        syncKeyboard()
        // A MIDI keyboard makes its own sound; its keys light on the screen's keyboard while held
        viewModelScope.launch {
            container.midi.noteOn.collect { event ->
                keyboard.midiActiveKeys += event.note
                act { notePlayed(event.note) }
            }
        }
        viewModelScope.launch {
            container.midi.noteOff.collect { note -> keyboard.midiActiveKeys -= note }
        }
    }

    // ---- Screen Lifecycle

    /** The screen is on: takes the microphone if it was left on. */
    fun activate() {
        viewModelScope.launch {
            if (!usesMicrophone && container.settings.get(LearnKeys.USE_MICROPHONE, false) && microphone.hasPermission()) {
                setMicrophone(true)
            }
        }
    }

    /** The screen went away: stops sound, timers and the microphone. */
    fun stop() {
        demoJob?.cancel()
        timedJob?.cancel()
        act { stop() }
        audio.stopAllNotes()
        releaseMicrophone()
    }

    override fun onCleared() {
        stop()
    }

    // ---- Going Through the Lesson

    fun continueLesson() = act { continueLesson() }.also { clearFlashes() }

    fun repeatStep() = act { repeatStep() }.also { clearFlashes() }

    fun restartLesson() = act { restartLesson() }.also { clearFlashes() }

    fun open(lesson: Lesson) = act { open(lesson) }.also { clearFlashes() }

    fun playDemo() = act { playDemo() }

    /** Starts a timed step. With the microphone over the speaker, the beat is shown and the music is left out. */
    fun startTimedStep() = act { startTimedStep(makesSound = !usesMicrophone || app.hasHeadphones()) }

    fun setWhiteKeyCount(count: Int) = act { setWhiteKeyCount(count) }

    // ---- Input

    /** A key tapped on the screen, which sounds through the app. */
    fun screenKeyPressed(note: Int) {
        audio.playNote(note, 85)
        // The phone's speaker must not count as the piano
        microphone.ignoreInput(0.5)
        act { notePlayed(note) }
    }

    fun screenKeyReleased(note: Int) = audio.stopNote(note)

    /** Turns the microphone on or off (the screen asked for the permission first). */
    fun setMicrophone(on: Boolean) {
        usesMicrophone = on
        microphoneFailed = false
        viewModelScope.launch { container.settings.set(LearnKeys.USE_MICROPHONE, on) }
        if (!on) {
            releaseMicrophone()
            publish()
            return
        }
        claimMicrophone()
        publish()
    }

    /** The permission was refused: the switch goes back off with a note on the screen. */
    fun microphoneDenied() {
        usesMicrophone = false
        microphoneFailed = true
        viewModelScope.launch { container.settings.set(LearnKeys.USE_MICROPHONE, false) }
        publish()
    }

    private fun claimMicrophone() {
        microphoneJob?.cancel()
        microphoneJob = viewModelScope.launch {
            val errorAtStart = microphone.errorMessage.value
            launch {
                microphone.notesDetected.collect { note ->
                    heardNote = note
                    act { notePlayed(note, LessonSession.MICROPHONE_DELAY) }
                }
            }
            launch { microphone.chordMissed.collect { act { chordNotHeard() } } }
            launch {
                microphone.errorMessage.drop(1).filterNotNull().first { it != errorAtStart }
                usesMicrophone = false
                microphoneFailed = true
                container.settings.set(LearnKeys.USE_MICROPHONE, false)
                releaseMicrophone()
                publish()
            }
            microphone.expect(session.expectedNotes)
            microphone.startListening()
        }
    }

    private fun releaseMicrophone() {
        microphoneJob?.cancel()
        microphoneJob = null
        heardNote = null
        microphone.expect(null)
        microphone.stopListening()
    }

    // ---- Private

    private suspend fun playDemo(plan: LessonSession.DemoPlan) {
        var clock = 0.0
        for ((index, note) in plan.steps.withIndex()) {
            val wait = note.globalBeat * plan.secondsPerBeat - clock
            if (wait > 0) {
                delay((wait * 1000).roundToLong())
                clock += wait
            }
            if (!session.demoReached(plan, index)) return
            publish()
        }
        val tail = plan.lastEnd - clock
        if (tail > 0) delay((tail * 1000).roundToLong())
        session.demoEnded(plan)
        publish()
    }

    /** Runs [block] on the session, then shows the result. */
    private inline fun act(block: LessonSession.() -> Unit) {
        session.block()
        publish()
    }

    private fun publish() {
        val before = _state.value
        val now = snapshot()
        if (!before.isStepDone && now.isStepDone) _haptics.tryEmit(LearnHaptic.STEP_DONE)
        _state.value = now
        syncKeyboard()
    }

    private fun clearFlashes() {
        keyboard.correctKeys = emptySet()
        keyboard.incorrectKeys = emptySet()
    }

    private fun syncKeyboard() {
        keyboard.targetNoteKeys = session.targetKeys
        // Keys are named with letters in English and in solfège in Portuguese, while a note is being learned
        val names = if (AppLanguage.usesLetterNames(app)) KeyLabelStyle.LETTER else KeyLabelStyle.SOLFEGE
        keyboard.labelStyle = if (session.namesKeys) names else KeyLabelStyle.HIDDEN
        keyboard.marksOctaves = true
        session.keyboardRange?.let { range ->
            if (range.first != keyboard.rangeStart || range.last != keyboard.rangeEnd) {
                keyboard.rangeStart = range.first
                keyboard.rangeEnd = range.last
            }
        }
    }

    private fun snapshot(): LessonUiState = with(session) {
        LessonUiState(
            lessonTitle = lesson.title,
            step = step,
            stepIndex = stepIndex,
            stepCount = lesson.steps.size,
            feedback = feedback,
            pageNumber = pageNumber,
            pageCount = pages.size,
            visibleSteps = visibleSteps,
            visibleAccidentals = visibleAccidentals,
            visibleResults = visibleResults,
            visibleCurrent = visibleCurrent,
            visibleDemoNote = visibleDemoNote,
            wrongPitch = wrongPitch,
            hasNotes = segment.steps.isNotEmpty(),
            isChord = (segment.currentStep?.midiNotes?.size ?: 1) > 1,
            isFinished = isFinished,
            stars = stars,
            cleanNotes = cleanNotes,
            totalNotes = totalNotes,
            progress = progress.toFloat(),
            nextStepTitle = nextStepTitle,
            nextLesson = nextLesson,
            showsRepeat = showsRepeat,
            showsListen = showsListen,
            isDemonstrating = isDemonstrating,
            timedPhase = timedPhase,
            beatInMeasure = beatInMeasure,
            isSilentForMicrophone = isSilentForMicrophone,
            usesMicrophone = usesMicrophone,
            microphoneFailed = microphoneFailed,
            // The last note the microphone recognized, named for the step's key
            heardNoteName = heardNote?.takeIf { usesMicrophone }?.let {
                ReadingDrill.name(ReadingDrill.spelledPitch(it, step.keySignature), AppLanguage.usesLetterNames(app))
            },
        )
    }
}
