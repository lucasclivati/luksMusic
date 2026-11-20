// StudyScreen.kt — Modo Estudo laid out for the Deck on the music stand: the mode, view, tempo and metronome in one
// row, the music (falling notes over the key strip, or the scrolling grand staff) filling the middle, and big
// transport buttons with the session's results at the bottom.
package com.lukstrike.luksmusic.desktop.study

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.desktop.Shortcut
import com.lukstrike.luksmusic.desktop.ui.ActionButton
import com.lukstrike.luksmusic.desktop.ui.KeyStrip
import com.lukstrike.luksmusic.desktop.ui.LocalStrings
import com.lukstrike.luksmusic.desktop.ui.MidiStatus
import com.lukstrike.luksmusic.desktop.ui.Palette
import com.lukstrike.luksmusic.desktop.ui.Segmented
import com.lukstrike.luksmusic.desktop.ui.SquareIconButton
import com.lukstrike.luksmusic.desktop.ui.Stat
import com.lukstrike.luksmusic.desktop.ui.TopBar
import kotlin.math.roundToInt

@Composable
fun StudyScreen(
    controller: StudyController,
    score: Score,
    connected: List<String>,
    held: Set<Int>,
    beatFlash: Int,
    onBack: () -> Unit,
    onSwitch: () -> Unit,
    onSettings: () -> Unit,
) {
    val strings = LocalStrings.current
    val state by controller.state.collectAsState()
    val music = remember(score) { StripMusic(score) }
    val currentState by rememberUpdatedState(state)

    // The display's frame clock moves the playhead while practice plays
    LaunchedEffect(controller, state.isPlaying) {
        if (!state.isPlaying) return@LaunchedEffect
        var last = -1L
        while (true) {
            withFrameNanos { now ->
                if (last >= 0) controller.frame((now - last) / 1_000_000_000.0)
                last = now
            }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(
            state.title,
            "${strings.studyMode} · ${strings.measure} ${state.measureIndex + 1}/${state.measureCount}",
            onBack,
        ) {
            MidiStatus(connected, onSettings)
            ActionButton(strings.readingDrill, Icons.AutoMirrored.Filled.MenuBook, hint = "Tab", onClick = onSwitch)
            SquareIconButton(Icons.Filled.Settings, strings.settings, onClick = onSettings)
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(20.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Segmented(
                strings.mode,
                listOf(
                    PracticeMode.GUIDED to strings.modeGuided, PracticeMode.FREE_PLAY to strings.modeFree,
                    PracticeMode.HANDS_SEPARATE_RIGHT to strings.modeRight, PracticeMode.HANDS_SEPARATE_LEFT to strings.modeLeft,
                    PracticeMode.SLOW_PRACTICE to strings.modeSlow,
                ),
                state.mode, onSelect = controller::setMode,
            )
            Segmented(
                strings.view + " (V)",
                listOf(StudyView.FALLING to strings.viewFalling, StudyView.STAFF to strings.viewStaff),
                state.view, onSelect = controller::setView,
            )
            Column {
                Text((strings.tempo + " (↑ ↓)").uppercase(), color = Palette.muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SquareIconButton(Icons.Filled.Remove, "-", size = 50.dp) { controller.changeTempo(-1) }
                    Text(
                        strings.bpm(state.tempoBpm), color = Palette.text, fontSize = 20.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.width(110.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                    SquareIconButton(Icons.Filled.Add, "+", size = 50.dp) { controller.changeTempo(1) }
                }
            }
            MetronomeToggle(state.isMetronomeOn, beatFlash, strings.metronome + " (M)", controller::toggleMetronome)
        }
        Column(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 16.dp).clip(RoundedCornerShape(16.dp))) {
            when (state.view) {
                StudyView.FALLING -> FallingNotesView(
                    controller.track, { controller.playhead }, state.keyRange, controller.beatsPerMeasure,
                    Modifier.weight(1f).fillMaxWidth(),
                )
                StudyView.STAFF -> StaffStripView(
                    music, { controller.playhead }, { currentState.targets }, Modifier.weight(1f).fillMaxWidth(),
                )
            }
            val hitColors = state.hits.startBeats.mapValues { (_, start) -> Palette.colorForBeat(start, controller.beatsPerMeasure) }
            KeyStrip(
                state.keyRange,
                Modifier.fillMaxWidth().height(if (state.view == StudyView.FALLING) 84.dp else 64.dp).background(Color(0.07f, 0.09f, 0.11f)),
                targets = state.targets + state.hits.active,
                targetColors = hitColors,
                held = held,
                correct = state.correctKeys,
                incorrect = state.incorrectKeys,
                usesLetters = strings.usesLetters,
            )
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ActionButton(
                when { !state.isRunning -> strings.start; state.isPaused -> strings.resume; else -> strings.pause },
                if (state.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                Modifier.width(220.dp), primary = true, hint = "Space  Enter  X", onClick = controller::togglePlay,
            )
            ActionButton(strings.stop, Icons.Filled.Stop, enabled = state.isRunning, onClick = controller::stop)
            ActionButton("", Icons.Filled.SkipPrevious, hint = "←  L1") { controller.seekMeasure(-1) }
            ActionButton("", Icons.Filled.SkipNext, hint = "→  R1") { controller.seekMeasure(1) }
            val status = state.lastSummary?.let { (played, right, best) -> strings.summary(played, right, best) }
                ?: if (state.isRunning) strings.playNow else strings.ready
            Text(
                status, color = if (state.lastSummary != null) Palette.cyan else Palette.muted, fontSize = 17.sp,
                maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f).padding(start = 8.dp),
            )
            Stat(strings.accuracy, "${state.accuracy.roundToInt()}%", Palette.green)
            Spacer(Modifier.width(20.dp))
            Stat(strings.streak, "${state.streak}", Palette.amber)
        }
    }
}

@Composable
private fun MetronomeToggle(on: Boolean, beatFlash: Int, label: String, onClick: () -> Unit) {
    val flashing = on && beatFlash % 2 == 1
    val color = if (on) Palette.cyan else Palette.muted
    Row(
        Modifier
            .heightIn(min = 50.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (flashing) Palette.cyan.copy(alpha = 0.35f) else if (on) Palette.cyan.copy(alpha = 0.12f) else Palette.raised)
            .border(1.dp, color.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Timer, contentDescription = null, tint = color, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(8.dp))
        Box { Text(label, color = color, fontSize = 15.sp, fontWeight = FontWeight.SemiBold) }
    }
}

/** Modo Estudo's keys and buttons; true when handled. */
fun StudyController.handle(shortcut: Shortcut): Boolean {
    when (shortcut) {
        Shortcut.SPACE, Shortcut.ENTER -> togglePlay()
        Shortcut.UP, Shortcut.TEMPO_UP -> changeTempo(1)
        Shortcut.DOWN, Shortcut.TEMPO_DOWN -> changeTempo(-1)
        Shortcut.LEFT, Shortcut.PAGE_UP -> seekMeasure(-1)
        Shortcut.RIGHT, Shortcut.PAGE_DOWN -> seekMeasure(1)
        Shortcut.METRONOME -> toggleMetronome()
        Shortcut.VIEW -> toggleView()
        Shortcut.REPEAT -> stop()
        else -> return false
    }
    return true
}
