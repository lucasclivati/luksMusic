// DeleteAccountSheet.kt — confirms and deletes the account (iOS App/ContentView.swift, DeleteAccountView). Firebase
// only deletes an account with a recent sign-in, so the user confirms who they are first: their password for e-mail
// accounts, Google for Google accounts. Apple accounts cannot be confirmed on Android.
package com.lukstrike.luksmusic.feature.account

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.account.AuthProvider
import com.lukstrike.luksmusic.account.AuthRepository.Reauthentication
import com.lukstrike.luksmusic.account.asString
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DeleteAccountSheet(viewModel: AccountViewModel, onDismiss: () -> Unit) {
    val user by viewModel.user.collectAsStateWithLifecycle()
    val isAuthenticating by viewModel.isAuthenticating.collectAsStateWithLifecycle()
    val authError by viewModel.authError.collectAsStateWithLifecycle()
    val activityContext = LocalActivity.current ?: LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var password by rememberSaveable { mutableStateOf("") }

    val close: () -> Unit = {
        scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
    }
    fun delete(reauthentication: Reauthentication) = viewModel.deleteAccount(reauthentication, onDeleted = onDismiss)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.account_delete_title),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = close) { Text(stringResource(R.string.action_cancel)) }
            }

            Text(stringResource(R.string.account_delete_explanation), style = MaterialTheme.typography.bodyMedium)

            val signedIn = user
            if (signedIn != null && signedIn.authProvider != AuthProvider.GUEST) {
                Text(
                    stringResource(R.string.account_delete_confirm_identity),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                when (signedIn.authProvider) {
                    AuthProvider.EMAIL -> {
                        val canDelete = password.isNotEmpty() && !isAuthenticating
                        OutlinedTextField(
                            value = password,
                            onValueChange = { password = it },
                            label = { Text(stringResource(R.string.account_delete_password_for, signedIn.email)) },
                            singleLine = true,
                            enabled = !isAuthenticating,
                            visualTransformation = PasswordVisualTransformation(),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                            keyboardActions = KeyboardActions(onDone = { if (canDelete) delete(Reauthentication.Password(password)) }),
                            modifier = Modifier.fillMaxWidth().semantics { contentType = ContentType.Password },
                        )
                        DestructiveButton(
                            text = stringResource(R.string.account_delete_permanently),
                            enabled = canDelete,
                            onClick = { delete(Reauthentication.Password(password)) },
                        )
                    }
                    AuthProvider.GOOGLE -> DestructiveButton(
                        text = stringResource(R.string.account_delete_with_google),
                        enabled = !isAuthenticating,
                        onClick = { delete(Reauthentication.Google(activityContext)) },
                    )
                    AuthProvider.APPLE -> Text(
                        stringResource(R.string.account_delete_apple_unavailable),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    AuthProvider.GUEST -> Unit
                }
            }

            if (isAuthenticating) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            }

            authError?.let { error ->
                Text(error.asString(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun DestructiveButton(text: String, enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.error,
            contentColor = Color.White,
        ),
        modifier = Modifier.fillMaxWidth().height(48.dp),
    ) {
        Text(text)
    }
}
