// LessonPlayerScreen.kt — port of luksMusic/Views/Learn/LessonPlayerView.swift.
//
// One lesson on screen: what the step is (a badge), what to do, the staff, whether the note played was right, and
// the keyboard. A finished step shows a result card with what comes next; the end of the lesson shows the stars
// (with confetti when one was earned). Notes can be played on the screen, on a USB/Bluetooth keyboard, or on a
// real piano with the microphone on.
package com.lukstrike.luksmusic.feature.learn

import android.Manifest
import android.app.Application
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.QueueMusic
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.FastForward
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Hearing
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.SmartDisplay
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.filled.Usb
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.lessons.LessonStep
import com.lukstrike.luksmusic.core.lessons.LessonSession.Feedback
import com.lukstrike.luksmusic.core.lessons.LessonSession.TimedPhase
import com.lukstrike.luksmusic.core.model.Clef

@Composable
fun LessonPlayerScreen(lessonId: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val container = appContainer()
    val viewModel: LessonPlayerViewModel = viewModel {
        LessonPlayerViewModel(lessonId, context.applicationContext as Application, container)
    }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val keyboardName by viewModel.connectedKeyboardName.collectAsStateWithLifecycle()

    // The microphone is taken while the screen is on and let go when it leaves
    LifecycleStartEffect(viewModel) {
        viewModel.activate()
        onStopOrDispose { viewModel.stop() }
    }

    val haptics = LocalHapticFeedback.current
    LaunchedEffect(viewModel) {
        viewModel.haptics.collect { haptic ->
            haptics.performHapticFeedback(
                when (haptic) {
                    LearnHaptic.CORRECT -> HapticFeedbackType.SegmentTick
                    LearnHaptic.WRONG -> HapticFeedbackType.Reject
                    LearnHaptic.STEP_DONE -> HapticFeedbackType.Confirm
                }
            )
        }
    }

    // RECORD_AUDIO is asked for only when the microphone is turned on
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.setMicrophone(true) else viewModel.microphoneDenied()
    }
    val toggleMicrophone = {
        when {
            state.usesMicrophone -> viewModel.setMicrophone(false)
            container.microphone.hasPermission() -> viewModel.setMicrophone(true)
            else -> permission.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(LearnColors.background)) {
        val keyboardHeight = (maxHeight * 0.26f).coerceIn(130.dp, 220.dp)
        Column(Modifier.fillMaxSize()) {
            LearnTopBar(
                title = lessonText(state.lessonTitle),
                subtitle = if (state.isFinished) stringResource(R.string.learn_lesson_finished)
                else stringResource(R.string.learn_step_of, state.stepIndex + 1, state.stepCount),
                onBack = {
                    viewModel.stop()
                    onBack()
                },
            ) {
                // The introduction asks for no notes, so it has no microphone
                if (!state.step.isIntro || state.isFinished) {
                    ChromeIconButton(
                        icon = if (state.usesMicrophone) Icons.Filled.Mic else Icons.Filled.MicOff,
                        label = stringResource(if (state.usesMicrophone) R.string.learn_microphone_off else R.string.learn_microphone_on),
                        tint = if (state.usesMicrophone) LearnColors.green else LearnColors.text,
                        onClick = toggleMicrophone,
                    )
                }
            }

            val progress by animateFloatAsState(state.progress, label = "lessonProgress")
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth(),
                color = LearnColors.cyan,
                trackColor = LearnColors.raised,
                drawStopIndicator = {},
            )

            AnimatedContent(
                targetState = state.isFinished,
                transitionSpec = { (fadeIn() + scaleIn(initialScale = 0.96f)) togetherWith fadeOut() },
                modifier = Modifier.weight(1f),
                label = "lessonFinished",
            ) { finished ->
                val intro = state.step.intro
                if (finished) {
                    FinishedView(state, viewModel)
                } else if (state.step.isIntro && intro != null) {
                    // A new visit to the introduction starts it from the beginning
                    key(state.stepIndex, state.lessonTitle) {
                        LessonIntroScreen(intro, onContinue = viewModel::continueLesson)
                    }
                } else {
                    Column(Modifier.fillMaxSize()) {
                        LessonContent(state, viewModel, keyboardName, Modifier.weight(1f))
                        LearnKeyboard(
                            state = viewModel.keyboard,
                            modifier = Modifier.fillMaxWidth().height(keyboardHeight),
                            onWhiteKeyCount = viewModel::setWhiteKeyCount,
                            whiteKeysFor = ::lessonWhiteKeyCount,
                            onKeyPress = viewModel::screenKeyPressed,
                            onKeyRelease = viewModel::screenKeyReleased,
                        )
                    }
                }
            }
        }
    }
}

// ---- Step

@Composable
private fun LessonContent(state: LessonUiState, viewModel: LessonPlayerViewModel, keyboardName: String?, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        // A new step slides in from the right
        AnimatedContent(
            targetState = state.stepIndex to state.step,
            transitionSpec = {
                (slideInHorizontally { it / 4 } + fadeIn()) togetherWith (slideOutHorizontally { -it / 4 } + fadeOut())
            },
            label = "lessonStep",
        ) { (_, step) ->
            StepHeader(step, state.pageNumber, state.pageCount)
        }

        if (state.hasNotes) {
            Box(
                Modifier
                    .padding(horizontal = 12.dp)
                    .fillMaxWidth()
                    .weight(1f)
                    .heightIn(min = 110.dp)
                    .background(Color.White, RoundedCornerShape(12.dp))
                    .padding(horizontal = 4.dp, vertical = 6.dp),
            ) {
                // A new segment or page starts with its highlight in place instead of gliding back
                key(state.stepIndex, state.pageNumber, state.visibleSteps.firstOrNull()?.notes?.firstOrNull()?.id) {
                    LessonStaff(state, Modifier.fillMaxSize())
                }
            }
        } else {
            Spacer(Modifier.weight(1f))
        }

        InputStatus(state, keyboardName, viewModel)
        AnimatedContent(
            targetState = state.isStepDone,
            transitionSpec = { (fadeIn() + expandVertically()) togetherWith (fadeOut() + shrinkVertically()) },
            label = "lessonResult",
        ) { done ->
            if (done) ResultCard(state, viewModel) else Column {
                FeedbackLine(state)
                Actions(state, viewModel)
            }
        }
    }
}

@Composable
private fun StepHeader(step: LessonStep, pageNumber: Int, pageCount: Int) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp).padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            val badge = stepBadge(step)
            Row(
                Modifier.background(badge.color.copy(alpha = 0.16f), CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(badge.icon, contentDescription = null, tint = badge.color, modifier = Modifier.size(13.dp))
                Text(stringResource(badge.text), color = badge.color, fontSize = 11.sp, fontWeight = FontWeight.Black)
            }
            if (pageCount > 1) {
                Text(stringResource(R.string.learn_part_of, pageNumber, pageCount), color = LearnColors.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Text(lessonText(step.title), color = LearnColors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(lessonText(step.text), color = LearnColors.muted, fontSize = 15.sp)
    }
}

private class Badge(val text: Int, val icon: ImageVector, val color: Color)

/** What kind of step this is, so learning, practice and music look different at a glance. */
private fun stepBadge(step: LessonStep): Badge = when (step.kind) {
    LessonStep.Kind.INTRO -> Badge(R.string.learn_badge_video, Icons.Filled.SmartDisplay, LearnColors.cyan)
    LessonStep.Kind.LEARN -> Badge(R.string.learn_badge_learn, Icons.Filled.Lightbulb, LearnColors.cyan)
    LessonStep.Kind.READ -> when {
        step.isChallenge -> Badge(R.string.learn_badge_challenge, Icons.Filled.EmojiEvents, LearnColors.amber)
        step.isDrill -> Badge(R.string.learn_badge_drill, Icons.Filled.TrackChanges, LearnColors.green)
        step.isPiece -> Badge(R.string.learn_badge_music, Icons.Filled.MusicNote, LearnColors.amber)
        else -> Badge(R.string.learn_badge_reading, Icons.Filled.Visibility, LearnColors.green)
    }
    LessonStep.Kind.LISTEN -> Badge(R.string.learn_badge_ear, Icons.Filled.Hearing, LearnColors.violet)
    LessonStep.Kind.RHYTHM -> Badge(R.string.learn_badge_rhythm, Icons.Filled.Timer, LearnColors.amber)
    LessonStep.Kind.PLAY_ALONG -> Badge(R.string.learn_badge_play_along, Icons.AutoMirrored.Filled.QueueMusic, LearnColors.amber)
}

@Composable
private fun LessonStaff(state: LessonUiState, modifier: Modifier) {
    val step = state.step
    val namesEverything = step.kind == LessonStep.Kind.LEARN
    if (step.isGrand) {
        GrandStaff(
            steps = state.visibleSteps,
            accidentals = state.visibleAccidentals,
            results = state.visibleResults,
            current = state.visibleCurrent,
            keySignature = step.keySignature,
            modifier = modifier,
            wrongPitch = state.wrongPitch,
            listeningStep = state.visibleDemoNote,
            showsAllNames = namesEverything,
            timeSignature = step.meter,
        )
    } else {
        ReadingStaff(
            steps = state.visibleSteps,
            accidentals = state.visibleAccidentals,
            results = state.visibleResults,
            current = state.visibleCurrent,
            clef = Clef.of(step.staff),
            keySignature = step.keySignature,
            modifier = modifier,
            wrongPitch = state.wrongPitch,
            listeningStep = state.visibleDemoNote,
            showsAllNames = namesEverything,
            timeSignature = step.meter,
        )
    }
}

/** Where the notes are coming from. */
@Composable
private fun InputStatus(state: LessonUiState, keyboardName: String?, viewModel: LessonPlayerViewModel) {
    when {
        state.microphoneFailed -> StatusText(stringResource(R.string.learn_microphone_failed), Icons.Filled.Warning, LearnColors.orange)
        state.isSilentForMicrophone -> StatusText(stringResource(R.string.learn_silent_for_microphone), Icons.Filled.Headphones, LearnColors.orange)
        keyboardName != null -> StatusText(stringResource(R.string.learn_keyboard_connected, keyboardName), Icons.Filled.Usb, LearnColors.green)
        state.usesMicrophone -> MicrophoneMeter(state, viewModel)
    }
}

/** Shows that the microphone hears the room, and the last note it recognized. */
@Composable
private fun MicrophoneMeter(state: LessonUiState, viewModel: LessonPlayerViewModel) {
    val level by viewModel.microphoneLevel.collectAsStateWithLifecycle()
    val shown by animateFloatAsState(level.coerceIn(0.03f, 1f), label = "micLevel")
    Row(
        Modifier.padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Filled.Mic, contentDescription = null, tint = LearnColors.green, modifier = Modifier.size(14.dp))
        Text(stringResource(R.string.learn_listening), color = LearnColors.green, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        Box(Modifier.width(70.dp).height(6.dp).background(LearnColors.raised, CircleShape)) {
            Box(Modifier.fillMaxWidth(shown).height(6.dp).background(LearnColors.green, CircleShape))
        }
        state.heardNoteName?.let {
            Text(stringResource(R.string.learn_last_note, it), color = LearnColors.text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun StatusText(text: String, icon: ImageVector, color: Color) {
    Row(Modifier.padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(14.dp))
        Text(text, color = color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

private class FeedbackContent(val icon: ImageVector, val text: String, val color: Color)

@Composable
private fun feedbackContent(state: LessonUiState): FeedbackContent? = when (val feedback = state.feedback) {
    Feedback.None, is Feedback.StepDone -> null // the result card shows a finished step
    Feedback.Prompt -> FeedbackContent(
        Icons.Filled.TouchApp,
        stringResource(
            if (state.step.kind == LessonStep.Kind.LEARN) {
                if (state.isChord) R.string.learn_prompt_lit_keys else R.string.learn_prompt_lit_key
            } else {
                if (state.isChord) R.string.learn_prompt_blue_notes else R.string.learn_prompt_blue_note
            }
        ),
        LearnColors.text,
    )
    is Feedback.Correct -> FeedbackContent(Icons.Filled.CheckCircle, stringResource(R.string.learn_correct, feedback.name), LearnColors.green)
    is Feedback.Wrong -> FeedbackContent(Icons.Filled.Cancel, stringResource(R.string.learn_wrong, feedback.name), LearnColors.red)
    is Feedback.Revealed -> FeedbackContent(Icons.Filled.Lightbulb, stringResource(R.string.learn_revealed_lit, feedback.name), LearnColors.amber)
    Feedback.Listening -> FeedbackContent(Icons.Filled.Hearing, stringResource(R.string.learn_listen_now), LearnColors.cyan)
    Feedback.YourTurn -> FeedbackContent(Icons.Filled.TouchApp, stringResource(R.string.learn_your_turn), LearnColors.text)
    Feedback.ReadyToStart -> FeedbackContent(Icons.Filled.Timer, stringResource(R.string.learn_ready_to_start), LearnColors.text)
    is Feedback.CountIn -> FeedbackContent(Icons.Filled.Timer, stringResource(R.string.learn_count_in, feedback.beats), LearnColors.cyan)
    Feedback.Playing -> FeedbackContent(Icons.Filled.MusicNote, stringResource(R.string.learn_play_in_time), LearnColors.cyan)
    Feedback.OnTime -> FeedbackContent(Icons.Filled.CheckCircle, stringResource(R.string.learn_on_time), LearnColors.green)
    Feedback.Early -> FeedbackContent(Icons.Filled.FastForward, stringResource(R.string.learn_early), LearnColors.amber)
    Feedback.Late -> FeedbackContent(Icons.Filled.HourglassBottom, stringResource(R.string.learn_late), LearnColors.amber)
    Feedback.Missed -> FeedbackContent(Icons.Filled.Cancel, stringResource(R.string.learn_missed), LearnColors.red)
    Feedback.ChordMissed -> FeedbackContent(Icons.Filled.GraphicEq, stringResource(R.string.learn_chord_missed), LearnColors.amber)
}

@Composable
private fun FeedbackLine(state: LessonUiState) {
    val content = feedbackContent(state) ?: return
    val color by animateColorAsState(content.color, label = "feedbackColor")
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 14.dp).heightIn(min = 28.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(content.icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Text(content.text, color = color, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 2,
            overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        BeatDots(state)
    }
}

/** The metronome on screen: one dot per beat of the measure. */
@Composable
private fun BeatDots(state: LessonUiState) {
    val beat = state.beatInMeasure ?: return
    Row(Modifier.height(16.dp).clearAndSetSemantics {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        for (index in 0 until (state.step.meter ?: 4)) {
            val on = index == beat
            val dot by animateDpAsState(if (on) 14.dp else 10.dp, label = "beatDot")
            Box(Modifier.size(dot).background(if (on) LearnColors.cyan else LearnColors.raised, CircleShape))
        }
    }
}

@Composable
private fun Actions(state: LessonUiState, viewModel: LessonPlayerViewModel) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 42.dp).padding(horizontal = 12.dp).padding(bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (state.showsListen) {
            LearnSecondaryButton(stringResource(R.string.learn_listen), Icons.AutoMirrored.Filled.VolumeUp, enabled = !state.isDemonstrating) {
                viewModel.playDemo()
            }
        }
        Spacer(Modifier.weight(1f))
        if (state.timedPhase == TimedPhase.READY) {
            LearnPrimaryButton(stringResource(R.string.learn_start), enabled = !state.isDemonstrating) { viewModel.startTimedStep() }
        }
    }
}

/** The step's result, what comes next, and the buttons to go on or try again. */
@Composable
private fun ResultCard(state: LessonUiState, viewModel: LessonPlayerViewModel) {
    val done = state.feedback as? Feedback.StepDone ?: return
    // Learning a note is never wrong
    val perfect = !state.step.isScored || done.clean == done.total
    val headline = when {
        !state.step.isScored -> stringResource(R.string.learn_well_done)
        perfect -> stringResource(R.string.learn_all_correct)
        else -> stringResource(R.string.learn_clean_of, done.clean, done.total)
    }
    val color = if (perfect) LearnColors.green else LearnColors.amber
    Column(
        Modifier
            .padding(horizontal = 12.dp)
            .padding(bottom = 8.dp)
            .fillMaxWidth()
            .background(LearnColors.raised.copy(alpha = 0.7f), RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(if (perfect) Icons.Filled.Star else Icons.Filled.SportsScore, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
            Text(headline, color = color, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
        Text(
            state.nextStepTitle?.let { stringResource(R.string.learn_next, lessonText(it)) } ?: stringResource(R.string.learn_next_end),
            color = LearnColors.muted, fontSize = 13.sp,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (state.showsRepeat) {
                LearnSecondaryButton(stringResource(R.string.learn_repeat), Icons.Filled.Replay) { viewModel.repeatStep() }
            }
            Spacer(Modifier.weight(1f))
            LearnPrimaryButton(stringResource(R.string.learn_continue)) { viewModel.continueLesson() }
        }
    }
}

// ---- End of the Lesson

@Composable
private fun FinishedView(state: LessonUiState, viewModel: LessonPlayerViewModel) {
    val starsLabel = pluralStringResource(R.plurals.learn_stars_of_three, state.stars, state.stars)
    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = 32.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            StarRow(state.stars, 44.dp, Modifier.clearAndSetSemantics { contentDescription = starsLabel })
            Text(stringResource(R.string.learn_lesson_finished), color = LearnColors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.learn_notes_clean_of, state.cleanNotes, state.totalNotes),
                color = LearnColors.muted, fontSize = 15.sp, textAlign = TextAlign.Center,
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                state.nextLesson?.let { next ->
                    LearnPrimaryButton(
                        stringResource(R.string.learn_next_lesson, lessonText(next.title)),
                        Modifier.fillMaxWidth().height(46.dp),
                    ) { viewModel.open(next) }
                }
                TextButton(onClick = viewModel::restartLesson) {
                    Text(stringResource(R.string.learn_restart_lesson), color = LearnColors.cyan, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        // Every finished lesson earns at least one star: celebrate it
        AnimatedVisibility(visible = state.stars > 0, enter = fadeIn()) {
            ConfettiBurst(Modifier.fillMaxSize())
        }
    }
}
