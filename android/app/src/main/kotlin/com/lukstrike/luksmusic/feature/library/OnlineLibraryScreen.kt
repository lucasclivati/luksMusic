// OnlineLibraryScreen.kt — port of luksMusic/Views/Library/OnlineLibraryView.swift ("Ver todas") and
// Views/Score/OnlineScoreView.swift: the whole luksMusic catalog this account can download, public-domain editions
// for everyone plus private scores for their author and the people the author invited by e-mail. Opening one
// downloads it to the phone (OnlineScoreScreen) and plays it like the user's own scores.
package com.lukstrike.luksmusic.feature.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.LibraryMusic
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.WifiOff
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.ui.theme.LuksColors
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private val PrivatePurple = Color(0.69f, 0.32f, 0.87f)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnlineLibraryScreen(onBack: () -> Unit, onOpen: (OnlineScore) -> Unit) {
    val context = LocalContext.current
    val container = appContainer()
    val library = remember { OnlineLibraryService.get(context) }
    val scores by library.scores.collectAsStateWithLifecycle()
    val isLoading by library.isLoading.collectAsStateWithLifecycle()
    val error by library.errorMessage.collectAsStateWithLifecycle()
    val localScores by container.scores.scores.collectAsStateWithLifecycle()
    val user by container.auth.currentUser.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val downloaded = remember(localScores) { localScores.mapNotNullTo(HashSet()) { it.catalogId } }

    LaunchedEffect(user?.email, user?.authProvider) { library.refresh() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.library_catalog_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
                },
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = isLoading && scores.isNotEmpty(),
            onRefresh = { scope.launch { library.refresh() } },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            LazyColumn(Modifier.fillMaxSize()) {
                if (scores.isEmpty() && !isLoading) {
                    item(key = "empty") {
                        Column(
                            Modifier.fillMaxWidth().padding(vertical = 40.dp, horizontal = 24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Icon(Icons.Outlined.LibraryMusic, null, tint = LuksColors.textSecondary, modifier = Modifier.size(36.dp))
                            Text(
                                error?.resolve() ?: stringResource(R.string.library_catalog_empty),
                                style = MaterialTheme.typography.bodyMedium,
                                color = LuksColors.textSecondary,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }
                items(scores, key = { it.id }) { score ->
                    val isDownloaded = score.id in downloaded
                    ListItem(
                        leadingContent = {
                            Icon(
                                if (score.isPrivate) Icons.Filled.Lock else Icons.Outlined.LibraryMusic,
                                contentDescription = if (score.isPrivate) stringResource(R.string.library_catalog_private) else null,
                                tint = if (score.isPrivate) PrivatePurple else MaterialTheme.colorScheme.secondary,
                                modifier = Modifier.width(28.dp),
                            )
                        },
                        headlineContent = { Text(score.title, fontWeight = FontWeight.SemiBold) },
                        supportingContent = { Text(score.credits, maxLines = 2, overflow = TextOverflow.Ellipsis) },
                        trailingContent = {
                            Icon(
                                if (isDownloaded) Icons.Filled.CheckCircle else Icons.Outlined.Download,
                                contentDescription = stringResource(
                                    if (isDownloaded) R.string.library_catalog_downloaded else R.string.library_catalog_download
                                ),
                                tint = if (isDownloaded) LuksColors.success else MaterialTheme.colorScheme.secondary,
                            )
                        },
                        modifier = Modifier.clickable { onOpen(score) }.animateItem(),
                    )
                    HorizontalDivider(Modifier.padding(start = 56.dp))
                }
                item(key = "footer") {
                    Text(
                        stringResource(R.string.library_catalog_footer),
                        style = MaterialTheme.typography.bodySmall,
                        color = LuksColors.textSecondary,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
                    )
                }
            }
            if (isLoading && scores.isEmpty()) {
                CircularProgressIndicator(Modifier.align(Alignment.Center))
            }
        }
    }
}

/**
 * A catalog score opened from the full list: downloaded into the library first when it is not there yet, then
 * handed to the score player ([onReady] replaces this screen with it).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnlineScoreScreen(catalogId: String, onBack: () -> Unit, onReady: (String) -> Unit) {
    val context = LocalContext.current
    val library = remember { OnlineLibraryService.get(context) }
    val scores by library.scores.collectAsStateWithLifecycle()
    val downloads by library.downloads.collectAsStateWithLifecycle()
    val entry = scores.firstOrNull { it.id == catalogId }
    val scope = rememberCoroutineScope()
    var errorMessage by remember { mutableStateOf<LibraryText?>(null) }
    var attempt by remember { mutableStateOf(0) }
    val isLoading by library.isLoading.collectAsStateWithLifecycle()

    // Back here after the app was closed, the catalog may need loading again
    LaunchedEffect(Unit) { library.refreshIfNeeded() }

    LaunchedEffect(entry?.id, attempt, isLoading) {
        val score = entry ?: run {
            // Not in the catalog (yet): wait while it loads, then say why it cannot be opened
            errorMessage = when {
                library.isLoading.value -> null
                library.errorMessage.value != null -> library.errorMessage.value
                else -> LibraryText(R.string.library_catalog_score_download_failed, LibraryText(R.string.library_catalog_error_not_found))
            }
            return@LaunchedEffect
        }
        errorMessage = null
        try {
            onReady(library.download(score).id)
        } catch (e: OnlineLibraryException) {
            errorMessage = LibraryText(R.string.library_catalog_score_download_failed, e.text)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            errorMessage = LibraryText(R.string.library_catalog_score_download_failed, LibraryText(R.string.library_catalog_error_unreadable))
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(entry?.pieceTitle.orEmpty(), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (!entry?.composer.isNullOrEmpty()) {
                            Text(entry!!.composer, style = MaterialTheme.typography.bodySmall, color = LuksColors.textSecondary)
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
                },
            )
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            val message = errorMessage
            if (message != null) {
                Column(
                    Modifier.padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Icon(Icons.Outlined.WifiOff, null, tint = LuksColors.textSecondary, modifier = Modifier.size(36.dp))
                    Text(message.resolve(), style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
                    Button(onClick = {
                        attempt++
                        if (entry == null) scope.launch { library.refresh() }
                    }) { Text(stringResource(R.string.action_retry)) }
                }
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    val fraction = downloads[catalogId]?.fraction
                    if (fraction != null) {
                        LinearProgressIndicator(progress = { fraction }, modifier = Modifier.width(180.dp))
                    } else {
                        CircularProgressIndicator()
                    }
                    Text(stringResource(R.string.library_catalog_downloading_score), style = MaterialTheme.typography.bodyMedium, color = LuksColors.textSecondary)
                }
            }
        }
    }
}
