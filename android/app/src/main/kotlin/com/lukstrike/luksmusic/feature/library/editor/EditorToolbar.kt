// EditorToolbar.kt — port of luksMusic/Views/Editor/EditorToolbar.swift: the MuseScore-style palette. Staff
// choice, undo, redo, delete and a new measure on top; note values, rest, dot and accidentals below.
package com.lukstrike.luksmusic.feature.library.editor

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Backspace
import androidx.compose.material.icons.automirrored.outlined.Redo
import androidx.compose.material.icons.automirrored.outlined.Undo
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Staff

@Composable
fun EditorToolbar(state: EditorState, viewModel: EditorViewModel, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainer).padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Top row: staff, undo, redo, delete, add measure
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            SingleChoiceSegmentedButtonRow(Modifier.width(180.dp)) {
                listOf(Staff.TREBLE to R.string.editor_staff_treble, Staff.BASS to R.string.editor_staff_bass)
                    .forEachIndexed { index, (staff, label) ->
                        SegmentedButton(
                            selected = state.selectedStaff == staff,
                            onClick = { viewModel.selectStaff(staff) },
                            shape = SegmentedButtonDefaults.itemShape(index, 2),
                            icon = {},
                        ) { Text(stringResource(label), maxLines = 1) }
                    }
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = viewModel::undo, enabled = state.canUndo) {
                Icon(Icons.AutoMirrored.Outlined.Undo, contentDescription = stringResource(R.string.editor_undo))
            }
            IconButton(onClick = viewModel::redo, enabled = state.canRedo) {
                Icon(Icons.AutoMirrored.Outlined.Redo, contentDescription = stringResource(R.string.editor_redo))
            }
            IconButton(onClick = viewModel::deleteLastNote) {
                Icon(
                    Icons.AutoMirrored.Outlined.Backspace,
                    contentDescription = stringResource(R.string.editor_delete_note),
                    tint = MaterialTheme.colorScheme.error,
                )
            }
            FilledTonalButton(onClick = viewModel::addNewMeasure, contentPadding = PaddingValues(horizontal = 10.dp)) {
                Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                Text(stringResource(R.string.editor_add_measure), style = MaterialTheme.typography.labelMedium)
            }
        }

        // Bottom row: durations, rest and dot, accidentals
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            DurationButton(state, viewModel, NoteDuration.WHOLE, "𝅝", stringResource(R.string.editor_whole))
            DurationButton(state, viewModel, NoteDuration.HALF, "𝅗𝅥", stringResource(R.string.editor_half))
            DurationButton(state, viewModel, NoteDuration.QUARTER, "♩", "1/4")
            DurationButton(state, viewModel, NoteDuration.EIGHTH, "♪", "1/8")
            DurationButton(state, viewModel, NoteDuration.SIXTEENTH, "𝅘𝅥𝅯", "1/16")

            VerticalDivider(Modifier.height(24.dp))

            PaletteButton(state.isRestSelected, "𝄽", stringResource(R.string.editor_rest), onClick = viewModel::toggleRest)
            PaletteButton(state.isDottedSelected, "•", stringResource(R.string.editor_dot), onClick = viewModel::toggleDot)

            VerticalDivider(Modifier.height(24.dp))

            for ((accidental, symbol) in listOf(Accidental.SHARP to "♯", Accidental.FLAT to "♭", Accidental.NATURAL to "♮")) {
                PaletteButton(
                    isActive = state.selectedAccidental == accidental,
                    symbol = symbol,
                    label = null,
                    width = 36,
                    onClick = { viewModel.toggleAccidental(accidental) },
                )
            }
        }
    }
}

@Composable
private fun DurationButton(state: EditorState, viewModel: EditorViewModel, duration: NoteDuration, symbol: String, label: String) =
    PaletteButton(state.selectedDuration == duration, symbol, label) { viewModel.selectDuration(duration) }

/** A 44 dp palette key: a symbol over a small label, filled with the accent color when on. */
@Composable
private fun PaletteButton(isActive: Boolean, symbol: String, label: String?, width: Int = 44, onClick: () -> Unit) {
    val background by animateColorAsState(
        if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh, label = "palette"
    )
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(8.dp),
        color = background,
        contentColor = if (isActive) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.size(width.dp, 44.dp).semantics {
            role = Role.Button
            selected = isActive
            if (label != null) contentDescription = label
        },
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(symbol, fontSize = if (label == null) 18.sp else 20.sp, fontWeight = if (label == null) FontWeight.Bold else null, maxLines = 1)
            if (label != null) {
                Text(label, fontSize = 9.sp, maxLines = 1, overflow = TextOverflow.Clip, modifier = Modifier.padding(horizontal = 2.dp))
            }
        }
    }
}
