// Lesson.kt — port of luksMusic/Models/Lessons/Lesson.swift.
//
// The "Aprender" course as data: modules of lessons, each a list of steps. Every step asks for notes to be played:
// a new note is learned by playing it, then read without help, then used in a short piece. Notes are written as
// text so lessons read like a score:
//   "C4"  "F#4"  "Bb3"           a note
//   "C4:h"  "D4:q."  "E4:e"      with a value: w h q e s, and "." for a dot (a quarter when left out)
//   "R:q"                        a rest
//   "C4+E4+G4"                   notes played together
//   "C4/t"  "C4/b"               forced onto the treble or the bass staff
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Staff
import kotlin.math.abs
import kotlin.random.Random

/**
 * A text of the course. This module has no Android resources, so a text is the name of a string resource
 * (strings_learn.xml in the app), which the app looks up; [suffixKey] is a second resource written after it,
 * separated by a space (the drills' shared "No help…" sentence). A [isVerbatim] text is shown as written
 * (song titles that are the same in every language).
 */
data class LessonText(val key: String, val suffixKey: String? = null, val isVerbatim: Boolean = false) {
    companion object {
        fun verbatim(text: String) = LessonText(text, isVerbatim = true)
    }
}

data class LessonEvent(
    val pitches: List<Pitch>,
    val duration: NoteDuration,
    val isRest: Boolean,
    val forcedStaff: Staff?,
)

object LessonNotation {
    /** Reads "C4", "F#4" or "Bb3". */
    fun pitch(text: String): Pitch? {
        val first = text.firstOrNull() ?: return null
        val name = NoteName.entries.firstOrNull { it.name == first.toString() } ?: return null
        val octave = text.dropWhile { !it.isDigit() && it != '-' }.toIntOrNull() ?: return null
        val accidental = when (text.drop(1).takeWhile { !it.isDigit() && it != '-' }) {
            "" -> Accidental.NATURAL
            "#" -> Accidental.SHARP
            "b" -> Accidental.FLAT
            else -> return null
        }
        return Pitch(name, octave, accidental)
    }

    private val durations = mapOf(
        "w" to NoteDuration.WHOLE, "h." to NoteDuration.DOTTED_HALF, "h" to NoteDuration.HALF,
        "q." to NoteDuration.DOTTED_QUARTER, "q" to NoteDuration.QUARTER, "e." to NoteDuration.DOTTED_EIGHTH,
        "e" to NoteDuration.EIGHTH, "s" to NoteDuration.SIXTEENTH,
    )

    /** Reads one written event, or null when the text is not valid notation. */
    fun event(token: String): LessonEvent? {
        var text = token
        var staff: Staff? = null
        val slash = text.indexOf('/')
        if (slash >= 0) {
            staff = when (text.substring(slash + 1)) {
                "t" -> Staff.TREBLE
                "b" -> Staff.BASS
                else -> return null
            }
            text = text.substring(0, slash)
        }
        var duration = NoteDuration.QUARTER
        val colon = text.indexOf(':')
        if (colon >= 0) {
            duration = durations[text.substring(colon + 1)] ?: return null
            text = text.substring(0, colon)
        }
        if (text == "R") return LessonEvent(emptyList(), duration, isRest = true, forcedStaff = staff)
        val pitches = text.split('+').filter { it.isNotEmpty() }.map { pitch(it) }
        if (pitches.isEmpty() || pitches.any { it == null }) return null
        return LessonEvent(pitches.filterNotNull(), duration, isRest = false, forcedStaff = staff)
    }

    /**
     * [count] notes drawn from [pool], never the same one twice in a row. Notes in [focus] (the ones just
     * learned) come up twice as often as the others, and each of them at least once.
     */
    fun draw(count: Int, pool: List<String>, focus: List<String> = emptyList(), random: Random = Random.Default): List<String> {
        if (pool.isEmpty() || count <= 0) return emptyList()
        val weights = pool.map { if (it in focus) 2.0 else 1.0 }
        val drawn = mutableListOf<String>()
        while (drawn.size < count) {
            val choices = pool.indices.filter { pool.size == 1 || pool[it] != drawn.lastOrNull() }
            val total = choices.sumOf { weights[it] }
            var roll = random.nextDouble(total)
            var chosen = choices[0]
            for (index in choices) {
                roll -= weights[index]
                if (roll < 0) {
                    chosen = index
                    break
                }
            }
            drawn += pool[chosen]
        }
        for (note in focus) {
            if (note !in pool || note in drawn) continue
            val spot = drawn.indices.shuffled(random).firstOrNull { index ->
                drawn[index] !in focus &&
                    (index == 0 || drawn[index - 1] != note) &&
                    (index + 1 == drawn.size || drawn[index + 1] != note)
            }
            if (spot != null) drawn[spot] = note
        }
        return drawn
    }

    /**
     * The columns shown at once, since a phone's staff fits about eight. Measures are kept whole; without
     * measures the notes are split into even pages. Ranges are half-open (`start until end`), like Swift's.
     */
    fun pages(steps: List<ReadingStep>, measured: Boolean, columns: Int = 8): List<IntRange> {
        if (steps.isEmpty()) return emptyList()
        if (!measured) {
            val count = (steps.size + columns - 1) / columns
            val size = (steps.size + count - 1) / count
            return (0 until steps.size step size).map { it until minOf(steps.size, it + size) }
        }
        val pages = mutableListOf<IntRange>()
        var start = 0
        var index = 0
        while (index < steps.size) {
            val measure = steps[index].measureIndex
            var end = index
            while (end < steps.size && steps[end].measureIndex == measure) end += 1
            if (end - start > columns && index > start) {
                pages += start until index
                start = index
            }
            index = end
        }
        pages += start until steps.size
        return pages
    }
}

class LessonStep(
    val kind: Kind,
    val title: LessonText,
    val text: LessonText,
    notes: String = "",
    litKeys: String? = null,
    val staff: Staff = Staff.TREBLE,
    grand: Boolean = false,
    key: Int = 0,
    /** Beats per measure when the step is written in measures */
    val meter: Int? = null,
    val tempo: Int = 72,
    pool: String? = null,
    focus: String = "",
    draw: Int = 10,
    /** Lesson finale step where the student plays a longer song passage on their own */
    challenge: Boolean = false,
    /** The animated introduction a [Kind.INTRO] step shows */
    val intro: LessonIntro? = null,
) {
    enum class Kind {
        /** Animated vertical introduction explaining a concept before the player touches the keys ([intro]). */
        INTRO,
        /** Something new: its notes are named on the staff and their keys lit. Playing them goes on; they don't count toward the stars. */
        LEARN,
        /** Only the staff: the notes must be read. Drawn at random from `pool`, it is a drill. */
        READ,
        /** The app plays the notes and they are found by ear; each appears on the staff once played */
        LISTEN,
        /** Played in time with the metronome */
        RHYTHM,
        /** Played in time while the app plays the music too */
        PLAY_ALONG,
    }

    /** The events on the staff, in order */
    val notes: List<String> = notes.split(' ').filter { it.isNotEmpty() }
    /** Keys lit while learning, when they differ from the notes on the staff */
    val litKeys: List<String>? = litKeys?.split(' ')?.filter { it.isNotEmpty() }
    /** Both staves: notes from middle C up go on the treble staff, the others on the bass staff */
    val isGrand: Boolean = grand
    /** Sharps (+) or flats (-) in the key signature */
    val keySignature: Int = key
    /** A drill: [drawCount] notes from this pool, instead of [notes] */
    val pool: List<String>? = pool?.split(' ')?.filter { it.isNotEmpty() }
    /** The notes of the pool just learned, drawn more often */
    val focus: List<String> = focus.split(' ').filter { it.isNotEmpty() }
    val drawCount: Int = draw
    /** Lesson finale step where the student plays a longer song passage on their own */
    val isChallenge: Boolean = challenge

    val isIntro: Boolean get() = kind == Kind.INTRO
    val isTimed: Boolean get() = kind == Kind.RHYTHM || kind == Kind.PLAY_ALONG
    /** Introductions and learning a note aren't scored; everything else counts toward the lesson's stars */
    val isScored: Boolean get() = !isIntro && kind != Kind.LEARN
    val isDrill: Boolean get() = pool != null
    /** A written piece, read at one's own pace: it can be heard first */
    val isPiece: Boolean get() = kind == Kind.READ && meter != null

    /** The events as the staff and the answer checking expect them. Without a meter each event takes one column. */
    fun readingSteps(tokens: List<String>): List<ReadingStep> {
        var beat = 0.0
        return tokens.mapNotNull(LessonNotation::event).map { event ->
            val length = if (meter == null) 1.0 else event.duration.beats
            val measure = meter?.let { ((beat + 0.0001) / it).toInt() } ?: 0
            val notes = if (event.isRest) {
                listOf(Note.rest(duration = event.duration, staff = event.forcedStaff ?: staff, beat = beat + 1))
            } else {
                event.pitches.map { pitch ->
                    val target = event.forcedStaff
                        ?: if (isGrand) (if (pitch.midiNoteNumber >= 60) Staff.TREBLE else Staff.BASS) else staff
                    Note(pitch = pitch, duration = event.duration, staff = target, beat = beat + 1)
                }.sortedBy { it.midiNote }
            }
            val step = ReadingStep(measureIndex = measure, measureNumber = 0, beat = beat + 1, globalBeat = beat,
                notes = notes, heldBeats = length)
            beat += length
            step
        }
    }

    val readingSteps: List<ReadingStep> get() = readingSteps(notes)

    /** The MIDI numbers of the keys lit while learning, when they differ from the notes on the staff. */
    val litMidiKeys: Set<Int>
        get() {
            litKeys?.let { keys -> return keys.mapNotNull(LessonNotation::pitch).mapTo(LinkedHashSet()) { it.midiNoteNumber } }
            return readingSteps.filter { !it.isRest }.flatMapTo(LinkedHashSet()) { it.midiNotes }
        }

    /** Every key this step writes, lights or may draw. */
    val allMidiNotes: List<Int>
        get() {
            val written = (notes + (pool ?: emptyList())).mapNotNull(LessonNotation::event).flatMap { it.pitches }
            val lit = (litKeys ?: emptyList()).mapNotNull(LessonNotation::pitch)
            return (written + lit).map { it.midiNoteNumber }
        }
}

class Lesson(
    val id: String,
    val title: LessonText,
    val summary: LessonText,
    val steps: List<LessonStep>,
) {
    val hasIntro: Boolean get() = steps.any { it.isIntro }

    /** Every note the lesson writes or lights, for choosing the keyboard's keys. */
    val midiRange: IntRange?
        get() {
            val notes = steps.flatMap { it.allMidiNotes }
            val low = notes.minOrNull() ?: return null
            return low..notes.max()
        }

    companion object {
        /** Stars for how many notes were right on the first try. */
        fun stars(clean: Int, total: Int): Int {
            if (total <= 0) return 3
            val share = clean.toDouble() / total
            return if (share >= 0.9) 3 else if (share >= 0.7) 2 else 1
        }
    }
}

class LessonModule(
    val id: String,
    val title: LessonText,
    val summary: LessonText,
    val lessons: List<Lesson>,
)

/** When each note of a timed exercise should sound, and how to judge a key played around that moment. */
class RhythmTiming(steps: List<ReadingStep>, secondsPerBeat: Double) {
    enum class Verdict { ON_TIME, EARLY, LATE }

    /** Seconds from the first beat to each step */
    val times: List<Double> = steps.map { it.globalBeat * secondsPerBeat }

    /** How far from its moment a key still counts as on time */
    val tolerances: List<Double> = times.indices.map { index ->
        val gap = if (index + 1 < times.size) times[index + 1] - times[index] else steps[index].heldBeats * secondsPerBeat
        minOf(0.22, gap * 0.45)
    }

    fun verdict(step: Int, elapsed: Double): Verdict {
        val difference = elapsed - times[step]
        if (abs(difference) <= tolerances[step]) return Verdict.ON_TIME
        return if (difference < 0) Verdict.EARLY else Verdict.LATE
    }

    /** The moment to play this step has passed: a late key still counts until the next note is due. */
    fun isOverdue(step: Int, elapsed: Double): Boolean {
        val limit = if (step + 1 < times.size) times[step + 1] - tolerances[step + 1] else times[step] + tolerances[step] * 3
        return elapsed > maxOf(times[step] + tolerances[step], limit)
    }
}

/**
 * The best result of each lesson, kept on the device (the app saves it under the iOS keys "lessons.stars" and
 * "lessons.unlockAll"). A lesson opens when the one before it was finished.
 */
data class LessonProgress(
    val stars: Map<String, Int> = emptyMap(),
    val unlocksEverything: Boolean = false,
) {
    /** Keeps the best result. */
    fun recording(lessonId: String, earned: Int): LessonProgress =
        copy(stars = stars + (lessonId to maxOf(stars[lessonId] ?: 0, earned)))

    fun isOpen(lesson: Lesson, lessons: List<Lesson>): Boolean {
        if (unlocksEverything) return true
        val index = lessons.indexOfFirst { it.id == lesson.id }
        if (index <= 0) return true
        return (stars[lessons[index - 1].id] ?: 0) > 0
    }
}
