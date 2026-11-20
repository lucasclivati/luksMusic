// AccountComponents.kt — the grouped sections Ajustes and Progresso are built from (the iOS inset-grouped List/Form):
// a small header above a rounded card of rows.
package com.lukstrike.luksmusic.feature.account

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

internal val SectionCorner = 16.dp

@Composable
internal fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.9f),
        modifier = modifier
            .padding(start = 32.dp, end = 32.dp, top = 20.dp, bottom = 8.dp)
            .semantics { heading() },
    )
}

/** A titled card of rows; separate rows with [SectionDivider]. */
@Composable
internal fun SettingsSection(
    title: String?,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth()) {
        if (title != null) SectionHeader(title)
        Surface(
            shape = RoundedCornerShape(SectionCorner),
            color = MaterialTheme.colorScheme.surfaceContainer,
            modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth(),
        ) {
            Column(content = content)
        }
    }
}

@Composable
internal fun SectionDivider() {
    HorizontalDivider(Modifier.padding(start = 56.dp), color = MaterialTheme.colorScheme.outlineVariant)
}

/** Rows sit on the section's card, so they draw no background of their own. */
@Composable
internal fun transparentListItemColors() = ListItemDefaults.colors(containerColor = Color.Transparent)
