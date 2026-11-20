package com.lukstrike.luksmusic.desktop

import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.core.lessons.ReadingOrder
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.desktop.data.DesktopSettings
import com.lukstrike.luksmusic.desktop.data.ResourceSamples
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import com.lukstrike.luksmusic.desktop.drill.DrillController
import com.lukstrike.luksmusic.desktop.drill.DrillFeedback
import com.lukstrike.luksmusic.desktop.drill.DrillNavigation
import com.lukstrike.luksmusic.core.musicxml.MusicXMLParser
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

@OptIn(ExperimentalCoroutinesApi::class)
class DrillControllerTest {

    private val score: Score = MusicXMLParser.parse(ResourceSamples.read("minuet-in-g.musicxml")!!).score

    private fun store(settings: DesktopSettings = DesktopSettings()): SettingsStore {
        val file = File(Files.createTempDirectory("drill").toFile(), "settings.json")
        return SettingsStore(file).apply { update { settings } }
    }

    private fun steps(hand: ReadingHand, notes: ReadingNotes) =
        ReadingDrill.steps(score.measures, hand, score.timeSignatureTop, score.timeSignatureBottom, notes)

    @Test
    fun navigationAlignsAndWraps() {
        assertEquals(8, DrillNavigation.aligned(10, 4))
        assertEquals(0, DrillNavigation.aligned(-3, 4))
        assertEquals(4, DrillNavigation.next(0, 4, 10))
        assertEquals(0, DrillNavigation.next(8, 4, 10))
        assertEquals(0, DrillNavigation.previous(2, 4))
        assertEquals(4, DrillNavigation.previous(8, 4))
    }

    @Test
    fun rightKeysFinishThePassageAndMoveOn() {
        val scope = TestScope()
        val player = RecordingPlayer()
        val drill = DrillController(score, player, store(DesktopSettings(drillSegmentSize = 3)), scope, usesLetters = true)
        val expected = steps(ReadingHand.RIGHT, ReadingNotes.ONE)
        assertEquals(expected.take(3), drill.state.value.segmentSteps)

        for (step in expected.take(3)) for (key in step.midiNotes) drill.keyPressed(key)
        val done = drill.state.value
        assertTrue(done.isSegmentComplete)
        assertEquals(DrillFeedback.SegmentDone(3, 3), done.feedback)
        assertEquals(3, done.answeredClean)
        assertEquals(3, done.streak)
        // The keys played were heard
        assertEquals(expected.take(3).flatMap { it.midiNotes }, player.played)

        // A clean passage moves on by itself
        scope.advanceUntilIdle()
        assertEquals(expected.drop(3).take(3), drill.state.value.segmentSteps)
        assertEquals(2, drill.state.value.segmentNumber)
    }

    @Test
    fun wrongKeysAreNamedAndTheAnswerShowsAfterThree() {
        val drill = DrillController(score, RecordingPlayer(), store(), TestScope(), usesLetters = false)
        val target = steps(ReadingHand.RIGHT, ReadingNotes.ONE).first().midiNotes.first()
        drill.keyPressed(target + 1)
        val wrong = drill.state.value
        assertTrue(wrong.feedback is DrillFeedback.Wrong)
        assertNotNull(wrong.wrongPitch)
        drill.keyPressed(target + 1)
        drill.keyPressed(target + 2)
        val revealed = drill.state.value
        assertTrue(revealed.feedback is DrillFeedback.Revealed)
        assertEquals(setOf(target), revealed.targetKeys)
        // Solfège in Portuguese
        assertTrue((revealed.feedback as DrillFeedback.Revealed).name.first() in "DRMFSL")
    }

    @Test
    fun midiSoundCanBeOff() {
        val player = RecordingPlayer()
        val drill = DrillController(score, player, store(), TestScope(), usesLetters = true)
        drill.keyPressed(60, sounds = false)
        assertTrue(player.played.isEmpty())
    }

    @Test
    fun handNotesAndPositionAreRemembered() {
        val settings = store(DesktopSettings(drillSegmentSize = 4))
        val drill = DrillController(score, RecordingPlayer(), settings, TestScope(), usesLetters = true)
        drill.setHand(ReadingHand.BOTH)
        drill.setNotes(ReadingNotes.ALL)
        drill.nextSegment()
        drill.nextSegment()
        assertEquals("both", settings.value.drillHand)
        assertEquals("all", settings.value.drillNotes)
        assertEquals(8, settings.value.drillPositions["${score.id}/both/all"])

        // A new drill on the same score continues there
        val again = DrillController(score, RecordingPlayer(), settings, TestScope(), usesLetters = true)
        assertEquals(ReadingHand.BOTH, again.state.value.hand)
        assertEquals(3, again.state.value.segmentNumber)
        assertEquals(steps(ReadingHand.BOTH, ReadingNotes.ALL).drop(8).take(4), again.state.value.segmentSteps)
        assertTrue(again.state.value.canGoBack)
    }

    @Test
    fun randomOrderCannotGoBack() {
        val drill = DrillController(score, RecordingPlayer(), store(), TestScope(), usesLetters = true, random = kotlin.random.Random(7))
        drill.setOrder(ReadingOrder.RANDOM)
        assertFalse(drill.state.value.canGoBack)
        drill.cycleNotes()
        assertEquals(ReadingNotes.TWO, drill.state.value.notes)
        drill.toggleOrder()
        assertEquals(ReadingOrder.SEQUENTIAL, drill.state.value.order)
    }

    @Test
    fun theKeyStripHoldsThePassage() {
        val drill = DrillController(score, RecordingPlayer(), store(), TestScope(), usesLetters = true)
        val state = drill.state.value
        val keys = state.segmentSteps.flatMap { it.midiNotes }
        assertTrue(keys.all { it in state.keyRange })
    }
}
