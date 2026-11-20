// EditorViewModel.kt — port of luksMusic/ViewModels/EditorViewModel.swift: step input of notes into the score's
// measures, with undo and redo. The edits stay here until Save writes them to the library (iOS edits the stored
// score in place).
package com.lukstrike.luksmusic.feature.library.editor

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EditorState(
    val score: Score? = null,
    val measures: List<Measure> = emptyList(),
    val selectedMeasureIndex: Int = 0,
    val selectedBeat: Double = 1.0,
    val selectedStaff: Staff = Staff.TREBLE,
    val selectedDuration: NoteDuration = NoteDuration.QUARTER,
    val selectedAccidental: Accidental = Accidental.NATURAL,
    val isRestSelected: Boolean = false,
    val isDottedSelected: Boolean = false,
    val selectedVoice: Int = 1,
    val canUndo: Boolean = false,
    val canRedo: Boolean = false,
    /** True once the score was not found (deleted meanwhile). */
    val isMissing: Boolean = false,
) {
    /** Whether there are edits Save has not written yet. */
    val hasChanges: Boolean get() = canUndo
}

class EditorViewModel(private val container: AppContainer, private val scoreId: String) : ViewModel() {

    private val _state = MutableStateFlow(EditorState())
    val state: StateFlow<EditorState> = _state

    // History
    private val undoStack = ArrayDeque<List<Measure>>()
    private val redoStack = ArrayDeque<List<Measure>>()

    init {
        viewModelScope.launch {
            container.scores.isLoaded.first { it }
            val score = container.scores.get(scoreId)
            if (score == null) {
                _state.update { it.copy(isMissing = true) }
                return@launch
            }
            // A score with no measures starts with an empty one
            val measures = score.measures.ifEmpty { listOf(Measure(number = 1)) }
            _state.update { it.copy(score = score, measures = measures) }
        }
    }

    // region Selection

    fun selectMeasure(index: Int) = _state.update { it.copy(selectedMeasureIndex = index, selectedBeat = 1.0) }
    fun selectStaff(staff: Staff) = _state.update { it.copy(selectedStaff = staff) }
    fun selectDuration(duration: NoteDuration) = _state.update { it.copy(selectedDuration = duration) }
    fun toggleRest() = _state.update { it.copy(isRestSelected = !it.isRestSelected) }
    fun toggleDot() = _state.update { it.copy(isDottedSelected = !it.isDottedSelected) }

    /** Tapping the selected accidental again goes back to natural. */
    fun toggleAccidental(accidental: Accidental) = _state.update {
        it.copy(selectedAccidental = if (it.selectedAccidental == accidental) Accidental.NATURAL else accidental)
    }

    // endregion

    // region Note operations

    /** The value inserted: the selected duration, dotted when the dot is on and the value has a dotted form. */
    private fun insertedDuration(state: EditorState): NoteDuration {
        if (!state.isDottedSelected) return state.selectedDuration
        return when (state.selectedDuration) {
            NoteDuration.HALF -> NoteDuration.DOTTED_HALF
            NoteDuration.QUARTER -> NoteDuration.DOTTED_QUARTER
            NoteDuration.EIGHTH -> NoteDuration.DOTTED_EIGHTH
            NoteDuration.SIXTEENTH -> NoteDuration.DOTTED_SIXTEENTH
            else -> state.selectedDuration
        }
    }

    /** Inserts a note (or rest) of the selected value at the cursor, plays it, and moves the cursor past it. */
    fun insertNote(pitch: Pitch) {
        val state = _state.value
        val score = state.score ?: return
        if (state.selectedMeasureIndex !in state.measures.indices) return
        saveStateForUndo()

        val duration = insertedDuration(state)
        val note = Note(
            pitch = pitch,
            duration = duration,
            velocity = 80,
            isRest = state.isRestSelected,
            staff = state.selectedStaff,
            voice = state.selectedVoice,
            beat = state.selectedBeat,
        )
        val measures = state.measures.toMutableList()
        val measure = measures[state.selectedMeasureIndex]
        measures[state.selectedMeasureIndex] = measure.copy(notes = (measure.notes + note).sortedBy { it.beat })

        // Play audio preview
        if (!note.isRest) container.audio.playNote(note.midiNote, velocity = 80)

        // Advance the cursor; past the last beat it moves to the next measure, adding one at the end
        var beat = state.selectedBeat + duration.beats
        var index = state.selectedMeasureIndex
        if (beat > score.timeSignatureTop) {
            beat = 1.0
            if (index + 1 < measures.size) {
                index += 1
            } else {
                measures += Measure(number = measures.size + 1)
                index = measures.size - 1
            }
        }
        _state.update { it.copy(measures = measures, selectedMeasureIndex = index, selectedBeat = beat) }
        refreshHistoryFlags()
    }

    /** Deletes the last note of the selected measure. */
    fun deleteLastNote() {
        val state = _state.value
        if (state.selectedMeasureIndex !in state.measures.indices) return
        val measure = state.measures[state.selectedMeasureIndex]
        if (measure.notes.isEmpty()) return
        saveStateForUndo()
        val measures = state.measures.toMutableList()
        measures[state.selectedMeasureIndex] = measure.copy(notes = measure.notes.dropLast(1))
        _state.update { it.copy(measures = measures) }
        refreshHistoryFlags()
    }

    /** Adds an empty measure at the end and selects it. */
    fun addNewMeasure() {
        saveStateForUndo()
        val measures = _state.value.measures + Measure(number = _state.value.measures.size + 1)
        _state.update { it.copy(measures = measures, selectedMeasureIndex = measures.size - 1, selectedBeat = 1.0) }
        refreshHistoryFlags()
    }

    // endregion

    // region Undo / redo

    private fun saveStateForUndo() {
        undoStack.addLast(_state.value.measures)
        redoStack.clear()
    }

    fun undo() {
        val previous = undoStack.removeLastOrNull() ?: return
        redoStack.addLast(_state.value.measures)
        restore(previous)
    }

    fun redo() {
        val next = redoStack.removeLastOrNull() ?: return
        undoStack.addLast(_state.value.measures)
        restore(next)
    }

    /** Puts back [measures], keeping the selection inside them. */
    private fun restore(measures: List<Measure>) {
        _state.update {
            val index = it.selectedMeasureIndex.coerceIn(0, (measures.size - 1).coerceAtLeast(0))
            it.copy(measures = measures, selectedMeasureIndex = index, selectedBeat = if (index != it.selectedMeasureIndex) 1.0 else it.selectedBeat)
        }
        refreshHistoryFlags()
    }

    private fun refreshHistoryFlags() =
        _state.update { it.copy(canUndo = undoStack.isNotEmpty(), canRedo = redoStack.isNotEmpty()) }

    // endregion

    /** Writes the edited measures to the library. Editing the notes drops the MusicXML the score was read from, so
     *  the viewer then draws the edited measures (as on iOS). */
    fun save(onSaved: () -> Unit) {
        val state = _state.value
        val score = state.score ?: return onSaved()
        // The bundled sample pieces are never changed (the menus hide Edit for them; this guards any other way in)
        if (!state.hasChanges || score.isSample) return onSaved()
        viewModelScope.launch {
            container.scores.save(
                score.copy(measures = state.measures, hasMusicXml = false, lastModified = System.currentTimeMillis())
            )
            onSaved()
        }
    }
}
