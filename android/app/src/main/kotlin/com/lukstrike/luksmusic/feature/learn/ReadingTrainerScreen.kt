// ReadingTrainerScreen.kt — port of luksMusic/Views/Practice/ReadingTrainerView.swift.
//
// "Treino de leitura": a few notes of one hand (or both, on a grand staff) to be found on the keyboard. Each note turns green
// when found on the first try, orange when found after a mistake or a hint; a wrong key flashes red and shows
// where it would be written. The piece is read in order (remembering where it stopped) or in random segments.
package com.lukstrike.luksmusic.feature.learn

import android.app.Application
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FastForward
import androidx.compose.material.icons.filled.FastRewind
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingKeyLabels
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.core.lessons.ReadingOrder
import com.lukstrike.luksmusic.core.model.ClefChoice
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.bassClef
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.trebleClef

/** The drill for one score of the library. The score player can open it the same way (ReadingDrillScoreRoute). */
@Composable
fun ReadingTrainerScreen(scoreId: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val container = appContainer()
    val viewModel: ReadingTrainerViewModel = viewModel {
        ReadingTrainerViewModel(scoreId, context.applicationContext as Application, container)
    }
    val state by viewModel.state.collectAsStateWithLifecycle()

    LifecycleStartEffect(viewModel) { onStopOrDispose { viewModel.stop() } }

    val haptics = LocalHapticFeedback.current
    LaunchedEffect(viewModel) {
        viewModel.haptics.collect {
            haptics.performHapticFeedback(
                when (it) {
                    LearnHaptic.CORRECT -> HapticFeedbackType.SegmentTick
                    LearnHaptic.WRONG -> HapticFeedbackType.Reject
                    LearnHaptic.STEP_DONE -> HapticFeedbackType.Confirm
                }
            )
        }
    }

    var showsSettings by remember { mutableStateOf(false) }
    val close = {
        viewModel.stop()
        onBack()
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(LearnColors.background)) {
        val keyboardHeight = (maxHeight * 0.27f).coerceIn(130.dp, 230.dp)
        Column(Modifier.fillMaxSize()) {
            LearnTopBar(stringResource(R.string.learn_drill_title), state.title, onBack = close) {
                ChromeIconButton(Icons.Filled.Tune, stringResource(R.string.learn_drill_settings)) { showsSettings = true }
            }
            if (state.isMissing) {
                Text(
                    stringResource(R.string.learn_drill_score_missing), color = LearnColors.muted, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(32.dp),
                )
                return@Column
            }
            val devices by container.midi.connectedDevices.collectAsStateWithLifecycle()
            SetupBar(state, connectedKeyboard = devices.firstOrNull()?.name) { showsSettings = true }
            StaffCard(state, Modifier.weight(1f))
            StatusLine(state)
            FeedbackLine(state)
            Controls(state, viewModel)
            StatsLine(state)
            // Hidden in the settings when playing on a real piano or a MIDI keyboard
            AnimatedVisibility(
                visible = state.showsKeyboard,
                enter = expandVertically(expandFrom = Alignment.Top) + fadeIn(),
                exit = shrinkVertically(shrinkTowards = Alignment.Top) + fadeOut(),
            ) {
                LearnKeyboard(
                    state = viewModel.keyboard,
                    modifier = Modifier.fillMaxWidth().height(keyboardHeight),
                    onWhiteKeyCount = viewModel::setWhiteKeyCount,
                    onKeyPress = { viewModel.keyPressed(it) },
                    onKeyRelease = viewModel::keyReleased,
                )
            }
        }
    }

    if (showsSettings) {
        SettingsSheet(state, viewModel) { showsSettings = false }
    }
}

// ---- Hand and Order

@Composable
private fun handName(hand: ReadingHand) = stringResource(
    when (hand) {
        ReadingHand.RIGHT -> R.string.learn_hand_right
        ReadingHand.LEFT -> R.string.learn_hand_left
        ReadingHand.BOTH -> R.string.reading_hand_both
    }
)

@Composable
private fun notesName(notes: ReadingNotes) = stringResource(
    when (notes) {
        ReadingNotes.ONE -> R.string.reading_notes_one
        ReadingNotes.TWO -> R.string.reading_notes_two
        ReadingNotes.ALL -> R.string.reading_notes_all
    }
)

@Composable
private fun orderName(order: ReadingOrder) =
    stringResource(if (order == ReadingOrder.SEQUENTIAL) R.string.learn_order_sequential else R.string.learn_order_random)

/**
 * What is being read (hand, notes, order: changed in the settings, which a tap opens) and, when one is plugged in,
 * the MIDI keyboard.
 */
@Composable
private fun SetupBar(state: ReadingUiState, connectedKeyboard: String?, onOpenSettings: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Surface(
            onClick = onOpenSettings,
            shape = RoundedCornerShape(8.dp),
            color = LearnColors.raised,
            border = BorderStroke(1.dp, LearnColors.border),
            modifier = Modifier.weight(1f, fill = false).height(32.dp),
        ) {
            Row(Modifier.padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ClefIcon(state.hand, LearnColors.text)
                Text(
                    "${handName(state.hand)} · ${notesName(state.notes)} · ${orderName(state.order)}",
                    color = LearnColors.text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Spacer(Modifier.weight(0.01f))
        AnimatedVisibility(visible = connectedKeyboard != null, enter = fadeIn(), exit = fadeOut()) {
            val description = stringResource(R.string.reading_keyboard_connected_named, connectedKeyboard.orEmpty())
            Row(
                Modifier
                    .height(32.dp)
                    .background(LearnColors.green.copy(alpha = 0.14f), RoundedCornerShape(8.dp))
                    .border(1.dp, LearnColors.green.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp)
                    .semantics(mergeDescendants = true) { contentDescription = description },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Icon(Icons.Filled.Piano, contentDescription = null, tint = LearnColors.green, modifier = Modifier.size(14.dp))
                Text(stringResource(R.string.reading_keyboard_connected), color = LearnColors.green, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            }
        }
    }
}

/** A small clef: sol for the right hand (and both hands), fá for the left. */
@Composable
private fun ClefIcon(hand: ReadingHand, color: Color) {
    Canvas(Modifier.size(width = 16.dp, height = 22.dp)) {
        val space = size.height / 7f
        if (hand != ReadingHand.LEFT) {
            trebleClef(0f, size.height, size.height, size.height - space * 2.4f, space, color)
        } else {
            val bassSpace = size.height / 4.6f
            bassClef(0f, size.height * 0.8f, bassSpace * 3.6f, size.height * 0.8f - bassSpace * 2.6f, bassSpace * 0.55f, color)
        }
    }
}

// ---- Staff

@Composable
private fun StaffCard(state: ReadingUiState, modifier: Modifier) {
    Box(
        modifier
            .padding(horizontal = 12.dp)
            .fillMaxWidth()
            .heightIn(min = 120.dp)
            .background(Color.White, RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center,
    ) {
        if (!state.isLoaded) return@Box
        if (!state.hasSteps) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(20.dp)) {
                Icon(Icons.Filled.MusicNote, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(30.dp))
                Text(
                    if (state.hand == ReadingHand.BOTH) stringResource(R.string.reading_score_has_no_notes)
                    else stringResource(R.string.learn_hand_has_no_notes, handName(state.hand).lowercase()),
                    color = StaffColors.ink, fontSize = 15.sp, textAlign = TextAlign.Center,
                )
            }
        } else {
            // A new segment fades in
            AnimatedContent(
                targetState = state,
                contentKey = { it.segmentSteps },
                transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(120)) },
                label = "readingSegment",
            ) { shown ->
                if (shown.hand == ReadingHand.BOTH) {
                    // Both hands: each note on its own staff, sol and fá, with the columns lined up
                    GrandStaff(
                        steps = shown.segmentSteps,
                        accidentals = shown.accidentals,
                        results = shown.results,
                        current = shown.current,
                        keySignature = shown.keySignature,
                        modifier = Modifier.fillMaxSize().padding(horizontal = 4.dp, vertical = 8.dp),
                        wrongPitch = shown.wrongPitch,
                        listeningStep = shown.listeningStep,
                    )
                } else {
                    ReadingStaff(
                        steps = shown.segmentSteps,
                        accidentals = shown.accidentals,
                        results = shown.results,
                        current = shown.current,
                        clef = shown.clef,
                        keySignature = shown.keySignature,
                        modifier = Modifier.fillMaxSize().padding(horizontal = 4.dp, vertical = 8.dp),
                        wrongPitch = shown.wrongPitch,
                        listeningStep = shown.listeningStep,
                    )
                }
            }
        }
    }
}

// ---- Status and Feedback

@Composable
private fun measuresLabel(measures: Pair<Int, Int>?): String {
    val (first, last) = measures ?: return ""
    if (first == 0) {
        return when (last) {
            0 -> stringResource(R.string.learn_pickup)
            1 -> stringResource(R.string.learn_pickup_and_measure_1)
            else -> stringResource(R.string.learn_pickup_and_measures, last)
        }
    }
    return if (first == last) stringResource(R.string.learn_measure, first) else stringResource(R.string.learn_measures, first, last)
}

@Composable
private fun StatusLine(state: ReadingUiState) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp).padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        val measures = measuresLabel(state.measures)
        Text(
            if (state.order == ReadingOrder.SEQUENTIAL && state.segmentCount > 0) {
                stringResource(R.string.learn_segment_of, state.segmentNumber, state.segmentCount, measures)
            } else measures,
            color = LearnColors.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
            overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
        )
        if (state.segmentSteps.isNotEmpty()) {
            val total = state.segmentSteps.size
            Text(
                stringResource(R.string.learn_note_of, minOf(state.current + 1, total), total),
                color = LearnColors.text, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.background(LearnColors.raised, RoundedCornerShape(6.dp)).padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
    }
}

@Composable
private fun FeedbackLine(state: ReadingUiState) {
    val (icon, text, color) = when (val feedback = state.feedback) {
        is ReadingFeedback.Prompt -> if (feedback.chord > 1) {
            Triple(Icons.Filled.TouchApp, stringResource(R.string.learn_drill_prompt_chord, feedback.chord), LearnColors.text)
        } else {
            Triple(Icons.Filled.TouchApp, stringResource(R.string.learn_drill_prompt), LearnColors.text)
        }
        is ReadingFeedback.Correct -> Triple(Icons.Filled.CheckCircle, stringResource(R.string.learn_correct, feedback.name), LearnColors.green)
        is ReadingFeedback.Wrong -> Triple(Icons.Filled.Cancel, stringResource(R.string.learn_wrong, feedback.name), LearnColors.red)
        is ReadingFeedback.Revealed -> Triple(Icons.Outlined.Lightbulb, stringResource(R.string.learn_revealed, feedback.name), LearnColors.amber)
        is ReadingFeedback.SegmentDone -> if (feedback.clean == feedback.total) {
            Triple(Icons.Filled.Star, stringResource(R.string.learn_segment_perfect, feedback.total, feedback.total), LearnColors.green)
        } else {
            Triple(Icons.Filled.SportsScore, stringResource(R.string.learn_segment_done, feedback.clean, feedback.total), LearnColors.amber)
        }
        ReadingFeedback.NoNotes -> Triple(Icons.Filled.MusicNote, stringResource(R.string.learn_choose_other_hand), LearnColors.muted)
    }
    val animated by animateColorAsState(color, tween(150), label = "drillFeedback")
    Row(
        Modifier.fillMaxWidth().height(44.dp).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(icon, contentDescription = null, tint = animated, modifier = Modifier.size(20.dp))
        Text(text, color = animated, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

// ---- Controls

@Composable
private fun Controls(state: ReadingUiState, viewModel: ReadingTrainerViewModel) {
    val done = state.isSegmentComplete && state.segmentSteps.isNotEmpty()
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ControlButton(Icons.Filled.FastRewind, stringResource(R.string.learn_previous), enabled = state.canGoBack) { viewModel.previousSegment() }
        ControlButton(Icons.AutoMirrored.Filled.VolumeUp, stringResource(R.string.learn_listen)) { viewModel.listen() }
        ControlButton(Icons.Outlined.Lightbulb, stringResource(R.string.learn_hint), enabled = !state.isSegmentComplete) { viewModel.reveal() }
        ControlButton(Icons.Filled.Replay, stringResource(R.string.learn_repeat)) { viewModel.repeatSegment() }

        val nextLabel = stringResource(R.string.learn_next_segment)
        val shape = RoundedCornerShape(10.dp)
        Button(
            onClick = viewModel::nextSegment,
            enabled = state.hasSteps,
            shape = shape,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent, disabledContainerColor = Color.Transparent),
            modifier = Modifier
                .weight(1f)
                .height(40.dp)
                .shadow(if (done) 8.dp else 0.dp, shape, ambientColor = LearnColors.blue, spotColor = LearnColors.blue)
                .background(
                    if (done) Brush.verticalGradient(listOf(LearnColors.blue, LearnColors.deepBlue)) else Brush.linearGradient(listOf(LearnColors.raised, LearnColors.raised)),
                    shape,
                )
                .border(1.dp, if (done) LearnColors.blue else LearnColors.border, shape)
                .semantics { this.contentDescription = nextLabel },
        ) {
            Text(stringResource(R.string.learn_next_short), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(6.dp))
            Icon(Icons.Filled.FastForward, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
private fun ControlButton(icon: ImageVector, label: String, enabled: Boolean = true, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(8.dp),
        color = LearnColors.raised,
        border = BorderStroke(1.dp, LearnColors.border),
        modifier = Modifier.size(width = 50.dp, height = 40.dp).alpha(if (enabled) 1f else 0.4f),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Icon(icon, contentDescription = null, tint = LearnColors.text, modifier = Modifier.size(16.dp))
            Text(label, color = LearnColors.text, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

// ---- Session Results

@Composable
private fun StatsLine(state: ReadingUiState) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(Icons.Filled.Verified, contentDescription = null, tint = LearnColors.green, modifier = Modifier.size(13.dp))
            Text(
                if (state.answered == 0) stringResource(R.string.learn_first_try_none)
                else stringResource(R.string.learn_first_try, state.cleanPercentage, state.answeredClean, state.answered),
                color = LearnColors.text, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = LearnColors.orange, modifier = Modifier.size(13.dp))
            Text(stringResource(R.string.learn_streak, state.streak), color = LearnColors.text, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
        }
        if (state.bestStreak > 0) {
            Text(stringResource(R.string.learn_best_streak, state.bestStreak), color = LearnColors.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
        }
    }
}

// ---- Settings

@Composable
private fun clefChoiceName(choice: ClefChoice) = stringResource(
    when (choice) {
        ClefChoice.SCORE -> R.string.learn_clef_choice_score
        ClefChoice.AUTOMATIC -> R.string.learn_clef_choice_automatic
        ClefChoice.TREBLE -> R.string.learn_clef_choice_treble
        ClefChoice.BASS -> R.string.learn_clef_choice_bass
        ClefChoice.ALTO -> R.string.learn_clef_choice_alto
    }
)

@Composable
private fun keyLabelsName(labels: ReadingKeyLabels) = when (labels) {
    ReadingKeyLabels.SOLFEGE -> stringResource(R.string.learn_key_labels_solfege)
    ReadingKeyLabels.LETTERS -> "C D E"
    ReadingKeyLabels.OCTAVES_ONLY -> stringResource(R.string.learn_key_labels_octaves)
    ReadingKeyLabels.HIDDEN -> stringResource(R.string.learn_key_labels_hidden)
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun SettingsSheet(state: ReadingUiState, viewModel: ReadingTrainerViewModel, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = LearnColors.panel,
        contentColor = LearnColors.text,
    ) {
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 16.dp)
                .windowInsetsPadding(WindowInsets.navigationBars),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(stringResource(R.string.learn_drill_settings), fontSize = 18.sp, fontWeight = FontWeight.Bold)

            SettingSection(stringResource(R.string.reading_hand)) {
                for (hand in ReadingHand.entries) {
                    Choice(handName(hand), state.hand == hand) { viewModel.setHand(hand) }
                }
            }
            SettingSection(stringResource(R.string.reading_notes)) {
                for (notes in ReadingNotes.entries) {
                    Choice(notesName(notes), state.notes == notes) { viewModel.setNotes(notes) }
                }
            }
            SettingSection(stringResource(R.string.learn_order)) {
                for (order in ReadingOrder.entries) {
                    Choice(orderName(order), state.order == order) { viewModel.setOrder(order) }
                }
            }
            SettingSection(stringResource(R.string.learn_notes_per_segment)) {
                for (size in ReadingTrainerViewModel.SEGMENT_SIZES) {
                    Choice(pluralStringResource(R.plurals.learn_notes_count, size, size), state.segmentSize == size) { viewModel.setSegmentSize(size) }
                }
            }
            // Both hands read sol and fá, as the piece is written
            if (state.hand != ReadingHand.BOTH) {
                SettingSection(stringResource(R.string.learn_clef_for_hand, handName(state.hand).lowercase())) {
                    for (choice in ClefChoice.entries) {
                        Choice(clefChoiceName(choice), state.clefChoice == choice) { viewModel.setClefChoice(choice) }
                    }
                }
            }
            if (state.hand != ReadingHand.BOTH && state.clefChoice == ClefChoice.AUTOMATIC) {
                SwitchRow(stringResource(R.string.learn_automatic_uses_alto), state.automaticUsesAlto, viewModel::setAutomaticUsesAlto)
            }
            SettingSection(stringResource(R.string.learn_key_labels)) {
                for (labels in ReadingKeyLabels.entries) {
                    Choice(keyLabelsName(labels), state.keyLabels == labels) { viewModel.setKeyLabels(labels) }
                }
            }
            SwitchRow(stringResource(R.string.reading_show_keyboard), state.showsKeyboard, viewModel::setShowsKeyboard)
            SwitchRow(stringResource(R.string.learn_auto_advance), state.advancesAutomatically, viewModel::setAdvancesAutomatically)
            if (state.order == ReadingOrder.SEQUENTIAL) {
                OutlinedButton(
                    onClick = {
                        viewModel.restartPiece()
                        onDismiss()
                    },
                    border = BorderStroke(1.dp, LearnColors.border),
                ) {
                    Icon(Icons.Filled.SkipPrevious, contentDescription = null, tint = LearnColors.cyan)
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.learn_restart_piece), color = LearnColors.cyan)
                }
            }
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) {
                Text(stringResource(R.string.action_done), color = LearnColors.cyan)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SettingSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, color = LearnColors.muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { content() }
    }
}

@Composable
private fun Choice(label: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            containerColor = LearnColors.raised,
            labelColor = LearnColors.text,
            selectedContainerColor = LearnColors.deepBlue,
            selectedLabelColor = Color.White,
        ),
    )
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
