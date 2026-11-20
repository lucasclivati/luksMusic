// AccountGraph.kt — the Progresso and Ajustes tabs. The login screen (LoginScreen.kt) is shown by the app's root
// before anyone signs in, outside the navigation graph.
package com.lukstrike.luksmusic.feature.account

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import com.lukstrike.luksmusic.ui.navigation.ProgressRoute
import com.lukstrike.luksmusic.ui.navigation.SettingsRoute

/** Progresso and Ajustes tabs. */
fun NavGraphBuilder.accountGraph(@Suppress("UNUSED_PARAMETER") navController: NavHostController) {
    composable<ProgressRoute> { PracticeHistoryScreen() }
    composable<SettingsRoute> { SettingsScreen() }
}
