// TunerScreen.kt — the tuner tab (port of iOS Views/Tuner/TunerView.swift): listens to the microphone and shows the
// nearest note, its octave and how many cents off it is on a needle, green within ±5 cents. Guitar mode tunes the six
// strings (chosen by ear or by hand) and says whether to tighten or loosen; piano mode names any key from A0 to C8.
// The reference A and the mode are remembered. The microphone runs only while the screen is visible.
package com.lukstrike.luksmusic.feature.tuner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.LocalActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowCircleDown
import androidx.compose.material.icons.filled.ArrowCircleUp
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Piano
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.TunerMode
import com.lukstrike.luksmusic.core.model.Tuning
import com.lukstrike.luksmusic.core.model.TuningReading
import com.lukstrike.luksmusic.ui.usesLetterNames
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun TunerScreen() {
    val container = appContainer()
    val viewModel: TunerViewModel = viewModel { TunerViewModel(container) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val permission = rememberMicrophonePermission()

    // Listen while the screen is visible and the microphone allowed; stop when it leaves or the app goes away
    if (permission.isGranted) {
        LifecycleStartEffect(viewModel) {
            viewModel.startListening()
            onStopOrDispose { viewModel.stopListening() }
        }
    }

    TunerContent(
        state = state,
        letters = usesLetterNames(),
        permission = permission,
        onMode = viewModel::setMode,
        onPickString = viewModel::pickString,
        onLowerA4 = viewModel::lowerA4,
        onRaiseA4 = viewModel::raiseA4,
        onResetA4 = viewModel::resetA4,
        onPlayReference = viewModel::playReference,
    )
}

/** Digits of equal width, so changing numbers don't jitter. */
private val TabularDigits = TextStyle(fontFeatureSettings = "tnum")

// Microphone permission

/** The microphone permission and how to get it: the system dialog, or the app's settings once it was denied for good. */
class MicrophonePermission(
    val isGranted: Boolean,
    /** Denied with "don't ask again" (or by policy): only the app's settings can turn it on. */
    val isPermanentlyDenied: Boolean,
    val request: () -> Unit,
    val openSettings: () -> Unit,
)

@Composable
private fun rememberMicrophonePermission(): MicrophonePermission {
    val context = LocalContext.current
    val activity = LocalActivity.current
    fun granted() = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

    var isGranted by remember { mutableStateOf(granted()) }
    var permanentlyDenied by rememberSaveable { mutableStateOf(false) }
    var askedOnce by rememberSaveable { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { result ->
        isGranted = result
        // Refused without the system offering to ask again: the dialog won't show anymore
        permanentlyDenied = !result && activity?.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO) == false
    }
    // Back from the app's settings (or a permission changed elsewhere)
    LifecycleResumeEffect(Unit) {
        isGranted = granted()
        if (isGranted) permanentlyDenied = false
        onPauseOrDispose { }
    }
    // Like iOS, the tuner asks as soon as it opens; the explanation stays on screen if the answer is no
    LaunchedEffect(Unit) {
        if (!isGranted && !askedOnce) {
            askedOnce = true
            launcher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }
    return MicrophonePermission(
        isGranted = isGranted,
        isPermanentlyDenied = permanentlyDenied,
        request = { launcher.launch(Manifest.permission.RECORD_AUDIO) },
        openSettings = {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        },
    )
}

// Content

@Composable
private fun TunerContent(
    state: TunerUiState,
    letters: Boolean,
    permission: MicrophonePermission,
    onMode: (TunerMode) -> Unit,
    onPickString: (Int?) -> Unit,
    onLowerA4: () -> Unit,
    onRaiseA4: () -> Unit,
    onResetA4: () -> Unit,
    onPlayReference: () -> Unit,
) {
    val reading = state.reading
    Box(
        Modifier
            .fillMaxSize()
            .background(TunerPalette.background)
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal))
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Header(state)
            ModePicker(state.mode, onMode)
            NoteDisplay(reading, letters)
            TunerGauge(
                cents = reading?.cents,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(170.dp)
                    .padding(horizontal = 8.dp),
            )
            if (permission.isGranted) {
                Status(state, reading)
            } else {
                PermissionCard(permission)
            }
            Frequencies(reading, state.heardFrequency)
            if (state.mode == TunerMode.GUITAR) {
                StringPicker(state, reading, letters, onPickString)
            }
            ReferenceControls(state.a4, letters, onLowerA4, onRaiseA4, onResetA4, onPlayReference)
        }
    }
}

@Composable
private fun Header(state: TunerUiState) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            stringResource(R.string.tuner_title),
            fontSize = 30.sp,
            fontWeight = FontWeight.Bold,
            color = TunerPalette.text,
            modifier = Modifier.weight(1f),
        )
        LevelMeter(level = state.inputLevel, isListening = state.isListening)
    }
}

@Composable
private fun ModePicker(mode: TunerMode, onMode: (TunerMode) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(TunerPalette.panel, RoundedCornerShape(12.dp))
            .border(1.dp, TunerPalette.border, RoundedCornerShape(12.dp))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        for (option in TunerMode.entries) {
            val selected = option == mode
            val background by animateColorAsState(if (selected) TunerPalette.deepBlue else Color.Transparent, label = "mode")
            Row(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(9.dp))
                    .background(background)
                    .clickable(role = Role.Tab) { onMode(option) }
                    .semantics { this.selected = selected }
                    .padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                val tint = if (selected) TunerPalette.text else TunerPalette.muted
                Icon(option.icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(6.dp))
                Text(stringResource(option.title), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = tint)
            }
        }
    }
}

private val TunerMode.title: Int
    get() = when (this) {
        TunerMode.GUITAR -> R.string.tuner_mode_guitar
        TunerMode.PIANO -> R.string.tuner_mode_piano
    }

private val TunerMode.icon: ImageVector
    get() = when (this) {
        TunerMode.GUITAR -> Icons.Outlined.MusicNote
        TunerMode.PIANO -> Icons.Outlined.Piano
    }

@Composable
private fun NoteDisplay(reading: TuningReading?, letters: Boolean) {
    val color by animateColorAsState(
        when {
            reading == null -> TunerPalette.muted
            reading.isInTune -> TunerPalette.green
            else -> TunerPalette.text
        },
        label = "note",
    )
    val description = reading?.let { Tuning.noteName(it.midi, letters) + Tuning.octave(it.midi) } ?: "--"
    Row(
        Modifier
            .height(110.dp)
            .semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (reading != null) {
            Text(
                Tuning.noteName(reading.midi, letters), fontSize = 92.sp, fontWeight = FontWeight.Bold, color = color,
                modifier = Modifier.alignByBaseline(),
            )
            Spacer(Modifier.size(4.dp))
            Text(
                "${Tuning.octave(reading.midi)}", fontSize = 34.sp, fontWeight = FontWeight.SemiBold,
                color = TunerPalette.muted, modifier = Modifier.alignByBaseline(),
            )
        } else {
            Text("--", fontSize = 92.sp, fontWeight = FontWeight.Bold, color = color)
        }
    }
}

@Composable
private fun Status(state: TunerUiState, reading: TuningReading?) {
    val statusColor = if (reading == null) TunerPalette.muted else tuningColor(reading.cents)
    val text = when {
        reading == null -> state.errorMessage
            ?: stringResource(if (state.mode == TunerMode.GUITAR) R.string.tuner_play_string else R.string.tuner_play_note)
        reading.isInTune -> stringResource(R.string.tuner_in_tune)
        state.mode == TunerMode.GUITAR ->
            stringResource(if (reading.isFlat) R.string.tuner_tighten else R.string.tuner_loosen)
        else -> stringResource(if (reading.isFlat) R.string.tuner_flat else R.string.tuner_sharp)
    }
    val icon = when {
        reading == null -> null
        reading.isInTune -> Icons.Filled.CheckCircle
        reading.isFlat -> Icons.Filled.ArrowCircleUp
        else -> Icons.Filled.ArrowCircleDown
    }
    val cents = reading?.cents?.roundToInt()
    Column(
        Modifier.semantics(mergeDescendants = true) { },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            if (cents == null) " " else stringResource(R.string.tuner_cents, if (cents > 0) "+$cents" else "$cents"),
            fontSize = 22.sp, fontWeight = FontWeight.Bold, color = statusColor, style = TabularDigits,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            if (icon != null) Icon(icon, contentDescription = null, tint = statusColor, modifier = Modifier.size(20.dp))
            Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = statusColor, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun PermissionCard(permission: MicrophonePermission) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(TunerPalette.panel, RoundedCornerShape(12.dp))
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Filled.Mic, contentDescription = null, tint = TunerPalette.cyan, modifier = Modifier.size(28.dp))
        Text(
            stringResource(R.string.tuner_permission_title),
            fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = TunerPalette.text, textAlign = TextAlign.Center,
        )
        Text(
            stringResource(if (permission.isPermanentlyDenied) R.string.tuner_permission_denied else R.string.tuner_permission_body),
            fontSize = 14.sp, color = TunerPalette.muted, textAlign = TextAlign.Center,
        )
        Button(
            onClick = if (permission.isPermanentlyDenied) permission.openSettings else permission.request,
            colors = ButtonDefaults.buttonColors(containerColor = TunerPalette.deepBlue, contentColor = TunerPalette.text),
        ) {
            Text(
                stringResource(
                    if (permission.isPermanentlyDenied) R.string.tuner_permission_settings else R.string.tuner_permission_allow
                )
            )
        }
    }
}

@Composable
private fun Frequencies(reading: TuningReading?, heard: Double?) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        FrequencyCard(stringResource(R.string.tuner_heard), reading?.frequency ?: heard, Modifier.weight(1f))
        FrequencyCard(stringResource(R.string.tuner_target), reading?.targetFrequency, Modifier.weight(1f))
    }
}

@Composable
private fun FrequencyCard(title: String, value: Double?, modifier: Modifier) {
    val locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()
    Column(
        modifier
            .background(TunerPalette.panel, RoundedCornerShape(12.dp))
            .padding(vertical = 10.dp)
            .semantics(mergeDescendants = true) { },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = TunerPalette.muted)
        Text(
            if (value == null) "-- Hz" else String.format(locale, "%.1f Hz", value),
            fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = TunerPalette.text, style = TabularDigits,
        )
    }
}

@Composable
private fun StringPicker(state: TunerUiState, reading: TuningReading?, letters: Boolean, onPickString: (Int?) -> Unit) {
    val active = state.activeString
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.tuner_string), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = TunerPalette.muted)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            val auto = state.manualString == null
            ChoiceTile(
                selected = auto,
                background = if (auto) TunerPalette.deepBlue else TunerPalette.raised,
                outline = Color.Transparent,
                onClick = { onPickString(null) },
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    stringResource(R.string.tuner_auto), fontSize = 14.sp, fontWeight = FontWeight.Bold,
                    color = if (auto) TunerPalette.text else TunerPalette.muted,
                )
            }
            Tuning.guitarStrings.forEachIndexed { index, midi ->
                val isActive = active == index
                val isPicked = state.manualString == index
                val isTuned = isActive && reading?.isInTune == true
                val name = Tuning.noteName(midi, letters)
                ChoiceTile(
                    selected = isPicked,
                    background = if (isPicked) TunerPalette.deepBlue else TunerPalette.raised,
                    outline = when {
                        isTuned -> TunerPalette.green
                        isActive -> TunerPalette.cyan
                        else -> Color.Transparent
                    },
                    onClick = { onPickString(if (isPicked) null else index) },
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = name + Tuning.octave(midi) },
                ) {
                    val color = if (isActive) TunerPalette.text else TunerPalette.muted
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(name, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = color, maxLines = 1, softWrap = false)
                        Text(
                            "${Tuning.octave(midi)}", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = color,
                            modifier = Modifier.alpha(0.7f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChoiceTile(
    selected: Boolean,
    background: Color,
    outline: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(10.dp)
    Box(
        modifier
            .heightIn(min = 50.dp)
            .clip(shape)
            .background(background)
            .border(BorderStroke(2.dp, outline), shape)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected },
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun ReferenceControls(
    a4: Double,
    letters: Boolean,
    onLower: () -> Unit,
    onRaise: () -> Unit,
    onReset: () -> Unit,
    onPlay: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(TunerPalette.panel, RoundedCornerShape(12.dp))
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.tuner_reference_a), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = TunerPalette.text)
                Text("${Tuning.noteName(69, letters)}4", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = TunerPalette.muted)
            }
            RoundButton(Icons.Filled.Remove, stringResource(R.string.tuner_reference_down), a4 > Tuning.a4Range.start, onLower)
            val resetLabel = stringResource(R.string.tuner_reference_reset)
            Text(
                "${a4.roundToInt()} Hz",
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                style = TabularDigits,
                color = if (a4 == Tuning.DEFAULT_A4) TunerPalette.text else TunerPalette.cyan,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .widthIn(min = 76.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClickLabel = resetLabel, onClick = onReset)
                    .padding(vertical = 8.dp),
            )
            RoundButton(Icons.Filled.Add, stringResource(R.string.tuner_reference_up), a4 < Tuning.a4Range.endInclusive, onRaise)
        }
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(TunerPalette.raised)
                .clickable(role = Role.Button, onClick = onPlay)
                .padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.AutoMirrored.Filled.VolumeUp, contentDescription = null, tint = TunerPalette.text, modifier = Modifier.size(20.dp))
            Spacer(Modifier.size(8.dp))
            Text(stringResource(R.string.tuner_play_reference), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = TunerPalette.text)
        }
    }
}

@Composable
private fun RoundButton(icon: ImageVector, label: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(TunerPalette.raised)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label }
            .alpha(if (enabled) 1f else 0.4f),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = TunerPalette.text, modifier = Modifier.size(16.dp))
    }
}
