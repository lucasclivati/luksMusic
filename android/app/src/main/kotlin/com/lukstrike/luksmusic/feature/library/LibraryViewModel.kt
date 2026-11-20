// LibraryViewModel.kt — the library screen's state (iOS keeps it in LibraryView's @State; LibraryViewModel.swift
// is unused there): search, sort, filters and layout of the user's scores, the catalog shown above them, catalog
// downloads, the import flow, and deleting with undo.
package com.lukstrike.luksmusic.feature.library

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.ScoreSource
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.Collator

/** Sort options of the library (iOS LibrarySortOption). */
enum class LibrarySortOption(val label: Int) {
    DATE_CREATED(R.string.library_sort_date_added),
    TITLE(R.string.library_sort_title),
    DIFFICULTY(R.string.library_sort_difficulty),
    LAST_PRACTICED(R.string.library_sort_last_practiced),
}

enum class LibraryLayout { GRID, LIST }

/** Search, sort and filters of "My scores". */
data class LibraryQuery(
    val searchText: String = "",
    val sortOption: LibrarySortOption = LibrarySortOption.DATE_CREATED,
    val sortAscending: Boolean = false,
    val selectedDifficulty: Difficulty? = null,
    val selectedSource: ScoreSource? = null,
    val showFavoritesOnly: Boolean = false,
) {
    val activeFilterCount: Int
        get() = listOf(selectedDifficulty != null, selectedSource != null, showFavoritesOnly).count { it }
}

/** A catalog score that could not be downloaded, and why. */
data class DownloadFailure(val score: OnlineScore, val message: LibraryText)

/** Phases of importing a file (iOS ImportPhase). */
sealed interface ImportPhase {
    data object Idle : ImportPhase
    data object Loading : ImportPhase
    data class Previewing(val file: PickedScoreFile) : ImportPhase
    data object Importing : ImportPhase
    data class Success(val scoreId: String, val title: String) : ImportPhase
    data class Failure(val message: LibraryText) : ImportPhase
}

/** The details the user can change before importing (title, composer, difficulty). */
data class ImportForm(val title: String = "", val composer: String = "", val difficulty: Difficulty = Difficulty.BEGINNER)

class LibraryViewModel(
    private val container: AppContainer,
    val catalog: OnlineLibraryService,
) : ViewModel() {

    private val _query = MutableStateFlow(LibraryQuery())
    val query: StateFlow<LibraryQuery> = _query

    private val _layout = MutableStateFlow(LibraryLayout.GRID)
    val layout: StateFlow<LibraryLayout> = _layout

    /** Every score of the library (for the empty state and the catalog's "Downloaded" badges). */
    val allScores: StateFlow<List<Score>> = container.scores.scores

    /** The user's scores after search, filters and sort. */
    val filteredScores: StateFlow<List<Score>> = combine(container.scores.scores, _query) { scores, query -> filter(scores, query) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** Catalog scores matching the search. */
    val filteredCatalog: StateFlow<List<OnlineScore>> = combine(catalog.scores, _query) { scores, query ->
        val text = query.searchText.trim().lowercase()
        if (text.isEmpty()) scores
        else scores.filter { it.title.lowercase().contains(text) || it.credits.lowercase().contains(text) }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val _downloadFailure = MutableStateFlow<DownloadFailure?>(null)
    val downloadFailure: StateFlow<DownloadFailure?> = _downloadFailure

    /** A score to open once downloaded; consumed by the screen. */
    private val _scoreToOpen = MutableStateFlow<String?>(null)
    val scoreToOpen: StateFlow<String?> = _scoreToOpen

    /** The library itself is on screen, with nothing pushed over it. */
    var isInFront = false

    // region Search, sort, filters

    fun setSearchText(text: String) = _query.update { it.copy(searchText = text) }

    /** Choosing the current sort again flips its direction (iOS). */
    fun chooseSort(option: LibrarySortOption) = _query.update {
        if (it.sortOption == option) it.copy(sortAscending = !it.sortAscending) else it.copy(sortOption = option, sortAscending = false)
    }

    fun toggleDifficulty(difficulty: Difficulty) =
        _query.update { it.copy(selectedDifficulty = if (it.selectedDifficulty == difficulty) null else difficulty) }

    fun toggleSource(source: ScoreSource) =
        _query.update { it.copy(selectedSource = if (it.selectedSource == source) null else source) }

    fun toggleFavoritesOnly() = _query.update { it.copy(showFavoritesOnly = !it.showFavoritesOnly) }

    fun clearFilters() = _query.update { it.copy(selectedDifficulty = null, selectedSource = null, showFavoritesOnly = false) }

    fun toggleLayout() = _layout.update { if (it == LibraryLayout.GRID) LibraryLayout.LIST else LibraryLayout.GRID }

    private val collator = Collator.getInstance().apply { strength = Collator.SECONDARY }

    private fun filter(scores: List<Score>, query: LibraryQuery): List<Score> {
        var result = scores
        val text = query.searchText.lowercase()
        if (text.isNotEmpty()) {
            result = result.filter { it.title.lowercase().contains(text) || it.composer.lowercase().contains(text) }
        }
        query.selectedDifficulty?.let { difficulty -> result = result.filter { it.difficulty == difficulty } }
        query.selectedSource?.let { source -> result = result.filter { it.source == source } }
        if (query.showFavoritesOnly) result = result.filter { it.isFavorite }

        val ascending: Comparator<Score> = when (query.sortOption) {
            LibrarySortOption.DATE_CREATED -> compareBy { it.dateCreated }
            LibrarySortOption.TITLE -> Comparator { a, b -> collator.compare(a.title, b.title) }
            LibrarySortOption.DIFFICULTY -> compareBy { it.difficulty.ordinal }
            LibrarySortOption.LAST_PRACTICED -> compareBy { it.lastPracticed ?: Long.MIN_VALUE }
        }
        return result.sortedWith(if (query.sortAscending) ascending else ascending.reversed())
    }

    // endregion

    // region Scores

    fun toggleFavorite(score: Score) = viewModelScope.launch {
        container.scores.update(score.id) { it.copy(isFavorite = !it.isFavorite) }
    }

    /** What was last deleted, so Undo can put it back with its MusicXML. */
    private var lastDeleted: Pair<Score, String?>? = null

    fun delete(score: Score) = viewModelScope.launch {
        lastDeleted = score to container.scores.musicXml(score.id)
        container.scores.delete(score.id)
    }

    fun undoDelete() = viewModelScope.launch {
        val (score, xml) = lastDeleted ?: return@launch
        lastDeleted = null
        container.scores.save(score, xml)
    }

    /** Adds a blank score and hands back its id (the screen opens the editor on it). */
    fun createNewScore(title: String, onCreated: (String) -> Unit) = viewModelScope.launch {
        val score = Score(title = title, composer = "", source = ScoreSource.MANUAL)
        container.scores.save(score)
        onCreated(score.id)
    }

    // endregion

    // region Catalog

    /** Opens a catalog score's copy on the phone, downloading it first when it is not there yet. */
    fun open(entry: OnlineScore) {
        catalog.localCopy(entry)?.let { _scoreToOpen.value = it.id; return }
        if (entry.id in catalog.downloads.value) return
        viewModelScope.launch {
            try {
                val score = catalog.download(entry)
                // Never pushed over a score opened meanwhile; its card then just says "Downloaded"
                if (isInFront) _scoreToOpen.value = score.id
            } catch (e: OnlineLibraryException) {
                _downloadFailure.value = DownloadFailure(entry, e.text)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _downloadFailure.value = DownloadFailure(entry, LibraryText(R.string.library_catalog_error_unreadable))
            }
        }
    }

    fun consumeScoreToOpen() { _scoreToOpen.value = null }
    fun dismissDownloadFailure() { _downloadFailure.value = null }

    // endregion

    // region Import

    private val _importPhase = MutableStateFlow<ImportPhase>(ImportPhase.Idle)
    val importPhase: StateFlow<ImportPhase> = _importPhase

    private val _importForm = MutableStateFlow(ImportForm())
    val importForm: StateFlow<ImportForm> = _importForm

    private var importJob: Job? = null

    fun updateImportForm(form: ImportForm) { _importForm.value = form }

    /** Reads and parses the picked file off the main thread, then shows its details for review. */
    fun pickFile(context: Context, uri: Uri) {
        importJob?.cancel()
        _importPhase.value = ImportPhase.Loading
        importJob = viewModelScope.launch {
            _importPhase.value = try {
                val file = ScoreFiles.read(context.applicationContext, uri)
                val score = file.parsed.score
                // The file's own title and composer when it names them, else its file name (iOS uses the file name)
                _importForm.value = ImportForm(
                    title = score.title.takeIf { it.isNotBlank() && it != "Imported Score" } ?: ScoreFiles.titleFromFileName(file.fileName),
                    composer = score.composer.takeIf { it.isNotBlank() && it != "Unknown" } ?: "",
                    difficulty = score.difficulty,
                )
                ImportPhase.Previewing(file)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                ImportPhase.Failure(e.importMessage())
            }
        }
    }

    /** Saves the previewed score with the details from the form. */
    fun performImport() {
        val file = (_importPhase.value as? ImportPhase.Previewing)?.file ?: run {
            _importPhase.value = ImportPhase.Failure(LibraryText(R.string.library_import_error_no_file))
            return
        }
        val form = _importForm.value
        _importPhase.value = ImportPhase.Importing
        importJob = viewModelScope.launch {
            val score = file.parsed.score.let { parsed ->
                parsed.copy(
                    title = form.title.trim().ifEmpty { parsed.title },
                    composer = form.composer.trim().ifEmpty { parsed.composer },
                    difficulty = form.difficulty,
                )
            }
            _importPhase.value = try {
                container.scores.save(score, file.parsed.musicXml)
                ImportPhase.Success(score.id, score.title)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                ImportPhase.Failure(e.importMessage())
            }
        }
    }

    fun failImport(message: LibraryText) { _importPhase.value = ImportPhase.Failure(message) }

    fun resetImport() {
        importJob?.cancel()
        _importPhase.value = ImportPhase.Idle
        _importForm.value = ImportForm()
    }

    // endregion
}
