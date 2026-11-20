// ScoreScreen.kt — port of Views/Score/ScoreView.swift. Sheet music viewer for the scores saved on the device: the
// engraving by OpenSheetMusicDisplay (ScoreWebView) on a sheet of paper in the player frame, with a cursor that
// steps note by note, the dock below it (timeline, transport, notes under the cursor, keyboard) and the score's
// actions in the title bar's menu. Full screen: the system bars hide while the piece plays.
package com.lukstrike.luksmusic.feature.player

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.systemBarsIgnoringVisibility
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.FileUpload
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.ZoomIn
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.ClefChoice
import com.lukstrike.luksmusic.ui.navigation.EditorRoute
import com.lukstrike.luksmusic.ui.navigation.PracticeRoute
import com.lukstrike.luksmusic.ui.navigation.ReadingDrillScoreRoute
import com.lukstrike.luksmusic.ui.usesLetterNames
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ScoreScreen(scoreId: String, navController: NavHostController) {
    val container = appContainer()
    val viewModel: ScoreViewModel = viewModel(key = "player-$scoreId") { ScoreViewModel(container, scoreId) }

    val score by viewModel.score.collectAsStateWithLifecycle()
    val found by viewModel.found.collectAsStateWithLifecycle()
    val musicXml by viewModel.musicXml.collectAsStateWithLifecycle()
    val display by viewModel.display.collectAsStateWithLifecycle()
    val position by viewModel.position.collectAsStateWithLifecycle()
    val elapsed by viewModel.elapsedSeconds.collectAsStateWithLifecycle()
    val cursorNotes by viewModel.cursorNotes.collectAsStateWithLifecycle()
    val isPlaying by viewModel.isPlaying.collectAsStateWithLifecycle()
    val speed by viewModel.playbackSpeed.collectAsStateWithLifecycle()
    val transposition by viewModel.transposition.collectAsStateWithLifecycle()
    val mixer by viewModel.mixer.collectAsStateWithLifecycle()
    val loopMode by viewModel.loopMode.collectAsStateWithLifecycle()
    val metronomeOn by viewModel.isMetronomeOn.collectAsStateWithLifecycle()

    var showMixer by rememberSaveable { mutableStateOf(false) }
    var showSettings by rememberSaveable { mutableStateOf(false) }

    val letters = usesLetterNames()
    LaunchedEffect(letters) { viewModel.setUsesLetterNames(letters) }

    // The reverb belongs to the audio engine the whole app shares, so the remembered choice is set again on opening
    val concertHall = display?.concertHall
    LaunchedEffect(concertHall) {
        if (concertHall != null) container.audio.reverb = if (concertHall) 0.25f else 0f
    }

    // The music stops when the screen is covered (Modo Estudo, the editor) or the app goes to the background
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) { viewModel.pause() }

    // Deleted meanwhile: nothing to show
    LaunchedEffect(found) { if (!found) navController.popBackStack() }

    ImmersiveWhilePlaying(isPlaying)

    val close = {
        viewModel.stop()
        navController.popBackStack()
        Unit
    }

    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/vnd.recordare.musicxml+xml"),
    ) { uri ->
        val xml = viewModel.musicXml.value
        if (uri != null && xml != null) {
            scope.launch {
                withContext(Dispatchers.IO) {
                    runCatching { context.contentResolver.openOutputStream(uri)?.use { it.write(xml.toByteArray()) } }
                }
            }
        }
    }

    val dockActions = remember(viewModel) {
        object : DockActions {
            override fun togglePlayback() = viewModel.togglePlayback()
            override fun restart() = viewModel.restart()
            override fun stepBackward() = viewModel.stepBackward()
            override fun stepForward() = viewModel.stepForward()
            override fun seekToMeasure(index: Int) = viewModel.seek(index, 1.0)
            override fun setSpeed(speed: Double) = viewModel.setPlaybackSpeed(speed)
            override fun cycleLoopMode() = viewModel.cycleLoopMode()
            override fun toggleMetronome() = viewModel.toggleMetronome()
            override fun openMixer() { showMixer = true }
            override fun toggleKeyboard() {
                val show = !(viewModel.display.value?.showKeyboard ?: true)
                viewModel.updateSettings { setShowKeyboard(show) }
            }
            override fun pressKey(midi: Int) = container.audio.playNote(midi, velocity = 90)
            override fun releaseKey(midi: Int) = container.audio.stopNote(midi)
        }
    }

    val subtitle = score?.let { s ->
        listOfNotNull(
            s.composer.takeIf { it.isNotEmpty() },
            "${s.tempo} BPM",
            pluralStringResource(R.plurals.player_measures, s.measureCount, s.measureCount),
        ).joinToString(" • ")
    }.orEmpty()

    // The panels reach the screen's edges; their content stays clear of the bars and the camera cutout. The space
    // stays the same while the bars hide, so the engraving is not reflowed (the page re-renders on every resize).
    val safe = WindowInsets.systemBarsIgnoringVisibility.union(WindowInsets.displayCutout)
    val compactHeight = LocalConfiguration.current.screenHeightDp < 480

    Box(Modifier.fillMaxSize().background(PlayerTheme.background)) {
        Column(Modifier.fillMaxSize()) {
            PlayerTopBar(
                title = score?.title.orEmpty(),
                subtitle = subtitle,
                onBack = close,
                insets = safe.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal),
            ) {
                val favorite = score?.isFavorite == true
                PlayerIconButton(
                    if (favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                    stringResource(if (favorite) R.string.player_remove_favorite else R.string.player_add_favorite),
                    onClick = viewModel::toggleFavorite,
                    tint = if (favorite) PlayerTheme.favorite else PlayerTheme.text,
                )
                ScoreMenu(
                    display = display ?: PlayerDisplay(),
                    canEdit = score?.isSample == false,
                    onPractice = {
                        viewModel.pause()
                        navController.navigate(PracticeRoute(scoreId))
                    },
                    onReadingDrill = {
                        viewModel.pause()
                        navController.navigate(ReadingDrillScoreRoute(scoreId))
                    },
                    onMixer = { showMixer = true },
                    onSettings = { showSettings = true },
                    onZoom = { zoom -> viewModel.updateSettings { setZoom(zoom) } },
                    onRightClef = { choice -> viewModel.updateSettings { setRightClef(choice) } },
                    onLeftClef = { choice -> viewModel.updateSettings { setLeftClef(choice) } },
                    onEdit = {
                        viewModel.pause()
                        navController.navigate(EditorRoute(scoreId))
                    },
                    onExport = { exportLauncher.launch("${score?.title?.ifBlank { null } ?: "score"}.musicxml") },
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .windowInsetsPadding(safe.only(WindowInsetsSides.Horizontal)),
                contentAlignment = Alignment.Center,
            ) {
                val xml = musicXml
                val settings = display
                if (xml != null && settings != null && score != null) {
                    ScoreWebView(
                        musicXml = xml,
                        measureIndex = position.measure,
                        cursorBeat = cursorNotes.cursorBeat,
                        modifier = Modifier.fillMaxSize(),
                        title = score?.title.orEmpty(),
                        composer = score?.composer.orEmpty(),
                        zoom = settings.renderZoom,
                        transposition = transposition,
                        rightClef = settings.rightClef,
                        leftClef = settings.leftClef,
                        automaticUsesAlto = settings.automaticUsesAlto,
                        horizontal = settings.mode == ScoreDisplayMode.SINGLE_LINE,
                        isDark = true,
                        topInset = 0.dp,
                        bottomInset = 16.dp,
                        onSeek = viewModel::seek,
                    )
                } else {
                    CircularProgressIndicator(color = PlayerTheme.cyan)
                }
            }

            PlayerDock(
                state = DockState(
                    isPlaying = isPlaying,
                    measureIndex = position.measure,
                    measureCount = score?.measureCount ?: 0,
                    elapsedSeconds = elapsed,
                    totalSeconds = viewModel.totalSeconds,
                    speed = speed,
                    loopMode = loopMode,
                    isMetronomeOn = metronomeOn,
                    cursorNotes = cursorNotes,
                    showKeyboard = display?.showKeyboard ?: true,
                ),
                actions = dockActions,
                metronomeClicks = viewModel.metronomeClicks,
                insets = safe.only(WindowInsetsSides.Bottom + WindowInsetsSides.Horizontal),
                keyboardHeight = if (compactHeight) 64.dp else 100.dp,
            )
        }
    }

    if (showMixer) {
        HandsMixerSheet(mixer = mixer, onChange = viewModel::setMixer, onDismiss = { showMixer = false })
    }

    val settings = display
    if (showSettings && settings != null) {
        ScoreSettingsSheet(
            display = settings,
            transposition = transposition,
            transpositionKeyText = viewModel.transpositionKeyText,
            actions = remember(viewModel) {
                object : ScoreSettingsActions {
                    override fun setMode(mode: ScoreDisplayMode) = viewModel.updateSettings { setMode(mode) }
                    override fun setRightClef(choice: ClefChoice) = viewModel.updateSettings { setRightClef(choice) }
                    override fun setLeftClef(choice: ClefChoice) = viewModel.updateSettings { setLeftClef(choice) }
                    override fun setAutomaticUsesAlto(on: Boolean) = viewModel.updateSettings { setAutomaticUsesAlto(on) }
                    override fun setConcertHall(on: Boolean) = viewModel.updateSettings { setConcertHall(on) }
                    override fun setShowKeyboard(show: Boolean) = viewModel.updateSettings { setShowKeyboard(show) }
                    override fun setTransposition(semitones: Int) = viewModel.setTransposition(semitones)
                }
            },
            onDismiss = { showSettings = false },
        )
    }
}

/** Hides the status and navigation bars while the piece plays (a swipe from the edge shows them for a moment) and
 *  keeps the screen on; everything comes back on pause or when the screen leaves. */
@Composable
private fun ImmersiveWhilePlaying(isPlaying: Boolean) {
    val view = LocalView.current
    DisposableEffect(isPlaying) {
        val window = view.context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (isPlaying) controller?.hide(WindowInsetsCompat.Type.systemBars())
        else controller?.show(WindowInsetsCompat.Type.systemBars())
        view.keepScreenOn = isPlaying
        onDispose {
            controller?.show(WindowInsetsCompat.Type.systemBars())
            view.keepScreenOn = false
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

// MARK: - Menu

private enum class MenuPage { MAIN, ZOOM, RIGHT_CLEF, LEFT_CLEF }

/** The title bar's "…" menu. Zoom and each hand's clef open their choices in place (iOS's inline pickers). */
@Composable
private fun ScoreMenu(
    display: PlayerDisplay,
    /** False for the bundled sample pieces, which are not editable. */
    canEdit: Boolean,
    onPractice: () -> Unit,
    onReadingDrill: () -> Unit,
    onMixer: () -> Unit,
    onSettings: () -> Unit,
    onZoom: (Double) -> Unit,
    onRightClef: (ClefChoice) -> Unit,
    onLeftClef: (ClefChoice) -> Unit,
    onEdit: () -> Unit,
    onExport: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var page by remember { mutableStateOf(MenuPage.MAIN) }
    fun dismiss() {
        expanded = false
        page = MenuPage.MAIN
    }

    Box {
        PlayerIconButton(Icons.Rounded.MoreHoriz, stringResource(R.string.player_options), onClick = { expanded = true })
        DropdownMenu(expanded = expanded, onDismissRequest = ::dismiss) {
            when (page) {
                MenuPage.MAIN -> {
                    MenuItem(Icons.Rounded.School, stringResource(R.string.player_practice_mode)) { dismiss(); onPractice() }
                    MenuItem(Icons.Rounded.MusicNote, stringResource(R.string.player_reading_drill)) { dismiss(); onReadingDrill() }
                    MenuItem(Icons.Rounded.Tune, stringResource(R.string.player_mixer)) { dismiss(); onMixer() }
                    MenuItem(Icons.Rounded.Settings, stringResource(R.string.player_settings)) { dismiss(); onSettings() }
                    HorizontalDivider()
                    MenuItem(Icons.Rounded.ZoomIn, stringResource(R.string.player_zoom), detail = "${(display.zoom * 100).toInt()}%", submenu = true) {
                        page = MenuPage.ZOOM
                    }
                    MenuItem(Icons.Rounded.MusicNote, stringResource(R.string.player_right_hand), detail = clefChoiceFullName(display.rightClef), submenu = true) {
                        page = MenuPage.RIGHT_CLEF
                    }
                    MenuItem(Icons.Rounded.MusicNote, stringResource(R.string.player_left_hand), detail = clefChoiceFullName(display.leftClef), submenu = true) {
                        page = MenuPage.LEFT_CLEF
                    }
                    HorizontalDivider()
                    if (canEdit) MenuItem(Icons.Rounded.Edit, stringResource(R.string.player_edit)) { dismiss(); onEdit() }
                    MenuItem(Icons.Rounded.FileUpload, stringResource(R.string.player_export)) { dismiss(); onExport() }
                }
                MenuPage.ZOOM -> PlayerSettings.zoomLevels.forEach { level ->
                    ChoiceItem("${(level * 100).toInt()}%", selected = level == display.zoom) { dismiss(); onZoom(level) }
                }
                MenuPage.RIGHT_CLEF, MenuPage.LEFT_CLEF -> {
                    val right = page == MenuPage.RIGHT_CLEF
                    Text(
                        stringResource(if (right) R.string.player_right_hand else R.string.player_left_hand),
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 4.dp),
                    )
                    val current = if (right) display.rightClef else display.leftClef
                    ClefChoice.entries.forEach { choice ->
                        ChoiceItem(clefChoiceFullName(choice), selected = choice == current) {
                            dismiss()
                            if (right) onRightClef(choice) else onLeftClef(choice)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MenuItem(icon: ImageVector, title: String, detail: String? = null, submenu: Boolean = false, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(title) },
        leadingIcon = { Icon(icon, contentDescription = null) },
        trailingIcon = if (detail != null || submenu) {
            {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (detail != null) Text(detail, color = PlayerTheme.muted)
                    if (submenu) Icon(Icons.Rounded.ChevronRight, contentDescription = null)
                }
            }
        } else null,
        onClick = onClick,
    )
}

@Composable
private fun ChoiceItem(title: String, selected: Boolean, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(title, fontWeight = if (selected) FontWeight.SemiBold else null) },
        trailingIcon = if (selected) {
            { Icon(Icons.Rounded.Check, contentDescription = null) }
        } else null,
        onClick = onClick,
    )
}
