// LibraryScreen.kt — the first screen: the bundled samples and the imported scores as big cards, each opening the
// sight-reading drill or Modo Estudo. The arrows (the D-pad) move the selection, Enter opens the drill, P Modo Estudo.
package com.lukstrike.luksmusic.desktop.library

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileOpen
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.desktop.ui.ActionButton
import com.lukstrike.luksmusic.desktop.ui.LocalStrings
import com.lukstrike.luksmusic.desktop.ui.MidiStatus
import com.lukstrike.luksmusic.desktop.ui.Palette
import com.lukstrike.luksmusic.desktop.ui.SquareIconButton
import com.lukstrike.luksmusic.desktop.ui.TopBar

const val LIBRARY_COLUMNS = 3

@Composable
fun LibraryScreen(
    scores: List<Score>,
    selected: Int,
    connected: List<String>,
    message: String?,
    onSelect: (Int) -> Unit,
    onDrill: (Score) -> Unit,
    onStudy: (Score) -> Unit,
    onImport: () -> Unit,
    onDelete: (Score) -> Unit,
    onSettings: () -> Unit,
) {
    val strings = LocalStrings.current
    val grid = rememberLazyGridState()
    LaunchedEffect(selected) { if (selected in scores.indices) grid.animateScrollToItem(selected) }
    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar("luksMusic · ${strings.library}", message ?: strings.librarySubtitle, onBack = null) {
            MidiStatus(connected, onSettings)
            ActionButton(strings.importScore, Icons.Filled.FileOpen, hint = "I", onClick = onImport)
            SquareIconButton(Icons.Filled.Settings, strings.settings, onClick = onSettings)
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(LIBRARY_COLUMNS),
            state = grid,
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.weight(1f).fillMaxWidth(),
        ) {
            itemsIndexed(scores, key = { _, s -> s.id }) { index, score ->
                ScoreCard(score, index == selected, { onSelect(index) }, { onDrill(score) }, { onStudy(score) }, { onDelete(score) })
            }
        }
    }
}

@Composable
private fun ScoreCard(
    score: Score,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onDrill: () -> Unit,
    onStudy: () -> Unit,
    onDelete: () -> Unit,
) {
    val strings = LocalStrings.current
    Column(
        Modifier
            .fillMaxWidth()
            .height(300.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(if (isSelected) Palette.raisedHigh else Palette.panel)
            .border(if (isSelected) 3.dp else 1.dp, if (isSelected) Palette.blue else Palette.border, RoundedCornerShape(18.dp))
            .clickable(onClick = onSelect)
            .padding(18.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(52.dp).clip(RoundedCornerShape(12.dp)).background(Palette.deepBlue.copy(alpha = 0.25f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.LibraryMusic, contentDescription = null, tint = Palette.cyan, modifier = Modifier.size(30.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(score.title, color = Palette.text, fontSize = 21.sp, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis, lineHeight = 24.sp)
                Text(score.composer, color = Palette.muted, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            if (!score.isSample) {
                Box(Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).clickable(onClick = onDelete), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Delete, contentDescription = strings.deleteScore, tint = Palette.muted)
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Badge(if (score.isSample) strings.sample else strings.imported, if (score.isSample) Palette.violet else Palette.amber)
            Badge(strings.measures(score.measureCount), Palette.muted)
            Badge(strings.notes(score.totalNoteCount), Palette.muted)
        }
        Spacer(Modifier.weight(1f))
        ActionButton(strings.readingDrill, Icons.AutoMirrored.Filled.MenuBook, Modifier.fillMaxWidth(), primary = isSelected, hint = if (isSelected) "Enter  A" else null, onClick = onDrill)
        Spacer(Modifier.height(10.dp))
        ActionButton(strings.studyMode, Icons.Filled.Piano, Modifier.fillMaxWidth(), hint = if (isSelected) "P" else null, onClick = onStudy)
    }
}

@Composable
private fun Badge(text: String, color: Color) {
    Text(
        text, color = color, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(color.copy(alpha = 0.12f)).padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/** The selection after an arrow in a grid of [count] cards, [columns] wide (pure, tested). */
object LibraryNavigation {
    fun move(selected: Int, count: Int, columns: Int, dx: Int, dy: Int): Int {
        if (count <= 0) return 0
        val current = selected.coerceIn(0, count - 1)
        val next = current + dx + dy * columns
        return if (next in 0 until count) next else current
    }
}
