package com.lukstrike.luksmusic.feature.tuner

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import com.lukstrike.luksmusic.ui.navigation.TunerRoute

/** Afinador tab (guitar and piano). */
@Suppress("UNUSED_PARAMETER")
fun NavGraphBuilder.tunerGraph(navController: NavHostController) {
    composable<TunerRoute> { TunerScreen() }
}
