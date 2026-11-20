// LessonIntro.kt — port of luksMusic/Models/Lessons/LessonIntro.swift.
//
// Scripted motion-graphics introductions for lessons: timed chapters, progressive staff construction, animated key
// presses across a two-octave keyboard, and subtitles in the app's language. Everything here is pure: the screen
// (feature/learn/LessonIntroScreen.kt) asks for the snapshot at the current time and draws it.
//
// Texts are string resource names (LessonText, like LessonCatalog): English in res/values/strings_intro.xml,
// Portuguese in res/values-pt/strings_intro.xml, named intro_*.
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.model.NoteNaming
import kotlin.math.PI
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

enum class LessonIntro {
    /** How sheet music begins: the 5 lines, 4 spaces, middle C two steps below line 1, and climbing one octave. */
    TREBLE_OCTAVE,
}

/** One timed subtitle chapter shown above the animated staff. */
data class LessonIntroCue(
    val startTime: Double,
    val endTime: Double,
    val phaseNumber: Int,
    val phaseLabel: LessonText,
    val title: LessonText,
    val subtitle: LessonText,
)

/** One key press in the scripted choreography, spawning or highlighting a note on the staff. */
data class LessonIntroPress(
    val id: Int,
    /** Pitch token such as "C4" */
    val token: String,
    val midi: Int,
    /** Diatonic staff position in treble clef (-6 = middle C ledger line, -4 = line 1, +1 = space 3) */
    val staffPosition: Int,
    /** Column index on the staff (0..7 for C4..C5) */
    val staffColumn: Int,
    /** Time in seconds when the key is struck */
    val onset: Double,
    /** How long the key stays held down */
    val holdDuration: Double,
    /** Whether this strike spawns the note on the staff for the first time (false during the finale replay) */
    val spawnsNote: Boolean,
    /** Short callout tag shown by the staff line or space while this note is introduced (none in the finale) */
    val positionCallout: LessonText?,
)

/** Complete state of the intro animation at a given [time] (0..duration). */
data class LessonIntroSnapshot(
    val time: Double,
    val duration: Double,
    val cue: LessonIntroCue,
    val totalPhases: Int,
    /** Draw progress (0..1) for each of the 5 staff lines, bottom (index 0, pos -4) to top (index 4, pos +4) */
    val lineProgress: List<Double>,
    /** Highlight intensity (0..1) for each of the 5 staff lines when a note lands on that line */
    val lineGlow: List<Double>,
    /** Highlight intensity (0..1) for each of the 4 spaces, bottom (index 0, pos -3) to top (index 3, pos +3) */
    val spaceGlow: List<Double>,
    /** Highlight intensity (0..1) for the space right below line 1 (D4, pos -5) */
    val belowLineSpaceGlow: Double,
    /** Reveal progress (0..1) of the treble clef */
    val clefProgress: Double,
    /** Extra pulse (0..1) around the treble clef's G-line curl when G4 is introduced */
    val clefLinePulse: Double,
    /** Visibility (0..1) of the 2-steps-below guide leading from line 1 down to middle C */
    val middleCGuideOpacity: Double,
    /** Active callout label next to the current note's line/space, if any */
    val activeCallout: Callout?,
    /** The "+1/2" step indicator between the previous note and the current note */
    val stepUpIndicator: StepUp?,
    /** Visibility (0..1) of the octave arch spanning from C4 (col 0) to C5 (col 7) */
    val octaveArchProgress: Double,
    /** Notes currently visible on the staff */
    val notes: List<VisibleNote>,
    /** Highlight intensity (0..1) on the pairs of 2 black keys (showing how to find C) */
    val twoBlackKeysGlow: Double,
    /** Touch cursor visibility (0..1) */
    val cursorOpacity: Double,
    /** Continuous MIDI position of the gliding touch cursor on the two-octave keyboard */
    val cursorMidiPosition: Double,
    /** Key depression amount (0..1) at the cursor */
    val cursorPressDepth: Double,
    /** Expanding touch ripple anchored at the struck key, or null when idle */
    val ripple: Ripple?,
    /** MIDI key currently lit in cyan (learning strike) */
    val activeCyanKey: Int?,
    /** MIDI key currently lit in green (finale scale replay) */
    val activeGreenKey: Int?,
    /** Light beam rising from the struck key to the newly spawned note on the staff */
    val beam: Beam?,
) {
    data class VisibleNote(
        /** staffColumn 0..7 */
        val id: Int,
        val midi: Int,
        val staffPosition: Int,
        val name: String,
        /** 0..1 spring-in progress when the note first materializes */
        val appearProgress: Double,
        /** 0..1 highlight while being introduced */
        val activeGlow: Double,
        /** 0..1 emerald highlight during the octave replay finale */
        val finaleGlow: Double,
    ) {
        /** Stem points up below the middle line, down from B4 up */
        val stemUp: Boolean get() = staffPosition < 0
    }

    data class Callout(val staffColumn: Int, val staffPosition: Int, val text: LessonText, val opacity: Double)
    data class StepUp(val fromColumn: Int, val toColumn: Int, val progress: Double)
    data class Ripple(val midi: Int, val progress: Double)
    data class Beam(val midi: Int, val staffColumn: Int, val staffPosition: Int, val progress: Double)
}

object LessonIntroScript {

    /** Two clean octaves from middle C (C4 = 60 to C6 = 84, 15 white keys), avoiding visual overload. */
    val keyboardRange: IntRange = 60..84

    private fun t(key: String) = LessonText(key)

    fun duration(intro: LessonIntro): Double = when (intro) {
        LessonIntro.TREBLE_OCTAVE -> 45.5
    }

    private class Beat(val token: String, val midi: Int, val pos: Int, val onset: Double, val callout: String)

    /** All scripted piano strikes, in chronological order. Each `id` fires audio once when playback crosses `onset`. */
    fun presses(intro: LessonIntro): List<LessonIntroPress> = when (intro) {
        LessonIntro.TREBLE_OCTAVE -> {
            val steps = listOf(
                Beat("C4", 60, -6, 10.6, "intro_callout_c4"),
                Beat("D4", 62, -5, 14.6, "intro_callout_d4"),
                Beat("E4", 64, -4, 18.0, "intro_callout_e4"),
                Beat("F4", 65, -3, 21.4, "intro_callout_f4"),
                Beat("G4", 67, -2, 24.8, "intro_callout_g4"),
                Beat("A4", 69, -1, 28.2, "intro_callout_a4"),
                Beat("B4", 71, 0, 31.6, "intro_callout_b4"),
                Beat("C5", 72, 1, 35.0, "intro_callout_c5"),
            )
            val result = steps.mapIndexed { index, item ->
                LessonIntroPress(
                    id = index, token = item.token, midi = item.midi, staffPosition = item.pos, staffColumn = index,
                    onset = item.onset, holdDuration = 1.35, spawnsNote = true, positionCallout = t(item.callout),
                )
            }.toMutableList()
            // Finale replay: smooth ascending C major scale across the whole octave
            val finaleStart = 39.4
            val stepGap = 0.48
            steps.forEachIndexed { index, item ->
                val isLast = index == steps.size - 1
                result += LessonIntroPress(
                    id = steps.size + index, token = item.token, midi = item.midi, staffPosition = item.pos,
                    staffColumn = index, onset = finaleStart + index * stepGap, holdDuration = if (isLast) 1.4 else 0.42,
                    spawnsNote = false, positionCallout = null,
                )
            }
            result
        }
    }

    fun cues(intro: LessonIntro): List<LessonIntroCue> = when (intro) {
        LessonIntro.TREBLE_OCTAVE -> {
            val phase1 = t("intro_phase_staff")
            val phase2 = t("intro_phase_middle_c")
            val phase3 = t("intro_phase_ladder")
            val phase4 = t("intro_phase_octave")
            fun cue(start: Double, end: Double, phase: Int, label: LessonText, name: String) =
                LessonIntroCue(start, end, phase, label, t("intro_treble_${name}_title"), t("intro_treble_${name}_text"))
            listOf(
                cue(0.0, 4.2, 1, phase1, "lines"),
                cue(4.2, 8.0, 1, phase1, "spaces"),
                cue(8.0, 14.3, 2, phase2, "middle_c"),
                cue(14.3, 17.8, 3, phase3, "d"),
                cue(17.8, 21.2, 3, phase3, "e"),
                cue(21.2, 24.6, 3, phase3, "f"),
                cue(24.6, 28.0, 3, phase3, "g"),
                cue(28.0, 34.8, 3, phase3, "a_b"),
                cue(34.8, 39.0, 4, phase4, "octave"),
                cue(39.0, 45.5, 4, phase4, "one_per_key"),
            )
        }
    }

    /** Note label without octave number ("Dó", "Ré"... in Portuguese; "C", "D"... in English). */
    fun shortNoteName(token: String, usesLetters: Boolean): String {
        val pitch = LessonNotation.pitch(token) ?: return token
        return NoteNaming.name(pitch.noteName, usesLetters)
    }

    fun snapshot(intro: LessonIntro, rawTime: Double, usesLetters: Boolean): LessonIntroSnapshot {
        val total = duration(intro)
        val t = min(max(0.0, rawTime), total)
        val allCues = cues(intro)
        val activeCue = allCues.lastOrNull { t >= it.startTime } ?: allCues[0]
        val allPresses = presses(intro)
        val introPresses = allPresses.filter { it.spawnsNote }
        val finalePresses = allPresses.filter { !it.spawnsNote }

        // 1. Five staff lines draw bottom-to-top between 0.3s and 3.5s
        val lineProgress = (0 until 5).map { index ->
            val start = 0.35 + index * 0.55
            easeOut(progress(t, start, 0.65))
        }

        // 2. Four spaces pulse gently between 4.4s and 6.4s, and glow when their note is introduced
        val spaceGlow = (0 until 4).map { index ->
            val waveStart = 4.4 + index * 0.36
            bellCurve(t, waveStart, 1.4) * 0.85
        }.toMutableList()

        val lineGlow = MutableList(5) { 0.0 }
        var belowLineSpaceGlow = 0.0

        // 3. Treble clef enters at 6.0s
        val clefProgress = easeOut(progress(t, 5.9, 1.1))
        var clefLinePulse = bellCurve(t, 6.3, 1.6) * 0.65

        // 4. Two-steps-below guide for Middle C (8.3s to 14.3s)
        val middleCGuideOpacity = smoothWindow(t, 8.3, 9.1, 13.5, 14.3)
        val twoBlackKeysGlow = smoothWindow(t, 8.1, 8.7, 10.3, 11.1)

        // 5. Notes on the staff & line/space highlights
        var activeCallout: LessonIntroSnapshot.Callout? = null
        var stepUpIndicator: LessonIntroSnapshot.StepUp? = null
        var beam: LessonIntroSnapshot.Beam? = null
        var activeCyanKey: Int? = null
        var activeGreenKey: Int? = null

        val visibleNotes = mutableListOf<LessonIntroSnapshot.VisibleNote>()
        for (press in introPresses) {
            if (t < press.onset) continue
            val age = t - press.onset
            val appear = min(1.0, age / 0.42)
            val active = smoothWindow(t, press.onset, press.onset + 0.12, press.onset + 2.4, press.onset + 3.1)

            // Finale glow if the replay scale is hitting or has just hit this column
            var finale = 0.0
            val replay = finalePresses.firstOrNull { it.staffColumn == press.staffColumn }
            if (replay != null && t >= replay.onset) {
                finale = smoothWindow(t, replay.onset, replay.onset + 0.08,
                    replay.onset + replay.holdDuration, replay.onset + replay.holdDuration + 0.6)
            }

            visibleNotes += LessonIntroSnapshot.VisibleNote(
                id = press.staffColumn,
                midi = press.midi,
                staffPosition = press.staffPosition,
                name = shortNoteName(press.token, usesLetters),
                appearProgress = appear,
                activeGlow = active,
                finaleGlow = finale,
            )

            // Highlight corresponding staff line or space while active
            if (active > 0.01) {
                when (press.staffPosition) {
                    -5 -> belowLineSpaceGlow = max(belowLineSpaceGlow, active)
                    -4, -2, 0, 2, 4 -> {
                        val lineIdx = (press.staffPosition + 4) / 2
                        if (lineIdx in lineGlow.indices) lineGlow[lineIdx] = max(lineGlow[lineIdx], active)
                        if (press.staffPosition == -2) clefLinePulse = max(clefLinePulse, active)
                    }
                    -3, -1, 1, 3 -> {
                        val spaceIdx = (press.staffPosition + 3) / 2
                        if (spaceIdx in spaceGlow.indices) spaceGlow[spaceIdx] = max(spaceGlow[spaceIdx], active)
                    }
                    else -> Unit
                }
                press.positionCallout?.let {
                    activeCallout = LessonIntroSnapshot.Callout(press.staffColumn, press.staffPosition, it, active)
                }
            }

            if (age >= 0 && age <= 0.75) {
                beam = LessonIntroSnapshot.Beam(press.midi, press.staffColumn, press.staffPosition, age / 0.75)
            }
            if (press.staffColumn > 0 && age >= 0 && age <= 1.8) {
                stepUpIndicator = LessonIntroSnapshot.StepUp(press.staffColumn - 1, press.staffColumn,
                    easeOut(min(1.0, age / 0.55)) * (1 - max(0.0, (age - 1.2) / 0.6)))
            }
            if (age >= 0 && age <= press.holdDuration) activeCyanKey = press.midi
        }

        for (replay in finalePresses) {
            val age = t - replay.onset
            if (age >= 0 && age <= replay.holdDuration) activeGreenKey = replay.midi
        }

        val octaveArchProgress = smoothWindow(t, 35.4, 36.3, 44.8, 45.5)

        // 6. Motion-capture touch cursor position, press depth, and ripple
        val cursor = cursorState(t, introPresses, finalePresses)

        return LessonIntroSnapshot(
            time = t,
            duration = total,
            cue = activeCue,
            totalPhases = 4,
            lineProgress = lineProgress,
            lineGlow = lineGlow,
            spaceGlow = spaceGlow,
            belowLineSpaceGlow = belowLineSpaceGlow,
            clefProgress = clefProgress,
            clefLinePulse = clefLinePulse,
            middleCGuideOpacity = middleCGuideOpacity,
            activeCallout = activeCallout,
            stepUpIndicator = stepUpIndicator,
            octaveArchProgress = octaveArchProgress,
            notes = visibleNotes,
            twoBlackKeysGlow = twoBlackKeysGlow,
            cursorOpacity = cursor.opacity,
            cursorMidiPosition = cursor.midiPosition,
            cursorPressDepth = cursor.pressDepth,
            ripple = cursor.ripple,
            activeCyanKey = activeCyanKey,
            activeGreenKey = activeGreenKey,
            beam = beam,
        )
    }

    // ---- Cursor Kinematics

    private class Cursor(val opacity: Double, val midiPosition: Double, val pressDepth: Double, val ripple: LessonIntroSnapshot.Ripple?)

    private fun cursorState(t: Double, introPresses: List<LessonIntroPress>, finalePresses: List<LessonIntroPress>): Cursor {
        val all = introPresses + finalePresses
        val first = all.firstOrNull() ?: return Cursor(0.0, 60.0, 0.0, null)
        val last = all.last()

        val fadeInStart = first.onset - 1.2
        val fadeOutEnd = last.onset + last.holdDuration + 0.8
        val opacity = smoothWindow(t, fadeInStart, first.onset - 0.3, last.onset + last.holdDuration + 0.1, fadeOutEnd)
        if (opacity <= 0.001) return Cursor(0.0, first.midi.toDouble(), 0.0, null)

        // Smoothly glide between consecutive strikes
        var midiPos = first.midi.toDouble()
        if (t <= first.onset) {
            // Glide in slightly from the right toward Middle C
            val glide = easeInOut(progress(t, fadeInStart, first.onset - fadeInStart))
            midiPos = 64.0 + (first.midi - 64.0) * glide
        } else {
            for (index in all.indices) {
                val current = all[index]
                if (index + 1 < all.size) {
                    val next = all[index + 1]
                    if (t >= current.onset && t < next.onset) {
                        val gap = next.onset - current.onset
                        val moveDuration = min(0.65, gap * 0.42)
                        val moveStart = next.onset - moveDuration
                        midiPos = if (t <= moveStart) {
                            current.midi.toDouble()
                        } else {
                            val glide = easeInOut(progress(t, moveStart, moveDuration))
                            current.midi + (next.midi - current.midi) * glide
                        }
                        break
                    }
                } else if (t >= current.onset) {
                    midiPos = current.midi.toDouble()
                }
            }
        }

        // Press depth and touch ripple anchored on the struck key
        var pressDepth = 0.0
        var ripple: LessonIntroSnapshot.Ripple? = null
        val active = all.lastOrNull { t >= it.onset }
        if (active != null) {
            val age = t - active.onset
            if (age <= active.holdDuration + 0.18) {
                val attack = min(1.0, age / 0.07)
                val release = if (age <= active.holdDuration) 1.0 else max(0.0, 1.0 - (age - active.holdDuration) / 0.18)
                pressDepth = attack * release
            }
            if (age >= 0 && age <= 0.55) ripple = LessonIntroSnapshot.Ripple(active.midi, age / 0.55)
        }
        return Cursor(opacity, midiPos, pressDepth, ripple)
    }

    // ---- Keyboard Geometry

    /** Maps a continuous MIDI number in 60..84 to a continuous white-key slot index in 0..14. */
    fun whiteSlot(midi: Double): Double {
        val clamped = min(84.0, max(60.0, midi))
        val rel = clamped - 60.0
        val octave = floor(rel / 12.0)
        val semitone = rel - octave * 12.0
        val anchors = listOf(0.0 to 0.0, 2.0 to 1.0, 4.0 to 2.0, 5.0 to 3.0, 7.0 to 4.0, 9.0 to 5.0, 11.0 to 6.0, 12.0 to 7.0)
        var localSlot = 0.0
        for (idx in 0 until anchors.size - 1) {
            val (aSemi, aSlot) = anchors[idx]
            val (bSemi, bSlot) = anchors[idx + 1]
            if (semitone >= aSemi && semitone <= bSemi) {
                val frac = (semitone - aSemi) / (bSemi - aSemi)
                localSlot = aSlot + (bSlot - aSlot) * frac
                break
            }
        }
        return octave * 7.0 + localSlot
    }

    // ---- Easing Helpers

    private fun progress(t: Double, start: Double, duration: Double): Double {
        if (duration <= 0) return if (t >= start) 1.0 else 0.0
        return min(1.0, max(0.0, (t - start) / duration))
    }

    private fun easeOut(x: Double): Double = 1 - (1 - x).pow(3)

    private fun easeInOut(x: Double): Double = if (x < 0.5) 4 * x * x * x else 1 - (-2 * x + 2).pow(3) / 2

    private fun bellCurve(t: Double, start: Double, duration: Double): Double {
        val p = progress(t, start, duration)
        if (p <= 0 || p >= 1) return 0.0
        return sin(p * PI)
    }

    private fun smoothWindow(t: Double, fadeInStart: Double, fadeInEnd: Double, fadeOutStart: Double, fadeOutEnd: Double): Double {
        if (t <= fadeInStart || t >= fadeOutEnd) return 0.0
        if (t < fadeInEnd) return easeOut(progress(t, fadeInStart, fadeInEnd - fadeInStart))
        if (t > fadeOutStart) return 1 - easeInOut(progress(t, fadeOutStart, fadeOutEnd - fadeOutStart))
        return 1.0
    }
}
