// LessonIntroScreen.kt — port of luksMusic/Views/Learn/LessonIntroView.swift.
//
// Full-screen vertical animated introduction for a lesson: builds the five staff lines and four spaces, shows
// middle C two steps below the first line, and presses one white key at a time up to the next C across a clean
// two-octave keyboard, with subtitles in the app's language. What is on screen at each moment comes from core's
// LessonIntroScript; this file only keeps the clock, plays the piano at each press and draws the snapshot.
package com.lukstrike.luksmusic.feature.learn

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.SmartDisplay
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleStartEffect
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.audio.AudioEngine
import com.lukstrike.luksmusic.core.lessons.LessonIntro
import com.lukstrike.luksmusic.core.lessons.LessonIntroPress
import com.lukstrike.luksmusic.core.lessons.LessonIntroScript
import com.lukstrike.luksmusic.core.lessons.LessonIntroSnapshot
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.practice.PianoKeys
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.trebleClef
import com.lukstrike.luksmusic.ui.components.PianoKeyboardState
import com.lukstrike.luksmusic.ui.usesLetterNames
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

// ---- Controller

/** The intro's clock and sound (iOS LessonIntroController). Each scripted press sounds once as the clock crosses it. */
@Stable
class LessonIntroController(
    val intro: LessonIntro,
    private val audio: AudioEngine,
    private val scope: CoroutineScope,
) {
    val duration: Double = LessonIntroScript.duration(intro)
    private val presses: List<LessonIntroPress> = LessonIntroScript.presses(intro)
    private val firedPressIds = HashSet<Int>()

    var elapsed by mutableDoubleStateOf(0.0)
        private set
    var isPlaying by mutableStateOf(true)
        private set
    var isFinished by mutableStateOf(false)
        private set
    /** A key the student tapped, lit for a moment */
    var userTappedKey by mutableStateOf<Int?>(null)
        private set

    val progress: Double get() = if (duration > 0) (elapsed / duration).coerceIn(0.0, 1.0) else 0.0

    fun start() {
        audio.start()
    }

    /** The screen went away or to the background: the clock stops and the piano goes quiet. */
    fun pause() {
        isPlaying = false
        audio.stopAllNotes()
    }

    fun stop() = pause()

    fun togglePlayback() {
        if (isFinished) return replay()
        if (isPlaying) pause() else isPlaying = true
    }

    fun replay() {
        audio.stopAllNotes()
        elapsed = 0.0
        firedPressIds.clear()
        isFinished = false
        isPlaying = true
    }

    fun seek(fraction: Double) {
        elapsed = fraction.coerceIn(0.0, 1.0) * duration
        // Presses already passed stay silent
        firedPressIds.clear()
        presses.filter { it.onset <= elapsed }.mapTo(firedPressIds) { it.id }
        isFinished = elapsed >= duration
        if (isFinished) isPlaying = false
    }

    /** One display frame went by: moves the clock and strikes the keys it crossed. */
    fun advance(seconds: Double) {
        if (!isPlaying) return
        val previous = elapsed
        val next = min(duration, previous + seconds)
        elapsed = next
        for (press in presses) {
            if (press.onset <= next && press.onset >= previous - 0.15 && firedPressIds.add(press.id)) {
                audio.playNote(press.midi, if (press.spawnsNote) 86 else 78, press.holdDuration * 0.92)
            }
        }
        if (next >= duration) {
            isPlaying = false
            isFinished = true
        }
    }

    fun tapPreviewKey(midi: Int) {
        audio.start()
        audio.playNote(midi, 84, 0.55)
        userTappedKey = midi
        scope.launch {
            delay(380)
            if (userTappedKey == midi) userTappedKey = null
        }
    }
}

// ---- Main Vertical Stage

/** The animated introduction filling the lesson's content area; [onContinue] moves on to the next step. */
@Composable
fun LessonIntroScreen(intro: LessonIntro, onContinue: () -> Unit, modifier: Modifier = Modifier) {
    val container = appContainer()
    val scope = rememberCoroutineScope()
    val controller = remember(intro) { LessonIntroController(intro, container.audio, scope) }
    val usesLetters = usesLetterNames()

    // The clock follows the display's frames, at the real time between them
    LaunchedEffect(controller, controller.isPlaying) {
        if (!controller.isPlaying) return@LaunchedEffect
        var last = -1L
        while (isActive && controller.isPlaying) {
            withFrameNanos { now ->
                if (last >= 0) controller.advance(((now - last) / 1e9).coerceIn(0.0, 0.1))
                last = now
            }
        }
    }
    // Paused when the app goes to the background, silent when the screen leaves
    LifecycleStartEffect(controller) {
        controller.start()
        onStopOrDispose { controller.pause() }
    }

    val snap = LessonIntroScript.snapshot(intro, controller.elapsed, usesLetters)
    val callout = snap.activeCallout?.let { lessonText(it.text) }
    val octaveBadge = stringResource(R.string.intro_octave_badge)

    Column(modifier.fillMaxSize().background(LearnColors.background)) {
        BoxWithConstraints(Modifier.fillMaxWidth().weight(1f)) {
            val keyboardHeight = (maxHeight * 0.26f).coerceIn(135.dp, 215.dp)
            val controlsHeight = 54.dp
            val subtitleHeight = (maxHeight * 0.19f).coerceIn(106.dp, 132.dp)
            // What is left between the fixed rows and their 8 dp gaps (the keyboard ends at the bottom edge)
            val staffHeight = (maxHeight - keyboardHeight - controlsHeight - subtitleHeight - 32.dp).coerceAtLeast(145.dp)

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SubtitleHeader(snap, Modifier.padding(horizontal = 12.dp).padding(top = 8.dp).height(subtitleHeight))
                IntroStaffCard(snap, callout, octaveBadge, Modifier.padding(horizontal = 12.dp).fillMaxWidth().height(staffHeight))
                TransportBar(snap, controller, onContinue, Modifier.padding(horizontal = 12.dp).height(controlsHeight))
                IntroTwoOctaveKeyboard(snap, controller.userTappedKey, usesLetters, controller::tapPreviewKey,
                    Modifier.fillMaxWidth().height(keyboardHeight))
            }

            // Luminous connection beam from the struck white key up to its note on the staff
            snap.beam?.let { beam ->
                IntroBeamOverlay(beam, staffTop = subtitleHeight + 16.dp, staffHeight = staffHeight,
                    keyboardTop = maxHeight - keyboardHeight, modifier = Modifier.fillMaxSize())
            }
        }
        // The keyboard's panel runs on under the navigation bar
        Spacer(Modifier.fillMaxWidth().background(LearnColors.panel).windowInsetsBottomHeight(WindowInsets.navigationBars))
    }
}

// ---- Subtitle Card

@Composable
private fun SubtitleHeader(snap: LessonIntroSnapshot, modifier: Modifier) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier
            .fillMaxWidth()
            .background(LearnColors.panel, shape)
            .border(1.dp, LearnColors.raised, shape)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                Modifier.background(LearnColors.cyan.copy(alpha = 0.16f), CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(Icons.Filled.SmartDisplay, contentDescription = null, tint = LearnColors.cyan, modifier = Modifier.size(13.dp))
                Text(stringResource(R.string.learn_badge_video), color = LearnColors.cyan, fontSize = 11.sp, fontWeight = FontWeight.Black)
            }
            Text(
                stringResource(R.string.intro_phase_of, snap.cue.phaseNumber, snap.totalPhases, lessonText(snap.cue.phaseLabel)),
                color = LearnColors.muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        AnimatedContent(
            targetState = snap.cue,
            transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(250)) },
            label = "introCue",
        ) { cue ->
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(lessonText(cue.title), color = LearnColors.text, fontSize = 19.sp, fontWeight = FontWeight.Bold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(lessonText(cue.subtitle), color = LearnColors.muted, fontSize = 14.sp, fontWeight = FontWeight.Medium,
                    lineHeight = 18.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

// ---- Transport & Action Bar

@Composable
private fun TransportBar(snap: LessonIntroSnapshot, controller: LessonIntroController, onContinue: () -> Unit, modifier: Modifier) {
    val readyToAdvance = controller.isFinished || snap.time >= snap.duration - 4.0
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        TransportButton(
            icon = when {
                controller.isPlaying -> Icons.Filled.Pause
                controller.isFinished -> Icons.Filled.Replay
                else -> Icons.Filled.PlayArrow
            },
            label = stringResource(if (controller.isPlaying) R.string.intro_pause else R.string.intro_play),
            width = 38.dp,
            onClick = controller::togglePlayback,
        )

        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            IntroScrubber(controller.progress, controller::seek, Modifier.fillMaxWidth().height(26.dp))
            Row(Modifier.fillMaxWidth()) {
                val style = TextStyle(color = LearnColors.muted, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace)
                Text(clock(snap.time), style = style)
                Spacer(Modifier.weight(1f))
                Text(clock(snap.duration), style = style)
            }
        }

        if (controller.elapsed > 3 && !controller.isFinished) {
            TransportButton(Icons.Filled.Replay, stringResource(R.string.intro_replay), width = 34.dp, onClick = controller::replay)
        }

        val background by animateColorAsState(if (readyToAdvance) LearnColors.deepBlue else LearnColors.raised, label = "introContinue")
        val shape = RoundedCornerShape(9.dp)
        Row(
            Modifier
                .height(38.dp)
                .then(if (readyToAdvance) Modifier.shadow(8.dp, shape, ambientColor = LearnColors.blue, spotColor = LearnColors.blue) else Modifier)
                .clip(shape)
                .background(background)
                .clickable {
                    controller.stop()
                    onContinue()
                }
                .padding(horizontal = if (readyToAdvance) 16.dp else 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            val color = if (readyToAdvance) Color.White else LearnColors.text
            Text(stringResource(if (readyToAdvance) R.string.intro_start_playing else R.string.intro_skip),
                color = color, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun TransportButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, width: androidx.compose.ui.unit.Dp, onClick: () -> Unit) {
    Box(
        Modifier
            .size(width, 38.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(LearnColors.raised)
            .clickable(onClickLabel = label, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = LearnColors.text, modifier = Modifier.size(20.dp))
    }
}

/** A thin cyan scrubber: tap or drag to move through the video. */
@Composable
private fun IntroScrubber(progress: Double, onSeek: (Double) -> Unit, modifier: Modifier) {
    Canvas(
        modifier
            .pointerInput(Unit) { detectTapGestures { onSeek((it.x / size.width).toDouble()) } }
            .pointerInput(Unit) {
                detectHorizontalDragGestures { change, _ ->
                    change.consume()
                    onSeek((change.position.x / size.width).toDouble())
                }
            },
    ) {
        val track = 4.dp.toPx()
        val radius = 7.dp.toPx()
        val y = size.height / 2
        val x = radius + (size.width - radius * 2) * progress.toFloat()
        drawRoundRect(LearnColors.raised, Offset(radius, y - track / 2), Size(size.width - radius * 2, track), CornerRadius(track / 2))
        drawRoundRect(LearnColors.cyan, Offset(radius, y - track / 2), Size(x - radius, track), CornerRadius(track / 2))
        drawCircle(Color.White, radius, Offset(x, y))
        drawCircle(LearnColors.cyan, radius, Offset(x, y), style = Stroke(1.5.dp.toPx()))
    }
}

private fun clock(seconds: Double): String {
    val whole = max(0, seconds.toInt())
    return "%d:%02d".format(whole / 60, whole % 60)
}

// ---- Shared Staff Metrics

/** Where the staff's lines and columns go in a card of [size] pixels (iOS IntroStaffMetrics, in points × density). */
private class IntroStaffMetrics(val size: Size, density: Float) {
    val unit: Float
    val originY: Float
    val topPosition = 6
    val left = 14f * density
    val right = size.width - 28f * density
    val clefWidth: Float
    val notesStart: Float
    val columnWidth: Float
    val space: Float get() = unit * 2

    init {
        val maxUnitByHeight = (size.height - 44f * density) / 15f
        val maxUnitByWidth = (size.width - 36f * density) / 30f
        unit = min(12f * density, max(5.5f * density, min(maxUnitByHeight, maxUnitByWidth)))
        val usedHeight = 14f * unit // positions +6 down to -8
        originY = 14f * density + max(0f, (size.height - 38f * density - usedHeight) / 2)
        clefWidth = unit * 2 * 2.95f
        notesStart = left + clefWidth + unit * 2 * 0.7f
        columnWidth = max(14f * density, (right - notesStart - unit * 2 * 0.3f) / 8f)
    }

    fun y(position: Int): Float = originY + (topPosition - position) * unit
    fun columnX(column: Int): Float = notesStart + columnWidth * (column + 0.5f)
}

// ---- Animated Staff Card

private val introCyan = Color(14, 165, 233)

@Composable
private fun IntroStaffCard(snapshot: LessonIntroSnapshot, callout: String?, octaveBadge: String, modifier: Modifier) {
    val measurer = rememberTextMeasurer(cacheSize = 64)
    val shape = RoundedCornerShape(14.dp)
    Canvas(modifier.clip(shape).background(Color.White, shape)) {
        if (size.width > 60.dp.toPx() && size.height > 60.dp.toPx()) drawIntroStaff(snapshot, callout, octaveBadge, measurer)
    }
}

private fun DrawScope.drawIntroStaff(snapshot: LessonIntroSnapshot, callout: String?, octaveBadge: String, measurer: TextMeasurer) {
    val m = IntroStaffMetrics(size, density)
    val space = m.space
    val ink = StaffColors.ink
    val activeBlue = StaffColors.current
    val green = StaffColors.right

    // 1. Space bands (between lines, plus the space below line 1 for D4)
    fun band(topPosition: Int, glow: Double) {
        drawRoundRect(
            introCyan.copy(alpha = (0.22 * glow).toFloat()),
            Offset(m.left, m.y(topPosition) + 1.dp.toPx()),
            Size(m.right - m.left, max(2.dp.toPx(), space - 2.dp.toPx())),
            CornerRadius(3.dp.toPx()),
        )
    }
    for (spaceIdx in 0 until 4) {
        val glow = snapshot.spaceGlow[spaceIdx]
        if (glow > 0.01) band(-3 + spaceIdx * 2 + 1, glow)
    }
    if (snapshot.belowLineSpaceGlow > 0.01) band(-4, snapshot.belowLineSpaceGlow)

    // 2. Five staff lines (drawn progressively left to right, numbered 1 to 5 on the right)
    for (lineIdx in 0 until 5) {
        val progress = snapshot.lineProgress[lineIdx]
        if (progress <= 0.005) continue
        val y = m.y(-4 + lineIdx * 2)
        val endX = m.left + (m.right - m.left) * progress.toFloat()
        val glow = snapshot.lineGlow[lineIdx]
        if (glow > 0.01) {
            drawLine(activeBlue.copy(alpha = (0.35 * glow).toFloat()), Offset(m.left, y), Offset(endX, y), 5.dp.toPx())
        }
        val lit = glow > 0.1
        drawLine(if (lit) activeBlue else ink.copy(alpha = 0.84f), Offset(m.left, y), Offset(endX, y), (if (lit) 2.0 else 1.3).dp.toPx())

        // Line number badge on the right margin
        val numberOpacity = min(1.0, progress * 1.4).toFloat()
        val numberColor = if (lit) activeBlue else Color.Gray.copy(alpha = 0.75f * numberOpacity)
        drawLabel(measurer, "${lineIdx + 1}", Offset(m.right + 12.dp.toPx(), y), max(10.dp.toPx(), m.unit * 1.05f), FontWeight.Bold, numberColor)
    }

    // 3. Two-steps-below guide leading down to middle C before and during C4
    if (snapshot.middleCGuideOpacity > 0.01) {
        val alpha = snapshot.middleCGuideOpacity.toFloat()
        val cX = m.columnX(0)
        for ((stepPos, label) in listOf(-5 to "-1", -6 to "-2")) {
            val y = m.y(stepPos)
            drawLine(
                introCyan.copy(alpha = 0.55f * alpha), Offset(cX - space * 1.1f, y), Offset(cX + space * 1.1f, y), 1.2.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx())),
            )
            drawLabel(measurer, label, Offset(cX + space * 1.45f, y), 10.dp.toPx(), FontWeight.Bold, introCyan.copy(alpha = 0.9f * alpha))
        }
    }

    // 4. Treble clef (with a glow around the G-line curl while G4 plays)
    if (snapshot.clefProgress > 0.01) {
        if (snapshot.clefLinePulse > 0.01) {
            val radius = space * (1.1f + 0.25f * snapshot.clefLinePulse.toFloat())
            drawCircle(introCyan.copy(alpha = (0.18 * snapshot.clefLinePulse).toFloat()), radius, Offset(m.left + space * 1.35f, m.y(-2)))
        }
        trebleClef(m.left + space * 0.2f, m.y(-7) + m.unit * 0.3f, space * 7.0f, m.y(-2), space,
            ink.copy(alpha = snapshot.clefProgress.toFloat().coerceIn(0f, 1f)))
    }

    // 5. Step-up arc (+1/2 line) between consecutive notes
    snapshot.stepUpIndicator?.takeIf { it.progress > 0.02 }?.let { stepUp ->
        val x1 = m.columnX(stepUp.fromColumn)
        val x2 = m.columnX(stepUp.toColumn)
        val y1 = m.y(-6 + stepUp.fromColumn)
        val y2 = m.y(-6 + stepUp.toColumn)
        val arc = Path().apply {
            moveTo(x1 + space * 0.45f, y1 - m.unit * 0.8f)
            quadraticTo((x1 + x2) / 2, min(y1, y2) - space * 1.15f, x2 - space * 0.45f, y2 - m.unit * 0.9f)
        }
        drawPath(arc, introCyan.copy(alpha = (0.85 * stepUp.progress).toFloat().coerceIn(0f, 1f)),
            style = Stroke(1.8.dp.toPx(), cap = StrokeCap.Round))
    }

    // 6. Octave arch connecting C4 (column 0) and C5 (column 7)
    if (snapshot.octaveArchProgress > 0.01) {
        val alpha = snapshot.octaveArchProgress.toFloat()
        val startX = m.columnX(0)
        val endX = m.columnX(7)
        val archTopY = m.y(5) - m.unit * 0.6f
        val arch = Path().apply {
            moveTo(startX, m.y(3))
            quadraticTo((startX + endX) / 2, archTopY - space * 0.9f, endX, m.y(3))
        }
        drawPath(arch, green.copy(alpha = 0.75f * alpha), style = Stroke(
            2.dp.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.dp.toPx())),
        ))
        drawLabel(measurer, octaveBadge, Offset((startX + endX) / 2, archTopY - space * 0.35f), 11.dp.toPx(), FontWeight.Black, green.copy(alpha = alpha))
    }

    // 7. Spawned notes (C4 through C5)
    val headWidth = space * 1.26f
    val headHeight = space * 0.92f
    val labelsY = m.y(-7) + m.unit * 1.05f
    for (note in snapshot.notes) {
        val x = m.columnX(note.id)
        val y = m.y(note.staffPosition)
        val scale = springScale(note.appearProgress)
        val color = when {
            note.finaleGlow > 0.15 -> green
            note.activeGlow > 0.15 -> activeBlue
            else -> ink
        }

        // Halo while active or during the finale
        val halo = max(note.activeGlow, note.finaleGlow)
        if (halo > 0.05) {
            val radius = headWidth * (0.85f + 0.25f * halo.toFloat())
            drawCircle((if (note.finaleGlow > 0.15) green else introCyan).copy(alpha = (0.20 * halo).toFloat()), radius, Offset(x, y))
        }

        // Short ledger line for middle C (position -6)
        if (note.staffPosition <= -6) {
            val half = headWidth * 0.85f * scale
            val lit = note.activeGlow > 0.15
            drawLine(if (lit) activeBlue else ink.copy(alpha = 0.88f), Offset(x - half, m.y(-6)), Offset(x + half, m.y(-6)),
                (if (lit) 2.2 else 1.6).dp.toPx())
        }

        // Stem
        val stemTip = if (note.stemUp) max(note.staffPosition + 7, 0) else min(note.staffPosition - 7, 0)
        val stemX = if (note.stemUp) x + headWidth * scale / 2 - 0.8.dp.toPx() else x - headWidth * scale / 2 + 0.8.dp.toPx()
        drawLine(color.copy(alpha = min(1.0, note.appearProgress * 1.4).toFloat()), Offset(stemX, y),
            Offset(stemX, y + (m.y(stemTip) - y) * scale), 1.6.dp.toPx())

        // Notehead, tilted like an engraved one
        rotate(-20f, Offset(x, y)) {
            drawOval(color, Offset(x - headWidth * scale / 2, y - headHeight * scale / 2), Size(headWidth * scale, headHeight * scale))
        }

        // Note name underneath
        drawLabel(measurer, note.name, Offset(x, labelsY), max(11.dp.toPx(), m.unit * 1.25f), FontWeight.Bold, color, anchorTop = true)
    }

    // 8. Position callout floating above the staff for the active note
    val active = snapshot.activeCallout
    if (active != null && !callout.isNullOrEmpty() && active.opacity > 0.05) {
        val targetX = m.columnX(active.staffColumn).coerceIn(m.left + 72.dp.toPx(), max(m.left + 72.dp.toPx(), m.right - 68.dp.toPx()))
        val pillY = max(14.dp.toPx(), m.y(5) - m.unit * 0.5f)
        drawLabel(measurer, callout, Offset(targetX, pillY), 11.dp.toPx(), FontWeight.Bold, activeBlue.copy(alpha = active.opacity.toFloat()))
    }
}

/** Grows past full size and settles, as a note pops onto the staff. */
private fun springScale(p: Double): Float {
    if (p >= 1) return 1f
    if (p < 0.65) {
        val t = p / 0.65
        return (0.25 + 0.90 * (1 - (1 - t).pow(3))).toFloat()
    }
    val t = (p - 0.65) / 0.35
    return (1.15 - 0.15 * t).toFloat()
}

/** Text centered on [at] (or hanging from it with [anchorTop]), [sizePx] tall, in the default rounded-ish sans. */
private fun DrawScope.drawLabel(
    measurer: TextMeasurer,
    text: String,
    at: Offset,
    sizePx: Float,
    weight: FontWeight,
    color: Color,
    anchorTop: Boolean = false,
) {
    if (color.alpha <= 0.01f) return
    val layout = measurer.measure(text, TextStyle(fontSize = sizePx.toSp(), fontWeight = weight), softWrap = false, maxLines = 1)
    val topLeft = Offset(at.x - layout.size.width / 2f, if (anchorTop) at.y else at.y - layout.size.height / 2f)
    drawText(layout, color = color, topLeft = topLeft)
}

// ---- Beam Overlay Connecting Keyboard Key to Staff Note

@Composable
private fun IntroBeamOverlay(
    beam: LessonIntroSnapshot.Beam,
    staffTop: androidx.compose.ui.unit.Dp,
    staffHeight: androidx.compose.ui.unit.Dp,
    keyboardTop: androidx.compose.ui.unit.Dp,
    modifier: Modifier,
) {
    Canvas(modifier) {
        val staffCardWidth = size.width - 24.dp.toPx()
        if (staffCardWidth <= 60.dp.toPx()) return@Canvas
        val m = IntroStaffMetrics(Size(staffCardWidth, staffHeight.toPx()), density)
        val end = Offset(12.dp.toPx() + m.columnX(beam.staffColumn), staffTop.toPx() + m.y(beam.staffPosition))

        val whiteKeyWidth = (size.width - 4.dp.toPx()) / 15f
        val slot = LessonIntroScript.whiteSlot(beam.midi.toDouble()).toFloat()
        val start = Offset(2.dp.toPx() + (slot + 0.5f) * whiteKeyWidth, keyboardTop.toPx() + 18.dp.toPx())

        val p = beam.progress.toFloat()
        val headT = min(1f, p * 1.45f)
        val tailT = max(0f, (p - 0.25f) / 0.75f)
        if (headT <= tailT) return@Canvas
        val control = Offset(start.x + (end.x - start.x) * 0.35f, (start.y + end.y) * 0.5f)
        fun point(t: Float): Offset {
            val u = 1 - t
            return Offset(u * u * start.x + 2 * u * t * control.x + t * t * end.x, u * u * start.y + 2 * u * t * control.y + t * t * end.y)
        }
        val segments = 28
        val path = Path().apply {
            val first = point(tailT)
            moveTo(first.x, first.y)
            for (index in 1..segments) {
                val q = point(tailT + (headT - tailT) * index / segments)
                lineTo(q.x, q.y)
            }
        }
        drawPath(path, LearnColors.cyan.copy(alpha = 0.65f * (1 - p * 0.6f)), style = Stroke(3.5.dp.toPx(), cap = StrokeCap.Round))
        drawCircle(LearnColors.cyan.copy(alpha = (1 - p * 0.7f).coerceIn(0f, 1f)), 5.5.dp.toPx(), point(headT))
    }
}

// ---- Two-Octave Animated Keyboard (C4 to C6, 15 White Keys)

private val introKeys = LessonIntroScript.keyboardRange.toList()
private val introWhiteKeys = introKeys.filter { !PianoKeys.isBlack(it) }
private val introBlackKeys = introKeys.filter { PianoKeys.isBlack(it) }
/** The pairs of 2 black keys, lit while showing how to find C */
private val pairsOfTwo = setOf(61, 63, 73, 75)

@Composable
private fun IntroTwoOctaveKeyboard(
    snapshot: LessonIntroSnapshot,
    userTappedKey: Int?,
    usesLetters: Boolean,
    onTapKey: (Int) -> Unit,
    modifier: Modifier,
) {
    val measurer = rememberTextMeasurer(cacheSize = 64)
    val description = stringResource(R.string.intro_keyboard)
    val density = LocalDensity.current
    Box(modifier.background(LearnColors.panel).padding(horizontal = 2.dp)) {
        Canvas(
            Modifier
                .fillMaxSize()
                .semantics { contentDescription = description }
                .pointerInput(Unit) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        introKeyAt(down.position, Size(size.width.toFloat(), size.height.toFloat()))?.let(onTapKey)
                    }
                },
        ) {
            drawIntroKeyboard(snapshot, userTappedKey, usesLetters, measurer, density.density)
        }
    }
}

/** The key under a touch: a black key where one is, the white key below otherwise. */
private fun introKeyAt(position: Offset, size: Size): Int? {
    val wWidth = size.width / introWhiteKeys.size
    val bWidth = wWidth * 0.60f
    if (position.y <= size.height * 0.61f) {
        for (midi in introBlackKeys) {
            val left = blackKeyLeft(midi, wWidth, bWidth)
            if (position.x >= left && position.x <= left + bWidth) return midi
        }
    }
    return introWhiteKeys.getOrNull((position.x / wWidth).toInt().coerceIn(0, introWhiteKeys.size - 1))
}

private fun blackKeyLeft(midi: Int, whiteWidth: Float, blackWidth: Float): Float {
    val whiteIndex = introWhiteKeys.indexOfLast { it < midi }
    return (whiteIndex + 1) * whiteWidth - blackWidth / 2
}

private fun whiteHighlight(snapshot: LessonIntroSnapshot, userTappedKey: Int?, midi: Int): Color? = when (midi) {
    userTappedKey -> PianoKeyboardState.electricCyan
    snapshot.activeGreenKey -> PianoKeyboardState.neonGreen
    snapshot.activeCyanKey -> PianoKeyboardState.electricCyan
    else -> null
}

private fun DrawScope.drawIntroKeyboard(
    snapshot: LessonIntroSnapshot,
    userTappedKey: Int?,
    usesLetters: Boolean,
    measurer: TextMeasurer,
    density: Float,
) {
    val wWidth = size.width / introWhiteKeys.size
    val wHeight = size.height
    val bWidth = wWidth * 0.60f
    val bHeight = wHeight * 0.61f
    val corner = CornerRadius(3.5f * density)

    // White keys
    introWhiteKeys.forEachIndexed { index, midi ->
        val highlight = whiteHighlight(snapshot, userTappedKey, midi)
        val depressed = (snapshot.activeCyanKey == midi || snapshot.activeGreenKey == midi) && snapshot.cursorPressDepth > 0.1
        val dy = if (depressed) 2.5f * density * snapshot.cursorPressDepth.toFloat() else 0f
        val topLeft = Offset(index * wWidth, dy)
        val keySize = Size(wWidth, wHeight)
        if (highlight != null) {
            // A soft glow around the lit key
            drawRoundRect(highlight.copy(alpha = 0.35f), topLeft - Offset(3f * density, 3f * density),
                Size(wWidth + 6f * density, wHeight + 6f * density), CornerRadius(6f * density))
        }
        drawRoundRect(Color.White, topLeft, keySize, corner)
        val brush = if (highlight != null) {
            Brush.verticalGradient(listOf(highlight, highlight.copy(alpha = 0.84f)), startY = topLeft.y, endY = topLeft.y + wHeight)
        } else {
            Brush.verticalGradient(listOf(Color(0.98f, 0.98f, 0.98f), Color(0.93f, 0.93f, 0.93f), Color(0.88f, 0.88f, 0.88f)),
                startY = topLeft.y, endY = topLeft.y + wHeight)
        }
        drawRoundRect(brush, topLeft, keySize, corner)
        drawRoundRect(Color.Gray.copy(alpha = 0.32f), topLeft, keySize, corner, style = Stroke(0.5f * density))

        // Name, with the octave on each C
        val isC = Math.floorMod(midi, 12) == 0
        val label = NoteNaming.chromaticName(midi, usesLetters) + if (isC) "${midi / 12 - 1}" else ""
        val labelColor = when {
            highlight != null -> Color.Black.copy(alpha = 0.85f)
            isC -> Color.Black.copy(alpha = 0.75f)
            else -> Color.Gray
        }
        val fontPx = min(wWidth * 0.36f, 13f * density)
        var layout = measurer.measure(label, TextStyle(fontSize = fontPx.toSp(), fontWeight = if (isC) FontWeight.Bold else FontWeight.Medium),
            softWrap = false, maxLines = 1)
        if (layout.size.width > wWidth - 2 * density) {
            val shrunk = fontPx * max(0.55f, (wWidth - 2 * density) / layout.size.width)
            layout = measurer.measure(label, TextStyle(fontSize = shrunk.toSp(), fontWeight = if (isC) FontWeight.Bold else FontWeight.Medium),
                softWrap = false, maxLines = 1)
        }
        drawText(layout, color = labelColor,
            topLeft = Offset(topLeft.x + (wWidth - layout.size.width) / 2, dy + wHeight - 8f * density - layout.size.height))
    }

    // Black keys (the pairs of 2 glow while showing how to find C)
    for (midi in introBlackKeys) {
        val pairGlow = if (midi in pairsOfTwo) snapshot.twoBlackKeysGlow.toFloat() else 0f
        val tapped = userTappedKey == midi
        val left = blackKeyLeft(midi, wWidth, bWidth)
        val topLeft = Offset(left, 0f)
        val keySize = Size(bWidth, bHeight)
        val blackCorner = CornerRadius(3f * density)
        val glowing = pairGlow > 0.05f
        // Drop shadow, or a cyan glow on the pairs
        drawRoundRect(
            if (glowing) LearnColors.cyan.copy(alpha = 0.35f * pairGlow) else Color.Black.copy(alpha = 0.25f),
            topLeft + Offset(-2f * density, if (glowing) -2f * density else 2f * density),
            Size(bWidth + 4f * density, bHeight + (if (glowing) 4f else 1f) * density), CornerRadius(5f * density),
        )
        val colors = when {
            tapped -> listOf(PianoKeyboardState.electricCyan, PianoKeyboardState.electricCyan.copy(alpha = 0.8f))
            glowing -> listOf(LearnColors.cyan.copy(alpha = 0.45f + 0.45f * pairGlow), Color(0.14f, 0.14f, 0.14f))
            else -> listOf(Color(0.22f, 0.22f, 0.22f), Color(0.12f, 0.12f, 0.12f), Color(0.05f, 0.05f, 0.05f))
        }
        if (glowing && !tapped) drawRoundRect(Color(0.14f, 0.14f, 0.14f), topLeft, keySize, blackCorner)
        drawRoundRect(Brush.verticalGradient(colors, startY = 0f, endY = bHeight), topLeft, keySize, blackCorner)
        drawRoundRect(
            if (glowing) LearnColors.cyan.copy(alpha = pairGlow) else Color.Black.copy(alpha = 0.5f),
            topLeft, keySize, blackCorner, style = Stroke((if (glowing) 1.5f else 0.5f) * density),
        )
    }

    // Motion-capture touch orb gliding smoothly over the white keys
    if (snapshot.cursorOpacity > 0.01) {
        val opacity = snapshot.cursorOpacity.toFloat()
        val depth = snapshot.cursorPressDepth.toFloat()
        val orbColor = if (snapshot.activeGreenKey != null) PianoKeyboardState.neonGreen else PianoKeyboardState.electricCyan
        snapshot.ripple?.let { ripple ->
            val x = (LessonIntroScript.whiteSlot(ripple.midi.toDouble()).toFloat() + 0.5f) * wWidth
            val diameter = (24f + ripple.progress.toFloat() * 34f) * density
            drawCircle(orbColor.copy(alpha = ((1 - ripple.progress) * 0.85).toFloat() * opacity), diameter / 2,
                Offset(x, wHeight * 0.72f + 2f * density), style = Stroke(2.5f * density))
        }
        val center = Offset(
            (LessonIntroScript.whiteSlot(snapshot.cursorMidiPosition).toFloat() + 0.5f) * wWidth,
            wHeight * 0.72f + depth * 2.5f * density,
        )
        drawCircle(orbColor.copy(alpha = 0.28f * opacity), 17f * density, center)
        // The orb's own light
        drawCircle(orbColor.copy(alpha = 0.35f * opacity), 13f * density, center)
        val radius = 10f * density * (1f - 0.14f * depth)
        drawCircle(
            Brush.radialGradient(listOf(Color.White, orbColor), center = center, radius = radius),
            radius, center, alpha = opacity,
        )
    }
}
