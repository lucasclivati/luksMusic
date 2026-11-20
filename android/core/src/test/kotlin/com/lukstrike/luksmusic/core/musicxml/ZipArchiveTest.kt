// ZipArchiveTest.kt — port of luksMusicTests/ZipArchiveTests.swift: the ZIP reader behind compressed MusicXML
// (.mxl), against two small archives in luksMusicTests/Fixtures: duet.mxl (every file deflated, with
// META-INF/container.xml) and stored.mxl (every file stored, without a container).
package com.lukstrike.luksmusic.core.musicxml

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ZipArchiveTest {

    private fun ByteArray.indexOf(pattern: ByteArray): Int =
        (0..size - pattern.size).firstOrNull { i -> pattern.indices.all { this[i + it] == pattern[it] } } ?: -1

    @Test
    fun deflatedFilesInflate() {
        val archive = ZipArchive(TestFiles.fixture("duet"))
        assertEquals(listOf("META-INF/container.xml", "decoy.xml", "score/duet.musicxml"), archive.entries.map { it.path })
        assertEquals(listOf(8, 8, 8), archive.entries.map { it.method })
        val decoy = archive.entry("decoy.xml")
        assertNotNull(decoy)
        assertEquals("<notes>not the score</notes>\n", String(archive.contents(decoy!!)))
    }

    @Test
    fun storedFilesReadAsIs() {
        val archive = ZipArchive(TestFiles.fixture("stored"))
        assertEquals(listOf("META-INF/manifest.xml", "readme.txt", "piece.musicxml"), archive.entries.map { it.path })
        assertEquals(listOf(0, 0, 0), archive.entries.map { it.method })
        val readme = archive.entry("readme.txt")!!
        assertEquals(24, readme.uncompressedSize)
        assertEquals("Stored, not compressed.\n", String(archive.contents(readme)))
    }

    /** The check value of CRC-32: the digits 1 to 9. */
    @Test
    fun crc32() {
        assertEquals(0xCBF43926L, ZipArchive.crc32("123456789".toByteArray()))
        assertEquals(0L, ZipArchive.crc32(ByteArray(0)))
    }

    /** The score is the file container.xml names, not the first XML file of the archive; without a container it is
     *  the first .musicxml or .xml outside META-INF. */
    @Test
    fun scoreFileOfAnMxl() {
        val named = String(MusicXMLParser.scoreFile(TestFiles.fixture("duet")))
        assertTrue(named.startsWith("<?xml"))
        assertTrue(named.contains("<work-title>Duet</work-title>"))
        val found = String(MusicXMLParser.scoreFile(TestFiles.fixture("stored")))
        assertTrue(found.contains("<work-title>Stored</work-title>"))
    }

    @Test
    fun damagedArchivesThrow() {
        assertThrows(ZipArchiveException::class.java) { ZipArchive(ByteArray(0)) }
        assertThrows(ZipArchiveException::class.java) { ZipArchive("not a zip archive at all".toByteArray()) }
        assertThrows(ZipArchiveException::class.java) { MusicXMLParser.parse("PK\u0003\u0004 but nothing after".toByteArray()) }

        val stored = TestFiles.fixture("stored")
        // Without its last 22 bytes the archive loses the end of central directory record
        assertThrows(ZipArchiveException::class.java) { ZipArchive(stored.copyOf(stored.size - 22)) }

        // A central directory said to start past the end of the data (offset field at 16 in that record)
        val farDirectory = stored.copyOf()
        val directoryEnd = stored.size - 22
        for (i in directoryEnd + 16 until directoryEnd + 20) farDirectory[i] = 0xFF.toByte()
        assertThrows(ZipArchiveException::class.java) { ZipArchive(farDirectory) }

        // One letter of a stored file changed: the central directory still reads, the file fails its CRC-32
        val changedLetter = stored.copyOf()
        val marker = "<work-title>Stored".toByteArray()
        val title = stored.indexOf(marker)
        assertTrue(title >= 0)
        changedLetter[title + marker.size - 1] = 'x'.code.toByte()
        val archive = ZipArchive(changedLetter)
        val piece = archive.entry("piece.musicxml")!!
        assertThrows(ZipArchiveException::class.java) { archive.contents(piece) }
        assertThrows(ZipArchiveException::class.java) { MusicXMLParser.parse(changedLetter) }

        // The first file's method (field at 10 of its central directory header) set to 12, bzip2
        val bzip2 = stored.copyOf()
        val firstHeader = stored.indexOf(byteArrayOf(0x50, 0x4B, 0x01, 0x02))
        bzip2[firstHeader + 10] = 12
        val unsupported = ZipArchive(bzip2)
        assertEquals(12, unsupported.entries[0].method)
        val error = assertThrows(ZipArchiveException::class.java) { unsupported.contents(unsupported.entries[0]) }
        assertEquals(ZipArchiveException.Reason.UNSUPPORTED, error.reason)
    }

    /** Eight bytes in the middle of the deflated score overwritten: it no longer inflates to the recorded size and CRC. */
    @Test
    fun damagedDeflateStreamThrows() {
        val duet = TestFiles.fixture("duet")
        val entry = ZipArchive(duet).entry("score/duet.musicxml")!!
        // Python's zipfile wrote no extra field in the local header, so the data follows the 30 bytes and the name
        val middle = entry.localHeaderOffset + 30 + entry.path.toByteArray().size + entry.compressedSize / 2
        for (i in middle until middle + 8) duet[i] = 0xFF.toByte()
        val archive = ZipArchive(duet)
        assertThrows(ZipArchiveException::class.java) { archive.contents(entry) }
        assertThrows(ZipArchiveException::class.java) { MusicXMLParser.parse(duet) }
    }
}
