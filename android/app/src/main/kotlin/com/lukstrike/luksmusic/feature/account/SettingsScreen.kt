// SettingsScreen.kt — the Ajustes tab (iOS App/ContentView.swift, SettingsView): account and cloud sync, external MIDI
// keyboards, the app's language and its version. Android applies a new language at once, so there is no
// "reopen the app" note as on iOS.
package com.lukstrike.luksmusic.feature.account

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Piano
import androidx.compose.material.icons.outlined.Sync
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.BuildConfig
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.account.AuthProvider
import com.lukstrike.luksmusic.account.UserProfile
import com.lukstrike.luksmusic.account.asString
import com.lukstrike.luksmusic.midi.MidiDeviceInfo
import com.lukstrike.luksmusic.ui.AppLanguage
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(viewModel: AccountViewModel = viewModel(factory = AccountViewModel.Factory)) {
    val user by viewModel.user.collectAsStateWithLifecycle()
    val isSyncing by viewModel.isSyncing.collectAsStateWithLifecycle()
    val lastSync by viewModel.lastSyncDate.collectAsStateWithLifecycle()
    val syncError by viewModel.syncError.collectAsStateWithLifecycle()
    val midiDevices by viewModel.midiDevices.collectAsStateWithLifecycle()

    var showDeleteAccount by rememberSaveable { mutableStateOf(false) }
    var showLanguagePicker by rememberSaveable { mutableStateOf(false) }
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            LargeTopAppBar(
                title = { Text(stringResource(R.string.tab_settings)) },
                scrollBehavior = scrollBehavior,
            )
        },
        // The tab bar below already keeps the content above the navigation bar
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            // The login screen covers the app while signed out, so there is always a user here
            user?.let { signedIn ->
                item(key = "account") {
                    AccountSection(
                        user = signedIn,
                        isSyncing = isSyncing,
                        lastSync = lastSync,
                        syncErrorText = syncError?.asString(),
                        onSync = viewModel::syncLibrary,
                        onSignOut = viewModel::signOut,
                        onDeleteAccount = {
                            viewModel.clearError()
                            showDeleteAccount = true
                        },
                    )
                }
            }
            item(key = "midi") { MidiSection(midiDevices) }
            item(key = "language") { LanguageSection(onClick = { showLanguagePicker = true }) }
            item(key = "about") { AboutSection() }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    if (showDeleteAccount) {
        DeleteAccountSheet(viewModel = viewModel, onDismiss = { showDeleteAccount = false })
    }
    if (showLanguagePicker) {
        LanguageDialog(
            onChoose = { language ->
                showLanguagePicker = false
                if (language != AppLanguage.chosen) AppLanguage.choose(language)
            },
            onDismiss = { showLanguagePicker = false },
        )
    }
}

@Composable
private fun AccountSection(
    user: UserProfile,
    isSyncing: Boolean,
    lastSync: Long?,
    syncErrorText: String?,
    onSync: () -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
) {
    val destructive = MaterialTheme.colorScheme.error
    SettingsSection(stringResource(R.string.account_section_account)) {
        ListItem(
            colors = transparentListItemColors(),
            leadingContent = { Avatar(user.displayName) },
            headlineContent = { Text(user.displayName, style = MaterialTheme.typography.titleMedium) },
            supportingContent = {
                Text(
                    stringResource(R.string.account_email_and_provider, user.email, providerName(user.authProvider)),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            },
        )

        // Sync needs a cloud account; guests keep everything on the device
        if (user.authProvider != AuthProvider.GUEST) {
            SectionDivider()
            ListItem(
                colors = transparentListItemColors(),
                modifier = Modifier.clickable(enabled = !isSyncing, onClick = onSync),
                leadingContent = { Icon(Icons.Outlined.Sync, contentDescription = null) },
                headlineContent = { Text(stringResource(R.string.account_sync_button)) },
                supportingContent = syncErrorText?.let { { Text(it, color = destructive) } },
                trailingContent = {
                    when {
                        isSyncing -> CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        lastSync != null -> Text(
                            formatTime(lastSync),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
            )
        }

        SectionDivider()
        ListItem(
            colors = transparentListItemColors(),
            modifier = Modifier.clickable(onClick = onSignOut),
            leadingContent = { Icon(Icons.AutoMirrored.Outlined.Logout, contentDescription = null, tint = destructive) },
            headlineContent = { Text(stringResource(R.string.account_sign_out), color = destructive) },
        )

        if (user.authProvider != AuthProvider.GUEST) {
            SectionDivider()
            ListItem(
                colors = transparentListItemColors(),
                modifier = Modifier.clickable(onClick = onDeleteAccount),
                leadingContent = { Icon(Icons.Outlined.DeleteForever, contentDescription = null, tint = destructive) },
                headlineContent = { Text(stringResource(R.string.account_delete_account), color = destructive) },
            )
        }
    }
}

@Composable
private fun Avatar(name: String) {
    Box(
        modifier = Modifier.size(44.dp),
        contentAlignment = Alignment.Center,
    ) {
        Surface(shape = CircleShape, color = MaterialTheme.colorScheme.primary, modifier = Modifier.fillMaxSize()) {}
        Text(
            text = name.take(1).uppercase(),
            style = MaterialTheme.typography.titleMedium,
            color = Color.White,
        )
    }
}

@Composable
private fun MidiSection(devices: List<MidiDeviceInfo>) {
    SettingsSection(stringResource(R.string.account_section_midi)) {
        if (devices.isEmpty()) {
            ListItem(
                colors = transparentListItemColors(),
                leadingContent = { Icon(Icons.Outlined.Piano, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                headlineContent = { Text(stringResource(R.string.account_midi_connection)) },
                supportingContent = { Text(stringResource(R.string.account_midi_none)) },
            )
        } else {
            devices.forEachIndexed { index, device ->
                if (index > 0) SectionDivider()
                ListItem(
                    colors = transparentListItemColors(),
                    leadingContent = { Icon(Icons.Outlined.Piano, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                    headlineContent = { Text(device.name.ifBlank { stringResource(R.string.account_midi_connection) }) },
                    supportingContent = {
                        Text(
                            if (device.manufacturer.isBlank()) stringResource(R.string.account_midi_connected)
                            else stringResource(R.string.account_midi_connected_by, device.manufacturer)
                        )
                    },
                )
            }
        }
    }
}

@Composable
private fun LanguageSection(onClick: () -> Unit) {
    SettingsSection(stringResource(R.string.account_section_language)) {
        ListItem(
            colors = transparentListItemColors(),
            modifier = Modifier.clickable(onClick = onClick),
            leadingContent = { Icon(Icons.Outlined.Language, contentDescription = null) },
            headlineContent = { Text(stringResource(R.string.account_section_language)) },
            supportingContent = { Text(languageName(AppLanguage.chosen)) },
        )
    }
}

@Composable
private fun LanguageDialog(onChoose: (AppLanguage) -> Unit, onDismiss: () -> Unit) {
    val current = remember { AppLanguage.chosen }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.account_section_language)) },
        text = {
            Column(Modifier.selectableGroup()) {
                AppLanguage.entries.forEach { language ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .selectable(
                                selected = language == current,
                                onClick = { onChoose(language) },
                                role = Role.RadioButton,
                            )
                            .padding(horizontal = 4.dp),
                    ) {
                        RadioButton(selected = language == current, onClick = null)
                        Text(languageName(language), style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) } },
    )
}

@Composable
private fun AboutSection() {
    SettingsSection(stringResource(R.string.account_section_about)) {
        ListItem(
            colors = transparentListItemColors(),
            leadingContent = { Icon(Icons.Outlined.Info, contentDescription = null) },
            headlineContent = { Text(stringResource(R.string.account_app_version)) },
            trailingContent = {
                Text(
                    "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            },
        )
    }
}

@Composable
internal fun providerName(provider: AuthProvider): String = stringResource(
    when (provider) {
        AuthProvider.GOOGLE -> R.string.account_provider_google
        AuthProvider.EMAIL -> R.string.account_provider_email
        AuthProvider.APPLE -> R.string.account_provider_apple
        AuthProvider.GUEST -> R.string.account_provider_guest
    }
)

@Composable
private fun languageName(language: AppLanguage): String = stringResource(
    when (language) {
        AppLanguage.SYSTEM -> R.string.account_language_system
        AppLanguage.PORTUGUESE -> R.string.account_language_portuguese
        AppLanguage.ENGLISH -> R.string.account_language_english
    }
)

/** Hour and minute in the language on screen (iOS `.dateTime.hour().minute()`). */
@Composable
private fun formatTime(epochMillis: Long): String {
    val locale = LocalConfiguration.current.locales[0]
    return DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale)
        .format(Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault()))
}
