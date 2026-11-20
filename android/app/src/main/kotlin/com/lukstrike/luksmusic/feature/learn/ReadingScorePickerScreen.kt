// ReadingScorePickerScreen.kt — which score of the library to read in the drill. On iOS the drill is opened from
// a score's screen; the Aprender tab on Android also reaches it here, with the scores of the library.
package com.lukstrike.luksmusic.feature.learn

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.Score

@Composable
fun ReadingScorePickerScreen(onBack: () -> Unit, onPick: (String) -> Unit) {
    val container = appContainer()
    val scores by container.scores.scores.collectAsStateWithLifecycle()
    val loaded by container.scores.isLoaded.collectAsStateWithLifecycle()

    Column(Modifier.fillMaxSize().background(LearnColors.background)) {
        LearnTopBar(stringResource(R.string.learn_drill_title), stringResource(R.string.learn_drill_pick_score), onBack = onBack)
        when {
            !loaded -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            scores.isEmpty() -> Column(
                Modifier.fillMaxSize().padding(32.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Filled.LibraryMusic, contentDescription = null, tint = LearnColors.muted, modifier = Modifier.size(40.dp))
                Text(stringResource(R.string.learn_drill_no_scores), color = LearnColors.muted, textAlign = TextAlign.Center)
            }
            else -> LazyColumn(
                contentPadding = PaddingValues(
                    start = 16.dp, end = 16.dp, top = 12.dp,
                    bottom = 16.dp + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding(),
                ),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item {
                    Text(stringResource(R.string.learn_drill_intro), color = LearnColors.muted, fontSize = 14.sp)
                }
                items(scores, key = { it.id }) { score -> ScoreRow(score) { onPick(score.id) } }
            }
        }
    }
}

@Composable
private fun ScoreRow(score: Score, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(LearnColors.panel, RoundedCornerShape(12.dp))
            .border(1.dp, LearnColors.raised, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(score.title, color = LearnColors.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                "${score.composer} • ${pluralStringResource(R.plurals.learn_notes_count, score.totalNoteCount, score.totalNoteCount)}",
                color = LearnColors.muted, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = LearnColors.muted)
    }
}
