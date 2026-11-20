// ImportScoreSheet.kt — port of luksMusic/Views/Library/ImportScoreView.swift: importing a MusicXML file, plain
// (.xml, .musicxml) or compressed (.mxl), picked with the system file picker or opened from another app. The file is
// read as soon as it is picked, so a damaged one says so at once; then its details can be changed before import.
package com.lukstrike.luksmusic.feature.library

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.automirrored.outlined.NoteAdd
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.ui.theme.LuksColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportScoreSheet(viewModel: LibraryViewModel, onDismiss: () -> Unit, onOpenScore: (String) -> Unit) {
    val context = LocalContext.current
    val phase by viewModel.importPhase.collectAsStateWithLifecycle()
    val form by viewModel.importForm.collectAsStateWithLifecycle()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        // Closing the picker without a file leaves the sheet as it was
        if (uri != null) viewModel.pickFile(context, uri)
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding()) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterStart)) {
                    Text(stringResource(R.string.action_cancel))
                }
                Text(
                    stringResource(R.string.library_import_title),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.align(Alignment.Center),
                )
            }

            AnimatedContent(
                targetState = phase,
                contentKey = { it::class },
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "import",
                modifier = Modifier.fillMaxWidth().heightIn(min = 420.dp),
            ) { current ->
                when (current) {
                    ImportPhase.Idle -> FileSelection { picker.launch(ScoreFiles.pickerMimeTypes) }
                    ImportPhase.Loading -> Progress(stringResource(R.string.library_import_reading), null)
                    is ImportPhase.Previewing -> MetadataForm(current.file.fileName, form, viewModel::updateImportForm, viewModel::performImport)
                    ImportPhase.Importing -> Progress(stringResource(R.string.library_import_importing), form.title)
                    is ImportPhase.Success -> Success(current.title, onDone = onDismiss, onOpen = { onOpenScore(current.scoreId) })
                    is ImportPhase.Failure -> Failure(current.message.resolve(), onRetry = viewModel::resetImport, onCancel = onDismiss)
                }
            }
        }
    }
}

/** Before a file is picked. */
@Composable
private fun FileSelection(onChoose: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 32.dp, horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        Box(
            Modifier.size(200.dp, 160.dp).border(
                BorderStroke(2.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)), RoundedCornerShape(20.dp)
            ),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.AutoMirrored.Outlined.NoteAdd, contentDescription = null, tint = MaterialTheme.colorScheme.secondary, modifier = Modifier.size(44.dp))
                Text(
                    stringResource(R.string.library_import_choose_prompt),
                    style = MaterialTheme.typography.bodyMedium,
                    color = LuksColors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 12.dp),
                )
            }
        }
        Button(onClick = onChoose, modifier = Modifier.fillMaxWidth().height(52.dp)) {
            Icon(Icons.Outlined.Folder, contentDescription = null)
            Spacer(Modifier.size(8.dp))
            Text(stringResource(R.string.library_import_choose_file), fontWeight = FontWeight.SemiBold)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.library_import_formats), style = MaterialTheme.typography.labelMedium, color = LuksColors.textSecondary)
            Text(
                stringResource(R.string.library_import_formats_list),
                style = MaterialTheme.typography.labelMedium,
                color = LuksColors.textSecondary.copy(alpha = 0.7f),
            )
        }
    }
}

@Composable
private fun Progress(message: String, detail: String?) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 120.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        CircularProgressIndicator()
        Text(message, style = MaterialTheme.typography.bodyMedium, color = LuksColors.textSecondary)
        if (!detail.isNullOrEmpty()) Text(detail, style = MaterialTheme.typography.labelSmall, color = LuksColors.textSecondary.copy(alpha = 0.7f))
    }
}

/** The file's details, editable before import. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MetadataForm(fileName: String, form: ImportForm, onChange: (ImportForm) -> Unit, onImport: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SectionHeader(stringResource(R.string.library_import_selected_file))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Outlined.Description, contentDescription = null, tint = MaterialTheme.colorScheme.secondary)
            Text(fileName, color = LuksColors.textSecondary, style = MaterialTheme.typography.bodyMedium)
        }

        SectionHeader(stringResource(R.string.library_import_details))
        OutlinedTextField(
            value = form.title,
            onValueChange = { onChange(form.copy(title = it)) },
            label = { Text(stringResource(R.string.library_import_field_title)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Next),
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = form.composer,
            onValueChange = { onChange(form.copy(composer = it)) },
            label = { Text(stringResource(R.string.library_import_field_composer)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
            modifier = Modifier.fillMaxWidth(),
        )
        var expanded by remember { mutableStateOf(false) }
        ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
            OutlinedTextField(
                value = stringResource(difficultyLabel(form.difficulty)),
                onValueChange = {},
                readOnly = true,
                label = { Text(stringResource(R.string.library_import_field_difficulty)) },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                modifier = Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable),
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                Difficulty.entries.forEach { difficulty ->
                    DropdownMenuItem(
                        text = { Text(stringResource(difficultyLabel(difficulty))) },
                        onClick = { onChange(form.copy(difficulty = difficulty)); expanded = false },
                    )
                }
            }
        }
        Text(stringResource(R.string.library_import_details_footer), style = MaterialTheme.typography.labelMedium, color = LuksColors.textSecondary)

        Button(onClick = onImport, modifier = Modifier.fillMaxWidth().padding(top = 8.dp).height(52.dp)) {
            Icon(Icons.Outlined.FileDownload, contentDescription = null)
            Spacer(Modifier.size(8.dp))
            Text(stringResource(R.string.library_import_button), fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun SectionHeader(text: String) =
    Text(text.uppercase(), style = MaterialTheme.typography.labelMedium, color = LuksColors.textSecondary, modifier = Modifier.padding(top = 8.dp))

@Composable
private fun Success(title: String, onDone: () -> Unit, onOpen: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 72.dp, horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(Icons.Outlined.CheckCircle, contentDescription = null, tint = LuksColors.success, modifier = Modifier.size(64.dp))
        Text(stringResource(R.string.library_import_success), style = MaterialTheme.typography.titleLarge)
        Text(
            stringResource(R.string.library_import_success_detail, title),
            style = MaterialTheme.typography.bodyMedium,
            color = LuksColors.textSecondary,
            textAlign = TextAlign.Center,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.padding(top = 8.dp)) {
            OutlinedButton(onClick = onDone) { Text(stringResource(R.string.action_done)) }
            Button(onClick = onOpen) { Text(stringResource(R.string.library_import_open)) }
        }
    }
}

@Composable
private fun Failure(message: String, onRetry: () -> Unit, onCancel: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 72.dp, horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(Icons.Outlined.Warning, contentDescription = null, tint = LuksColors.warning, modifier = Modifier.size(56.dp))
        Text(stringResource(R.string.library_import_failed), style = MaterialTheme.typography.titleLarge)
        Text(message, style = MaterialTheme.typography.bodyMedium, color = LuksColors.textSecondary, textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.padding(top = 8.dp)) {
            Button(onClick = onRetry) { Text(stringResource(R.string.action_retry)) }
            OutlinedButton(onClick = onCancel) { Text(stringResource(R.string.action_cancel)) }
        }
    }
}
