// ReadingDrill.kt — port of luksMusic/Models/ReadingDrill.swift.
//
// Rules of the sight-reading drill ("Treino de leitura"), kept apart from the screen so they can be tested:
// one hand's notes as steps (the keys struck together), the segments shown to the player, the accidentals
// printed against the key signature, note names, and the window of keys the phone's keyboard shows.
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Staff
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.roundToLong
import kotlin.random.Random

/** The hand being read: the right hand reads the treble staff, the left hand the bass staff. Raw values match iOS. */
enum class ReadingHand(val raw: String) {
    RIGHT("right"), LEFT("left"),
    /** Both staves together: the whole piece, on a grand staff. */
    BOTH("both");

    /** The staff a single hand reads (both hands: the treble staff, the one the melody is on). */
    val staff: Staff get() = if (this == LEFT) Staff.BASS else Staff.TREBLE

    companion object {
        fun fromRaw(raw: String?): ReadingHand? = entries.firstOrNull { it.raw == raw }
    }
}

/** How many of the notes struck together the drill asks for at each step. Raw values match iOS. */
enum class ReadingNotes(val raw: String) {
    /** One: the melody (the highest note; the lowest for the left hand alone) */
    ONE("one"),
    /** Two: the two highest notes of the right hand, the two lowest of the left, or with both hands melody and bass */
    TWO("two"),
    /** Every note, as the piece is written */
    ALL("all");

    companion object {
        fun fromRaw(raw: String?): ReadingNotes? = entries.firstOrNull { it.raw == raw }
    }
}

/** How one segment follows another. Raw values match iOS. */
enum class ReadingOrder(val raw: String) {
    /** Through the piece from the start, segment after segment */
    SEQUENTIAL("sequential"),
    /** Any segment of the piece */
    RANDOM("random");

    companion object {
        fun fromRaw(raw: String?): ReadingOrder? = entries.firstOrNull { it.raw == raw }
    }
}

/** What the drill's keyboard writes on its keys. Raw values match iOS. */
enum class ReadingKeyLabels(val raw: String) {
    SOLFEGE("solfege"), LETTERS("letters"), OCTAVES_ONLY("octavesOnly"), HIDDEN("hidden");

    companion object {
        fun fromRaw(raw: String?): ReadingKeyLabels? = entries.firstOrNull { it.raw == raw }
    }
}

/** The keys one hand strikes together at one moment of the piece. */
data class ReadingStep(
    /** Index of the measure in the score */
    val measureIndex: Int,
    /** The measure's printed number (0 for a pickup) */
    val measureNumber: Int,
    /** Onset in the measure, in the time signature's beat (from 1) */
    val beat: Double,
    /** Beats from the start of the piece to the onset */
    val globalBeat: Double,
    /** The notes, lowest first, one per key */
    val notes: List<Note>,
    /** How long the longest note is held, in the time signature's beat */
    val heldBeats: Double,
) {
    /** The keys, lowest first. */
    val midiNotes: Set<Int> get() = notes.mapTo(LinkedHashSet()) { it.midiNote }

    val isRest: Boolean get() = notes.isNotEmpty() && notes.all { it.isRest }
}

/** What the player did on one step of the current segment. */
data class ReadingStepResult(
    /** Keys of the step already found */
    val played: Set<Int> = emptySet(),
    /** Wrong keys pressed while on this step */
    val mistakes: Int = 0,
    /** The answer was shown (hint, or too many mistakes) */
    val revealed: Boolean = false,
    val isDone: Boolean = false,
) {
    /** Right on the first try: no wrong key and no hint. */
    val isClean: Boolean get() = isDone && mistakes == 0 && !revealed
}

/** The outcome of one key press. */
sealed interface ReadingPress {
    /** A key of the step; [stepDone] when it was the step's last missing key */
    data class Correct(val stepDone: Boolean) : ReadingPress
    /** A key of the step that was already found, or a press after the segment ended */
    data object Ignored : ReadingPress
    data object Wrong : ReadingPress
}

/** One segment being read: which step is next and how each step went. */
class ReadingSegmentState(val steps: List<ReadingStep>) {
    private val _results = MutableList(steps.size) { ReadingStepResult() }

    /** A copy of each step's result, safe to hand to the screen. */
    val results: List<ReadingStepResult> get() = _results.toList()

    var current: Int = 0
        private set

    init {
        skipRests()
    }

    val isComplete: Boolean get() = current >= steps.size

    /** Steps read right on the first try. */
    val cleanCount: Int get() = steps.indices.count { !steps[it].isRest && _results[it].isClean }

    /** Steps with keys to play. */
    val playableCount: Int get() = steps.count { !it.isRest }

    val currentStep: ReadingStep? get() = if (isComplete) null else steps[current]

    fun result(index: Int): ReadingStepResult = _results[index]

    /** Checks a key against the current step. A chord's keys may come one at a time, in any order. */
    fun press(midi: Int): ReadingPress {
        if (current >= steps.size) return ReadingPress.Ignored
        val target = steps[current].midiNotes
        val result = _results[current]
        if (midi !in target) {
            _results[current] = result.copy(mistakes = result.mistakes + 1)
            return ReadingPress.Wrong
        }
        if (midi in result.played) return ReadingPress.Ignored
        val played = result.played + midi
        if (!played.containsAll(target)) {
            _results[current] = result.copy(played = played)
            return ReadingPress.Correct(stepDone = false)
        }
        _results[current] = result.copy(played = played, isDone = true)
        current += 1
        skipRests()
        return ReadingPress.Correct(stepDone = true)
    }

    /** The moment for the current step passed without it being played. */
    fun miss() {
        if (current >= steps.size) return
        val result = _results[current]
        _results[current] = result.copy(mistakes = result.mistakes + 1, isDone = true)
        current += 1
        skipRests()
    }

    /** A step was played, but outside its moment. */
    fun markOffBeat(step: Int) {
        if (step !in _results.indices) return
        _results[step] = _results[step].let { it.copy(mistakes = it.mistakes + 1) }
    }

    /** Nothing is played on a rest, so it is passed over. */
    private fun skipRests() {
        while (current < steps.size && steps[current].isRest) {
            _results[current] = _results[current].copy(isDone = true)
            current += 1
        }
    }

    /** Shows the current step's answer; the step no longer counts as right on the first try. */
    fun reveal() {
        if (current >= steps.size) return
        _results[current] = _results[current].copy(revealed = true)
    }
}

object ReadingDrill {

    /** Lowest and highest keys of an 88-key piano. */
    val pianoRange = 21..108

    // ---- Steps and Segments

    /**
     * The hand's notes grouped by onset, in playing order, keeping [kept] of each group (see [ReadingNotes]). Rests
     * and the held ends of ties are left out, since no key is struck for them; with both hands and one note, moments
     * when only the left hand strikes are left out too (the melody goes on sounding).
     */
    fun steps(
        measures: List<Measure>,
        hand: ReadingHand,
        timeSignatureTop: Int,
        beatUnit: Int,
        kept: ReadingNotes = ReadingNotes.ALL,
    ): List<ReadingStep> {
        val steps = mutableListOf<ReadingStep>()
        var measureStart = 0.0
        measures.forEachIndexed { index, measure ->
            // A short first measure numbered 0 is a pickup; other unnumbered measures count from their position
            val number = if (measure.number > 0) measure.number else (if (index == 0 && measure.length != null) 0 else index + 1)
            val struck = measure.notes.filter {
                (hand == ReadingHand.BOTH || it.staff == hand.staff) && !it.isRest && it.isTieContinuation != true
            }
            // Onsets a rounding error apart (triplets) are one moment
            val byOnset = struck.groupBy { (it.beat * 1000).roundToLong() / 1000.0 }
            for (beat in byOnset.keys.sorted()) {
                val seen = HashSet<Int>()
                val all = byOnset.getValue(beat).sortedBy { it.midiNote }.filter { seen.add(it.midiNote) }
                val notes = selected(all, hand, kept)
                if (notes.isEmpty()) continue
                steps += ReadingStep(
                    measureIndex = index,
                    measureNumber = number,
                    beat = beat,
                    globalBeat = measureStart + beat - 1,
                    notes = notes,
                    heldBeats = notes.maxOfOrNull { it.heldBeats(beatUnit) } ?: 1.0,
                )
            }
            measureStart += measure.beats(timeSignatureTop)
        }
        return steps
    }

    /** The notes asked for at one moment, from its [notes] lowest first. */
    fun selected(notes: List<Note>, hand: ReadingHand, kept: ReadingNotes): List<Note> = when {
        kept == ReadingNotes.ALL -> notes
        hand == ReadingHand.RIGHT -> notes.takeLast(if (kept == ReadingNotes.ONE) 1 else 2)
        hand == ReadingHand.LEFT -> notes.take(if (kept == ReadingNotes.ONE) 1 else 2)
        kept == ReadingNotes.ONE -> notes.filter { it.staff == Staff.TREBLE }.takeLast(1)
        // The melody on top and the bass below, each when its hand strikes
        else -> notes.filter { it.staff == Staff.BASS }.take(1) + notes.filter { it.staff == Staff.TREBLE }.takeLast(1)
    }

    /** Number of segments when the piece is read in order, [size] steps at a time (the last one may be shorter). */
    fun segmentCount(stepCount: Int, size: Int): Int =
        if (stepCount == 0) 0 else (stepCount + maxOf(1, size) - 1) / maxOf(1, size)

    /** The steps of the segment that starts at [start] (half-open, like Swift's Range). */
    fun segment(start: Int, size: Int, stepCount: Int): IntRange {
        val lower = maxOf(0, minOf(start, stepCount))
        return lower until minOf(stepCount, lower + maxOf(1, size))
    }

    /** A random segment start, different from [previous] when the piece has more than one. */
    fun randomStart(stepCount: Int, size: Int, previous: Int?, random: Random): Int {
        val last = maxOf(0, stepCount - maxOf(1, size))
        if (last <= 0) return 0
        var start = random.nextInt(0, last + 1)
        if (start == previous) {
            start = (start + maxOf(1, size)) % (last + 1)
            if (start == previous) {
                start = (start + 1) % (last + 1)
            }
        }
        return start
    }

    // ---- Key Signature and Accidentals

    private val sharpOrder = listOf(NoteName.F, NoteName.C, NoteName.G, NoteName.D, NoteName.A, NoteName.E, NoteName.B)

    /** The alteration the key signature gives a letter: +1 sharp, -1 flat, 0 none. */
    fun keyAlteration(letter: NoteName, keySignature: Int): Int {
        val count = minOf(7, abs(keySignature))
        return when {
            keySignature > 0 -> if (letter in sharpOrder.take(count)) 1 else 0
            keySignature < 0 -> if (letter in sharpOrder.reversed().take(count)) -1 else 0
            else -> 0
        }
    }

    fun accidental(alteration: Int): Accidental = when (alteration) {
        2 -> Accidental.DOUBLE_SHARP
        1 -> Accidental.SHARP
        -1 -> Accidental.FLAT
        -2 -> Accidental.DOUBLE_FLAT
        else -> Accidental.NATURAL
    }

    /**
     * The accidental printed before each note of [steps] (same shape as the steps' notes), or null where the key
     * signature, or an accidental printed earlier in the same measure of the segment, already gives the note.
     */
    fun printedAccidentals(steps: List<ReadingStep>, keySignature: Int): List<List<Accidental?>> {
        val inEffect = HashMap<String, Int>()
        return steps.map { step ->
            step.notes.map { note ->
                val key = "${step.measureIndex}-${note.pitch.noteName.name}${note.pitch.octave}"
                val alteration = note.pitch.accidental.semitoneOffset
                val current = inEffect[key] ?: keyAlteration(note.pitch.noteName, keySignature)
                inEffect[key] = alteration
                if (alteration == current) null else accidental(alteration)
            }
        }
    }

    // ---- Spelling Scores Read Without Note Names

    /**
     * The key signature whose major scale holds the most notes (ties go to the fewest accidentals), for scores
     * whose data only has MIDI numbers.
     */
    fun estimatedKeySignature(midiNotes: List<Int>): Int {
        if (midiNotes.isEmpty()) return 0
        val histogram = IntArray(12)
        for (midi in midiNotes) histogram[Math.floorMod(midi, 12)] += 1
        val majorScale = listOf(0, 2, 4, 5, 7, 9, 11)
        var best = 0
        var bestCount = -1
        for (fifths in listOf(0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6)) {
            val tonic = Math.floorMod(fifths * 7, 12)
            val count = majorScale.sumOf { histogram[(tonic + it) % 12] }
            if (count > bestCount) {
                best = fifths
                bestCount = count
            }
        }
        return best
    }

    /**
     * Names a key the way a score in [keySignature] would: the key's own notes keep their letter (F♯ in G major,
     * B♭ in F major); other black keys are sharps in sharp keys, flats in flat keys, and C♯ E♭ F♯ A♭ B♭ in C.
     */
    fun spelledPitch(midi: Int, keySignature: Int): Pitch {
        val pitchClass = Math.floorMod(midi, 12)
        val octave = floor(midi / 12.0).toInt() - 1
        for (letter in NoteName.entries) {
            val alteration = keyAlteration(letter, keySignature)
            if (alteration == 0) continue
            val sounding = letter.baseSemitone + alteration
            if ((sounding + 12) % 12 == pitchClass) {
                // C♭ belongs to the octave above its key, B♯ to the one below
                val octaveShift = if (sounding < 0) 1 else if (sounding >= 12) -1 else 0
                return Pitch(letter, octave + octaveShift, accidental(alteration))
            }
        }
        val naturals = mapOf(0 to NoteName.C, 2 to NoteName.D, 4 to NoteName.E, 5 to NoteName.F, 7 to NoteName.G, 9 to NoteName.A, 11 to NoteName.B)
        naturals[pitchClass]?.let { return Pitch(it, octave, Accidental.NATURAL) }
        val sharps = mapOf(1 to NoteName.C, 3 to NoteName.D, 6 to NoteName.F, 8 to NoteName.G, 10 to NoteName.A)
        val flats = mapOf(1 to NoteName.D, 3 to NoteName.E, 6 to NoteName.G, 8 to NoteName.A, 10 to NoteName.B)
        val useSharp = keySignature > 0 || (keySignature == 0 && (pitchClass == 1 || pitchClass == 6))
        if (useSharp) sharps[pitchClass]?.let { return Pitch(it, octave, Accidental.SHARP) }
        return Pitch(flats[pitchClass] ?: NoteName.C, octave, Accidental.FLAT)
    }

    /** The measures with every note renamed for the estimated key, and that key. */
    fun respelled(measures: List<Measure>): Pair<List<Measure>, Int> {
        val midiNotes = measures.flatMap { m -> m.notes.filter { !it.isRest }.map { it.midiNote } }
        val keySignature = estimatedKeySignature(midiNotes)
        val renamed = measures.map { measure ->
            measure.copy(notes = measure.notes.map { note ->
                if (note.isRest) note else note.copy(pitch = spelledPitch(note.midiNote, keySignature))
            })
        }
        return renamed to keySignature
    }

    // ---- Note Names

    /** "Mi5", "Fá♯4", "Si♭3" in solfège; "E5", "F♯4", "B♭3" with [usesLetters] (the app in English). */
    fun name(pitch: Pitch, usesLetters: Boolean): String = NoteNaming.name(pitch, usesLetters) + pitch.octave

    /** A step's notes named from the highest down, the way they stack on the staff: "Mi5 · Dó5". */
    fun name(step: ReadingStep, usesLetters: Boolean): String =
        step.notes.reversed().joinToString(" · ") { name(it.pitch, usesLetters) }

    // ---- Keyboard Window

    fun isWhite(midi: Int): Boolean = Math.floorMod(midi, 12) !in setOf(1, 3, 6, 8, 10)

    /** The white key at or below [midi]. */
    fun whiteAtOrBelow(midi: Int): Int {
        var key = midi
        while (!isWhite(key)) key -= 1
        return key
    }

    /** The white key at or above [midi]. */
    fun whiteAtOrAbove(midi: Int): Int {
        var key = midi
        while (!isWhite(key)) key += 1
        return key
    }

    /** The white key [count] white keys away from the white key [from] (left when negative). */
    fun white(from: Int, count: Int): Int {
        var key = from
        var remaining = abs(count)
        while (remaining > 0) {
            key += if (count > 0) 1 else -1
            if (isWhite(key)) remaining -= 1
        }
        return key
    }

    /** White keys from [lower] through [upper]. */
    fun whiteCount(lower: Int, upper: Int): Int = if (lower > upper) 0 else (lower..upper).count(::isWhite)

    /**
     * The keys the phone shows: [whiteKeys] white keys, from a white key to a white key. The hand's whole range
     * when it fits, so the keyboard never moves; otherwise [current] while it still holds the segment, else a
     * window around the segment that starts on a C when it can. A segment wider than the window gets all its keys.
     */
    fun keyboardRange(segment: IntRange, hand: IntRange?, whiteKeys: Int, current: IntRange?): IntRange {
        val keys = maxOf(7, whiteKeys)

        if (hand != null) {
            val lower = whiteAtOrBelow(hand.first)
            val upper = whiteAtOrAbove(hand.last)
            val needed = whiteCount(lower, upper)
            if (needed <= keys) {
                return window(white(lower, -((keys - needed) / 2)), keys)
            }
        }

        if (current != null && current.first <= segment.first && segment.last <= current.last &&
            whiteCount(current.first, current.last) == keys
        ) {
            return current
        }

        val lower = whiteAtOrBelow(segment.first)
        val upper = whiteAtOrAbove(segment.last)
        val needed = whiteCount(lower, upper)
        if (needed >= keys) {
            return maxOf(pianoRange.first, lower)..minOf(pianoRange.last, upper)
        }
        val slack = keys - needed
        val centered = white(lower, -(slack / 2))
        // Any start from `slack` white keys left of the segment up to its lowest key keeps it on screen
        val candidates = (0..slack).map { white(lower, -it) }
        val start = candidates.filter { it % 12 == 0 }.minByOrNull { abs(it - centered) } ?: centered
        return window(start, keys)
    }

    /** [whiteKeys] white keys from [start], kept on the piano. */
    private fun window(start: Int, whiteKeys: Int): IntRange {
        var lower = maxOf(pianoRange.first, start)
        var upper = white(lower, whiteKeys - 1)
        if (upper > pianoRange.last) {
            upper = pianoRange.last
            lower = maxOf(pianoRange.first, white(upper, -(whiteKeys - 1)))
        }
        return lower..upper
    }
}
