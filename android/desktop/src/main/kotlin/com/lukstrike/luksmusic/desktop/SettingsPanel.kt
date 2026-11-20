// SettingsPanel.kt — Ajustes, over any screen: the MIDI keyboard's connection, whether the app sounds its notes, the
// volume, the language (it follows the system) and the keys and Deck buttons.
package com.lukstrike.luksmusic.desktop

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.automirrored.filled.VolumeDown
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.desktop.ui.ActionButton
import com.lukstrike.luksmusic.desktop.ui.LocalStrings
import com.lukstrike.luksmusic.desktop.ui.MidiStatus
import com.lukstrike.luksmusic.desktop.ui.Palette
import com.lukstrike.luksmusic.desktop.ui.SquareIconButton
import kotlin.math.roundToInt

@Composable
fun SettingsPanel(
    connected: List<String>,
    midiSound: Boolean,
    volume: Float,
    fullscreen: Boolean,
    audioAvailable: Boolean,
    onMidiSound: (Boolean) -> Unit,
    onVolume: (Float) -> Unit,
    onFullscreen: (Boolean) -> Unit,
    onRescan: () -> Unit,
    onClose: () -> Unit,
) {
    val strings = LocalStrings.current
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f))
            .clickable(remember { MutableInteractionSource() }, indication = null, onClick = onClose),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            Modifier.fillMaxWidth(0.94f).fillMaxHeight(0.92f).clip(RoundedCornerShape(20.dp)).background(Palette.panel)
                .clickable(remember { MutableInteractionSource() }, indication = null) {}
                .padding(24.dp),
            horizontalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            Column(Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(strings.settings, color = Palette.text, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                }
                Section(strings.midiDevices)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    MidiStatus(connected) {}
                    ActionButton(strings.rescan, Icons.Filled.Refresh, onClick = onRescan)
                }
                Spacer(Modifier.height(8.dp))
                if (connected.isEmpty()) {
                    Text(strings.noKeyboardHint, color = Palette.muted, fontSize = 16.sp)
                } else {
                    for (name in connected) Text("• $name", color = Palette.text, fontSize = 17.sp)
                }
                Section(strings.midiSound)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(strings.midiSoundHint, color = Palette.muted, fontSize = 15.sp)
                        if (!audioAvailable) Text("No audio output", color = Palette.red, fontSize = 15.sp)
                    }
                    Switch(
                        midiSound, onMidiSound,
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.deepBlue),
                        modifier = Modifier.padding(start = 12.dp),
                    )
                }
                Section(strings.volume + "  (← →)")
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SquareIconButton(Icons.AutoMirrored.Filled.VolumeDown, "-") { onVolume((volume - 0.1f).coerceIn(0f, 1f)) }
                    Slider(
                        volume, onVolume, Modifier.weight(1f),
                        colors = SliderDefaults.colors(thumbColor = Palette.blue, activeTrackColor = Palette.blue),
                    )
                    SquareIconButton(Icons.AutoMirrored.Filled.VolumeUp, "+") { onVolume((volume + 0.1f).coerceIn(0f, 1f)) }
                    Text("${(volume * 100).roundToInt()}%", color = Palette.text, fontSize = 18.sp, modifier = Modifier.width(56.dp))
                }
                Spacer(Modifier.height(14.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(strings.fullscreen, color = Palette.text, fontSize = 17.sp, modifier = Modifier.weight(1f))
                    Switch(fullscreen, onFullscreen, colors = SwitchDefaults.colors(checkedTrackColor = Palette.deepBlue))
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(strings.language, color = Palette.text, fontSize = 17.sp, modifier = Modifier.weight(1f))
                    Column(horizontalAlignment = Alignment.End) {
                        Text(strings.languageValue, color = Palette.text, fontSize = 16.sp)
                        Text(strings.languageHint, color = Palette.muted, fontSize = 13.sp)
                    }
                }
                Section(strings.controllerTitle)
                for (pair in strings.controllerHelp.chunked(2)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        for ((button, key) in pair) Box(Modifier.weight(1f)) { KeyRow(button, key, keyWidth = 120) }
                    }
                }
            }
            Column(Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(strings.shortcuts, color = Palette.text, fontSize = 24.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    SquareIconButton(Icons.Filled.Close, strings.close, onClick = onClose)
                }
                Spacer(Modifier.height(8.dp))
                for ((key, action) in strings.shortcutsHelp) KeyRow(key, action)
            }
        }
    }
}

@Composable
private fun Section(title: String) {
    Spacer(Modifier.height(12.dp))
    Text(title.uppercase(), color = Palette.cyan, fontSize = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
    Spacer(Modifier.height(6.dp))
}

@Composable
private fun KeyRow(key: String, action: String, keyWidth: Int = 150) {
    Row(Modifier.padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            key, color = Palette.text, fontSize = 14.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold,
            modifier = Modifier.width(keyWidth.dp).clip(RoundedCornerShape(6.dp)).background(Palette.raised).padding(horizontal = 8.dp, vertical = 4.dp),
        )
        Spacer(Modifier.width(12.dp))
        Text(action, color = Palette.muted, fontSize = 15.sp)
    }
}

/** A yes/no question over the screen (Enter confirms, Esc cancels). */
@Composable
fun ConfirmDialog(message: String, confirm: String, onConfirm: () -> Unit, onCancel: () -> Unit) {
    val strings = LocalStrings.current
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f))
            .clickable(remember { MutableInteractionSource() }, indication = null, onClick = onCancel),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.width(620.dp).clip(RoundedCornerShape(20.dp)).background(Palette.panel)
                .clickable(remember { MutableInteractionSource() }, indication = null) {}
                .padding(28.dp),
        ) {
            Text(message, color = Palette.text, fontSize = 22.sp)
            Spacer(Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ActionButton(strings.cancel, Icons.Filled.Close, Modifier.weight(1f), hint = "Esc  B", onClick = onCancel)
                ActionButton(confirm, Icons.Filled.Close, Modifier.weight(1f), primary = true, hint = "Enter  A", onClick = onConfirm)
            }
        }
    }
}
