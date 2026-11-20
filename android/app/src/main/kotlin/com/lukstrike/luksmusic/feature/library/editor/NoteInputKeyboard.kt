// NoteInputKeyboard.kt — port of luksMusic/Views/Editor/NoteInputView.swift: the step-input keyboard, C3 to C5.
// A white key inserts its note with the palette's accidental; a black key inserts the sharp of the white key on
// its left.
package com.lukstrike.luksmusic.feature.library.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.ui.usesLetterNames

/** Two octaves for step input: C3 to C5. */
private val whiteNotes: List<Pair<NoteName, Int>> =
    listOf(3, 4).flatMap { octave -> NoteName.entries.map { it to octave } } + (NoteName.C to 5)

@Composable
fun NoteInputKeyboard(selectedAccidental: Accidental, onPitch: (Pitch) -> Unit, modifier: Modifier = Modifier) {
    val letters = usesLetterNames()
    BoxWithConstraints(
        modifier
            .padding(horizontal = 8.dp)
            .fillMaxWidth()
            .height(120.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(Color(0xFF8E8E93)),
    ) {
        val keyWidth = maxWidth / whiteNotes.size
        val keyHeight = maxHeight

        // White keys, 1 dp apart
        whiteNotes.forEachIndexed { i, (name, octave) ->
            // The key's name with its octave: solfège ("Dó3"), or letters ("C3") when the app is in English
            val keyName = NoteNaming.name(name, letters) + octave
            Surface(
                onClick = {
                    // The palette's accidental applies to white keys
                    onPitch(Pitch(name, octave, selectedAccidental))
                },
                color = Color.White,
                shape = RoundedCornerShape(4.dp),
                modifier = Modifier.offset(x = keyWidth * i).size(keyWidth - 1.dp, keyHeight).semantics { contentDescription = keyName },
            ) {
                Box(contentAlignment = Alignment.BottomCenter, modifier = Modifier.padding(bottom = 6.dp)) {
                    Text(
                        keyName,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.Black.copy(alpha = 0.6f),
                        maxLines = 1,
                        overflow = TextOverflow.Clip,
                        softWrap = false,
                    )
                }
            }
        }

        // Black keys, between the white keys that have one (not after E or B)
        whiteNotes.dropLast(1).forEachIndexed { i, (name, octave) ->
            if (name == NoteName.E || name == NoteName.B) return@forEachIndexed
            val sharpName = NoteNaming.name(Pitch(name, octave, Accidental.SHARP), letters) + octave
            Surface(
                onClick = { onPitch(Pitch(name, octave, Accidental.SHARP)) },
                color = Color.Black,
                shape = RoundedCornerShape(3.dp),
                modifier = Modifier
                    .offset(x = keyWidth * (i + 1) - keyWidth * 0.35f)
                    .size(keyWidth * 0.7f, keyHeight * 0.6f)
                    .semantics { contentDescription = sharpName },
            ) {}
        }
    }
}
