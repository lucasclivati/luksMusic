package com.lukstrike.luksmusic.feature.player

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import com.lukstrike.luksmusic.ui.navigation.PlayerRoute

/** The score player (engraved score, playback, keyboard, settings). */
fun NavGraphBuilder.playerGraph(navController: NavHostController) {
    composable<PlayerRoute> { entry ->
        ScoreScreen(scoreId = entry.toRoute<PlayerRoute>().scoreId, navController = navController)
    }
}
