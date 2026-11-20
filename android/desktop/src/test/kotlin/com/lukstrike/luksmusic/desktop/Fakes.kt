package com.lukstrike.luksmusic.desktop

import com.lukstrike.luksmusic.desktop.audio.NotePlayer
import com.lukstrike.luksmusic.desktop.study.BeatClock

class RecordingPlayer : NotePlayer {
    val played = mutableListOf<Int>()
    val stopped = mutableListOf<Int>()
    var allOff = 0
    var pedal = false

    override fun playNote(midi: Int, velocity: Int, durationSeconds: Double?) { played += midi }
    override fun stopNote(midi: Int) { stopped += midi }
    override fun stopAllNotes() { allOff += 1 }
    override fun setSustain(down: Boolean) { pedal = down }
}

class FakeBeatClock : BeatClock {
    override var isRunning = false
    var bpm = 0
    var beats = 0

    override fun start(bpm: Int, beatsPerMeasure: Int) {
        isRunning = true
        this.bpm = bpm
        beats = beatsPerMeasure
    }

    override fun stop() { isRunning = false }
    override fun setTempo(bpm: Int) { this.bpm = bpm }
}
