// PracticeHistoryScreen.kt — the Progresso tab (iOS App/ContentView.swift, PracticeHistoryView): a summary of every
// practice session (count, average accuracy, longest streak) and the sessions, most recent first.
package com.lukstrike.luksmusic.feature.account

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Piano
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.model.PracticeSession
import com.lukstrike.luksmusic.ui.theme.LuksColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** At or above this accuracy a session's ring is green, below it orange (as on iOS). */
private const val GOOD_ACCURACY = 80.0

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PracticeHistoryScreen() {
    val sessions by appContainer().practice.sessions.collectAsStateWithLifecycle()
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            LargeTopAppBar(title = { Text(stringResource(R.string.tab_progress)) }, scrollBehavior = scrollBehavior)
        },
        // The tab bar below already keeps the content above the navigation bar
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        if (sessions.isEmpty()) {
            EmptyHistory(Modifier.padding(padding))
        } else {
            val locale = LocalConfiguration.current.locales[0]
            val dateFormatter = remember(locale) { sessionDateFormatter(locale) }
            LazyColumn(Modifier.fillMaxSize(), contentPadding = padding) {
                item(key = "summary") { SummaryCard(sessions, locale) }
                item(key = "recentHeader") { SectionHeader(stringResource(R.string.account_progress_recent)) }
                itemsIndexed(sessions, key = { _, session -> session.id }) { index, session ->
                    SessionRow(
                        session = session,
                        locale = locale,
                        date = dateFormatter.format(Instant.ofEpochMilli(session.startTime).atZone(ZoneId.systemDefault())),
                        shape = groupShape(index, sessions.size),
                        showDivider = index > 0,
                        modifier = Modifier.animateItem(),
                    )
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

@Composable
private fun EmptyHistory(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().padding(horizontal = 32.dp), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.padding(vertical = 40.dp),
        ) {
            Icon(
                Icons.Outlined.Piano,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(44.dp),
            )
            Text(stringResource(R.string.account_progress_empty_title), style = MaterialTheme.typography.titleMedium)
            Text(
                stringResource(R.string.account_progress_empty_message),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun SummaryCard(sessions: List<PracticeSession>, locale: Locale) {
    val averageAccuracy = if (sessions.isEmpty()) 0.0 else sessions.sumOf { it.accuracy } / sessions.size
    val maxStreak = sessions.maxOfOrNull { it.longestStreak } ?: 0

    Surface(
        shape = RoundedCornerShape(SectionCorner),
        color = MaterialTheme.colorScheme.surfaceContainer,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Stat(value = sessions.size.toString(), label = stringResource(R.string.account_progress_sessions))
            Stat(
                value = percent(averageAccuracy, locale),
                label = stringResource(R.string.account_progress_average_accuracy),
                color = LuksColors.success,
            )
            Stat(
                value = maxStreak.toString(),
                label = stringResource(R.string.account_progress_longest_streak),
                color = LuksColors.warning,
            )
        }
    }
}

@Composable
private fun Stat(value: String, label: String, color: Color = MaterialTheme.colorScheme.onSurface) {
    Column(
        verticalArrangement = Arrangement.spacedBy(2.dp),
        modifier = Modifier.semantics(mergeDescendants = true) {},
    ) {
        Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = color)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun SessionRow(
    session: PracticeSession,
    locale: Locale,
    date: String,
    shape: RoundedCornerShape,
    showDivider: Boolean,
    modifier: Modifier = Modifier,
) {
    Surface(
        shape = shape,
        color = MaterialTheme.colorScheme.surfaceContainer,
        modifier = modifier.padding(horizontal = 16.dp).fillMaxWidth(),
    ) {
        Column {
            if (showDivider) SectionDivider()
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 12.dp)
                    .semantics(mergeDescendants = true) {},
            ) {
                AccuracyRing(session.accuracy, locale)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        session.scoreTitle,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        pluralStringResource(
                            R.plurals.account_progress_session_detail,
                            session.totalNotesPlayed,
                            practiceModeName(session.practiceMode),
                            session.totalNotesPlayed,
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(date, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** The session's accuracy as a ring that fills when it appears. */
@Composable
private fun AccuracyRing(accuracy: Double, locale: Locale) {
    val color = if (accuracy >= GOOD_ACCURACY) LuksColors.success else LuksColors.warning
    val track = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f)
    val fraction = (accuracy / 100.0).toFloat().coerceIn(0f, 1f)
    val progress = remember { Animatable(0f) }
    LaunchedEffect(fraction) { progress.animateTo(fraction, tween(600, easing = FastOutSlowInEasing)) }
    val label = percent(accuracy, locale)

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.size(36.dp).clearAndSetSemantics { contentDescription = label },
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = 4.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(track, 0f, 360f, useCenter = false, topLeft = Offset(inset, inset), size = arcSize, style = Stroke(stroke))
            drawArc(
                color, -90f, 360f * progress.value, useCenter = false,
                topLeft = Offset(inset, inset), size = arcSize, style = Stroke(stroke),
            )
        }
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}

@Composable
private fun practiceModeName(mode: PracticeMode): String = stringResource(
    when (mode) {
        PracticeMode.FREE_PLAY -> R.string.account_mode_free_play
        PracticeMode.GUIDED -> R.string.account_mode_guided
        PracticeMode.HANDS_SEPARATE_RIGHT -> R.string.account_mode_right_hand
        PracticeMode.HANDS_SEPARATE_LEFT -> R.string.account_mode_left_hand
        PracticeMode.SLOW_PRACTICE -> R.string.account_mode_slow
    }
)

/** "87%" (iOS `String(format: "%.0f%%", …)`). */
private fun percent(value: Double, locale: Locale): String = String.format(locale, "%.0f%%", value)

/** Month, day, hour and minute in the order and clock of [locale] (iOS `.dateTime.month().day().hour().minute()`). */
private fun sessionDateFormatter(locale: Locale): DateTimeFormatter {
    val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "MMMdjmm")
    return runCatching { DateTimeFormatter.ofPattern(pattern, locale) }
        .getOrElse { DateTimeFormatter.ofLocalizedDateTime(java.time.format.FormatStyle.SHORT).withLocale(locale) }
}

/** Rows of one card: the first rounds its top corners, the last its bottom ones. */
private fun groupShape(index: Int, count: Int): RoundedCornerShape {
    val top = if (index == 0) SectionCorner else 0.dp
    val bottom = if (index == count - 1) SectionCorner else 0.dp
    return RoundedCornerShape(topStart = top, topEnd = top, bottomStart = bottom, bottomEnd = bottom)
}
