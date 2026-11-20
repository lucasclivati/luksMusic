// Components.kt — the pieces every screen uses, sized for a finger on the Deck's 7" screen: a title bar, big action
// buttons, segmented choices and the keyboard's connection status.
package com.lukstrike.luksmusic.desktop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** The title bar: back, a title and subtitle, and the screen's buttons on the right. */
@Composable
fun TopBar(title: String, subtitle: String, onBack: (() -> Unit)?, trailing: @Composable () -> Unit = {}) {
    val strings = LocalStrings.current
    Row(
        Modifier.fillMaxWidth().background(Palette.panel).padding(horizontal = 12.dp, vertical = 8.dp).height(56.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (onBack != null) SquareIconButton(Icons.AutoMirrored.Filled.ArrowBack, strings.back, onClick = onBack)
        Column(Modifier.weight(1f)) {
            Text(title, color = Palette.text, fontSize = 22.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle.isNotEmpty()) {
                Text(subtitle, color = Palette.muted, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        trailing()
    }
}

/** A square raised icon button, 56 dp (easy to hit with a thumb). */
@Composable
fun SquareIconButton(icon: ImageVector, label: String, tint: Color = Palette.text, size: Dp = 56.dp, onClick: () -> Unit) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(12.dp)).background(Palette.raised).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(size * 0.5f))
    }
}

/** A big labeled button with an icon (the drill's and Modo Estudo's controls). [hint] is its key, shown small. */
@Composable
fun ActionButton(
    text: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
    enabled: Boolean = true,
    hint: String? = null,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.heightIn(min = 64.dp),
        shape = RoundedCornerShape(14.dp),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (primary) Palette.deepBlue else Palette.raised,
            contentColor = Palette.text,
            disabledContainerColor = Palette.panel,
            disabledContentColor = Palette.muted.copy(alpha = 0.5f),
        ),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(10.dp))
        Column {
            Text(text, fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            if (hint != null) Text(hint, fontSize = 11.sp, color = Palette.muted, maxLines = 1)
        }
    }
}

/** A row of choices, one selected. */
@Composable
fun <T> Segmented(
    label: String,
    options: List<Pair<T, String>>,
    selected: T,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    Column(modifier) {
        Text(label.uppercase(), color = Palette.muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(Modifier.height(4.dp))
        Row(
            Modifier.clip(RoundedCornerShape(12.dp)).background(Palette.raised).padding(3.dp),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            for ((value, text) in options) {
                val isSelected = value == selected
                Box(
                    Modifier
                        .heightIn(min = 44.dp)
                        .clip(RoundedCornerShape(9.dp))
                        .background(if (isSelected) Palette.deepBlue else Color.Transparent)
                        .clickable { onSelect(value) }
                        .padding(horizontal = 14.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text, color = if (isSelected) Color.White else Palette.text, fontSize = 15.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium, maxLines = 1,
                    )
                }
            }
        }
    }
}

/** "Teclado conectado" in green, or "No keyboard" in amber; opens the settings when touched. */
@Composable
fun MidiStatus(connected: List<String>, onClick: () -> Unit) {
    val strings = LocalStrings.current
    val isConnected = connected.isNotEmpty()
    val color = if (isConnected) Palette.green else Palette.amber
    Row(
        Modifier
            .height(56.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.12f))
            .border(1.dp, color.copy(alpha = 0.45f), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(8.dp))
        Icon(Icons.Filled.Piano, contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(8.dp))
        Text(
            if (isConnected) strings.keyboardConnected else strings.noKeyboard,
            color = color, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
        )
    }
}

/** A labeled number for the session's results. */
@Composable
fun Stat(label: String, value: String, color: Color = Palette.text) {
    Column(horizontalAlignment = Alignment.End) {
        Text(value, color = color, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(label, color = Palette.muted, fontSize = 12.sp)
    }
}

/** A thin vertical divider for rows of controls. */
@Composable
fun VerticalRule() {
    Box(Modifier.width(1.dp).fillMaxHeight().padding(vertical = 8.dp).background(Palette.border))
}
