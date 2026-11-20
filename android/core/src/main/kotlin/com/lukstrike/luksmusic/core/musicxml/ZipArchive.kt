// ZipArchive.kt — port of luksMusic/Models/MusicXML/ZipArchive.swift: reads the files of a ZIP archive held in
// memory, the container of compressed MusicXML (.mxl). The central directory is read by hand (as on iOS, so a
// damaged archive fails the same way); inflating and the CRC-32 use java.util.zip.
package com.lukstrike.luksmusic.core.musicxml

import java.util.zip.CRC32
import java.util.zip.DataFormatException
import java.util.zip.Inflater

/** Why a ZIP archive could not be read. */
class ZipArchiveException(val reason: Reason) : Exception(reason.name) {
    enum class Reason {
        /** "O arquivo compactado está danificado." */
        CORRUPTED,
        /** "O arquivo compactado usa criptografia ou uma compressão que o app não lê." */
        UNSUPPORTED,
    }
}

/**
 * A ZIP archive: the central directory at its end lists the files, each stored as is or compressed with DEFLATE
 * (the two methods MusicXML allows). Every offset is checked against the data, so a damaged archive throws
 * instead of crashing, and every file is checked against the CRC-32 the archive recorded for it.
 */
class ZipArchive(private val bytes: ByteArray) {

    /** A file in the archive, as the central directory describes it. */
    data class Entry(
        val path: String,
        /** 0 stored, 8 deflated */
        val method: Int,
        val flags: Int,
        val crc32: Long,
        val compressedSize: Int,
        val uncompressedSize: Int,
        val localHeaderOffset: Int,
    )

    /** The files, in the order of the central directory. */
    val entries: List<Entry>

    init {
        val directoryEnd = endOfCentralDirectory(bytes)
        val count = uint16(bytes, directoryEnd + 10)
        var offset = uint32(bytes, directoryEnd + 16)

        val list = ArrayList<Entry>(count)
        repeat(count) {
            if (uint32(bytes, offset) != 0x0201_4B50) corrupted()
            val flags = uint16(bytes, offset + 8)
            val method = uint16(bytes, offset + 10)
            val crc32 = uint32Long(bytes, offset + 16)
            val compressedSize = uint32(bytes, offset + 20)
            val uncompressedSize = uint32(bytes, offset + 24)
            val nameLength = uint16(bytes, offset + 28)
            val extraLength = uint16(bytes, offset + 30)
            val commentLength = uint16(bytes, offset + 32)
            val localHeaderOffset = uint32(bytes, offset + 42)
            val nameStart = offset + 46
            if (nameStart + nameLength > bytes.size) corrupted()

            list += Entry(
                path = String(bytes, nameStart, nameLength, Charsets.UTF_8),
                method = method,
                flags = flags,
                crc32 = crc32,
                compressedSize = compressedSize,
                uncompressedSize = uncompressedSize,
                localHeaderOffset = localHeaderOffset,
            )
            offset = nameStart + nameLength + extraLength + commentLength
        }
        entries = list
    }

    /** The file at [path], spelled as the archive stores it. */
    fun entry(path: String): Entry? = entries.firstOrNull { it.path == path }

    /** The file's bytes, inflated when deflated. */
    fun contents(entry: Entry): ByteArray {
        // Bit 0 marks an encrypted file
        if (entry.flags and 1 != 0) throw ZipArchiveException(ZipArchiveException.Reason.UNSUPPORTED)
        val header = entry.localHeaderOffset
        if (uint32(bytes, header) != 0x0403_4B50) corrupted()
        // The local header's name and extra field need not be as long as the central directory's
        val start = header + 30 + uint16(bytes, header + 26) + uint16(bytes, header + 28)
        if (entry.compressedSize < 0 || start.toLong() + entry.compressedSize > bytes.size) corrupted()

        val file: ByteArray = when (entry.method) {
            0 -> {
                if (entry.compressedSize != entry.uncompressedSize) corrupted()
                bytes.copyOfRange(start, start + entry.compressedSize)
            }
            8 -> inflate(start, entry.compressedSize, entry.uncompressedSize)
            else -> throw ZipArchiveException(ZipArchiveException.Reason.UNSUPPORTED)
        }
        if (crc32(file) != entry.crc32) corrupted()
        return file
    }

    /** Raw DEFLATE (no zlib header) into exactly [size] bytes. */
    private fun inflate(start: Int, length: Int, size: Int): ByteArray {
        if (size == 0) return ByteArray(0)
        // DEFLATE shrinks data at most 1032 to 1
        if (length == 0 || size < 0 || size > minOf(MAX_FILE_SIZE.toLong(), length * 1032L)) corrupted()
        val inflater = Inflater(true)
        try {
            inflater.setInput(bytes, start, length)
            val out = ByteArray(size)
            var written = 0
            while (written < size) {
                val n = inflater.inflate(out, written, size - written)
                if (n == 0) {
                    if (inflater.finished() || inflater.needsDictionary()) break
                    // Raw inflate may want one more (dummy) byte to finish; with no input left, the data is short
                    if (inflater.needsInput()) break
                }
                written += n
            }
            if (written != size) corrupted()
            return out
        } catch (_: DataFormatException) {
            corrupted()
        } finally {
            inflater.end()
        }
    }

    companion object {
        /** How a ZIP archive starts, with the header of its first file: "PK\u0003\u0004". */
        val SIGNATURE = byteArrayOf(0x50, 0x4B, 0x03, 0x04)

        /** Far beyond any score; a bigger size is a damaged header, not a file worth the memory */
        private const val MAX_FILE_SIZE = 128 shl 20

        fun startsWithSignature(data: ByteArray): Boolean =
            data.size >= 4 && (0 until 4).all { data[it] == SIGNATURE[it] }

        /** The CRC-32 ZIP records for each file (the polynomial of zlib and PNG). */
        fun crc32(bytes: ByteArray): Long = CRC32().apply { update(bytes) }.value

        private fun corrupted(): Nothing = throw ZipArchiveException(ZipArchiveException.Reason.CORRUPTED)

        /** Where the end of central directory record starts: the last 22 bytes, or before a comment of up to 64 KB. */
        private fun endOfCentralDirectory(bytes: ByteArray): Int {
            if (bytes.size < 22) corrupted()
            var offset = bytes.size - 22
            val lowest = maxOf(0, offset - 0xFFFF)
            while (offset >= lowest) {
                if (bytes[offset] == 0x50.toByte() && bytes[offset + 1] == 0x4B.toByte() &&
                    bytes[offset + 2] == 0x05.toByte() && bytes[offset + 3] == 0x06.toByte()
                ) return offset
                offset--
            }
            corrupted()
        }

        private fun uint16(bytes: ByteArray, offset: Int): Int {
            if (offset < 0 || offset + 2 > bytes.size) corrupted()
            return (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)
        }

        private fun uint32Long(bytes: ByteArray, offset: Int): Long {
            if (offset < 0 || offset + 4 > bytes.size) corrupted()
            return (bytes[offset].toLong() and 0xFF) or ((bytes[offset + 1].toLong() and 0xFF) shl 8) or
                ((bytes[offset + 2].toLong() and 0xFF) shl 16) or ((bytes[offset + 3].toLong() and 0xFF) shl 24)
        }

        /** A 32-bit offset or size; one past Int.MAX_VALUE can only be a damaged header in an in-memory archive. */
        private fun uint32(bytes: ByteArray, offset: Int): Int {
            val value = uint32Long(bytes, offset)
            if (value > Int.MAX_VALUE) {
                // The signatures compared against are below Int.MAX_VALUE too, so this never hides a valid one
                return -1
            }
            return value.toInt()
        }
    }
}
