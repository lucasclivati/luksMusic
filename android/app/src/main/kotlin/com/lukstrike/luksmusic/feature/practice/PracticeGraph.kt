package com.lukstrike.luksmusic.feature.practice

import androidx.lifecycle.Lifecycle
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import com.lukstrike.luksmusic.ui.navigation.PracticeRoute

/** Modo Estudo: falling notes, piano keyboard, feedback, session stats. */
fun NavGraphBuilder.practiceGraph(navController: NavHostController) {
    composable<PracticeRoute> { entry ->
        PracticeScreen(
            route = entry.toRoute<PracticeRoute>(),
            onClose = {
                // Once, even if "Done" and back come together
                if (entry.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) navController.popBackStack()
            },
        )
    }
}
