package com.lukstrike.luksmusic.desktop

import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.musicxml.MusicXMLParser
import com.lukstrike.luksmusic.core.practice.PracticeEngine
import com.lukstrike.luksmusic.desktop.data.DesktopSettings
import com.lukstrike.luksmusic.desktop.data.ResourceSamples
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import com.lukstrike.luksmusic.desktop.study.StripMusic
import com.lukstrike.luksmusic.desktop.study.StudyController
import com.lukstrike.luksmusic.desktop.study.StudyView
import kotlinx.coroutines.test.TestScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

class StudyControllerTest {

    private val score = MusicXMLParser.parse(ResourceSamples.read("minuet-in-g.musicxml")!!).score

    private fun store(settings: DesktopSettings = DesktopSettings()) =
        SettingsStore(File(Files.createTempDirectory("study").toFile(), "settings.json")).apply { update { settings } }

    @Test
    fun guidedPracticeWaitsForTheNotesAndCountsThem() {
        val player = RecordingPlayer()
        val study = StudyController(score, player, null, store(), TestScope())
        // Keys pressed before Start sound but do not count
        study.keyPressed(60)
        assertEquals(0, study.state.value.played)

        study.togglePlay()
        assertTrue(study.state.value.isPlaying)
        val first = study.state.value.targets
        assertTrue(first.isNotEmpty())
        val startBeat = study.playhead
        for (key in first) study.keyPressed(key)
        val after = study.state.value
        assertEquals(first.size, after.correct)
        assertEquals(100.0, after.accuracy, 0.001)
        assertTrue(after.targets != first || study.playhead >= startBeat)

        study.keyPressed(first.min() - 1)
        assertEquals(first.size + 1, study.state.value.played)
        assertEquals(0, study.state.value.streak)
    }

    @Test
    fun theFrameClockHoldsAtTheExpectedNotesInGuidedMode() {
        val study = StudyController(score, RecordingPlayer(), null, store(), TestScope())
        study.start()
        val hold = study.engine.absoluteBeat
        repeat(200) { study.frame(1 / 60.0) }
        assertEquals(hold, study.playhead, 1e-9)
        // Paused, the clock stops
        study.pause()
        val paused = study.playhead
        study.frame(1.0)
        assertEquals(paused, study.playhead, 1e-9)
    }

    @Test
    fun stopShowsTheResultsAndGoesBackToTheStart() {
        val study = StudyController(score, RecordingPlayer(), null, store(), TestScope())
        study.start()
        for (key in study.state.value.targets) study.keyPressed(key)
        study.seekMeasure(3)
        assertEquals(3, study.state.value.measureIndex)
        study.stop()
        val state = study.state.value
        assertFalse(state.isRunning)
        assertNotNull(state.lastSummary)
        assertEquals(0, state.measureIndex)
    }

    @Test
    fun tempoModeViewAndMetronome() {
        val settings = store(DesktopSettings(metronome = false))
        val clock = FakeBeatClock()
        val study = StudyController(score, RecordingPlayer(), clock, settings, TestScope())
        study.setTempo(1000)
        assertEquals(PracticeEngine.MAX_TEMPO, study.state.value.tempoBpm)
        study.changeTempo(-2)
        assertEquals(PracticeEngine.MAX_TEMPO - 2 * PracticeEngine.TEMPO_STEP, study.state.value.tempoBpm)

        study.setMode(PracticeMode.HANDS_SEPARATE_LEFT)
        assertEquals("HANDS_SEPARATE_LEFT", settings.value.studyMode)

        study.toggleView()
        assertEquals(StudyView.STAFF, study.state.value.view)
        assertEquals("staff", settings.value.studyView)

        study.toggleMetronome()
        assertFalse(clock.isRunning) // only while playing
        study.start()
        assertTrue(clock.isRunning)
        assertEquals(study.state.value.tempoBpm, clock.bpm)
        study.pause()
        assertFalse(clock.isRunning)
        assertTrue(settings.value.metronome)
    }

    @Test
    fun theStaffStripLinesUpWithTheFallingNotes() {
        val music = StripMusic(score)
        val study = StudyController(score, RecordingPlayer(), null, store(), TestScope())
        // Every chord on the strip starts where a falling bar starts
        val barStarts = study.engine.fallingNotes.map { it.startBeat }.toSet()
        assertTrue(music.chords.all { chord -> barStarts.any { kotlin.math.abs(it - chord.beat) < 1e-6 } })
        assertEquals(score.measures.size + 1, music.barlines.size)
        assertEquals(1.0, music.barlines.first(), 0.0)
        assertTrue(music.chords.all { it.positions == it.positions.sorted() })
        assertEquals(100f, StripMusic.x(2.0, 1.0, 40f, 60f))
        assertTrue(music.visible(1.0, 2.0).all { it.beat in 1.0..2.0 })
    }
}
