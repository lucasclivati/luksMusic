// PracticeTally.kt — the counts of a Modo Estudo session: notes played, right and wrong, and the streak of right ones
// (the accuracy-tracking properties of ViewModels/PracticeViewModel.swift).
package com.lukstrike.luksmusic.core.practice

data class PracticeTally(
    val totalNotesPlayed: Int = 0,
    val correctNotes: Int = 0,
    val incorrectNotes: Int = 0,
    /** Never counted yet, as on iOS (kept for the session record). */
    val missedNotes: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
) {
    /** Percent 0..100 of the notes played (0 when none). */
    val accuracy: Double
        get() = if (totalNotesPlayed <= 0) 0.0 else correctNotes * 100.0 / totalNotesPlayed

    /** One more note played: a right one adds to the streak, a wrong one ends it. */
    fun recording(correct: Boolean): PracticeTally = if (correct) {
        val streak = currentStreak + 1
        copy(
            totalNotesPlayed = totalNotesPlayed + 1,
            correctNotes = correctNotes + 1,
            currentStreak = streak,
            longestStreak = maxOf(longestStreak, streak),
        )
    } else {
        copy(totalNotesPlayed = totalNotesPlayed + 1, incorrectNotes = incorrectNotes + 1, currentStreak = 0)
    }
}
