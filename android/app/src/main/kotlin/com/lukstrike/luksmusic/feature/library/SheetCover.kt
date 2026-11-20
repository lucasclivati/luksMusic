// SheetCover.kt — port of luksMusic/Views/Library/SheetCover.swift: the cover of a score in the library, a sheet
// of paper with the title engraved in a serif face over two grand staves, like the first page of a printed edition.
package com.lukstrike.luksmusic.feature.library

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max

@Composable
fun SheetCover(title: String, modifier: Modifier = Modifier, subtitle: String = "") {
    BoxWithConstraints(modifier.background(Color.White).clearAndSetSemantics { }) {
        val width = maxWidth.value
        val height = maxHeight.value
        // Small covers (list rows) show only the staves
        val showsText = width >= 90
        val fontScale = LocalDensity.current.fontScale
        Column(
            Modifier.fillMaxSize().padding(horizontal = (width * 0.09f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (showsText) {
                Spacer(Modifier.height((height * 0.1f).dp))
                Text(
                    title,
                    color = Color.Black,
                    fontFamily = FontFamily.Serif,
                    // The cover is a picture: its type follows the cover's size, not the font-size setting
                    fontSize = (max(10f, width * 0.085f) / fontScale).sp,
                    lineHeight = (max(10f, width * 0.085f) * 1.15f / fontScale).sp,
                    textAlign = TextAlign.Center,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
                if (subtitle.isNotEmpty()) {
                    Text(
                        subtitle,
                        color = Color.Black.copy(alpha = 0.6f),
                        fontFamily = FontFamily.Serif,
                        fontSize = (max(7f, width * 0.052f) / fontScale).sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            Spacer(Modifier.weight(1f).heightIn(min = 4.dp))
            val lineGap = max(2f, height * 0.018f)
            Column(verticalArrangement = Arrangement.spacedBy((height * 0.07f).dp)) {
                GrandStaff(lineGap.dp)
                GrandStaff(lineGap.dp)
            }
            Spacer(Modifier.height((height * 0.09f).dp))
        }
    }
}

/** Two five-line staves joined by a line at their left end. */
@Composable
private fun GrandStaff(lineGap: Dp) {
    // Each staff: five 0.6-high lines `lineGap` apart; the staves 2.2 gaps apart
    val staffHeight = lineGap * 4
    val total = staffHeight * 2 + lineGap * 2.2f
    val density = LocalDensity.current
    Canvas(Modifier.fillMaxWidth().height(total)) {
        val gap = with(density) { lineGap.toPx() }
        val lineHeight = with(density) { 0.6.dp.toPx() }
        for (staff in 0..1) {
            val top = staff * (gap * 4 + gap * 2.2f)
            for (i in 0..4) {
                drawRect(Color.Black.copy(alpha = 0.35f), topLeft = Offset(0f, top + i * gap), size = Size(size.width, lineHeight))
            }
        }
        drawRect(Color.Black.copy(alpha = 0.45f), topLeft = Offset.Zero, size = Size(with(density) { 0.8.dp.toPx() }, size.height))
    }
}
