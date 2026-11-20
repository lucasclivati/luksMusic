package com.lukstrike.luksmusic.core.musicxml

import java.io.File

/** Files shared with the iOS tests, read from the repository (Gradle runs the tests from android/core). */
internal object TestFiles {
    private val repo = File("../..")

    /** An .mxl in luksMusicTests/Fixtures (see ZipArchiveTest). */
    fun fixture(name: String): ByteArray = File(repo, "luksMusicTests/Fixtures/$name.mxl").readBytes()

    /** A bundled sample in luksMusic/SampleScores. */
    fun sample(name: String): ByteArray = File(repo, "luksMusic/SampleScores/$name.musicxml").readBytes()
}
