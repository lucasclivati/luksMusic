// LessonCatalog.kt — port of luksMusic/Models/Lessons/LessonCatalog.swift.
//
// The lessons themselves, in teaching order. A lesson is short and each of its steps does something different:
// new notes are learned by playing them, a drill draws notes from everything learned so far (the new ones more
// often), and the lesson ends with a short piece that uses them. Songs are traditional melodies or by composers
// long in the public domain, written out here.
//
// Texts are string resource names (see LessonText): English in res/values/strings_learn.xml, Portuguese in
// res/values-pt/strings_learn.xml, named learn_m_<module>_*, learn_l_<lesson>_* and learn_l_<lesson>_s<step>_*.
// A new text needs its two strings there, or the app shows the key.
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind.INTRO
import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind.LEARN
import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind.LISTEN
import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind.PLAY_ALONG
import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind.READ
import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind.RHYTHM
import com.lukstrike.luksmusic.core.model.Staff

object LessonCatalog {

    private fun t(key: String, suffixKey: String? = null) = LessonText(key, suffixKey)

    private const val drill = "learn_c_drill"
    private const val atYourPace = "learn_c_at_your_pace"

    // Pieces used in more than one lesson
    private const val auClairSnippet = "C4 C4 C4 D4 E4:h D4:h"
    private const val auClairFull = "C4 C4 C4 D4 E4:h D4:h C4 E4 D4 D4 C4:w"
    private const val hotCrossBuns = "E4 D4 C4:h E4 D4 C4:h C4:e C4:e C4:e C4:e D4:e D4:e D4:e D4:e E4 D4 C4:h"
    private const val odeToJoySnippet = "E4 E4 F4 G4 G4 F4 E4 D4"
    private const val odeToJoy = "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:q. D4:e D4:h"
    private const val odeToJoyFull = "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:q. D4:e D4:h E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4:q. C4:e C4:h"
    private const val twinkleSnippet = "C4 C4 G4 G4 A4 A4 G4:h"
    private const val twinkle = "C4 C4 G4 G4 A4 A4 G4:h F4 F4 E4 E4 D4 D4 C4:h"
    private const val maryHalf = "E4 D4 C4 D4 E4 E4 E4:h D4 D4 D4:h E4 G4 G4:h"

    // ---- Clave de Sol

    private val trebleClef = LessonModule(
        id = "treble",
        title = t("learn_m_treble_title"),
        summary = t("learn_m_treble_summary"),
        lessons = listOf(
            Lesson(id = "treble-1", title = t("learn_l_treble_1_title"), summary = t("learn_l_treble_1_summary"), steps = listOf(
                LessonStep(INTRO, t("learn_l_treble_1_s1_title"),
                           t("learn_l_treble_1_s1_text"), intro = LessonIntro.TREBLE_OCTAVE),
                LessonStep(LEARN, t("learn_l_treble_1_s2_title"),
                           t("learn_l_treble_1_s2_text"),
                           notes = "C4 D4 E4"),
                LessonStep(LEARN, t("learn_l_treble_1_s3_title"),
                           t("learn_l_treble_1_s3_text"),
                           notes = "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(READ, t("learn_l_treble_1_s4_title"),
                           t("learn_l_treble_1_s4_text", atYourPace),
                           notes = auClairSnippet, meter = 4),
                LessonStep(READ, t("learn_l_treble_1_s5_title"),
                           t("learn_l_treble_1_s5_text"),
                           notes = auClairFull, meter = 4, challenge = true),
            )),
            Lesson(id = "treble-2", title = t("learn_l_treble_2_title"), summary = t("learn_l_treble_2_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_2_s1_title"), t("learn_l_treble_2_s1_text"), notes = "D4"),
                LessonStep(LEARN, t("learn_l_treble_2_s2_title"), t("learn_l_treble_2_s2_text"), notes = "E4"),
                LessonStep(READ, t("learn_l_treble_2_s3_title"), t("learn_l_treble_2_s3_text", drill), pool = "C4 D4 E4", focus = "D4 E4"),
                LessonStep(READ, t("learn_l_treble_2_s4_title"), t("learn_l_treble_2_s4_text", atYourPace), notes = hotCrossBuns, meter = 4, challenge = true),
            )),
            Lesson(id = "treble-3", title = t("learn_l_treble_3_title"), summary = t("learn_l_treble_3_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_3_s1_title"), t("learn_l_treble_3_s1_text"), notes = "F4"),
                LessonStep(LEARN, t("learn_l_treble_3_s2_title"), t("learn_l_treble_3_s2_text"), notes = "G4"),
                LessonStep(READ, t("learn_l_treble_3_s3_title"), t("learn_l_treble_3_s3_text", drill), pool = "C4 D4 E4 F4 G4", focus = "F4 G4"),
                LessonStep(READ, t("learn_l_treble_3_s4_title"), t("learn_l_treble_3_s4_text", atYourPace), notes = odeToJoySnippet, meter = 4),
                LessonStep(READ, t("learn_l_treble_3_s5_title"), t("learn_l_treble_3_s5_text", drill), notes = odeToJoy, meter = 4, challenge = true),
            )),
            Lesson(id = "treble-4", title = t("learn_l_treble_4_title"), summary = t("learn_l_treble_4_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_4_s1_title"), t("learn_l_treble_4_s1_text"), notes = "A4"),
                LessonStep(LEARN, t("learn_l_treble_4_s2_title"), t("learn_l_treble_4_s2_text"), notes = "B4"),
                LessonStep(LEARN, t("learn_l_treble_4_s3_title"), t("learn_l_treble_4_s3_text"), notes = "C5"),
                LessonStep(READ, t("learn_l_treble_4_s4_title"), t("learn_l_treble_4_s4_text", drill), pool = "C4 D4 E4 F4 G4 A4 B4 C5", focus = "A4 B4 C5"),
                LessonStep(READ, t("learn_l_treble_4_s5_title"), t("learn_l_treble_4_s5_text", atYourPace), notes = twinkleSnippet, meter = 4),
                LessonStep(READ, t("learn_l_treble_4_s6_title"), t("learn_l_treble_4_s6_text", drill), notes = twinkle, meter = 4, challenge = true),
            )),
            Lesson(id = "treble-5", title = t("learn_l_treble_5_title"), summary = t("learn_l_treble_5_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_5_s1_title"), t("learn_l_treble_5_s1_text"), notes = "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(READ, t("learn_l_treble_5_s2_title"), t("learn_l_treble_5_s2_text"), notes = "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(READ, t("learn_l_treble_5_s3_title"), t("learn_l_treble_5_s3_text"), notes = "E4 G4 B4 F4 A4 C5"),
            )),
            Lesson(id = "treble-6", title = t("learn_l_treble_6_title"), summary = t("learn_l_treble_6_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_6_s1_title"), t("learn_l_treble_6_s1_text"), notes = "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(READ, t("learn_l_treble_6_s2_title"), t("learn_l_treble_6_s2_text"), notes = "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(READ, t("learn_l_treble_6_s3_title"), t("learn_l_treble_6_s3_text", drill), pool = "C4 D4 E4 F4 G4 A4 B4 C5"),
            )),
            Lesson(id = "treble-7", title = t("learn_l_treble_7_title"), summary = t("learn_l_treble_7_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_7_s1_title"), t("learn_l_treble_7_s1_text"), notes = "D5 E5"),
                LessonStep(LEARN, t("learn_l_treble_7_s2_title"), t("learn_l_treble_7_s2_text"), notes = "F5 G5"),
                LessonStep(READ, t("learn_l_treble_7_s3_title"), t("learn_l_treble_7_s3_text", drill), pool = "G4 A4 B4 C5 D5 E5 F5 G5", focus = "D5 E5 F5 G5"),
                LessonStep(READ, t("learn_l_treble_7_s4_title"), t("learn_l_treble_7_s4_text", atYourPace),
                           notes = "E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 E5:q. D5:e D5:h", meter = 4, challenge = true),
            )),
            Lesson(id = "treble-8", title = t("learn_l_treble_8_title"), summary = t("learn_l_treble_8_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_treble_8_s1_title"), t("learn_l_treble_8_s1_text"), notes = "A5"),
                LessonStep(LEARN, t("learn_l_treble_8_s2_title"), t("learn_l_treble_8_s2_text"), notes = "B5 C6"),
                LessonStep(READ, t("learn_l_treble_8_s3_title"), t("learn_l_treble_8_s3_text", drill), pool = "E5 F5 G5 A5 B5 C6", focus = "A5 B5 C6"),
            )),
            Lesson(id = "treble-9", title = t("learn_l_treble_9_title"), summary = t("learn_l_treble_9_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_treble_9_s1_title"), t("learn_l_treble_9_s1_text", drill), pool = "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(READ, t("learn_l_treble_9_s2_title"), t("learn_l_treble_9_s2_text", drill),
                           pool = "C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 G5 A5 B5 C6"),
                LessonStep(READ, t("learn_l_treble_9_s3_title"),
                           t("learn_l_treble_9_s3_text"),
                           notes = odeToJoyFull, meter = 4, challenge = true),
            )),
        ),
    )

    // ---- Clave de Fá

    private val bassClef = LessonModule(
        id = "bass",
        title = t("learn_m_bass_title"),
        summary = t("learn_m_bass_summary"),
        lessons = listOf(
            Lesson(id = "bass-1", title = t("learn_l_bass_1_title"), summary = t("learn_l_bass_1_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_bass_1_s1_title"), t("learn_l_bass_1_s1_text"), notes = "F3", staff = Staff.BASS),
                LessonStep(LEARN, t("learn_l_bass_1_s2_title"), t("learn_l_bass_1_s2_text"), notes = "C4", staff = Staff.BASS),
                LessonStep(READ, t("learn_l_bass_1_s3_title"), t("learn_l_bass_1_s3_text"), notes = "F3 C4 F3 F3 C4", staff = Staff.BASS),
            )),
            Lesson(id = "bass-2", title = t("learn_l_bass_2_title"), summary = t("learn_l_bass_2_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_bass_2_s1_title"), t("learn_l_bass_2_s1_text"), notes = "B3", staff = Staff.BASS),
                LessonStep(LEARN, t("learn_l_bass_2_s2_title"), t("learn_l_bass_2_s2_text"), notes = "A3 G3", staff = Staff.BASS),
                LessonStep(READ, t("learn_l_bass_2_s3_title"), t("learn_l_bass_2_s3_text", drill), staff = Staff.BASS, pool = "C4 B3 A3 G3 F3", focus = "B3 A3 G3"),
                LessonStep(READ, t("learn_l_bass_2_s4_title"), t("learn_l_bass_2_s4_text", atYourPace),
                           notes = "B3 A3 G3:h B3 A3 G3:h G3:e G3:e G3:e G3:e A3:e A3:e A3:e A3:e B3 A3 G3:h", staff = Staff.BASS, meter = 4),
            )),
            Lesson(id = "bass-3", title = t("learn_l_bass_3_title"), summary = t("learn_l_bass_3_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_bass_3_s1_title"), t("learn_l_bass_3_s1_text"), notes = "E3", staff = Staff.BASS),
                LessonStep(LEARN, t("learn_l_bass_3_s2_title"), t("learn_l_bass_3_s2_text"), notes = "D3 C3", staff = Staff.BASS),
                LessonStep(READ, t("learn_l_bass_3_s3_title"), t("learn_l_bass_3_s3_text", drill), staff = Staff.BASS, pool = "C4 B3 A3 G3 F3 E3 D3 C3", focus = "E3 D3 C3"),
                LessonStep(READ, t("learn_l_bass_3_s4_title"), t("learn_l_bass_3_s4_text", atYourPace),
                           notes = "E3 E3 F3 G3 G3 F3 E3 D3 C3 C3 D3 E3 E3:q. D3:e D3:h", staff = Staff.BASS, meter = 4),
            )),
            Lesson(id = "bass-4", title = t("learn_l_bass_4_title"), summary = t("learn_l_bass_4_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_bass_4_s1_title"), t("learn_l_bass_4_s1_text"), notes = "C4 B3 A3 G3 F3 E3 D3 C3", staff = Staff.BASS),
                LessonStep(READ, t("learn_l_bass_4_s2_title"), t("learn_l_bass_4_s2_text"), notes = "C4 B3 A3 G3 F3 E3 D3 C3", staff = Staff.BASS),
                LessonStep(READ, t("learn_l_bass_4_s3_title"), t("learn_l_bass_4_s3_text"), notes = "C3 D3 E3 F3 G3 A3 B3 C4", staff = Staff.BASS),
            )),
            Lesson(id = "bass-5", title = t("learn_l_bass_5_title"), summary = t("learn_l_bass_5_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_bass_5_s1_title"), t("learn_l_bass_5_s1_text"), notes = "B2 A2 G2", staff = Staff.BASS),
                LessonStep(LEARN, t("learn_l_bass_5_s2_title"), t("learn_l_bass_5_s2_text"), notes = "F2 E2 D2 C2", staff = Staff.BASS),
                LessonStep(READ, t("learn_l_bass_5_s3_title"), t("learn_l_bass_5_s3_text", drill), staff = Staff.BASS, pool = "C2 D2 E2 F2 G2 A2 B2 C3"),
            )),
            Lesson(id = "bass-6", title = t("learn_l_bass_6_title"), summary = t("learn_l_bass_6_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_bass_6_s1_title"), t("learn_l_bass_6_s1_text", drill), staff = Staff.BASS, pool = "C4 B3 A3 G3 F3 E3 D3 C3"),
                LessonStep(READ, t("learn_l_bass_6_s2_title"), t("learn_l_bass_6_s2_text", drill), staff = Staff.BASS,
                           pool = "C4 B3 A3 G3 F3 E3 D3 C3 B2 A2 G2 F2 E2 D2 C2"),
            )),
        ),
    )

    // ---- As Duas Claves

    private val bothClefs = LessonModule(
        id = "grand",
        title = t("learn_m_grand_title"),
        summary = t("learn_m_grand_summary"),
        lessons = listOf(
            Lesson(id = "grand-1", title = t("learn_l_grand_1_title"), summary = t("learn_l_grand_1_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_grand_1_s1_title"), t("learn_l_grand_1_s1_text"), notes = "C4/t C4/b", grand = true),
                LessonStep(LEARN, t("learn_l_grand_1_s2_title"), t("learn_l_grand_1_s2_text"), notes = "C3 G3 C4 G4 C5", grand = true),
                LessonStep(READ, t("learn_l_grand_1_s3_title"), t("learn_l_grand_1_s3_text"), notes = "C5 G4 C4 G3 C3", grand = true),
            )),
            Lesson(id = "grand-2", title = t("learn_l_grand_2_title"), summary = t("learn_l_grand_2_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_grand_2_s1_title"), t("learn_l_grand_2_s1_text"), notes = "E3 E4 A3 A4 D3 D4 G3 F4", grand = true),
                LessonStep(READ, t("learn_l_grand_2_s2_title"), t("learn_l_grand_2_s2_text", drill), grand = true,
                           pool = "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5"),
            )),
            Lesson(id = "grand-3", title = t("learn_l_grand_3_title"), summary = t("learn_l_grand_3_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_grand_3_s1_title"), t("learn_l_grand_3_s1_text", drill), grand = true,
                           pool = "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5", draw = 16),
            )),
        ),
    )

    // ---- Sustenido e Bemol

    private val accidentals = LessonModule(
        id = "accidentals",
        title = t("learn_m_accidentals_title"),
        summary = t("learn_m_accidentals_summary"),
        lessons = listOf(
            Lesson(id = "acc-1", title = t("learn_l_acc_1_title"), summary = t("learn_l_acc_1_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_acc_1_s1_title"), t("learn_l_acc_1_s1_text"), notes = "F4 F#4"),
                LessonStep(LEARN, t("learn_l_acc_1_s2_title"), t("learn_l_acc_1_s2_text"), notes = "C#4 D#4 F#4 G#4 A#4"),
                LessonStep(READ, t("learn_l_acc_1_s3_title"), t("learn_l_acc_1_s3_text", drill),
                           pool = "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4", focus = "C#4 D#4 F#4 G#4 A#4"),
            )),
            Lesson(id = "acc-2", title = t("learn_l_acc_2_title"), summary = t("learn_l_acc_2_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_acc_2_s1_title"), t("learn_l_acc_2_s1_text"), notes = "B4 Bb4"),
                LessonStep(LEARN, t("learn_l_acc_2_s2_title"), t("learn_l_acc_2_s2_text"), notes = "Db4 Eb4 Gb4 Ab4 Bb4"),
                LessonStep(READ, t("learn_l_acc_2_s3_title"), t("learn_l_acc_2_s3_text", drill),
                           pool = "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4", focus = "Db4 Eb4 Gb4 Ab4 Bb4"),
            )),
            Lesson(id = "acc-3", title = t("learn_l_acc_3_title"), summary = t("learn_l_acc_3_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_acc_3_s1_title"), t("learn_l_acc_3_s1_text"), notes = "C#4 Db4"),
                LessonStep(READ, t("learn_l_acc_3_s2_title"), t("learn_l_acc_3_s2_text"), notes = "C#4 Db4 F#4 Gb4 Eb4 D#4 Bb4 A#4"),
            )),
            Lesson(id = "acc-4", title = t("learn_l_acc_4_title"), summary = t("learn_l_acc_4_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_acc_4_s1_title"), t("learn_l_acc_4_s1_text"), notes = "F#4 F#4"),
                LessonStep(LEARN, t("learn_l_acc_4_s2_title"), t("learn_l_acc_4_s2_text"), notes = "F#4 F#4 F4"),
                LessonStep(READ, t("learn_l_acc_4_s3_title"), t("learn_l_acc_4_s3_text"),
                           notes = "C#4 C#4 C4 D4 C#4 D4 C#4:h", meter = 4),
            )),
            Lesson(id = "acc-5", title = t("learn_l_acc_5_title"), summary = t("learn_l_acc_5_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_acc_5_s1_title"), t("learn_l_acc_5_s1_text", drill), pool = "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4"),
                LessonStep(READ, t("learn_l_acc_5_s2_title"), t("learn_l_acc_5_s2_text", drill), pool = "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4"),
            )),
        ),
    )

    // ---- Ritmo

    private val rhythm = LessonModule(
        id = "rhythm",
        title = t("learn_m_rhythm_title"),
        summary = t("learn_m_rhythm_summary"),
        lessons = listOf(
            Lesson(id = "rhy-1", title = t("learn_l_rhy_1_title"), summary = t("learn_l_rhy_1_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_1_s1_title"), t("learn_l_rhy_1_s1_text"), notes = "C4:q C4:q C4:q C4:q", meter = 4),
                LessonStep(RHYTHM, t("learn_l_rhy_1_s2_title"), t("learn_l_rhy_1_s2_text"), notes = "C4 D4 E4 C4 E4 D4 C4 C4", meter = 4),
            )),
            Lesson(id = "rhy-2", title = t("learn_l_rhy_2_title"), summary = t("learn_l_rhy_2_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_2_s1_title"), t("learn_l_rhy_2_s1_text"), notes = "C4:h D4:h E4:h C4:h", meter = 4),
                LessonStep(RHYTHM, t("learn_l_rhy_2_s2_title"), t("learn_l_rhy_2_s2_text"), notes = "C4:q C4:q D4:h E4:w", meter = 4),
            )),
            Lesson(id = "rhy-3", title = t("learn_l_rhy_3_title"), summary = t("learn_l_rhy_3_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_3_s1_title"), t("learn_l_rhy_3_s1_text"), notes = "C4 D4 E4 F4 G4 F4 E4 D4", meter = 4),
                LessonStep(PLAY_ALONG, t("learn_l_rhy_3_s2_title"), t("learn_l_rhy_3_s2_text"), notes = maryHalf, meter = 4),
            )),
            Lesson(id = "rhy-4", title = t("learn_l_rhy_4_title"), summary = t("learn_l_rhy_4_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_4_s1_title"), t("learn_l_rhy_4_s1_text"), notes = "C4:q R:q D4:q R:q", meter = 4),
                LessonStep(RHYTHM, t("learn_l_rhy_4_s2_title"), t("learn_l_rhy_4_s2_text"), notes = "C4:h R:h E4:q E4:q R:h", meter = 4),
            )),
            Lesson(id = "rhy-5", title = t("learn_l_rhy_5_title"), summary = t("learn_l_rhy_5_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_5_s1_title"), t("learn_l_rhy_5_s1_text"), notes = "C4:e C4:e D4:e D4:e E4:q E4:q", meter = 4, tempo = 60),
                LessonStep(PLAY_ALONG, t("learn_l_rhy_5_s2_title"), t("learn_l_rhy_5_s2_text"), notes = hotCrossBuns, meter = 4, tempo = 66),
            )),
            Lesson(id = "rhy-6", title = t("learn_l_rhy_6_title"), summary = t("learn_l_rhy_6_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_6_s1_title"), t("learn_l_rhy_6_s1_text"), notes = "C4:h. D4:q E4:h. C4:q", meter = 4),
                LessonStep(RHYTHM, t("learn_l_rhy_6_s2_title"), t("learn_l_rhy_6_s2_text"), notes = "C4:q. D4:e E4:h E4:q. D4:e C4:h", meter = 4, tempo = 60),
                LessonStep(PLAY_ALONG, t("learn_l_rhy_6_s3_title"), t("learn_l_rhy_6_s3_text"), notes = odeToJoy, meter = 4),
            )),
            Lesson(id = "rhy-7", title = t("learn_l_rhy_7_title"), summary = t("learn_l_rhy_7_summary"), steps = listOf(
                LessonStep(RHYTHM, t("learn_l_rhy_7_s1_title"), t("learn_l_rhy_7_s1_text"), notes = "C4:q E4:q G4:q C5:h.", meter = 3),
                LessonStep(PLAY_ALONG, t("learn_l_rhy_7_s2_title"), t("learn_l_rhy_7_s2_text"),
                           notes = "D5:q G4:e A4:e B4:e C5:e D5:q G4:q G4:q E5:q C5:e D5:e E5:e F#5:e G5:q G4:q G4:q", meter = 3),
            )),
        ),
    )

    // ---- Tonalidades

    private val keySignatures = LessonModule(
        id = "keys",
        title = t("learn_m_keys_title"),
        summary = t("learn_m_keys_summary"),
        lessons = listOf(
            Lesson(id = "key-1", title = t("learn_l_key_1_title"), summary = t("learn_l_key_1_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_key_1_s1_title"), t("learn_l_key_1_s1_text"), notes = "F#4 F#5", key = 1),
                LessonStep(READ, t("learn_l_key_1_s2_title"), t("learn_l_key_1_s2_text"), notes = "G4 F#4 E4 F#4 G4 A4 F#4 G4", key = 1),
            )),
            Lesson(id = "key-2", title = t("learn_l_key_2_title"), summary = t("learn_l_key_2_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_key_2_s1_title"), t("learn_l_key_2_s1_text"), notes = "G4 A4 B4 C5 D5 E5 F#5 G5", key = 1),
                LessonStep(READ, t("learn_l_key_2_s2_title"), t("learn_l_key_2_s2_text"), notes = "G5 F#5 E5 D5 C5 B4 A4 G4", key = 1),
                LessonStep(READ, t("learn_l_key_2_s3_title"), t("learn_l_key_2_s3_text", drill), key = 1, pool = "F#4 G4 A4 B4 C5 D5 E5 F#5 G5", focus = "F#4 F#5"),
            )),
            Lesson(id = "key-3", title = t("learn_l_key_3_title"), summary = t("learn_l_key_3_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_key_3_s1_title"), t("learn_l_key_3_s1_text"), notes = "F4 G4 A4 Bb4 C5 D5 E5 F5", key = -1),
                LessonStep(READ, t("learn_l_key_3_s2_title"), t("learn_l_key_3_s2_text"), notes = "F5 E5 D5 C5 Bb4 A4 G4 F4", key = -1),
                LessonStep(READ, t("learn_l_key_3_s3_title"), t("learn_l_key_3_s3_text", drill), key = -1, pool = "F4 G4 A4 Bb4 C5 D5 E5 F5", focus = "Bb4"),
            )),
            Lesson(id = "key-4", title = t("learn_l_key_4_title"), summary = t("learn_l_key_4_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_key_4_s1_title"), t("learn_l_key_4_s1_text", drill), key = 1, pool = "G4 A4 B4 C5 D5 E5 F#5 G5"),
                LessonStep(READ, t("learn_l_key_4_s2_title"), t("learn_l_key_4_s2_text", drill), key = -1, pool = "F4 G4 A4 Bb4 C5 D5 E5 F5"),
            )),
        ),
    )

    // ---- Mãos Juntas e Acordes

    private val handsAndChords = LessonModule(
        id = "hands",
        title = t("learn_m_hands_title"),
        summary = t("learn_m_hands_summary"),
        lessons = listOf(
            Lesson(id = "hands-1", title = t("learn_l_hands_1_title"), summary = t("learn_l_hands_1_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_hands_1_s1_title"), t("learn_l_hands_1_s1_text"), notes = "C3+C4 D3+D4 E3+E4", grand = true),
                LessonStep(READ, t("learn_l_hands_1_s2_title"), t("learn_l_hands_1_s2_text"), notes = "E3+E4 C3+C4 D3+D4 C3+C4 E3+E4 D3+D4 C3+C4", grand = true),
            )),
            Lesson(id = "hands-2", title = t("learn_l_hands_2_title"), summary = t("learn_l_hands_2_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_hands_2_s1_title"), t("learn_l_hands_2_s1_text"), notes = "C3+E4 C3+F4 C3+G4 C3+E4", grand = true),
                LessonStep(READ, t("learn_l_hands_2_s2_title"), t("learn_l_hands_2_s2_text"), notes = "C3+E4 G3+D4 C3+C4 G3+D4 C3+E4", grand = true),
            )),
            Lesson(id = "chord-1", title = t("learn_l_chord_1_title"), summary = t("learn_l_chord_1_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_chord_1_s1_title"), t("learn_l_chord_1_s1_text"), notes = "C4+E4+G4"),
                LessonStep(READ, t("learn_l_chord_1_s2_title"), t("learn_l_chord_1_s2_text"), notes = "C4+E4+G4 C4+E4+G4 C4+E4+G4"),
            )),
            Lesson(id = "chord-2", title = t("learn_l_chord_2_title"), summary = t("learn_l_chord_2_summary"), steps = listOf(
                LessonStep(LEARN, t("learn_l_chord_2_s1_title"), t("learn_l_chord_2_s1_text"), notes = "F4+A4+C5 G4+B4+D5"),
                LessonStep(READ, t("learn_l_chord_2_s2_title"), t("learn_l_chord_2_s2_text"), notes = "G4+B4+D5 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
            )),
            Lesson(id = "chord-3", title = t("learn_l_chord_3_title"), summary = t("learn_l_chord_3_summary"), steps = listOf(
                LessonStep(READ, t("learn_l_chord_3_s1_title"), t("learn_l_chord_3_s1_text"), notes = "C4+E4+G4 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
                LessonStep(RHYTHM, t("learn_l_chord_3_s2_title"), t("learn_l_chord_3_s2_text"), notes = "C4+E4+G4:w F4+A4+C5:w G4+B4+D5:w C4+E4+G4:w", meter = 4, tempo = 80),
            )),
        ),
    )

    // ---- Primeiras Músicas

    /// Reads the whole song at one's own pace, then plays it in time along with the app.
    private fun song(id: String, title: LessonText, summary: LessonText, intro: String, phrases: List<String>, tempo: Int = 72): Lesson {
        val melody = phrases.joinToString(" ")
        return Lesson(id = id, title = title, summary = summary, steps = listOf(
            LessonStep(READ, t("learn_c_read_song"), t(intro, atYourPace), notes = melody, meter = 4, tempo = tempo),
            LessonStep(PLAY_ALONG, t("learn_c_play_along"), t("learn_c_play_along_text"), notes = melody, meter = 4, tempo = tempo),
        ))
    }

    private val songs = LessonModule(
        id = "songs",
        title = t("learn_m_songs_title"),
        summary = t("learn_m_songs_summary"),
        lessons = listOf(
            song(id = "song-1", title = t("learn_l_song_1_title"), summary = t("learn_l_song_1_summary"),
                 intro = ("learn_l_song_1_intro"),
                 phrases = listOf(
                     "C4 C4 G4 G4 A4 A4 G4:h",
                     "F4 F4 E4 E4 D4 D4 C4:h",
                     "G4 G4 F4 F4 E4 E4 D4:h",
                     "G4 G4 F4 F4 E4 E4 D4:h",
                     "C4 C4 G4 G4 A4 A4 G4:h",
                     "F4 F4 E4 E4 D4 D4 C4:h",
                 )),
            song(id = "song-2", title = LessonText.verbatim("Mary Had a Little Lamb"), summary = t("learn_l_song_2_summary"),
                 intro = ("learn_l_song_2_intro"),
                 phrases = listOf(
                     "E4 D4 C4 D4 E4 E4 E4:h",
                     "D4 D4 D4:h E4 G4 G4:h",
                     "E4 D4 C4 D4 E4 E4 E4 E4",
                     "D4 D4 E4 D4 C4:w",
                 )),
            song(id = "song-3", title = LessonText.verbatim("Frère Jacques"), summary = t("learn_l_song_3_summary"),
                 intro = ("learn_l_song_3_intro"),
                 phrases = listOf(
                     "C4 D4 E4 C4 C4 D4 E4 C4",
                     "E4 F4 G4:h E4 F4 G4:h",
                     "G4:e A4:e G4:e F4:e E4 C4",
                     "G4:e A4:e G4:e F4:e E4 C4",
                     "C4 G3 C4:h C4 G3 C4:h",
                 )),
            song(id = "song-4", title = t("learn_l_song_4_title"), summary = t("learn_l_song_4_summary"),
                 intro = ("learn_l_song_4_intro"),
                 phrases = listOf(
                     "E4 E4 F4 G4 G4 F4 E4 D4",
                     "C4 C4 D4 E4 E4:q. D4:e D4:h",
                     "E4 E4 F4 G4 G4 F4 E4 D4",
                     "C4 C4 D4 E4 D4:q. C4:e C4:h",
                 )),
        ),
    )

    // ---- Ouvido

    private val ear = LessonModule(
        id = "ear",
        title = t("learn_m_ear_title"),
        summary = t("learn_m_ear_summary"),
        lessons = listOf(
            Lesson(id = "ear-1", title = t("learn_l_ear_1_title"), summary = t("learn_l_ear_1_summary"), steps = listOf(
                LessonStep(LISTEN, t("learn_l_ear_1_s1_title"), t("learn_l_ear_1_s1_text"), pool = "C4 E4 G4", draw = 3),
                LessonStep(LISTEN, t("learn_l_ear_1_s2_title"), t("learn_l_ear_1_s2_text"), pool = "C4 E4 G4", draw = 4),
            )),
            Lesson(id = "ear-2", title = t("learn_l_ear_2_title"), summary = t("learn_l_ear_2_summary"), steps = listOf(
                LessonStep(LISTEN, t("learn_l_ear_2_s1_title"), t("learn_l_ear_2_s1_text"), pool = "C4 D4 E4 F4 G4", draw = 3),
                LessonStep(LISTEN, t("learn_l_ear_2_s2_title"), t("learn_l_ear_2_s2_text"), pool = "C4 D4 E4 F4 G4", draw = 4),
            )),
        ),
    )

    // Declared after the modules: an object's properties are made in order
    val modules: List<LessonModule> = listOf(
        trebleClef, bassClef, bothClefs, accidentals, rhythm, keySignatures, handsAndChords, songs, ear,
    )

    val allLessons: List<Lesson> = modules.flatMap { it.lessons }

    fun lesson(id: String): Lesson? = allLessons.firstOrNull { it.id == id }

    fun lesson(after: Lesson): Lesson? {
        val index = allLessons.indexOfFirst { it.id == after.id }
        return if (index >= 0 && index + 1 < allLessons.size) allLessons[index + 1] else null
    }

    /** The notes of a lesson's whole module, so the keyboard moves as little as possible between its lessons. */
    fun keyboardNotes(lesson: Lesson): IntRange? {
        val lessons = modules.firstOrNull { m -> m.lessons.any { it.id == lesson.id } }?.lessons ?: listOf(lesson)
        val ranges = lessons.mapNotNull { it.midiRange }
        val low = ranges.minOfOrNull { it.first } ?: return null
        return low..ranges.maxOf { it.last }
    }
}
