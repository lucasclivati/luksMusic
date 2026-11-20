// LibraryScreen.kt — port of luksMusic/Views/Library/LibraryView.swift: the Tocar tab. The luksmusic.web.app
// catalog on top, whose scores download to the phone on a tap and then open like the user's own, then the user's
// own scores in a searchable, filterable grid or list. Long-press a score for its menu; swipe a row to delete it.
package com.lukstrike.luksmusic.feature.library

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.LibraryMusic
import androidx.compose.material.icons.automirrored.outlined.List
import androidx.compose.material.icons.automirrored.outlined.Sort
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.SearchOff
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.MainActivity
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.ScoreSource
import com.lukstrike.luksmusic.ui.theme.LuksColors
import kotlinx.coroutines.launch

/** Sources a score can still come from (the camera scanner was removed). */
private val filterableSources = listOf(ScoreSource.MANUAL, ScoreSource.IMPORTED)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    onOpenScore: (String) -> Unit,
    onEditScore: (String) -> Unit,
    onOpenCatalog: () -> Unit,
) {
    val context = LocalContext.current
    val container = appContainer()
    val viewModel: LibraryViewModel = viewModel { LibraryViewModel(container, OnlineLibraryService.get(context)) }
    val catalog = viewModel.catalog
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }

    val query by viewModel.query.collectAsStateWithLifecycle()
    val layout by viewModel.layout.collectAsStateWithLifecycle()
    val allScores by viewModel.allScores.collectAsStateWithLifecycle()
    val scores by viewModel.filteredScores.collectAsStateWithLifecycle()
    val catalogScores by viewModel.filteredCatalog.collectAsStateWithLifecycle()
    val catalogLoading by catalog.isLoading.collectAsStateWithLifecycle()
    val downloads by catalog.downloads.collectAsStateWithLifecycle()
    val downloadFailure by viewModel.downloadFailure.collectAsStateWithLifecycle()
    val scoreToOpen by viewModel.scoreToOpen.collectAsStateWithLifecycle()
    val libraryLoaded by container.scores.isLoaded.collectAsStateWithLifecycle()
    val seeder = remember { SampleSeeder(container) }
    val seeding by seeder.isSeeding.collectAsStateWithLifecycle()
    val user by container.auth.currentUser.collectAsStateWithLifecycle()
    val incomingFile by MainActivity.incomingFile.collectAsStateWithLifecycle()

    var showAddSheet by rememberSaveable { mutableStateOf(false) }
    var showImportSheet by rememberSaveable { mutableStateOf(false) }
    var exportingId by rememberSaveable { mutableStateOf<String?>(null) }

    // The samples need a Context to read their assets

    // Loads the catalog the first time and again whenever the account changes
    LaunchedEffect(user?.email, user?.authProvider) { catalog.refreshIfNeeded() }

    // Whether the library is in front, so a finished download never opens over a score opened meanwhile
    LifecycleResumeEffect(viewModel) {
        viewModel.isInFront = true
        onPauseOrDispose { viewModel.isInFront = false }
    }
    LaunchedEffect(scoreToOpen) {
        scoreToOpen?.let { id ->
            viewModel.consumeScoreToOpen()
            onOpenScore(id)
        }
    }

    // A MusicXML file opened from another app goes straight into the import sheet
    LaunchedEffect(incomingFile) {
        val uri = incomingFile ?: return@LaunchedEffect
        MainActivity.clearIncomingFile()
        showAddSheet = false
        viewModel.pickFile(context, uri)
        showImportSheet = true
    }

    val canShare = remember { ScoreFiles.canShare(context) }
    val exporter = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(ScoreFiles.MUSICXML_MIME)) { uri ->
        val score = exportingId?.let { id -> allScores.firstOrNull { it.id == id } }
        exportingId = null
        if (uri != null && score != null) {
            scope.launch {
                val saved = ScoreFiles.export(context, container.scores, score, uri)
                snackbar.showSnackbar(context.getString(if (saved) R.string.library_exported else R.string.library_export_failed))
            }
        }
    }

    val actions = ScoreActions(
        open = { onOpenScore(it.id) },
        edit = { onEditScore(it.id) },
        toggleFavorite = { viewModel.toggleFavorite(it) },
        export = { score ->
            exportingId = score.id
            exporter.launch(ScoreFiles.exportFileName(score))
        },
        share = if (canShare) { score -> scope.launch { ScoreFiles.share(context, container.scores, score) } } else null,
        delete = { score ->
            viewModel.delete(score)
            scope.launch {
                snackbar.currentSnackbarData?.dismiss()
                val result = snackbar.showSnackbar(
                    context.getString(R.string.library_deleted, score.title),
                    actionLabel = context.getString(R.string.library_undo),
                    duration = SnackbarDuration.Short,
                )
                if (result == SnackbarResult.ActionPerformed) viewModel.undoDelete()
            }
        },
    )

    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        // The tab bar below already keeps the content clear of the navigation bar
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            LargeTopAppBar(
                title = { Text(stringResource(R.string.library_title)) },
                scrollBehavior = scrollBehavior,
                actions = {
                    IconButton(onClick = { showAddSheet = true }) {
                        Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.library_add_score))
                    }
                    IconButton(onClick = viewModel::toggleLayout) {
                        if (layout == LibraryLayout.GRID) {
                            Icon(Icons.AutoMirrored.Outlined.List, contentDescription = stringResource(R.string.library_show_list))
                        } else {
                            Icon(Icons.Outlined.GridView, contentDescription = stringResource(R.string.library_show_grid))
                        }
                    }
                    SortMenu(query, viewModel::chooseSort)
                    FilterMenu(query, viewModel)
                },
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = catalogLoading && catalogScores.isNotEmpty(),
            onRefresh = { scope.launch { catalog.refresh() } },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            val focusManager = LocalFocusManager.current
            LazyVerticalGrid(
                columns = if (layout == LibraryLayout.GRID) GridCells.Adaptive(160.dp) else GridCells.Adaptive(420.dp),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(if (layout == LibraryLayout.GRID) 16.dp else 12.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                fullSpan("search") {
                    SearchField(query.searchText, viewModel::setSearchText, onSearch = { focusManager.clearFocus() })
                }

                if (catalogLoading || catalogScores.isNotEmpty()) {
                    fullSpan("catalog") {
                        CatalogSection(
                            entries = catalogScores,
                            isLoading = catalogLoading && catalogScores.isEmpty(),
                            downloads = downloads,
                            downloadedIds = allScores.mapNotNullTo(HashSet()) { it.catalogId },
                            onOpen = viewModel::open,
                            onSeeAll = onOpenCatalog,
                        )
                    }
                }

                fullSpan("my-scores-header") {
                    Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.library_my_scores), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.weight(1f))
                        AnimatedVisibility(query.activeFilterCount > 0, enter = fadeIn(), exit = fadeOut()) {
                            TextButton(onClick = viewModel::clearFilters) { Text(stringResource(R.string.library_clear_filters)) }
                        }
                    }
                }

                when {
                    allScores.isEmpty() && (!libraryLoaded || seeding) -> fullSpan("loading") {
                        Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                    }
                    allScores.isEmpty() -> fullSpan("empty") { EmptyLibrary(onAdd = { showAddSheet = true }) }
                    scores.isEmpty() -> fullSpan("no-results") { NoResults(query.searchText) }
                    else -> items(scores, key = { it.id }) { score ->
                        if (layout == LibraryLayout.GRID) {
                            ScoreCard(score, actions) { ScoreGridCard(score) }
                        } else {
                            SwipeToDelete(score, onDelete = { actions.delete(score) }) {
                                ScoreCard(score, actions) { ScoreListRow(score) }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAddSheet) {
        AddScoreSheet(
            onDismiss = { showAddSheet = false },
            onCreate = {
                showAddSheet = false
                viewModel.createNewScore(context.getString(R.string.library_untitled_score), onEditScore)
            },
            onImport = {
                showAddSheet = false
                viewModel.resetImport()
                showImportSheet = true
            },
        )
    }

    if (showImportSheet) {
        ImportScoreSheet(
            viewModel = viewModel,
            onDismiss = {
                showImportSheet = false
                viewModel.resetImport()
            },
            onOpenScore = { id ->
                showImportSheet = false
                viewModel.resetImport()
                onOpenScore(id)
            },
        )
    }

    downloadFailure?.let { failure ->
        AlertDialog(
            onDismissRequest = viewModel::dismissDownloadFailure,
            title = { Text(stringResource(R.string.library_catalog_download_failed)) },
            text = { Text(failure.message.resolve()) },
            confirmButton = {
                TextButton(onClick = { viewModel.dismissDownloadFailure(); viewModel.open(failure.score) }) {
                    Text(stringResource(R.string.action_retry))
                }
            },
            dismissButton = { TextButton(onClick = viewModel::dismissDownloadFailure) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
}

private fun LazyGridScope.fullSpan(key: String, content: @Composable LazyGridItemScope.() -> Unit) =
    item(key = key, span = { GridItemSpan(maxLineSpan) }, content = content)

/** What can be done with a score from its card. [share] is null while sharing is not set up. */
private class ScoreActions(
    val open: (Score) -> Unit,
    val edit: (Score) -> Unit,
    val toggleFavorite: (Score) -> Unit,
    val export: (Score) -> Unit,
    val share: ((Score) -> Unit)?,
    val delete: (Score) -> Unit,
)

// region Search

@Composable
private fun SearchField(text: String, onChange: (String) -> Unit, onSearch: () -> Unit) {
    OutlinedTextField(
        value = text,
        onValueChange = onChange,
        placeholder = { Text(stringResource(R.string.library_search_prompt)) },
        leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
        trailingIcon = {
            if (text.isNotEmpty()) {
                IconButton(onClick = { onChange("") }) {
                    Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.library_clear_search))
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(28.dp),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = { onSearch() }),
        colors = OutlinedTextFieldDefaults.colors(
            unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
            focusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
            unfocusedBorderColor = Color.Transparent,
        ),
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
    )
}

// endregion

// region Toolbar menus

@Composable
private fun SortMenu(query: LibraryQuery, onChoose: (LibrarySortOption) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.AutoMirrored.Outlined.Sort, contentDescription = stringResource(R.string.library_sort))
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            LibrarySortOption.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(stringResource(option.label)) },
                    onClick = { onChoose(option) },
                    trailingIcon = {
                        if (query.sortOption == option) {
                            Icon(if (query.sortAscending) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward, contentDescription = null)
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun FilterMenu(query: LibraryQuery, viewModel: LibraryViewModel) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            BadgedBox(badge = { if (query.activeFilterCount > 0) Badge { Text("${query.activeFilterCount}") } }) {
                Icon(
                    Icons.Outlined.FilterList,
                    contentDescription = stringResource(R.string.library_filter),
                    tint = if (query.activeFilterCount > 0) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.onSurface,
                )
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            MenuHeader(stringResource(R.string.library_filter_difficulty))
            Difficulty.entries.forEach { difficulty ->
                CheckItem(stringResource(difficultyLabel(difficulty)), query.selectedDifficulty == difficulty) {
                    viewModel.toggleDifficulty(difficulty)
                }
            }
            HorizontalDivider()
            MenuHeader(stringResource(R.string.library_filter_source))
            filterableSources.forEach { source ->
                CheckItem(stringResource(sourceLabel(source)), query.selectedSource == source, sourceIcon(source)) {
                    viewModel.toggleSource(source)
                }
            }
            HorizontalDivider()
            CheckItem(stringResource(R.string.library_favorites_only), query.showFavoritesOnly, Icons.Filled.Star) {
                viewModel.toggleFavoritesOnly()
            }
        }
    }
}

@Composable
private fun MenuHeader(text: String) = Text(
    text,
    style = MaterialTheme.typography.labelMedium,
    color = LuksColors.textSecondary,
    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
)

@Composable
private fun CheckItem(text: String, checked: Boolean, icon: ImageVector? = null, onClick: () -> Unit) = DropdownMenuItem(
    text = { Text(text) },
    onClick = onClick,
    leadingIcon = icon?.let { { Icon(it, contentDescription = null) } },
    trailingIcon = { if (checked) Icon(Icons.Filled.Check, contentDescription = null) },
)

// endregion

// region Catalog

@Composable
private fun CatalogSection(
    entries: List<OnlineScore>,
    isLoading: Boolean,
    downloads: Map<String, CatalogDownload>,
    downloadedIds: Set<String>,
    onOpen: (OnlineScore) -> Unit,
    onSeeAll: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.library_catalog_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.library_catalog_subtitle), style = MaterialTheme.typography.bodySmall, color = LuksColors.textSecondary)
            }
            TextButton(onClick = onSeeAll) { Text(stringResource(R.string.library_catalog_see_all), fontWeight = FontWeight.SemiBold) }
        }
        // Bleeds to the screen edges while the cards line up with the rest of the page
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
            modifier = Modifier.fillMaxWidth().layoutBleed(16.dp),
        ) {
            if (isLoading) {
                items(3) { CatalogPlaceholder() }
            }
            items(entries, key = { it.id }) { entry ->
                CatalogCard(entry, downloads[entry.id], entry.id in downloadedIds, onClick = { onOpen(entry) })
            }
        }
    }
}

/** Widens a full-width row by [bleed] on each side, past the page's padding, so it scrolls edge to edge. */
private fun Modifier.layoutBleed(bleed: Dp) = this.then(
    Modifier.layout { measurable, constraints ->
        val extra = (bleed.roundToPx() * 2)
        val placeable = measurable.measure(constraints.copy(maxWidth = constraints.maxWidth + extra, minWidth = constraints.minWidth + extra))
        layout(constraints.maxWidth, placeable.height) { placeable.place(-extra / 2, 0) }
    }
)

@Composable
private fun CatalogPlaceholder() {
    val transition = rememberInfiniteTransition(label = "placeholder")
    val alpha by transition.animateFloat(0.4f, 0.9f, infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "alpha")
    Box(
        Modifier.size(140.dp, 186.dp).alpha(alpha).clip(RoundedCornerShape(6.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh)
    )
}

@Composable
private fun CatalogCard(entry: OnlineScore, download: CatalogDownload?, isDownloaded: Boolean, onClick: () -> Unit) {
    Column(
        Modifier.width(140.dp).clip(RoundedCornerShape(8.dp)).clickable(onClick = onClick),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.size(140.dp, 186.dp).shadow(6.dp, RoundedCornerShape(6.dp)).clip(RoundedCornerShape(6.dp))) {
            SheetCover(entry.pieceTitle, Modifier.fillMaxSize(), subtitle = entry.composer)
            if (download != null) DownloadProgress(download)
            if (entry.isPrivate) {
                Icon(
                    Icons.Filled.Lock,
                    contentDescription = stringResource(R.string.library_catalog_private),
                    tint = Color.White,
                    modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).size(22.dp)
                        .background(Color.Black.copy(alpha = 0.7f), CircleShape).padding(5.dp),
                )
            }
            if (download == null) {
                Row(
                    Modifier.align(Alignment.BottomStart).padding(6.dp)
                        .background(if (isDownloaded) LuksColors.success else LuksColors.accentIndigo, RoundedCornerShape(50))
                        .padding(horizontal = 7.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Icon(if (isDownloaded) Icons.Filled.CheckCircle else Icons.Filled.Download, null, tint = Color.White, modifier = Modifier.size(12.dp))
                    Text(
                        stringResource(if (isDownloaded) R.string.library_catalog_downloaded else R.string.library_catalog_download),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }
            }
        }
        Text(entry.title, style = MaterialTheme.typography.labelLarge, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(entry.credits, style = MaterialTheme.typography.labelSmall, color = LuksColors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Over a card's cover while its score downloads: the part received when the file's size is known. */
@Composable
private fun DownloadProgress(download: CatalogDownload) {
    Column(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically),
    ) {
        val fraction = download.fraction
        if (fraction != null) {
            LinearProgressIndicator(progress = { fraction }, color = Color.White, trackColor = Color.White.copy(alpha = 0.3f),
                modifier = Modifier.padding(horizontal = 22.dp).fillMaxWidth())
        } else {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(28.dp), strokeWidth = 3.dp)
        }
        Text(stringResource(R.string.library_catalog_downloading), style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold, color = Color.White)
    }
}

// endregion

// region My scores

/** A score's card: opens on tap, shows its menu on long press. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun LazyGridItemScope.ScoreCard(score: Score, actions: ScoreActions, content: @Composable () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    Box(Modifier.animateItem()) {
        Card(
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).combinedClickable(
                onClick = { actions.open(score) },
                onLongClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    menu = true
                },
            ),
        ) { content() }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            DropdownMenuItem(
                text = { Text(stringResource(if (score.isFavorite) R.string.library_unfavorite else R.string.library_favorite)) },
                leadingIcon = { Icon(if (score.isFavorite) Icons.Outlined.StarOutline else Icons.Outlined.Star, null) },
                onClick = { menu = false; actions.toggleFavorite(score) },
            )
            // The bundled sample pieces are not editable
            if (!score.isSample) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.library_edit)) },
                    leadingIcon = { Icon(Icons.Outlined.Edit, null) },
                    onClick = { menu = false; actions.edit(score) },
                )
            }
            DropdownMenuItem(
                text = { Text(stringResource(R.string.library_export)) },
                leadingIcon = { Icon(Icons.Outlined.UploadFile, null) },
                onClick = { menu = false; actions.export(score) },
            )
            actions.share?.let { share ->
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.library_share)) },
                    leadingIcon = { Icon(Icons.Outlined.Share, null) },
                    onClick = { menu = false; share(score) },
                )
            }
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text(stringResource(R.string.library_delete), color = MaterialTheme.colorScheme.error) },
                leadingIcon = { Icon(Icons.Outlined.Delete, null, tint = MaterialTheme.colorScheme.error) },
                onClick = { menu = false; actions.delete(score) },
            )
        }
    }
}

/** Swipe a list row to the left to delete it (Undo in the snackbar puts it back). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeToDelete(score: Score, onDelete: () -> Unit, content: @Composable () -> Unit) {
    val state = rememberSwipeToDismissBoxState()
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        onDismiss = { value -> if (value == SwipeToDismissBoxValue.EndToStart) onDelete() },
        backgroundContent = {
            Box(
                Modifier.fillMaxSize().clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.error).padding(horizontal = 24.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(Icons.Filled.Delete, contentDescription = stringResource(R.string.library_delete), tint = MaterialTheme.colorScheme.onError)
            }
        },
    ) { content() }
}

/** Shown when the user has no scores of their own yet. */
@Composable
private fun EmptyLibrary(onAdd: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 32.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(Icons.Outlined.LibraryMusic, contentDescription = null, tint = MaterialTheme.colorScheme.secondary, modifier = Modifier.size(40.dp))
        Text(stringResource(R.string.library_empty_title), style = MaterialTheme.typography.titleMedium)
        Text(
            stringResource(R.string.library_empty_message),
            style = MaterialTheme.typography.bodyMedium,
            color = LuksColors.textSecondary,
            textAlign = TextAlign.Center,
        )
        Button(onClick = onAdd) {
            Icon(Icons.Outlined.Add, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.library_add_score))
        }
    }
}

@Composable
private fun NoResults(searchText: String) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 32.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Outlined.SearchOff, contentDescription = null, tint = LuksColors.textSecondary, modifier = Modifier.size(40.dp))
        if (searchText.isNotEmpty()) {
            Text(stringResource(R.string.library_no_results_title, searchText), style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
            Text(stringResource(R.string.library_no_results_message), style = MaterialTheme.typography.bodyMedium, color = LuksColors.textSecondary)
        } else {
            Text(stringResource(R.string.library_no_filter_results), style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        }
    }
}

/** Bottom sheet for choosing how to add a score. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddScoreSheet(onDismiss: () -> Unit, onCreate: () -> Unit, onImport: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(bottom = 24.dp)) {
            Text(
                stringResource(R.string.library_add_score),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )
            AddOption(Icons.Outlined.EditNote, R.string.library_create_new, R.string.library_create_new_detail, onCreate)
            AddOption(Icons.Outlined.FileDownload, R.string.library_import_file, R.string.library_import_file_detail, onImport)
        }
    }
}

@Composable
private fun AddOption(icon: ImageVector, title: Int, detail: Int, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(stringResource(title), fontWeight = FontWeight.Medium) },
        supportingContent = { Text(stringResource(detail)) },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.secondary) },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier.clickable(onClick = onClick).padding(horizontal = 8.dp),
    )
}

// endregion
