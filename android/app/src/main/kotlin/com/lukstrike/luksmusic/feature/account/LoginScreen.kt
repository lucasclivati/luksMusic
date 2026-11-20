// LoginScreen.kt — shown until someone signs in (port of Views/Auth/LoginView.swift): Google, e-mail and password
// (signs in, or creates the account), or guest mode. Sign in with Apple does not exist on Android, so a short note
// tells iPhone users who signed up with Apple that they can continue as guests.
package com.lukstrike.luksmusic.feature.account

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.account.asString
import com.lukstrike.luksmusic.ui.theme.LuksColors

// iOS system colors (dark appearance) used by the login screen
private val SystemBlue = Color(0xFF0A84FF)
private val SystemGreen = Color(0xFF30D158)
private val SystemRed = Color(0xFFFF453A)
private val SystemPurple = Color(0xFFBF5AF2)

/** Firebase rejects passwords shorter than this. */
private const val MIN_PASSWORD_LENGTH = 6

/** Shown until someone signs in or continues as a guest. */
@Composable
fun LoginScreen() {
    val viewModel: AccountViewModel = viewModel(factory = AccountViewModel.Factory)
    val isAuthenticating by viewModel.isAuthenticating.collectAsStateWithLifecycle()
    val authError by viewModel.authError.collectAsStateWithLifecycle()
    val activityContext = LocalActivity.current ?: LocalContext.current

    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var showEmailForm by rememberSaveable { mutableStateOf(false) }

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(listOf(Color(0.08f, 0.08f, 0.08f), Color(0.02f, 0.02f, 0.02f))))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                modifier = Modifier.widthIn(max = 480.dp).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                Spacer(Modifier.height(20.dp))
                AppHeader()

                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    FeatureRow(
                        icon = Icons.Filled.Cloud, color = SystemBlue,
                        title = stringResource(R.string.account_feature_cloud_title),
                        subtitle = stringResource(R.string.account_feature_cloud_subtitle),
                    )
                    FeatureRow(
                        icon = Icons.Filled.GraphicEq, color = SystemGreen,
                        title = stringResource(R.string.account_feature_piano_title),
                        subtitle = stringResource(R.string.account_feature_piano_subtitle),
                    )
                }

                AnimatedVisibility(
                    visible = authError != null,
                    enter = fadeIn() + expandVertically(),
                    exit = fadeOut() + shrinkVertically(),
                ) {
                    Text(
                        text = authError?.asString().orEmpty(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                Column(
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(bottom = 32.dp),
                ) {
                    GoogleButton(
                        isAuthenticating = isAuthenticating,
                        onClick = { viewModel.signInWithGoogle(activityContext) },
                    )

                    AnimatedContent(
                        targetState = showEmailForm,
                        transitionSpec = { fadeIn() togetherWith fadeOut() },
                        label = "emailForm",
                    ) { formShown ->
                        if (formShown) {
                            EmailForm(
                                email = email,
                                onEmailChange = { email = it },
                                password = password,
                                onPasswordChange = { password = it },
                                enabled = !isAuthenticating,
                                onSubmit = { viewModel.signInWithEmail(email, password) },
                            )
                        } else {
                            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                                TextButton(onClick = { showEmailForm = true }) {
                                    Icon(Icons.Filled.Email, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(Modifier.size(8.dp))
                                    Text(
                                        stringResource(R.string.account_sign_in_email),
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    }

                    TextButton(onClick = viewModel::continueAsGuest, enabled = !isAuthenticating) {
                        Text(
                            stringResource(R.string.account_continue_guest),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }

                    Text(
                        text = stringResource(R.string.account_apple_note),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

@Composable
private fun AppHeader() {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        val accent = MaterialTheme.colorScheme.primary
        Box(
            modifier = Modifier
                .size(84.dp)
                .shadow(16.dp, CircleShape, ambientColor = accent.copy(alpha = 0.4f), spotColor = accent.copy(alpha = 0.4f))
                .background(Brush.linearGradient(listOf(accent, SystemPurple)), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Piano, contentDescription = null, tint = Color.White, modifier = Modifier.size(40.dp))
        }
        Text(
            text = stringResource(R.string.app_name),
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White,
        )
        Text(
            text = stringResource(R.string.account_tagline),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun FeatureRow(icon: ImageVector, color: Color, title: String, subtitle: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(
            Modifier.size(36.dp).background(color.copy(alpha = 0.15f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = Color.White)
            Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun GoogleButton(isAuthenticating: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        enabled = !isAuthenticating,
        shape = RoundedCornerShape(12.dp),
        color = LuksColors.backgroundSecondary,
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.1f)),
        modifier = Modifier.fillMaxWidth().height(52.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (isAuthenticating) {
                CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
            } else {
                Icon(Icons.Filled.Public, contentDescription = null, tint = SystemRed)
                Spacer(Modifier.size(12.dp))
                Text(
                    stringResource(R.string.account_sign_in_google),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
    }
}

@Composable
private fun EmailForm(
    email: String,
    onEmailChange: (String) -> Unit,
    password: String,
    onPasswordChange: (String) -> Unit,
    enabled: Boolean,
    onSubmit: () -> Unit,
) {
    val focusManager = LocalFocusManager.current
    var passwordVisible by rememberSaveable { mutableStateOf(false) }
    val canSubmit = enabled && password.length >= MIN_PASSWORD_LENGTH
    val submit = {
        if (canSubmit) {
            focusManager.clearFocus()
            onSubmit()
        }
    }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = LuksColors.backgroundSecondary,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedTextField(
                value = email,
                onValueChange = onEmailChange,
                label = { Text(stringResource(R.string.account_email)) },
                singleLine = true,
                enabled = enabled,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focusManager.moveFocus(FocusDirection.Down) }),
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentType = ContentType.EmailAddress + ContentType.Username },
            )
            OutlinedTextField(
                value = password,
                onValueChange = onPasswordChange,
                label = { Text(stringResource(R.string.account_password)) },
                singleLine = true,
                enabled = enabled,
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { submit() }),
                trailingIcon = {
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            if (passwordVisible) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                            contentDescription = stringResource(
                                if (passwordVisible) R.string.account_hide_password else R.string.account_show_password
                            ),
                        )
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentType = ContentType.Password },
            )
            Button(
                onClick = submit,
                enabled = canSubmit,
                shape = RoundedCornerShape(8.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SystemBlue, contentColor = Color.White),
                modifier = Modifier.fillMaxWidth().height(46.dp),
            ) {
                Text(stringResource(R.string.account_sign_in_or_create), fontWeight = FontWeight.Bold)
            }
        }
    }
}
