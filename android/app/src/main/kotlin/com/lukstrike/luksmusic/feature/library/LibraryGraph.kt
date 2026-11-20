package com.lukstrike.luksmusic.feature.library

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import com.lukstrike.luksmusic.feature.library.editor.EditorScreen
import com.lukstrike.luksmusic.ui.navigation.EditorRoute
import com.lukstrike.luksmusic.ui.navigation.LibraryRoute
import com.lukstrike.luksmusic.ui.navigation.OnlineLibraryRoute
import com.lukstrike.luksmusic.ui.navigation.PlayerRoute
import kotlinx.serialization.Serializable

/** A catalog score being downloaded before it opens in the player (iOS OnlineScoreView); used only here. */
@Serializable
data class OnlineScoreRoute(val catalogId: String)

/** Tocar tab: the library, the online catalog, the editor. */
fun NavGraphBuilder.libraryGraph(navController: NavHostController) {
    composable<LibraryRoute> {
        LibraryScreen(
            onOpenScore = { navController.navigate(PlayerRoute(it)) },
            onEditScore = { navController.navigate(EditorRoute(it)) },
            onOpenCatalog = { navController.navigate(OnlineLibraryRoute) },
        )
    }
    composable<OnlineLibraryRoute> {
        OnlineLibraryScreen(
            onBack = { navController.popBackStack() },
            onOpen = { navController.navigate(OnlineScoreRoute(it.id)) },
        )
    }
    composable<OnlineScoreRoute> { entry ->
        val route = entry.toRoute<OnlineScoreRoute>()
        OnlineScoreScreen(
            catalogId = route.catalogId,
            onBack = { navController.popBackStack() },
            // The player takes this screen's place, so Back returns to the catalog list
            onReady = { scoreId ->
                navController.navigate(PlayerRoute(scoreId)) {
                    popUpTo<OnlineScoreRoute> { inclusive = true }
                }
            },
        )
    }
    composable<EditorRoute> { entry ->
        val route = entry.toRoute<EditorRoute>()
        EditorScreen(scoreId = route.scoreId, onClose = { navController.popBackStack() })
    }
}
