// LuksMusicNavHost.kt — the app's root (iOS App/ContentView.swift): the login screen until someone signs in, then
// the five tabs. The tab bar hides on full-screen pages (score player, practice, lesson).
package com.lukstrike.luksmusic.ui.navigation

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Piano
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.lukstrike.luksmusic.MainActivity
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.feature.account.LoginScreen
import com.lukstrike.luksmusic.feature.account.accountGraph
import com.lukstrike.luksmusic.feature.learn.learnGraph
import com.lukstrike.luksmusic.feature.library.SampleSeeder
import com.lukstrike.luksmusic.feature.library.libraryGraph
import com.lukstrike.luksmusic.feature.player.playerGraph
import com.lukstrike.luksmusic.feature.practice.practiceGraph
import com.lukstrike.luksmusic.feature.tuner.tunerGraph
import kotlin.reflect.KClass

private data class Tab(val route: Any, val routeClass: KClass<*>, @StringRes val label: Int, val icon: ImageVector)

private val tabs = listOf(
    Tab(LearnRoute, LearnRoute::class, R.string.tab_learn, Icons.Outlined.School),
    Tab(LibraryRoute, LibraryRoute::class, R.string.tab_play, Icons.Outlined.Piano),
    Tab(TunerRoute, TunerRoute::class, R.string.tab_tuner, Icons.Outlined.Tune),
    Tab(ProgressRoute, ProgressRoute::class, R.string.tab_progress, Icons.Outlined.BarChart),
    Tab(SettingsRoute, SettingsRoute::class, R.string.tab_settings, Icons.Outlined.Settings),
)

@Composable
fun LuksMusicRoot() {
    val container = appContainer()
    val user by container.auth.currentUser.collectAsStateWithLifecycle()
    val restored by container.auth.isRestored.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        container.audio.start()
        container.midi.startListening()
        SampleSeeder(container).seedIfNeeded()
    }

    when {
        !restored -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        user == null -> LoginScreen()
        else -> MainTabs()
    }
}

@Composable
private fun MainTabs() {
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val destination = backStack?.destination
    val onTab = tabs.any { tab -> destination?.hasRoute(tab.routeClass) == true }

    // A MusicXML file opened from another app: the library (Tocar) imports it
    val incoming by MainActivity.incomingFile.collectAsStateWithLifecycle()
    LaunchedEffect(incoming) {
        if (incoming != null) navController.navigate(LibraryRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    Scaffold(
        bottomBar = {
            if (onTab) {
                NavigationBar {
                    tabs.forEach { tab ->
                        val selected = destination?.hierarchy?.any { it.hasRoute(tab.routeClass) } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = null) },
                            label = { Text(stringResource(tab.label)) },
                        )
                    }
                }
            }
        },
    ) { padding ->
        // Full-screen pages draw edge to edge; tab pages stay above the tab bar
        NavHost(
            navController = navController,
            startDestination = LearnRoute,
            modifier = if (onTab) Modifier.padding(bottom = padding.calculateBottomPadding()) else Modifier,
        ) {
            learnGraph(navController)
            libraryGraph(navController)
            playerGraph(navController)
            practiceGraph(navController)
            tunerGraph(navController)
            accountGraph(navController)
        }
    }
}
