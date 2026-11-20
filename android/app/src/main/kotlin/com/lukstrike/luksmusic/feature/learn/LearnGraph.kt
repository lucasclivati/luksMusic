// LearnGraph.kt — the Aprender tab's screens: the lesson list, a lesson, and the reading drill (a score picker,
// then the drill for one score, which can switch to Modo Estudo).
package com.lukstrike.luksmusic.feature.learn

import androidx.lifecycle.Lifecycle
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import com.lukstrike.luksmusic.ui.navigation.LearnRoute
import com.lukstrike.luksmusic.ui.navigation.LessonRoute
import com.lukstrike.luksmusic.ui.navigation.PracticeRoute
import com.lukstrike.luksmusic.ui.navigation.ReadingDrillRoute
import com.lukstrike.luksmusic.ui.navigation.ReadingDrillScoreRoute

fun NavGraphBuilder.learnGraph(navController: NavHostController) {
    composable<LearnRoute> {
        LearnHomeScreen(
            onOpenLesson = { navController.navigate(LessonRoute(it)) },
            onOpenReadingDrill = { navController.navigate(ReadingDrillRoute) },
        )
    }
    composable<LessonRoute> { entry ->
        LessonPlayerScreen(entry.toRoute<LessonRoute>().lessonId, onBack = { navController.popBackStack() })
    }
    composable<ReadingDrillRoute> {
        ReadingScorePickerScreen(
            onBack = { navController.popBackStack() },
            onPick = { navController.navigate(ReadingDrillScoreRoute(it)) },
        )
    }
    composable<ReadingDrillScoreRoute> { entry ->
        val scoreId = entry.toRoute<ReadingDrillScoreRoute>().scoreId
        ReadingTrainerScreen(
            scoreId = scoreId,
            onBack = { navController.popBackStack() },
            // Modo Estudo takes this screen's place, so back returns to where the drill was opened from
            onOpenPracticeMode = {
                if (entry.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                    navController.navigate(PracticeRoute(scoreId)) { popUpTo<ReadingDrillScoreRoute> { inclusive = true } }
                }
            },
        )
    }
}
