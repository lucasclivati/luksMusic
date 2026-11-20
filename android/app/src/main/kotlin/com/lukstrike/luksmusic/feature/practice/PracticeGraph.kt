package com.lukstrike.luksmusic.feature.practice

import androidx.lifecycle.Lifecycle
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import com.lukstrike.luksmusic.ui.navigation.PracticeRoute
import com.lukstrike.luksmusic.ui.navigation.ReadingDrillScoreRoute

/** Modo Estudo: falling notes, piano keyboard, feedback, session stats. */
fun NavGraphBuilder.practiceGraph(navController: NavHostController) {
    composable<PracticeRoute> { entry ->
        val route = entry.toRoute<PracticeRoute>()
        PracticeScreen(
            route = route,
            onClose = {
                // Once, even if "Done" and back come together
                if (entry.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) navController.popBackStack()
            },
            // The reading drill takes this screen's place, so back returns to where Modo Estudo was opened from
            onOpenReadingDrill = {
                if (entry.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                    navController.navigate(ReadingDrillScoreRoute(route.scoreId)) { popUpTo<PracticeRoute> { inclusive = true } }
                }
            },
        )
    }
}
