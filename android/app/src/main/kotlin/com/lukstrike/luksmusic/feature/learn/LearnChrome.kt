// LearnChrome.kt — the frame shared by the lesson player and the reading drill, drawn like the iOS PlayerChrome
// (the luksmusic.web.app player's colors): a dark title bar, raised buttons, and the docked keyboard.
package com.lukstrike.luksmusic.feature.learn

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.ui.components.PianoKeyboard
import com.lukstrike.luksmusic.ui.components.PianoKeyboardState

/** Colors of the web player (iOS PlayerTheme). */
object LearnColors {
    val background = Color(11, 17, 32)
    val panel = Color(17, 24, 39)
    val raised = Color(30, 41, 59)
    val border = Color(51, 65, 85)
    val blue = Color(59, 130, 246)
    val deepBlue = Color(37, 99, 235)
    val cyan = Color(56, 189, 248)
    val green = Color(74, 222, 128)
    val text = Color(248, 250, 252)
    val muted = Color(148, 163, 184)
    val amber = Color(251, 191, 36)
    val violet = Color(167, 139, 250)
    val red = Color(248, 113, 113)
    val orange = Color(251, 146, 60)
}

/** The title bar: back, a title and subtitle, and the screen's buttons on the right. Draws under the status bar. */
@Composable
fun LearnTopBar(
    title: String,
    subtitle: String,
    onBack: () -> Unit,
    trailing: @Composable () -> Unit = {},
) {
    Column(Modifier.background(LearnColors.panel).windowInsetsPadding(WindowInsets.statusBars)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ChromeIconButton(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back), onClick = onBack)
            Column(Modifier.weight(1f)) {
                Text(title, color = LearnColors.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (subtitle.isNotEmpty()) {
                    Text(subtitle, color = LearnColors.muted, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            trailing()
        }
        HorizontalDivider(color = LearnColors.raised)
    }
}

/** A square raised icon button of the title bar. */
@Composable
fun ChromeIconButton(icon: ImageVector, label: String, tint: Color = LearnColors.text, onClick: () -> Unit) {
    IconButton(
        onClick = onClick,
        modifier = Modifier.size(36.dp),
        shape = RoundedCornerShape(8.dp),
        colors = IconButtonDefaults.iconButtonColors(containerColor = LearnColors.raised, contentColor = tint),
    ) {
        Icon(icon, contentDescription = label, modifier = Modifier.size(20.dp))
    }
}

@Composable
fun LearnPrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(42.dp),
        shape = RoundedCornerShape(10.dp),
        contentPadding = PaddingValues(horizontal = 26.dp),
        colors = ButtonDefaults.buttonColors(containerColor = LearnColors.deepBlue, contentColor = Color.White),
    ) {
        Text(text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun LearnSecondaryButton(text: String, icon: ImageVector, enabled: Boolean = true, onClick: () -> Unit) {
    FilledTonalButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.height(42.dp),
        shape = RoundedCornerShape(10.dp),
        contentPadding = PaddingValues(horizontal = 12.dp),
        colors = ButtonDefaults.filledTonalButtonColors(containerColor = LearnColors.raised, contentColor = LearnColors.text),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * The docked on-screen keyboard. Reports how many white keys fit ([whiteKeysFor] the width in dp: by default about
 * 26 dp each, two octaves on a phone held upright and more on its side) and stays above the navigation bar.
 */
@Composable
fun LearnKeyboard(
    state: PianoKeyboardState,
    modifier: Modifier = Modifier,
    onWhiteKeyCount: (Int) -> Unit,
    onKeyPress: (Int) -> Unit,
    onKeyRelease: (Int) -> Unit,
    whiteKeysFor: (Float) -> Int = ::whiteKeyCount,
) {
    Box(modifier.background(LearnColors.panel).windowInsetsPadding(WindowInsets.navigationBars)) {
        BoxWithConstraints(Modifier.padding(horizontal = 2.dp)) {
            val width = with(LocalDensity.current) { constraints.maxWidth.toDp() }
            val count = whiteKeysFor(width.value)
            LaunchedEffect(count) { onWhiteKeyCount(count) }
            PianoKeyboard(state = state, onKeyPress = onKeyPress, onKeyRelease = onKeyRelease)
        }
    }
}

/** About 26 points per white key, from 10 to 36 keys (iOS whiteKeyCount). */
fun whiteKeyCount(widthDp: Float): Int = (widthDp / 26).toInt().coerceIn(10, 36)

/** The lessons' keyboard: two octaves at most (15 white keys, C to C) so it stays clean and readable (iOS). */
fun lessonWhiteKeyCount(widthDp: Float): Int = (widthDp / 25).toInt().coerceIn(10, 15)

/** Headphones or a headset are connected, so the app's sound won't reach the microphone. */
fun Context.hasHeadphones(): Boolean {
    val audio = getSystemService(AudioManager::class.java) ?: return false
    val private = setOf(
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_USB_HEADSET,
    ) + (if (android.os.Build.VERSION.SDK_INT >= 31) setOf(AudioDeviceInfo.TYPE_BLE_HEADSET) else emptySet())
    return audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in private }
}
