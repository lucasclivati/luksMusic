// EditorScreen.kt — port of luksMusic/Views/Editor/EditorView.swift: the score editor. The grand staff on top
// (tap a measure to put the cursor there), the cursor's position, the palette (EditorToolbar) and the step-input
// keyboard (NoteInputKeyboard).
package com.lukstrike.luksmusic.feature.library.editor

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.Staff
import com.lukstrike.luksmusic.ui.theme.LuksColors
import java.util.Locale

private const val LINE_SPACING = 11f
private const val MEASURE_WIDTH = 170f

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditorScreen(scoreId: String, onClose: () -> Unit) {
    val container = appContainer()
    val viewModel: EditorViewModel = viewModel(key = "editor-$scoreId") { EditorViewModel(container, scoreId) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    var confirmDiscard by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(state.isMissing) { if (state.isMissing) onClose() }

    val close = { if (state.hasChanges) confirmDiscard = true else onClose() }
    BackHandler(enabled = state.hasChanges) { confirmDiscard = true }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.editor_title)) },
                navigationIcon = { TextButton(onClick = close) { Text(stringResource(R.string.editor_close)) } },
                actions = {
                    TextButton(onClick = { viewModel.save(onClose) }, enabled = state.score != null) {
                        Text(stringResource(R.string.editor_save), fontWeight = FontWeight.Bold)
                    }
                },
            )
        },
    ) { padding ->
        if (state.score == null) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@Scaffold
        }
        val score = state.score!!
        Column(Modifier.fillMaxSize().padding(top = padding.calculateTopPadding())) {
            // Score in edit mode: white paper, scrolled to keep the selected measure in view
            val listState = rememberLazyListState()
            val density = LocalDensity.current
            LaunchedEffect(state.selectedMeasureIndex) {
                val item = state.selectedMeasureIndex + 1 // item 0 is the clef block
                val info = listState.layoutInfo
                val shown = info.visibleItemsInfo.firstOrNull { it.index == item }
                val fullyShown = shown != null && shown.offset >= info.viewportStartOffset &&
                    shown.offset + shown.size <= info.viewportEndOffset
                if (fullyShown) return@LaunchedEffect
                // Centre the measure (iOS scrollTo(anchor: .center)); the first one keeps the clefs in view
                if (state.selectedMeasureIndex == 0) {
                    listState.animateScrollToItem(0)
                } else {
                    val measurePx = with(density) { MEASURE_WIDTH.dp.toPx() }
                    listState.animateScrollToItem(item, -((info.viewportSize.width - measurePx) / 2).toInt().coerceAtLeast(0))
                }
            }
            LazyRow(
                state = listState,
                modifier = Modifier.fillMaxWidth().background(Color.White),
                contentPadding = PaddingValues(start = 16.dp, end = 40.dp, top = 12.dp, bottom = 12.dp),
            ) {
                item(key = "clefs") {
                    StaffClefs(LINE_SPACING, score.keySignatureValue, score.timeSignatureTop, score.timeSignatureBottom)
                }
                itemsIndexed(state.measures, key = { _, measure -> measure.id }) { index, measure ->
                    MeasureStaff(
                        measure = measure,
                        isCurrent = index == state.selectedMeasureIndex,
                        currentBeat = state.selectedBeat,
                        lineSpacing = LINE_SPACING,
                        measureWidth = MEASURE_WIDTH,
                        modifier = Modifier.clickable { viewModel.selectMeasure(index) },
                    )
                }
            }
            HorizontalDivider()

            // Cursor and position
            Row(
                Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(horizontal = 16.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.editor_position, state.selectedMeasureIndex + 1, String.format(Locale.ROOT, "%.1f", state.selectedBeat)),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.weight(1f))
                val staffName = stringResource(
                    if (state.selectedStaff == Staff.TREBLE) R.string.editor_staff_treble_long else R.string.editor_staff_bass_long
                )
                Text(
                    stringResource(R.string.editor_staff_label, staffName),
                    style = MaterialTheme.typography.labelMedium,
                    color = LuksColors.textSecondary,
                )
            }

            EditorToolbar(state, viewModel)
            HorizontalDivider()

            // Step-input keyboard
            Column(
                Modifier.fillMaxWidth().weight(1f).background(MaterialTheme.colorScheme.surfaceContainer).navigationBarsPadding()
                    .padding(bottom = 8.dp),
                verticalArrangement = Arrangement.Top,
            ) {
                Text(
                    stringResource(R.string.editor_keyboard_hint),
                    style = MaterialTheme.typography.labelSmall,
                    color = LuksColors.textSecondary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                )
                NoteInputKeyboard(selectedAccidental = state.selectedAccidental, onPitch = viewModel::insertNote)
            }
        }
    }

    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text(stringResource(R.string.editor_discard_title)) },
            text = { Text(stringResource(R.string.editor_discard_message)) },
            confirmButton = {
                TextButton(onClick = { confirmDiscard = false; onClose() }) {
                    Text(stringResource(R.string.editor_discard), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { confirmDiscard = false }) { Text(stringResource(R.string.editor_keep_editing)) } },
        )
    }
}
