// PlayerChrome.kt — port of Views/Score/Player/PlayerChrome.swift. The score player's frame, drawn like the
// luksmusic.web.app player: a dark title bar above the paper and a docked control panel below it (timeline,
// transport, the notes under the cursor by hand and the keyboard), so no control ever covers the music.
package com.lukstrike.luksmusic.feature.player

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBackIosNew
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.FastRewind
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.Piano
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.RepeatOne
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.playback.CursorNotes
import com.lukstrike.luksmusic.core.playback.HandsMixer
import com.lukstrike.luksmusic.core.playback.LoopMode
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** Colors of the web player (index.html's CSS variables). */
object PlayerTheme {
    val background = Color(11, 17, 32)
    val panel = Color(17, 24, 39)
    val raised = Color(30, 41, 59)
    val border = Color(51, 65, 85)
    val blue = Color(59, 130, 246)
    val deepBlue = Color(37, 99, 235)
    val cyan = Color(56, 189, 248)
    val green = Color(74, 222, 128)
    val text = Color(248, 250, 252)
    val muted = Color(148, 163, 184)
    /** The metronome's light on the first beat of a measure and on the others. */
    val downbeat = Color(239, 68, 68)
    val beat = Color(234, 179, 8)
    val favorite = Color(244, 63, 94)
}

private val ControlShape = RoundedCornerShape(8.dp)

// MARK: - Top Bar

@Composable
fun PlayerTopBar(
    title: String,
    subtitle: String,
    onBack: () -> Unit,
    insets: WindowInsets,
    trailing: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(PlayerTheme.panel)
            .drawBehind {
                drawRect(PlayerTheme.raised, topLeft = Offset(0f, size.height - 1.dp.toPx()))
            }
            .windowInsetsPadding(insets)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PlayerIconButton(Icons.Rounded.ArrowBackIosNew, stringResource(R.string.player_back), onBack, iconSize = 16.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title, color = PlayerTheme.text, fontSize = 15.sp, fontWeight = FontWeight.Bold,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            if (subtitle.isNotEmpty()) {
                Text(subtitle, color = PlayerTheme.muted, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        trailing()
    }
}

/** Square icon button of the top bar ("…" menus, favorite). */
@Composable
fun PlayerIconButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    tint: Color = PlayerTheme.text,
    iconSize: Dp = 18.dp,
) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(ControlShape)
            .background(PlayerTheme.raised)
            .clickable(role = Role.Button, onClickLabel = label, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(iconSize))
    }
}

// MARK: - Dock

/** Everything the dock shows, read from the view model by the screen. */
data class DockState(
    val isPlaying: Boolean,
    val measureIndex: Int,
    val measureCount: Int,
    val elapsedSeconds: Double,
    val totalSeconds: Double,
    val speed: Double,
    val loopMode: LoopMode,
    val isMetronomeOn: Boolean,
    val cursorNotes: CursorNotes,
    val showKeyboard: Boolean,
)

/** What the dock's controls do. */
interface DockActions {
    fun togglePlayback()
    fun restart()
    fun stepBackward()
    fun stepForward()
    fun seekToMeasure(index: Int)
    fun setSpeed(speed: Double)
    fun cycleLoopMode()
    fun toggleMetronome()
    fun openMixer()
    fun toggleKeyboard()
    fun pressKey(midi: Int)
    fun releaseKey(midi: Int)
}

@Composable
fun PlayerDock(
    state: DockState,
    actions: DockActions,
    /** Each metronome click (true on a first beat), so its light can flash. */
    metronomeClicks: Flow<Boolean>,
    insets: WindowInsets,
    keyboardHeight: Dp,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(PlayerTheme.panel)
            .drawBehind { drawRect(PlayerTheme.raised, size = size.copy(height = 1.dp.toPx())) }
            .windowInsetsPadding(insets),
    ) {
        Timeline(state, actions)
        Transport(state, actions, metronomeClicks)
        NotesUnderCursor(state.cursorNotes)
        AnimatedVisibility(
            visible = state.showKeyboard,
            enter = expandVertically(spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow)) + fadeIn(),
            exit = shrinkVertically(spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow)) + fadeOut(),
        ) {
            PlayerKeyboard(
                trebleKeys = state.cursorNotes.trebleMidi,
                bassKeys = state.cursorNotes.bassMidi,
                onPress = actions::pressKey,
                onRelease = actions::releaseKey,
                modifier = Modifier.fillMaxWidth().height(keyboardHeight),
            )
        }
    }
}

// MARK: Timeline

@Composable
private fun Timeline(state: DockState, actions: DockActions) {
    val measureCount = max(1, state.measureCount)
    // Timeline position while the finger is on the slider; the player seeks when it lets go
    var scrub by remember { mutableStateOf<Float?>(null) }
    val progress = if (state.totalSeconds > 0) (state.elapsedSeconds / state.totalSeconds).coerceIn(0.0, 1.0) else 0.0
    fun measureAt(p: Float) = min(measureCount - 1, (p * measureCount).toInt())
    val shown = scrub ?: progress.toFloat()
    val measure = scrub?.let(::measureAt) ?: state.measureIndex
    val seconds = scrub?.let { it * state.totalSeconds } ?: state.elapsedSeconds

    Row(
        modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            "${clock(seconds)} / ${clock(state.totalSeconds)}",
            color = PlayerTheme.cyan, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
            maxLines = 1,
        )
        val positionLabel = stringResource(R.string.player_position)
        Slider(
            value = shown,
            onValueChange = { scrub = it },
            onValueChangeFinished = {
                scrub?.let { actions.seekToMeasure(measureAt(it)) }
                scrub = null
            },
            colors = SliderDefaults.colors(
                thumbColor = Color.White,
                activeTrackColor = PlayerTheme.cyan,
                inactiveTrackColor = PlayerTheme.border,
            ),
            modifier = Modifier.weight(1f).semantics { contentDescription = positionLabel },
        )
        Text(
            stringResource(R.string.player_measure_badge, measure + 1, measureCount),
            color = PlayerTheme.text, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1,
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(PlayerTheme.raised)
                .border(1.dp, PlayerTheme.border, RoundedCornerShape(6.dp))
                .padding(horizontal = 8.dp, vertical = 4.dp),
        )
    }
}

private fun clock(seconds: Double): String {
    val whole = max(0, floor(seconds).toInt())
    return "%02d:%02d".format(whole / 60, whole % 60)
}

// MARK: Transport

@Composable
private fun Transport(state: DockState, actions: DockActions, metronomeClicks: Flow<Boolean>) {
    // Nine controls fit a 360 dp phone; wider screens spread them out
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        val repeatLabel = stringResource(
            when (state.loopMode) {
                LoopMode.OFF -> R.string.player_repeat_off
                LoopMode.MEASURE -> R.string.player_repeat_measure
                LoopMode.PIECE -> R.string.player_repeat_piece
            },
        )
        ControlButton(
            if (state.loopMode == LoopMode.MEASURE) Icons.Rounded.RepeatOne else Icons.Rounded.Repeat,
            repeatLabel, isOn = state.loopMode != LoopMode.OFF, onClick = actions::cycleLoopMode,
        )
        ControlButton(
            Icons.Rounded.SkipPrevious,
            stringResource(if (state.loopMode == LoopMode.MEASURE) R.string.player_restart_measure else R.string.player_restart),
            onClick = actions::restart,
        )
        ControlButton(Icons.Rounded.FastRewind, stringResource(R.string.player_previous_note), onClick = actions::stepBackward)

        PlayButton(state.isPlaying, actions::togglePlayback)

        ControlButton(Icons.Rounded.FastForward, stringResource(R.string.player_next_note), onClick = actions::stepForward)
        SpeedButton(state.speed, actions::setSpeed)
        MetronomeButton(state.isMetronomeOn, actions::toggleMetronome, metronomeClicks)
        ControlButton(Icons.Rounded.Tune, stringResource(R.string.player_mixer), onClick = actions::openMixer)
        ControlButton(
            Icons.Rounded.Piano, stringResource(R.string.player_keyboard), isOn = state.showKeyboard,
            onClick = actions::toggleKeyboard,
        )
    }
}

@Composable
private fun PlayButton(isPlaying: Boolean, onClick: () -> Unit) {
    val label = stringResource(if (isPlaying) R.string.player_pause else R.string.player_play)
    Box(
        modifier = Modifier
            .size(48.dp)
            .shadow(10.dp, CircleShape, ambientColor = PlayerTheme.blue, spotColor = PlayerTheme.blue)
            .clip(CircleShape)
            .background(Brush.verticalGradient(listOf(PlayerTheme.blue, PlayerTheme.deepBlue)))
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
            contentDescription = null, tint = Color.White,
            modifier = Modifier.size(28.dp).offset(x = if (isPlaying) 0.dp else 1.dp),
        )
    }
}

@Composable
private fun ControlButton(
    icon: ImageVector,
    label: String,
    isOn: Boolean = false,
    onClick: () -> Unit,
    content: (@Composable BoxScope.() -> Unit)? = null,
) {
    val shape = ControlShape
    Box(
        modifier = Modifier
            .size(width = 34.dp, height = 36.dp)
            .clip(shape)
            .background(if (isOn) PlayerTheme.cyan.copy(alpha = 0.15f) else PlayerTheme.raised)
            .border(1.dp, if (isOn) PlayerTheme.cyan.copy(alpha = 0.6f) else PlayerTheme.border, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = if (isOn) PlayerTheme.cyan else PlayerTheme.text, modifier = Modifier.size(18.dp))
        content?.invoke(this)
    }
}

/** The speed menu (0.5× to 1.25×). The decimal separator follows the app's language. */
@Composable
private fun SpeedButton(speed: Double, onSpeed: (Double) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val label = stringResource(R.string.player_speed)
    Box {
        Box(
            modifier = Modifier
                .size(width = 38.dp, height = 36.dp)
                .clip(ControlShape)
                .background(PlayerTheme.raised)
                .border(1.dp, PlayerTheme.border, ControlShape)
                .clickable(role = Role.Button) { open = true }
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                speedLabel(speed), fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1,
                color = if (speed == 1.0) PlayerTheme.text else PlayerTheme.cyan,
            )
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            PlayerSettings.speeds.forEach { option ->
                DropdownMenuItem(
                    text = { Text(speedLabel(option), fontWeight = if (option == speed) FontWeight.Bold else null) },
                    onClick = {
                        onSpeed(option)
                        open = false
                    },
                    trailingIcon = if (option == speed) {
                        { Icon(Icons.Rounded.Check, contentDescription = null) }
                    } else null,
                )
            }
        }
    }
}

@Composable
private fun speedLabel(speed: Double): String = when (speed) {
    0.5 -> stringResource(R.string.player_speed_half)
    0.75 -> stringResource(R.string.player_speed_three_quarters)
    1.25 -> stringResource(R.string.player_speed_one_and_quarter)
    else -> "1×"
}

/**
 * Clicks on every beat while the piece plays, like the web player's metronome; its light flashes red on the first
 * beat of the measure and yellow on the others.
 */
@Composable
private fun MetronomeButton(isOn: Boolean, onClick: () -> Unit, clicks: Flow<Boolean>) {
    var light by remember { mutableStateOf<Color?>(null) }
    LaunchedEffect(clicks) {
        // Each click restarts the 0.12 s flash
        clicks.collectLatest { accent ->
            light = if (accent) PlayerTheme.downbeat else PlayerTheme.beat
            delay(120)
            light = null
        }
    }
    ControlButton(MetronomeIcon, stringResource(R.string.player_metronome), isOn = isOn, onClick = onClick) {
        val color = light
        if (color != null) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(4.dp)
                    .size(7.dp)
                    .shadow(4.dp, CircleShape, ambientColor = color, spotColor = color)
                    .background(color, CircleShape),
            )
        }
    }
}

// MARK: Notes Under the Cursor

@Composable
private fun NotesUnderCursor(notes: CursorNotes) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 14.dp, end = 14.dp, bottom = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Hand(stringResource(R.string.player_right_hand_short), notes.trebleNames, PlayerTheme.cyan, Modifier.weight(1f, fill = false))
        Hand(stringResource(R.string.player_left_hand_short), notes.bassNames, PlayerTheme.green, Modifier.weight(1f, fill = false))
    }
}

@Composable
private fun Hand(title: String, names: String, color: Color, modifier: Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(7.dp).background(color, CircleShape))
        Text(title, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(
            names.ifEmpty { stringResource(R.string.player_rest) },
            color = if (names.isEmpty()) PlayerTheme.muted else PlayerTheme.text,
            fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
    }
}

// MARK: - Hands Mixer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HandsMixerSheet(mixer: HandsMixer, onChange: (HandsMixer) -> Unit, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = PlayerTheme.panel,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.player_mixer), color = PlayerTheme.text, fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_ok), fontWeight = FontWeight.SemiBold) }
            }
            Channel(
                symbol = "𝄞", title = stringResource(R.string.player_right_hand), color = PlayerTheme.cyan,
                volume = mixer.trebleVolume, muted = mixer.trebleMuted,
                onVolume = { onChange(mixer.copy(trebleVolume = it)) },
                onMuted = { onChange(mixer.copy(trebleMuted = it)) },
            )
            Channel(
                symbol = "𝄢", title = stringResource(R.string.player_left_hand), color = PlayerTheme.green,
                volume = mixer.bassVolume, muted = mixer.bassMuted,
                onVolume = { onChange(mixer.copy(bassVolume = it)) },
                onMuted = { onChange(mixer.copy(bassMuted = it)) },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Preset(stringResource(R.string.player_both_hands), mixer, treble = true, bass = true, onChange)
                Preset(stringResource(R.string.player_right_only), mixer, treble = true, bass = false, onChange)
                Preset(stringResource(R.string.player_left_only), mixer, treble = false, bass = true, onChange)
            }
        }
    }
}

@Composable
private fun Channel(
    symbol: String, title: String, color: Color, volume: Double, muted: Boolean,
    onVolume: (Double) -> Unit, onMuted: (Boolean) -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(symbol, color = color, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(30.dp))
        Column(Modifier.weight(1f)) {
            Text(title, color = PlayerTheme.text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Slider(
                value = volume.toFloat(),
                onValueChange = { onVolume(it.toDouble()) },
                enabled = !muted,
                colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = color, inactiveTrackColor = PlayerTheme.border),
            )
        }
        Text(
            stringResource(if (muted) R.string.player_muted else R.string.player_mute),
            color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(CircleShape)
                .background(if (muted) Color.Red else PlayerTheme.raised)
                .clickable(role = Role.Switch) { onMuted(!muted) }
                .padding(horizontal = 10.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun RowScope.Preset(title: String, mixer: HandsMixer, treble: Boolean, bass: Boolean, onChange: (HandsMixer) -> Unit) {
    val selected = mixer.trebleMuted == !treble && mixer.bassMuted == !bass
    Text(
        title, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .weight(1f)
            .clip(ControlShape)
            .background(if (selected) PlayerTheme.blue else PlayerTheme.raised)
            .clickable(role = Role.RadioButton) { onChange(mixer.copy(trebleMuted = !treble, bassMuted = !bass)) }
            .padding(vertical = 9.dp),
    )
}
