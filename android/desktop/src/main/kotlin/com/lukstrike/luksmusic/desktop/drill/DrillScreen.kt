// DrillScreen.kt — the sight-reading drill laid out for the Deck on the music stand (1280×800): the choices in one
// row, the staff as large as the rest leaves, the feedback in big letters, a slim key strip and five big buttons.
package com.lukstrike.luksmusic.desktop.drill

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.core.lessons.ReadingOrder
import com.lukstrike.luksmusic.core.model.Clef
import com.lukstrike.luksmusic.desktop.Shortcut
import com.lukstrike.luksmusic.desktop.ui.ActionButton
import com.lukstrike.luksmusic.desktop.ui.GrandStaff
import com.lukstrike.luksmusic.desktop.ui.KeyStrip
import com.lukstrike.luksmusic.desktop.ui.LocalStrings
import com.lukstrike.luksmusic.desktop.ui.MidiStatus
import com.lukstrike.luksmusic.desktop.ui.Palette
import com.lukstrike.luksmusic.desktop.ui.ReadingStaff
import com.lukstrike.luksmusic.desktop.ui.Segmented
import com.lukstrike.luksmusic.desktop.ui.SquareIconButton
import com.lukstrike.luksmusic.desktop.ui.Stat
import com.lukstrike.luksmusic.desktop.ui.Strings
import com.lukstrike.luksmusic.desktop.ui.TopBar

@Composable
fun DrillScreen(
    controller: DrillController,
    connected: List<String>,
    held: Set<Int>,
    onBack: () -> Unit,
    onSwitch: () -> Unit,
    onSettings: () -> Unit,
) {
    val strings = LocalStrings.current
    val state by controller.state.collectAsState()
    val subtitle = buildString {
        append(strings.readingDrill)
        if (state.segmentCount > 0) {
            append(" · ").append(strings.passage(state.segmentNumber, state.segmentCount))
            state.measures?.let { (first, last) -> append(" · ").append(strings.measureRange(maxOf(1, first), maxOf(1, last))) }
        }
    }
    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(state.title, subtitle, onBack) {
            MidiStatus(connected, onSettings)
            ActionButton(strings.studyMode, Icons.Filled.SwapHoriz, hint = "Tab", onClick = onSwitch)
            SquareIconButton(Icons.Filled.Settings, strings.settings, onClick = onSettings)
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(20.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Segmented(
                strings.hand + " (1 2 3)",
                listOf(ReadingHand.RIGHT to strings.handRight, ReadingHand.LEFT to strings.handLeft, ReadingHand.BOTH to strings.handBoth),
                state.hand, onSelect = controller::setHand,
            )
            Segmented(
                strings.notesLabel + " (N)",
                listOf(ReadingNotes.ONE to strings.notesOne, ReadingNotes.TWO to strings.notesTwo, ReadingNotes.ALL to strings.notesAll),
                state.notes, onSelect = controller::setNotes,
            )
            Segmented(
                strings.order + " (O)",
                listOf(ReadingOrder.SEQUENTIAL to strings.orderSequential, ReadingOrder.RANDOM to strings.orderRandom),
                state.order, onSelect = controller::setOrder,
            )
            Segmented(
                strings.perPassage,
                DrillController.SEGMENT_SIZES.map { it to "$it" },
                state.segmentSize, onSelect = controller::setSegmentSize,
            )
        }
        Box(
            Modifier.weight(1f).fillMaxWidth().padding(horizontal = 16.dp).clip(RoundedCornerShape(16.dp)).background(Palette.paper),
        ) {
            if (state.segmentSteps.isEmpty()) {
                Text(strings.noNotes, color = Palette.background, fontSize = 22.sp, modifier = Modifier.align(Alignment.Center))
            } else if (state.hand == ReadingHand.BOTH) {
                GrandStaff(
                    state.segmentSteps, state.accidentals, state.results, state.current, state.keySignature, strings.usesLetters,
                    Modifier.fillMaxSize().padding(vertical = 6.dp), state.wrongPitch, state.listeningStep,
                )
            } else {
                ReadingStaff(
                    state.segmentSteps, state.accidentals, state.results, state.current,
                    Clef.of(state.hand.staff), state.keySignature, strings.usesLetters,
                    Modifier.fillMaxSize().padding(vertical = 8.dp), state.wrongPitch, state.listeningStep,
                )
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val (text, color) = feedbackText(state.feedback, strings)
            Text(
                text, color = color, fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 1,
                overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
            )
            Stat(strings.clean, "${state.answeredClean}/${state.answered}", Palette.green)
            Spacer(Modifier.width(24.dp))
            Stat(strings.streak, "${state.streak}", Palette.amber)
        }
        KeyStrip(
            state.keyRange,
            Modifier.fillMaxWidth().height(58.dp).padding(horizontal = 16.dp),
            targets = state.targetKeys, held = held, correct = state.correctKeys, incorrect = state.incorrectKeys,
            usesLetters = strings.usesLetters,
        )
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ActionButton(strings.previous, Icons.AutoMirrored.Filled.ArrowBack, Modifier.weight(1f), enabled = state.canGoBack, hint = "←  L1", onClick = controller::previousSegment)
            ActionButton(strings.repeat, Icons.Filled.Replay, Modifier.weight(1f), hint = "R", onClick = controller::repeatSegment)
            ActionButton(strings.listen, Icons.AutoMirrored.Filled.VolumeUp, Modifier.weight(1f), hint = "Space  X", onClick = controller::listen)
            ActionButton(strings.hint, Icons.Filled.Lightbulb, Modifier.weight(1f), enabled = !state.isSegmentComplete, hint = "H", onClick = controller::reveal)
            ActionButton(strings.next, Icons.AutoMirrored.Filled.ArrowForward, Modifier.weight(1f), primary = true, hint = "→  Enter  R1", onClick = controller::nextSegment)
        }
    }
}

private fun feedbackText(feedback: DrillFeedback, strings: Strings) = when (feedback) {
    is DrillFeedback.Prompt -> (if (feedback.chord > 1) strings.promptChord(feedback.chord) else strings.prompt) to Palette.text
    is DrillFeedback.Correct -> strings.correct(feedback.name) to Palette.green
    is DrillFeedback.Wrong -> strings.wrong(feedback.name) to Palette.red
    is DrillFeedback.Revealed -> strings.revealed(feedback.name) to Palette.amber
    is DrillFeedback.SegmentDone -> strings.segmentDone(feedback.clean, feedback.total) to Palette.cyan
    DrillFeedback.NoNotes -> strings.noNotes to Palette.muted
}

/** The drill's keys and buttons; true when handled. */
fun DrillController.handle(shortcut: Shortcut): Boolean {
    when (shortcut) {
        Shortcut.RIGHT, Shortcut.PAGE_DOWN, Shortcut.ENTER -> nextSegment()
        Shortcut.LEFT, Shortcut.PAGE_UP -> previousSegment()
        Shortcut.SPACE -> listen()
        Shortcut.HINT -> reveal()
        Shortcut.REPEAT -> repeatSegment()
        Shortcut.HAND_RIGHT -> setHand(ReadingHand.RIGHT)
        Shortcut.HAND_LEFT -> setHand(ReadingHand.LEFT)
        Shortcut.HAND_BOTH -> setHand(ReadingHand.BOTH)
        Shortcut.NOTES -> cycleNotes()
        Shortcut.ORDER -> toggleOrder()
        else -> return false
    }
    return true
}
