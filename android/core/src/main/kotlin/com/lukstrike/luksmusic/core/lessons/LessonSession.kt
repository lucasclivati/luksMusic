// LessonSession.kt — the rules of luksMusic/ViewModels/LessonPlayerViewModel.swift, kept free of Android so they
// can be tested. The app's LessonPlayerViewModel owns one, feeds it the notes played and runs its timers; sound,
// the microphone and the saved progress go through [LessonEffects].
//
// Runs one lesson step by step. Every step asks for notes: a new note is learned by playing its lit key, drills and
// pieces are read from the staff, ear steps are found by listening, and timed steps are played with the metronome.
// The notes can come from the screen's keyboard, a USB keyboard or the microphone; each is checked the same way.
// A finished step waits on a result card, so the next one never starts by surprise. The microphone is told which
// note comes next, and goes deaf while the app is making sound, so it never hears itself.
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Pitch
import kotlin.random.Random

/** What the lesson asks of the outside world. Every call comes on the caller's thread (the app's main thread). */
interface LessonEffects {
    fun playNote(midi: Int, velocity: Int, durationSeconds: Double)
    /** A metronome click, louder on the first beat of the measure. */
    fun click(accent: Boolean)
    /** The notes the microphone should listen for next; null = anything. */
    fun expect(notes: Set<Int>?)
    /** The microphone ignores what it hears for this long (the app is making sound). */
    fun ignoreInput(seconds: Double)
    /** A key turned right or wrong (flash it, buzz). */
    fun flash(note: Int, correct: Boolean)
    /** Plays [plan]: wait for each note's moment, call [LessonSession.demoReached], then [LessonSession.demoEnded]. */
    fun runDemo(plan: LessonSession.DemoPlan)
    /** Calls [LessonSession.timedTick] with [token] about every 15 ms until it returns false. */
    fun runTimed(token: Int)
    /** The lesson ended with this many stars (saved as the lesson's best). */
    fun lessonFinished(lessonId: String, stars: Int)
}

class LessonSession(
    lesson: Lesson,
    private val effects: LessonEffects,
    /** Whether notes are named in letters (English) or solfège (Portuguese), asked each time */
    private val usesLetters: () -> Boolean,
    /** Seconds on a steady clock */
    private val clock: () -> Double = { System.nanoTime() / 1e9 },
    private val random: Random = Random.Default,
) {
    sealed interface Feedback {
        data object None : Feedback
        data object Prompt : Feedback
        data class Correct(val name: String) : Feedback
        data class Wrong(val name: String) : Feedback
        data class Revealed(val name: String) : Feedback
        data object Listening : Feedback
        data object YourTurn : Feedback
        data class StepDone(val clean: Int, val total: Int) : Feedback
        data object ReadyToStart : Feedback
        data class CountIn(val beats: Int) : Feedback
        data object Playing : Feedback
        data object OnTime : Feedback
        data object Early : Feedback
        data object Late : Feedback
        data object Missed : Feedback
        data object ChordMissed : Feedback
    }

    enum class TimedPhase { NOT_TIMED, READY, RUNNING }

    /** A demonstration to play: the notes, how fast, and how long until the sound is gone. */
    class DemoPlan(
        val token: Int,
        val steps: List<ReadingStep>,
        val secondsPerBeat: Double,
        /** Seconds from the first note to the end of the last one */
        val lastEnd: Double,
        internal val isWaiting: Boolean,
        internal val after: Feedback,
    )

    var lesson: Lesson = lesson
        private set
    var stepIndex = 0
        private set
    var segment = ReadingSegmentState(emptyList())
        private set
    var accidentals: List<List<Accidental?>> = emptyList()
        private set
    /** The steps shown together on the staff */
    var pages: List<IntRange> = emptyList()
        private set
    var feedback: Feedback = Feedback.None
        private set
    var wrongPitch: Pitch? = null
        private set
    /** The note the app is playing in a demonstration */
    var demoNote: Int? = null
        private set
    var isFinished = false
        private set
    var cleanNotes = 0
        private set
    var totalNotes = 0
        private set
    var timedPhase = TimedPhase.NOT_TIMED
        private set
    /** Which beat of the measure the metronome is on (from 0) */
    var beatInMeasure: Int? = null
        private set
    /** The microphone is on without headphones, so the app stays silent during a timed step */
    var isSilentForMicrophone = false
        private set
    /** The keys lit on the keyboard */
    var targetKeys: Set<Int> = emptySet()
        private set
    /** The keys the keyboard shows */
    var keyboardRange: IntRange? = null
        private set

    private var whiteKeys = 15
    private var demoToken = 0
    private var timedToken = 0
    private var timing: RhythmTiming? = null
    private var timedStart: Double? = null
    private var expected: Set<Int>? = null

    // The running timed step
    private var nextClick = 0
    private var nextNote = 0
    private var timedMakesSound = true

    init {
        begin(0)
    }

    // ---- State for the Screen

    val step: LessonStep get() = lesson.steps[stepIndex]
    val nextLesson: Lesson? get() = LessonCatalog.lesson(after = lesson)
    val stars: Int get() = Lesson.stars(cleanNotes, totalNotes)
    val progress: Double get() = (stepIndex + if (isFinished) 1 else 0).toDouble() / maxOf(1, lesson.steps.size)
    val isDemonstrating: Boolean get() = feedback == Feedback.Listening

    /** The step that comes after this one, for the result card. */
    val nextStepTitle: LessonText? get() = lesson.steps.getOrNull(stepIndex + 1)?.title

    val isStepDone: Boolean get() = feedback is Feedback.StepDone

    /** Learning a note shows the keys' names; elsewhere the keys are blank. */
    val namesKeys: Boolean get() = step.kind == LessonStep.Kind.LEARN

    /** The page of the staff on screen: the one with the note being played or heard (half-open). */
    val page: IntRange
        get() {
            val focus = demoNote ?: minOf(segment.current, maxOf(0, segment.steps.size - 1))
            return pages.firstOrNull { focus in it } ?: pages.lastOrNull() ?: IntRange.EMPTY
        }

    /** Ear steps show a note only once it was found. */
    val visibleRange: IntRange
        get() {
            val page = page
            if (page.isEmpty()) return IntRange.EMPTY
            if (step.kind != LessonStep.Kind.LISTEN || segment.isComplete) return page
            return page.first until maxOf(page.first, minOf(page.last + 1, segment.current))
        }

    val visibleSteps: List<ReadingStep> get() = segment.steps.slice(visibleRange)
    val visibleAccidentals: List<List<Accidental?>> get() = accidentals.slice(visibleRange)
    val visibleResults: List<ReadingStepResult> get() = segment.results.slice(visibleRange)
    /** The note to play, counted on the visible page (a demonstration may show a page ahead of it) */
    val visibleCurrent: Int get() = maxOf(0, segment.current - (visibleRange.takeUnless { it.isEmpty() }?.first ?: 0))
    val visibleDemoNote: Int? get() = demoNote?.let { it - (visibleRange.takeUnless { r -> r.isEmpty() }?.first ?: 0) }
    val pageNumber: Int get() = pages.indexOf(page) + 1

    /** A finished step waits for "Continuar". */
    val showsContinue: Boolean get() = !isFinished && isStepDone

    /** Learning a note can't go wrong, so only practice can be repeated. */
    val showsRepeat: Boolean get() = isStepDone && step.isScored

    /** "Ouvir" is offered by ear steps, by pieces and before a timed step starts. */
    val showsListen: Boolean
        get() {
            if (isFinished || segment.isComplete) return false
            return step.kind == LessonStep.Kind.LISTEN || step.isPiece || timedPhase == TimedPhase.READY
        }

    /** The notes the microphone is listening for, to tell it again when it is turned on. */
    val expectedNotes: Set<Int>? get() = expected

    // ---- Going Through the Lesson

    fun continueLesson() {
        cancelPending()
        if (stepIndex + 1 < lesson.steps.size) {
            begin(stepIndex + 1)
        } else {
            isFinished = true
            feedback = Feedback.None
            timedPhase = TimedPhase.NOT_TIMED
            targetKeys = emptySet()
            expect(null)
            effects.lessonFinished(lesson.id, stars)
        }
    }

    fun repeatStep() {
        cancelPending()
        // The new try replaces the one just counted
        if (isStepDone && step.isScored) {
            totalNotes -= segment.playableCount
            cleanNotes -= segment.cleanCount
        }
        begin(stepIndex)
    }

    fun restartLesson() = open(lesson)

    fun open(newLesson: Lesson) {
        cancelPending()
        lesson = newLesson
        isFinished = false
        cleanNotes = 0
        totalNotes = 0
        begin(0)
    }

    /**
     * Stops whatever is playing or counting (the screen went away). On Android the screen can come back (the app
     * returns from the background), so a timed step that was running starts over from "Começar", and a step
     * whose demonstration was cut short takes keys again.
     */
    fun stop() {
        val wasRunning = timedPhase == TimedPhase.RUNNING && !segment.isComplete
        cancelPending()
        expect(null)
        if (wasRunning) {
            begin(stepIndex)
        } else if (feedback == Feedback.Listening) {
            feedback = when {
                step.isTimed -> Feedback.ReadyToStart
                step.kind == LessonStep.Kind.LISTEN -> Feedback.YourTurn
                else -> Feedback.Prompt
            }
        }
    }

    /** Plays the current notes, in rhythm when the step is written in measures. */
    fun playDemo() {
        if (segment.steps.isEmpty()) return
        val token = nextDemoToken()
        val notes = segment.steps
        val secondsPerBeat = if (step.meter == null) SECONDS_PER_DEMO_NOTE else 60.0 / step.tempo
        val after = if (step.isTimed) Feedback.ReadyToStart else if (step.kind == LessonStep.Kind.LISTEN) Feedback.YourTurn else Feedback.Prompt
        val isWaiting = !segment.isComplete
        val lastEnd = notes.last().let { (it.globalBeat + it.heldBeats) * secondsPerBeat }
        effects.ignoreInput(lastEnd + SOUND_TAIL)
        wrongPitch = null
        if (isWaiting) feedback = Feedback.Listening
        effects.runDemo(DemoPlan(token, notes, secondsPerBeat, lastEnd, isWaiting, after))
    }

    /** The demonstration reached note [index]: plays it. False when the demonstration was cancelled. */
    fun demoReached(plan: DemoPlan, index: Int): Boolean {
        if (plan.token != demoToken) return false
        demoNote = index
        val note = plan.steps[index]
        if (!note.isRest) {
            for (key in note.midiNotes) effects.playNote(key, 80, note.heldBeats * plan.secondsPerBeat * 0.9)
        }
        return true
    }

    /** The demonstration's sound is over. */
    fun demoEnded(plan: DemoPlan) {
        if (plan.token != demoToken) return
        demoNote = null
        if (plan.isWaiting) feedback = plan.after
    }

    /**
     * Starts a timed step: one measure of count-in, then the notes. Without [makesSound] (the microphone over the
     * speaker) the beat is only shown and the music is left out.
     */
    fun startTimedStep(makesSound: Boolean) {
        if (timedPhase != TimedPhase.READY || segment.steps.isEmpty()) return
        nextDemoToken()
        demoNote = null
        timedPhase = TimedPhase.RUNNING
        timedToken += 1

        val secondsPerBeat = 60.0 / step.tempo
        val beats = step.meter ?: 4
        timing = RhythmTiming(segment.steps, secondsPerBeat)
        timedStart = clock() + beats * secondsPerBeat + 0.2
        timedMakesSound = makesSound
        isSilentForMicrophone = !makesSound
        nextClick = -beats
        nextNote = 0
        effects.runTimed(timedToken)
    }

    /** One look at the clock during a timed step: clicks, the music, notes that went by. False when it is over. */
    fun timedTick(token: Int): Boolean {
        if (token != timedToken) return false
        val timing = timing ?: return false
        val start = timedStart ?: return false
        val secondsPerBeat = 60.0 / step.tempo
        val beats = step.meter ?: 4
        val playsMusic = step.kind == LessonStep.Kind.PLAY_ALONG && timedMakesSound
        val elapsed = clock() - start

        while (nextClick * secondsPerBeat <= elapsed) {
            val beat = Math.floorMod(nextClick, beats)
            beatInMeasure = beat
            if (timedMakesSound) effects.click(accent = beat == 0)
            if (nextClick < 0) feedback = Feedback.CountIn(-nextClick)
            nextClick += 1
        }
        if (elapsed >= 0 && feedback is Feedback.CountIn) feedback = Feedback.Playing
        if (playsMusic) {
            val steps = segment.steps
            while (nextNote < steps.size && timing.times[nextNote] <= elapsed) {
                val note = steps[nextNote]
                if (!note.isRest) {
                    for (key in note.midiNotes) effects.playNote(key, 55, note.heldBeats * secondsPerBeat * 0.9)
                }
                nextNote += 1
            }
        }
        while (!segment.isComplete && timing.isOverdue(segment.current, elapsed)) {
            segment.miss()
            feedback = Feedback.Missed
            lightCurrentKeys()
        }
        if (segment.isComplete) {
            finishStep()
            return false
        }
        return true
    }

    // ---- Input

    fun setWhiteKeyCount(count: Int) {
        if (count == whiteKeys) return
        whiteKeys = count
        updateKeyboardRange()
    }

    /** Checks a note from any source against the current step. [inputDelay] is how late this source reports. */
    fun notePlayed(note: Int, inputDelay: Double = 0.0) {
        if (isFinished || isDemonstrating || segment.isComplete) return
        val current = segment.currentStep ?: return

        var elapsed: Double? = null
        if (step.isTimed) {
            val start = timedStart
            if (timedPhase != TimedPhase.RUNNING || start == null) return
            val time = clock() - start - inputDelay
            // Keys played during the count-in don't count
            if (time <= -0.35) return
            elapsed = time
        }

        val index = segment.current
        when (val press = segment.press(note)) {
            ReadingPress.Ignored -> return
            is ReadingPress.Correct -> {
                effects.flash(note, correct = true)
                wrongPitch = null
                if (!press.stepDone) {
                    lightCurrentKeys()
                    return
                }
                val timing = timing
                if (elapsed != null && timing != null) {
                    judge(timing.verdict(index, elapsed), index)
                } else {
                    feedback = Feedback.Correct(ReadingDrill.name(current, usesLetters()))
                }
                lightCurrentKeys()
                if (segment.isComplete) finishStep()
            }
            ReadingPress.Wrong -> {
                effects.flash(note, correct = false)
                val pitch = ReadingDrill.spelledPitch(note, step.keySignature)
                wrongPitch = pitch
                feedback = Feedback.Wrong(ReadingDrill.name(pitch, usesLetters()))
                if (!step.isTimed && segment.result(segment.current).mistakes >= MISTAKES_BEFORE_HINT) {
                    segment.reveal()
                    feedback = Feedback.Revealed(ReadingDrill.name(current, usesLetters()))
                    lightCurrentKeys()
                }
            }
        }
    }

    /** The microphone heard a chord that wasn't the one expected. */
    fun chordNotHeard() {
        if (segment.isComplete || isDemonstrating || segment.currentStep == null) return
        feedback = Feedback.ChordMissed
    }

    // ---- Private

    private fun begin(index: Int) {
        stepIndex = index
        val current = lesson.steps[index]
        val tokens = current.pool?.let { LessonNotation.draw(current.drawCount, it, current.focus, random) } ?: current.notes
        val shown = current.readingSteps(tokens)
        segment = ReadingSegmentState(shown)
        // A drill's notes are unrelated to each other, so each shows its own sign
        accidentals = if (current.isDrill) {
            shown.map { ReadingDrill.printedAccidentals(listOf(it), current.keySignature).firstOrNull() ?: emptyList() }
        } else {
            ReadingDrill.printedAccidentals(shown, current.keySignature)
        }
        pages = LessonNotation.pages(shown, measured = current.meter != null)
        wrongPitch = null
        demoNote = null
        beatInMeasure = null
        isSilentForMicrophone = false
        timedStart = null
        timing = null
        updateKeyboardRange()

        timedPhase = if (current.isTimed) TimedPhase.READY else TimedPhase.NOT_TIMED
        when (current.kind) {
            // The introduction plays on its own: nothing to press, and the microphone listens for nothing
            LessonStep.Kind.INTRO -> {
                feedback = Feedback.None
                targetKeys = emptySet()
                expect(null)
            }
            LessonStep.Kind.LEARN, LessonStep.Kind.READ -> {
                feedback = Feedback.Prompt
                lightCurrentKeys()
            }
            LessonStep.Kind.LISTEN -> {
                lightCurrentKeys()
                playDemo()
            }
            LessonStep.Kind.RHYTHM, LessonStep.Kind.PLAY_ALONG -> {
                feedback = Feedback.ReadyToStart
                lightCurrentKeys()
            }
        }
    }

    /**
     * While learning, the next key stays lit; elsewhere only after the answer was shown. The microphone is told
     * which notes come next.
     */
    private fun lightCurrentKeys() {
        val current = segment.currentStep
        if (current == null) {
            targetKeys = emptySet()
            expect(null)
            return
        }
        val result = segment.result(segment.current)
        val lit = step.kind == LessonStep.Kind.LEARN || result.revealed
        targetKeys = if (lit) current.midiNotes - result.played else emptySet()
        expect(current.midiNotes)
    }

    private fun expect(notes: Set<Int>?) {
        expected = notes
        effects.expect(notes)
    }

    private fun judge(verdict: RhythmTiming.Verdict, index: Int) {
        feedback = when (verdict) {
            RhythmTiming.Verdict.ON_TIME -> Feedback.OnTime
            RhythmTiming.Verdict.EARLY -> {
                segment.markOffBeat(index)
                Feedback.Early
            }
            RhythmTiming.Verdict.LATE -> {
                segment.markOffBeat(index)
                Feedback.Late
            }
        }
    }

    /** Shows the step's result and waits for "Continuar" or "Repetir". */
    private fun finishStep() {
        timedToken += 1
        if (step.isTimed) timedPhase = TimedPhase.NOT_TIMED
        beatInMeasure = null
        targetKeys = emptySet()
        expect(null)
        val clean = segment.cleanCount
        val total = segment.playableCount
        if (step.isScored) {
            cleanNotes += clean
            totalNotes += total
        }
        feedback = Feedback.StepDone(clean, total)
    }

    private fun updateKeyboardRange() {
        val module = LessonCatalog.keyboardNotes(lesson) ?: return
        val notes = segment.steps.filter { !it.isRest }.flatMap { it.midiNotes } + step.litMidiKeys
        val needed = notes.minOrNull()?.let { it..notes.max() } ?: module
        keyboardRange = ReadingDrill.keyboardRange(needed, module, whiteKeys, keyboardRange)
    }

    private fun cancelPending() {
        timedToken += 1
        nextDemoToken()
        demoNote = null
        beatInMeasure = null
    }

    private fun nextDemoToken(): Int {
        demoToken += 1
        return demoToken
    }

    companion object {
        /** Wrong keys on one note before its key is shown */
        const val MISTAKES_BEFORE_HINT = 2
        private const val SECONDS_PER_DEMO_NOTE = 0.65
        /** About how long the microphone takes to report a note, taken off when judging its timing */
        const val MICROPHONE_DELAY = 0.16
        /** The app's own sound still in the room after it stops playing */
        const val SOUND_TAIL = 0.4
    }
}
