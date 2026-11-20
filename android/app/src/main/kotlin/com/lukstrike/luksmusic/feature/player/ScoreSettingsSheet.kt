// ScoreSettingsSheet.kt — port of Views/Score/ScoreSettingsView.swift. The score's settings sheet: how the engraving
// is laid out, the clef of each hand's staff, the piano's room sound, the keyboard, and transposition by semitones.
package com.lukstrike.luksmusic.feature.player

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CropPortrait
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Start
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.Clef
import com.lukstrike.luksmusic.core.model.ClefChoice

/** What the settings sheet changes. */
interface ScoreSettingsActions {
    fun setMode(mode: ScoreDisplayMode)
    fun setRightClef(choice: ClefChoice)
    fun setLeftClef(choice: ClefChoice)
    fun setAutomaticUsesAlto(on: Boolean)
    fun setConcertHall(on: Boolean)
    fun setShowKeyboard(show: Boolean)
    fun setTransposition(semitones: Int)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScoreSettingsSheet(
    display: PlayerDisplay,
    transposition: Int,
    transpositionKeyText: String,
    actions: ScoreSettingsActions,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = PlayerTheme.panel,
    ) {
        Text(
            stringResource(R.string.player_settings), color = PlayerTheme.text, fontSize = 22.sp, fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
        )
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp)
                .padding(bottom = 28.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            Section(stringResource(R.string.player_section_display)) {
                DisplayModeRow(display.mode, ScoreDisplayMode.VERTICAL_SCROLL, R.string.player_mode_page, R.string.player_mode_page_detail, Icons.Rounded.Description, actions)
                DisplayModeRow(display.mode, ScoreDisplayMode.PORTRAIT_VIEW, R.string.player_mode_large, R.string.player_mode_large_detail, Icons.Rounded.CropPortrait, actions)
                DisplayModeRow(display.mode, ScoreDisplayMode.SINGLE_LINE, R.string.player_mode_single_line, R.string.player_mode_single_line_detail, Icons.Rounded.Start, actions)
            }

            Section(stringResource(R.string.player_section_clefs)) {
                ClefRow(stringResource(R.string.player_right_hand), display.rightClef, actions::setRightClef)
                ClefRow(stringResource(R.string.player_left_hand), display.leftClef, actions::setLeftClef)
                if (display.rightClef == ClefChoice.AUTOMATIC || display.leftClef == ClefChoice.AUTOMATIC) {
                    ToggleRow(
                        stringResource(R.string.player_automatic_alto), stringResource(R.string.player_automatic_alto_detail),
                        display.automaticUsesAlto, actions::setAutomaticUsesAlto,
                    )
                }
            }

            Section(stringResource(R.string.player_section_sound)) {
                ToggleRow(
                    stringResource(R.string.player_concert_hall), stringResource(R.string.player_concert_hall_detail),
                    display.concertHall, actions::setConcertHall,
                )
            }

            Section(stringResource(R.string.player_section_keyboard)) {
                ToggleRow(
                    stringResource(R.string.player_show_keyboard), stringResource(R.string.player_show_keyboard_detail),
                    display.showKeyboard, actions::setShowKeyboard,
                )
            }

            Section(stringResource(R.string.player_section_transposition)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(transpositionKeyText, color = PlayerTheme.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        Text(transpositionDetail(transposition), color = PlayerTheme.muted, fontSize = 12.sp)
                    }
                    StepButton(Icons.Rounded.Remove, stringResource(R.string.player_half_step_down)) {
                        actions.setTransposition(transposition - 1)
                    }
                    StepButton(Icons.Rounded.Add, stringResource(R.string.player_half_step_up)) {
                        actions.setTransposition(transposition + 1)
                    }
                    val enabled = transposition != 0
                    Text(
                        stringResource(R.string.player_original), color = PlayerTheme.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .alpha(if (enabled) 1f else 0.4f)
                            .clip(CircleShape)
                            .background(PlayerTheme.raised)
                            .clickable(enabled = enabled, role = Role.Button) { actions.setTransposition(0) }
                            .padding(horizontal = 14.dp, vertical = 9.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun transpositionDetail(semitones: Int): String = when {
    semitones == 0 -> stringResource(R.string.player_original_key)
    semitones > 0 -> pluralStringResource(R.plurals.player_semitones_up, semitones, semitones)
    else -> pluralStringResource(R.plurals.player_semitones_down, -semitones, -semitones)
}

// MARK: - Rows

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, color = PlayerTheme.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.5.sp)
        content()
    }
}

@Composable
private fun DisplayModeRow(
    current: ScoreDisplayMode, mode: ScoreDisplayMode, title: Int, detail: Int, icon: ImageVector, actions: ScoreSettingsActions,
) {
    val selected = current == mode
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .selectable(selected = selected, role = Role.RadioButton) { actions.setMode(mode) }
            .padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier.size(22.dp).border(2.dp, if (selected) PlayerTheme.blue else PlayerTheme.border, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) Box(Modifier.size(10.dp).background(PlayerTheme.blue, CircleShape))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(title), color = PlayerTheme.text, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            Text(stringResource(detail), color = PlayerTheme.muted, fontSize = 12.sp)
        }
        Icon(icon, contentDescription = null, tint = PlayerTheme.muted, modifier = Modifier.size(20.dp))
    }
}

@Composable
private fun ClefRow(title: String, choice: ClefChoice, onChoice: (ClefChoice) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, color = PlayerTheme.text, fontSize = 15.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
            Text(clefChoiceDetail(choice), color = PlayerTheme.muted, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ClefChoice.entries.forEach { option ->
                val selected = option == choice
                val description = "$title: ${clefChoiceFullName(option)}"
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(32.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (selected) PlayerTheme.blue else PlayerTheme.raised)
                        .selectable(selected = selected, role = Role.RadioButton) { onChoice(option) }
                        .semantics { contentDescription = description },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        clefChoiceName(option), color = if (selected) Color.White else PlayerTheme.text,
                        fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(horizontal = 2.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ToggleRow(title: String, detail: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(role = Role.Switch) { onChange(!isOn) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = PlayerTheme.text, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            Text(detail, color = PlayerTheme.muted, fontSize = 12.sp)
        }
        Switch(
            checked = isOn, onCheckedChange = null,
            colors = SwitchDefaults.colors(checkedTrackColor = PlayerTheme.blue, checkedThumbColor = Color.White),
        )
    }
}

@Composable
private fun StepButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(width = 40.dp, height = 36.dp)
            .clip(CircleShape)
            .background(PlayerTheme.raised)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = PlayerTheme.text, modifier = Modifier.size(18.dp))
    }
}

// MARK: - Clef names (iOS Clef.displayName, ClefChoice.displayName / detail)

@Composable
fun clefName(clef: Clef): String = stringResource(
    when (clef) {
        Clef.TREBLE -> R.string.player_clef_treble
        Clef.BASS -> R.string.player_clef_bass
        Clef.ALTO -> R.string.player_clef_alto
    },
)

/** The short name on the choice buttons ("Sol", "Automática"). */
@Composable
fun clefChoiceName(choice: ClefChoice): String = stringResource(
    when (choice) {
        ClefChoice.SCORE -> R.string.player_original
        ClefChoice.AUTOMATIC -> R.string.player_clef_choice_automatic
        ClefChoice.TREBLE -> R.string.player_clef_choice_treble
        ClefChoice.BASS -> R.string.player_clef_choice_bass
        ClefChoice.ALTO -> R.string.player_clef_choice_alto
    },
)

/** The full name for menus and TalkBack ("Clave de sol", "Automática"). */
@Composable
fun clefChoiceFullName(choice: ClefChoice): String = choice.fixedClef?.let { clefName(it) } ?: clefChoiceName(choice)

@Composable
private fun clefChoiceDetail(choice: ClefChoice): String = stringResource(
    when (choice) {
        ClefChoice.SCORE -> R.string.player_clef_detail_score
        ClefChoice.AUTOMATIC -> R.string.player_clef_detail_automatic
        ClefChoice.TREBLE -> R.string.player_clef_detail_treble
        ClefChoice.BASS -> R.string.player_clef_detail_bass
        ClefChoice.ALTO -> R.string.player_clef_detail_alto
    },
)
