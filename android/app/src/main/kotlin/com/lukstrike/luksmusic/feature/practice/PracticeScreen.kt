// PracticeScreen.kt — Modo Estudo (port of Views/Practice/PracticeView.swift): the engraved score on one line with
// its cursor on the notes to play, the falling notes in beat colors, the piano keyboard lighting up, and the practice
// controls (play, stop, microphone, metronome, tempo).
package com.lukstrike.luksmusic.feature.practice

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Headphones
import androidx.compose.material.icons.outlined.MicOff
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.ClefChoice
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.practice.PracticeEngine
import com.lukstrike.luksmusic.feature.player.ScoreWebView
import com.lukstrike.luksmusic.ui.components.KeyLabelStyle
import com.lukstrike.luksmusic.ui.components.PianoKeyboard
import com.lukstrike.luksmusic.ui.navigation.PracticeRoute
import com.lukstrike.luksmusic.ui.theme.LuksColors
import com.lukstrike.luksmusic.ui.usesLetterNames
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** The score player's metronome light colors (iOS PlayerTheme.downbeat / beat). */
private val downbeatLight = Color(239 / 255f, 68 / 255f, 68 / 255f)
private val beatLight = Color(234 / 255f, 179 / 255f, 8 / 255f)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PracticeScreen(route: PracticeRoute, onClose: () -> Unit) {
    val container = appContainer()
    val context = LocalContext.current
    val viewModel: PracticeViewModel = viewModel(
        factory = PracticeViewModel.factory(container, context, route.scoreId, practiceModeFromRoute(route.mode)),
    )
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    // Each hand's clef from the score player's settings
    val rightClef by remember { clefFlow(container.settings, ClefChoice.RIGHT_HAND_KEY) }.collectAsStateWithLifecycle(ClefChoice.SCORE)
    val leftClef by remember { clefFlow(container.settings, ClefChoice.LEFT_HAND_KEY) }.collectAsStateWithLifecycle(ClefChoice.SCORE)
    val automaticUsesAlto by remember {
        container.settings.flow(booleanPreferencesKey(ClefChoice.AUTOMATIC_USES_ALTO_KEY), true).catch { emit(true) }
    }.collectAsStateWithLifecycle(true)

    // Key names in the app's language: letters in English, solfège in Portuguese
    val usesLetters = usesLetterNames()
    LaunchedEffect(usesLetters) {
        viewModel.keyboard.labelStyle = if (usesLetters) KeyLabelStyle.LETTER else KeyLabelStyle.SOLFEGE
    }

    // The microphone, the metronome and the practice clock only while the screen shows
    LifecycleStartEffect(viewModel) {
        viewModel.onScreenStarted()
        onStopOrDispose { viewModel.onScreenStopped() }
    }

    LaunchedEffect(ui.isMissing) { if (ui.isMissing) onClose() }

    // "Done", or back: the session is saved (iOS saves on "Concluir")
    val finish = {
        viewModel.stopPractice(showSummary = false)
        onClose()
    }
    BackHandler(onBack = finish)

    // The microphone permission is asked only when the student turns it on
    val micNeeded = stringResource(R.string.practice_mic_needed)
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.setMicrophone(true) else scope.launch { snackbar.showSnackbar(micNeeded) }
    }
    val toggleMicrophone = {
        when {
            ui.isMicrophoneEnabled -> viewModel.setMicrophone(false)
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED ->
                viewModel.setMicrophone(true)
            else -> permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.practice_title)) },
                navigationIcon = { TextButton(onClick = finish) { Text(stringResource(R.string.practice_done)) } },
                actions = {
                    IconButton(onClick = toggleMicrophone) {
                        Icon(
                            if (ui.isMicrophoneEnabled) Icons.Filled.Mic else Icons.Outlined.MicOff,
                            contentDescription = stringResource(
                                if (ui.isMicrophoneEnabled) R.string.practice_mic_turn_off else R.string.practice_mic_turn_on,
                            ),
                            tint = if (ui.isMicrophoneEnabled) LuksColors.success else MaterialTheme.colorScheme.onSurface,
                        )
                    }
                    ModeMenu(
                        mode = ui.mode,
                        isMicrophoneEnabled = ui.isMicrophoneEnabled,
                        onMode = viewModel::setMode,
                        onToggleMicrophone = toggleMicrophone,
                        onSummary = viewModel::showSummary,
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        BoxWithConstraints(
            Modifier
                .fillMaxSize()
                .padding(top = padding.calculateTopPadding())
                .consumeWindowInsets(padding)
                .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal)),
        ) {
            if (!ui.isLoaded) {
                CircularProgressIndicator(Modifier.align(Alignment.Center))
                return@BoxWithConstraints
            }
            // iOS: a 150 pt strip and a keyboard a third of the screen; the strip shrinks in landscape
            val stripHeight = minOf(150.dp, maxHeight * 0.22f)
            val keyboardHeight = maxHeight * 0.33f
            Column(Modifier.fillMaxSize()) {
                PracticeHud(ui, Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                HorizontalDivider()

                // 1. Engraved score on one line, its cursor on the notes to play
                Box(Modifier.fillMaxWidth().height(stripHeight).background(Color.White)) {
                    ScoreWebView(
                        musicXml = ui.musicXml,
                        measureIndex = ui.measureIndex,
                        cursorBeat = ui.cursorBeat,
                        modifier = Modifier.fillMaxSize(),
                        rightClef = rightClef,
                        leftClef = leftClef,
                        automaticUsesAlto = automaticUsesAlto,
                        horizontal = true,
                        fitsHeight = true,
                        topInset = 0.dp,
                        bottomInset = 0.dp,
                        onSeek = viewModel::seek,
                    )
                }
                HorizontalDivider()

                // 2. Falling notes cascading down in matching beat colors
                FallingNotesView(viewModel.fallingNotes, Modifier.fillMaxWidth().weight(1f))
                HorizontalDivider()

                // 3. Piano keyboard illuminating in beat colors
                PianoKeyboard(
                    state = viewModel.keyboard,
                    modifier = Modifier.fillMaxWidth().height(keyboardHeight),
                    onKeyPress = viewModel::screenKeyPressed,
                    onKeyRelease = viewModel::screenKeyReleased,
                )

                PracticeToolbar(
                    ui = ui,
                    viewModel = viewModel,
                    onToggleMicrophone = toggleMicrophone,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceContainer)
                        .navigationBarsPadding()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        }
    }

    ui.stats?.let { session ->
        PracticeStatsSheet(session = session, onRate = viewModel::rateSession, onDismiss = viewModel::dismissSummary)
    }
}

private fun clefFlow(settings: com.lukstrike.luksmusic.data.SettingsRepository, key: String) =
    settings.flow(stringPreferencesKey(key), ClefChoice.SCORE.raw).map(ClefChoice::fromRaw).catch { emit(ClefChoice.SCORE) }

// MARK: - Menu

@Composable
private fun ModeMenu(
    mode: PracticeMode,
    isMicrophoneEnabled: Boolean,
    onMode: (PracticeMode) -> Unit,
    onToggleMicrophone: () -> Unit,
    onSummary: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.Outlined.Tune, contentDescription = stringResource(R.string.practice_mode_menu))
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            PracticeMode.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(stringResource(option.labelRes)) },
                    leadingIcon = { Icon(option.icon, contentDescription = null) },
                    trailingIcon = { if (option == mode) Icon(Icons.Outlined.Check, contentDescription = null) },
                    onClick = { expanded = false; onMode(option) },
                )
            }
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text(stringResource(if (isMicrophoneEnabled) R.string.practice_mic_turn_off else R.string.practice_mic_turn_on)) },
                leadingIcon = { Icon(if (isMicrophoneEnabled) Icons.Outlined.MicOff else Icons.Outlined.Mic, contentDescription = null) },
                onClick = { expanded = false; onToggleMicrophone() },
            )
            DropdownMenuItem(
                text = { Text(stringResource(R.string.practice_summary)) },
                leadingIcon = { Icon(Icons.Outlined.BarChart, contentDescription = null) },
                onClick = { expanded = false; onSummary() },
            )
        }
    }
}

// MARK: - HUD

@Composable
private fun PracticeHud(ui: PracticeUiState, modifier: Modifier = Modifier) {
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.practice_accuracy), style = MaterialTheme.typography.labelSmall, color = secondary)
            Text(
                stringResource(R.string.practice_percent, ui.accuracy.roundToInt()),
                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                color = if (ui.accuracy >= 80) LuksColors.success else LuksColors.warning,
            )
        }
        Spacer(Modifier.weight(1f))
        if (ui.isMicrophoneEnabled) {
            val heard = ui.detectedNote?.let { NoteNaming.nameWithOctave(it, usesLetterNames()) } ?: "--"
            Row(
                Modifier
                    .background(LuksColors.success.copy(alpha = 0.15f), CircleShape)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(Icons.Outlined.GraphicEq, contentDescription = null, tint = LuksColors.success, modifier = Modifier.size(12.dp))
                Text(
                    stringResource(R.string.practice_microphone_note, heard),
                    style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = LuksColors.success,
                )
            }
            Spacer(Modifier.weight(1f))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.practice_streak), style = MaterialTheme.typography.labelSmall, color = secondary)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = LuksColors.warning, modifier = Modifier.size(14.dp))
                Text(ui.currentStreak.toString(), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            }
        }
        Spacer(Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.practice_mode), style = MaterialTheme.typography.labelSmall, color = secondary)
            Text(
                stringResource(ui.mode.labelRes),
                style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f), RoundedCornerShape(6.dp))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
    }
}

// MARK: - Bottom practice controls

@Composable
private fun PracticeToolbar(
    ui: PracticeUiState,
    viewModel: PracticeViewModel,
    onToggleMicrophone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        AnimatedVisibility(ui.isMetronomeSilent) {
            Notice(Icons.Outlined.Headphones, stringResource(R.string.practice_metronome_silent))
        }
        AnimatedVisibility(ui.chordMissed) {
            Notice(Icons.Outlined.GraphicEq, stringResource(R.string.practice_chord_missed))
        }
        PracticeControls(ui, viewModel, onToggleMicrophone)
    }
}

@Composable
private fun Notice(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, contentDescription = null, tint = LuksColors.warning, modifier = Modifier.size(16.dp))
        Text(
            text, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
            color = LuksColors.warning, maxLines = 2, overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun PracticeControls(ui: PracticeUiState, viewModel: PracticeViewModel, onToggleMicrophone: () -> Unit) {
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    val fill = MaterialTheme.colorScheme.surfaceContainerHigh
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        IconButton(
            onClick = viewModel::togglePlay,
            modifier = Modifier.size(44.dp),
            colors = IconButtonDefaults.iconButtonColors(containerColor = MaterialTheme.colorScheme.primary, contentColor = Color.White),
        ) {
            Icon(
                if (ui.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                contentDescription = stringResource(
                    when {
                        ui.isPlaying -> R.string.practice_pause
                        ui.isRunning -> R.string.practice_resume
                        else -> R.string.practice_start
                    },
                ),
                modifier = Modifier.size(28.dp),
            )
        }
        IconButton(
            onClick = { viewModel.stopPractice() },
            modifier = Modifier.size(36.dp),
            colors = IconButtonDefaults.iconButtonColors(containerColor = fill),
        ) {
            Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.practice_stop))
        }
        IconButton(
            onClick = onToggleMicrophone,
            modifier = Modifier.size(36.dp),
            colors = IconButtonDefaults.iconButtonColors(
                containerColor = if (ui.isMicrophoneEnabled) LuksColors.success else fill,
                contentColor = if (ui.isMicrophoneEnabled) Color.White else MaterialTheme.colorScheme.onSurface,
            ),
        ) {
            Icon(
                if (ui.isMicrophoneEnabled) Icons.Filled.Mic else Icons.Outlined.MicOff,
                contentDescription = stringResource(
                    if (ui.isMicrophoneEnabled) R.string.practice_mic_turn_off else R.string.practice_mic_turn_on,
                ),
                modifier = Modifier.size(18.dp),
            )
        }
        PracticeMetronomeButton(viewModel, ui.isMetronomeOn)

        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.practice_tempo_label), style = MaterialTheme.typography.labelSmall, color = secondary)
                Text(stringResource(R.string.practice_bpm, ui.tempoBpm), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
            }
            val range = PracticeEngine.MIN_TEMPO..PracticeEngine.MAX_TEMPO
            Slider(
                value = ui.tempoBpm.coerceIn(range).toFloat(),
                onValueChange = { value ->
                    val step = PracticeEngine.TEMPO_STEP
                    viewModel.setTempo(((value / step).roundToInt() * step).coerceIn(range))
                },
                valueRange = range.first.toFloat()..range.last.toFloat(),
                steps = (range.last - range.first) / PracticeEngine.TEMPO_STEP - 1,
                modifier = Modifier.height(28.dp),
            )
        }

        // Label over value, so the row leaves the slider room beside the metronome
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.practice_measure), style = MaterialTheme.typography.labelSmall, color = secondary)
            Text(
                stringResource(R.string.practice_measure_progress, ui.measureIndex + 1, ui.measureCount),
                style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold,
            )
        }
    }
}

/**
 * Clicks at the tempo of the slider, apart from the practice cursor; its light flashes red on the first beat of the
 * measure and yellow on the others, like the score player's metronome. It reads the beats itself, so each beat
 * redraws only the button, not the score, the falling notes and the keyboard.
 */
@Composable
private fun PracticeMetronomeButton(viewModel: PracticeViewModel, isOn: Boolean) {
    val tick by viewModel.metronomeTick.collectAsStateWithLifecycle()
    // On for a moment at each beat
    var light by remember { mutableStateOf<Color?>(null) }
    LaunchedEffect(tick.count) {
        if (tick.count == 0) return@LaunchedEffect
        light = if (tick.isAccent) downbeatLight else beatLight
        delay(120)
        light = null
    }
    val label = stringResource(R.string.practice_metronome)
    Box {
        IconButton(
            onClick = viewModel::toggleMetronome,
            modifier = Modifier.size(36.dp).semantics { contentDescription = label },
            colors = IconButtonDefaults.iconButtonColors(
                containerColor = if (isOn) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh,
                contentColor = if (isOn) Color.White else MaterialTheme.colorScheme.onSurface,
            ),
        ) {
            Icon(Icons.Outlined.Timer, contentDescription = null, modifier = Modifier.size(18.dp))
        }
        light?.let { color ->
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .size(9.dp)
                    .shadow(4.dp, CircleShape, ambientColor = color, spotColor = color)
                    .background(color, CircleShape),
            )
        }
    }
}
