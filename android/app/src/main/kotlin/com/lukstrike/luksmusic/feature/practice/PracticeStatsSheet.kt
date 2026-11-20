// PracticeStatsSheet.kt — the summary after a practice session (port of Views/Practice/PracticeStatsView.swift): the
// accuracy ring, the counts, the session's details and a star rating.
package com.lukstrike.luksmusic.feature.practice

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.PracticeSession
import com.lukstrike.luksmusic.ui.theme.LuksColors
import kotlin.math.roundToInt

private val starYellow = Color(1f, 0.8f, 0f)
private val statBlue = Color(0f, 0.48f, 1f)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PracticeStatsSheet(session: PracticeSession, onRate: (Int) -> Unit, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    // Kept with the session when it was saved (the live summary from the menu only shows it)
    var rating by remember(session.id) { mutableIntStateOf(session.difficultyRating ?: 4) }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.practice_summary),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.practice_close)) }
            }
            AccuracyRingCard(session)
            StatsGrid(session)
            SessionDetailsCard(session)
            RatingSection(rating) { star -> rating = star; onRate(star) }
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(stringResource(R.string.practice_done), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 6.dp))
            }
        }
    }
}

@Composable
private fun Card(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(16.dp))) { content() }
}

@Composable
private fun AccuracyRingCard(session: PracticeSession) {
    val accuracy = session.accuracy
    val ringColor = when {
        accuracy >= 80 -> LuksColors.success
        accuracy >= 60 -> LuksColors.warning
        else -> LuksColors.noteIncorrect
    }
    val trackColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f)
    // The ring fills up when the sheet opens
    val progress = remember { Animatable(0f) }
    LaunchedEffect(accuracy) { progress.animateTo((accuracy / 100.0).toFloat(), tween(700)) }

    Card(Modifier.fillMaxWidth()) {
        Column(
            Modifier.fillMaxWidth().padding(vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.size(140.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.size(140.dp)) {
                    val stroke = 14.dp.toPx()
                    val inset = stroke / 2
                    val arcSize = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke)
                    val topLeft = androidx.compose.ui.geometry.Offset(inset, inset)
                    drawArc(trackColor, 0f, 360f, false, topLeft, arcSize, style = Stroke(stroke))
                    drawArc(ringColor, -90f, 360f * progress.value, false, topLeft, arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        stringResource(R.string.practice_percent, accuracy.roundToInt()),
                        fontSize = 32.sp, fontWeight = FontWeight.Bold,
                    )
                    Text(
                        stringResource(R.string.practice_accuracy),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    session.scoreTitle,
                    style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Text(
                    stringResource(session.practiceMode.labelRes),
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary,
                )
            }
        }
    }
}

@Composable
private fun StatsGrid(session: PracticeSession) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatItem(stringResource(R.string.practice_stats_correct), session.correctNotes, Icons.Filled.CheckCircle, LuksColors.success, Modifier.weight(1f))
            StatItem(stringResource(R.string.practice_stats_wrong), session.incorrectNotes, Icons.Filled.Cancel, LuksColors.noteIncorrect, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatItem(stringResource(R.string.practice_stats_longest_streak), session.longestStreak, Icons.Filled.LocalFireDepartment, LuksColors.warning, Modifier.weight(1f))
            StatItem(stringResource(R.string.practice_stats_played), session.totalNotesPlayed, Icons.Filled.Piano, statBlue, Modifier.weight(1f))
        }
    }
}

@Composable
private fun StatItem(title: String, value: Int, icon: ImageVector, color: Color, modifier: Modifier) {
    Box(modifier.background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(12.dp))) {
        Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(28.dp))
            Spacer(Modifier.width(12.dp))
            Column {
                Text(value.toString(), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun SessionDetailsCard(session: PracticeSession) {
    val seconds = session.durationSeconds.toInt()
    Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(12.dp))) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            DetailRow(stringResource(R.string.practice_stats_tempo), stringResource(R.string.practice_bpm, session.tempoUsed))
            HorizontalDivider()
            DetailRow(stringResource(R.string.practice_stats_sections), session.sectionsCompleted.toString())
            HorizontalDivider()
            DetailRow(
                stringResource(R.string.practice_stats_duration),
                stringResource(R.string.practice_stats_duration_value, seconds / 60, seconds % 60),
            )
        }
    }
}

@Composable
private fun DetailRow(title: String, value: String) {
    Row(Modifier.fillMaxWidth()) {
        Text(title, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun RatingSection(rating: Int, onRate: (Int) -> Unit) {
    Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(12.dp))) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                stringResource(R.string.practice_stats_rating),
                style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (star in 1..5) {
                    val description = pluralStringResource(R.plurals.practice_stats_stars, star, star)
                    Icon(
                        if (star <= rating) Icons.Filled.Star else Icons.Outlined.StarOutline,
                        contentDescription = description,
                        tint = starYellow,
                        modifier = Modifier
                            .size(32.dp)
                            .selectable(selected = star == rating, role = Role.RadioButton) { onRate(star) },
                    )
                }
            }
        }
    }
}
