// ScoreListItem.kt — port of luksMusic/Views/Library/ScoreListItemView.swift: a score of the library as a grid
// card or a list row, with its cover, difficulty badge, source and when it was last practiced.
package com.lukstrike.luksmusic.feature.library

import android.text.format.DateUtils
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.ScoreSource
import com.lukstrike.luksmusic.ui.theme.LuksColors

private val Favorite = Color(1f, 0.8f, 0f)

@Composable
fun ScoreGridCard(score: Score, modifier: Modifier = Modifier) {
    Column(modifier) {
        SheetCover(score.title, Modifier.fillMaxWidth().height(190.dp), subtitle = score.composer)
        Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    score.title,
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (score.isFavorite) FavoriteStar()
            }
            if (score.composer.isNotEmpty()) {
                Text(
                    score.composer,
                    style = MaterialTheme.typography.bodySmall,
                    color = LuksColors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                DifficultyBadge(score.difficulty)
                Spacer(Modifier.weight(1f))
                SourceIcon(score.source)
            }
            score.lastPracticed?.let { LastPracticed(it) }
        }
    }
}

@Composable
fun ScoreListRow(score: Score, modifier: Modifier = Modifier) {
    Row(modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        SheetCover(score.title, Modifier.size(64.dp).clip(RoundedCornerShape(10.dp)), subtitle = score.composer)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    score.title,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (score.isFavorite) {
                    Spacer(Modifier.width(6.dp))
                    FavoriteStar()
                }
            }
            if (score.composer.isNotEmpty()) {
                Text(
                    score.composer,
                    style = MaterialTheme.typography.bodyMedium,
                    color = LuksColors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DifficultyBadge(score.difficulty)
                if (score.estimatedDuration > 0) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                        Icon(Icons.Outlined.Schedule, contentDescription = null, tint = LuksColors.textSecondary, modifier = Modifier.size(12.dp))
                        Text(durationString(score.estimatedDuration), style = MaterialTheme.typography.labelSmall, color = LuksColors.textSecondary)
                    }
                }
                SourceIcon(score.source)
            }
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            score.lastPracticed?.let { LastPracticed(it) }
            Icon(
                Icons.AutoMirrored.Outlined.KeyboardArrowRight,
                contentDescription = null,
                tint = LuksColors.textSecondary.copy(alpha = 0.5f),
            )
        }
    }
}

@Composable
private fun FavoriteStar() = Icon(
    Icons.Filled.Star,
    contentDescription = stringResource(R.string.library_favorite_badge),
    tint = Favorite,
    modifier = Modifier.size(14.dp),
)

/** Color-coded difficulty badge. */
@Composable
fun DifficultyBadge(difficulty: Difficulty) {
    val color = difficultyColor(difficulty)
    Text(
        stringResource(difficultyLabel(difficulty)),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        color = color,
        maxLines = 1,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(color.copy(alpha = 0.2f))
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}

@Composable
private fun SourceIcon(source: ScoreSource) =
    Icon(sourceIcon(source), contentDescription = stringResource(sourceLabel(source)), tint = LuksColors.textSecondary, modifier = Modifier.size(14.dp))

/** "2 days ago", in the app's language. */
@Composable
private fun LastPracticed(time: Long) {
    Text(
        DateUtils.getRelativeTimeSpanString(time, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString(),
        style = MaterialTheme.typography.labelSmall,
        color = LuksColors.textSecondary.copy(alpha = 0.7f),
    )
}

/** "3:45". */
private fun durationString(seconds: Double): String {
    val total = seconds.toInt()
    return "%d:%02d".format(total / 60, total % 60)
}

fun difficultyColor(difficulty: Difficulty): Color = when (difficulty) {
    Difficulty.BEGINNER -> Color(0.20f, 0.78f, 0.35f)
    Difficulty.INTERMEDIATE -> Color(1f, 0.8f, 0f)
    Difficulty.ADVANCED -> Color(1f, 0.58f, 0f)
    Difficulty.EXPERT -> Color(1f, 0.23f, 0.19f)
}

@StringRes
fun difficultyLabel(difficulty: Difficulty): Int = when (difficulty) {
    Difficulty.BEGINNER -> R.string.difficulty_beginner
    Difficulty.INTERMEDIATE -> R.string.difficulty_intermediate
    Difficulty.ADVANCED -> R.string.difficulty_advanced
    Difficulty.EXPERT -> R.string.difficulty_expert
}

@StringRes
fun sourceLabel(source: ScoreSource): Int = when (source) {
    ScoreSource.MANUAL -> R.string.source_manual
    ScoreSource.IMPORTED -> R.string.source_imported
    ScoreSource.SCANNED -> R.string.source_scanned
}

fun sourceIcon(source: ScoreSource): ImageVector = when (source) {
    ScoreSource.MANUAL -> Icons.Outlined.Edit
    ScoreSource.IMPORTED -> Icons.Outlined.FileDownload
    ScoreSource.SCANNED -> Icons.Outlined.PhotoCamera
}
