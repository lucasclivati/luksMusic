// ScoreFiles.kt — reading a MusicXML file picked with the Storage Access Framework (or opened from another app)
// and writing a score back out as MusicXML: the import and export halves of iOS ScoreStorageService. Everything
// here runs off the main thread.
package com.lukstrike.luksmusic.feature.library

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.musicxml.MusicXMLExporter
import com.lukstrike.luksmusic.core.musicxml.MusicXMLParser
import com.lukstrike.luksmusic.core.musicxml.ParsedScore
import com.lukstrike.luksmusic.core.musicxml.ZipArchive
import com.lukstrike.luksmusic.data.ScoreRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException

/** A file picked for import, already read: its name and the score in it. */
data class PickedScoreFile(val fileName: String, val parsed: ParsedScore)

object ScoreFiles {

    /** What the system file picker offers. Many providers do not know the MusicXML types and report .musicxml and
     *  .mxl files as octet-stream, so that is offered too; the extension or the content decides afterwards. */
    val pickerMimeTypes = arrayOf(
        "application/vnd.recordare.musicxml+xml",
        "application/vnd.recordare.musicxml",
        "application/xml",
        "text/xml",
        "application/octet-stream",
    )

    private val supportedExtensions = setOf("musicxml", "xml", "mxl")

    /** Far beyond any score (the largest bundled piece is under 1 MB); a bigger file is not worth the memory. */
    private const val MAX_FILE_BYTES = 64L shl 20

    /** Reads and parses the file at [uri]. Throws [ImportException], MusicXMLException or ZipArchiveException. */
    suspend fun read(context: Context, uri: Uri): PickedScoreFile = withContext(Dispatchers.IO) {
        val name = displayName(context, uri)
        val bytes = try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    total += n
                    if (total > MAX_FILE_BYTES) throw ImportException(ImportException.Reason.TOO_LARGE)
                    out.write(buffer, 0, n)
                }
                out.toByteArray()
            } ?: throw ImportException(ImportException.Reason.FILE_NOT_READABLE)
        } catch (e: SecurityException) {
            throw ImportException(ImportException.Reason.FILE_NOT_READABLE)
        } catch (e: IOException) {
            throw ImportException(ImportException.Reason.FILE_NOT_READABLE)
        }

        // iOS accepts .musicxml, .xml and .mxl by name. Android files often come without a usable name (another
        // app's content link), so a file of another extension is still read when its content is MusicXML.
        val extension = name.substringAfterLast('.', "").lowercase()
        if (extension !in supportedExtensions && !looksLikeMusicXml(bytes)) {
            throw ImportException(ImportException.Reason.UNSUPPORTED_FORMAT)
        }
        val parsed = withContext(Dispatchers.Default) { MusicXMLParser.parse(bytes) }
        PickedScoreFile(name, parsed)
    }

    /** A ZIP archive (an .mxl) or XML whose start names a MusicXML score. */
    private fun looksLikeMusicXml(bytes: ByteArray): Boolean {
        if (ZipArchive.startsWithSignature(bytes)) return true
        val head = String(bytes, 0, minOf(bytes.size, 4096), Charsets.UTF_8)
        return head.contains("<score-partwise") || head.contains("<score-timewise")
    }

    /** The file's name as the provider shows it, else the last part of its path. */
    private fun displayName(context: Context, uri: Uri): String {
        runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) cursor.getString(index)?.takeIf { it.isNotBlank() }?.let { return it }
                }
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "score.musicxml"
    }

    /** The title a picked file suggests: its name without the extension, "_" and "-" read as spaces (iOS). */
    fun titleFromFileName(fileName: String): String =
        fileName.substringBeforeLast('.').replace('_', ' ').replace('-', ' ').trim()

    // region Export

    /**
     * The score as MusicXML: the file it was read from (the MusicXML inside an .mxl) when its notes were not
     * edited, else the edited measures written out (iOS exportScoreAsMusicXML).
     */
    suspend fun musicXml(scores: ScoreRepository, score: Score): String =
        (if (score.hasMusicXml) scores.musicXml(score.id) else null)
            ?: withContext(Dispatchers.Default) { MusicXMLExporter.export(score) }

    /** A file name for the score: its title with spaces as underscores (iOS), safe for any file system. */
    fun exportFileName(score: Score): String {
        val base = score.title.replace(' ', '_').replace(Regex("""[\\/:*?"<>|\u0000-\u001F]"""), "").ifBlank { "score" }
        return "$base.musicxml"
    }

    /** Writes the score's MusicXML to [uri] (a document the user created with the system picker). */
    suspend fun export(context: Context, scores: ScoreRepository, score: Score, uri: Uri): Boolean {
        val xml = musicXml(scores, score)
        return withContext(Dispatchers.IO) {
            runCatching {
                context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(xml.toByteArray()) } != null
            }.getOrDefault(false)
        }
    }

    /** MIME type of an exported score. */
    const val MUSICXML_MIME = "application/vnd.recordare.musicxml+xml"

    private fun fileProviderAuthority(context: Context) = "${context.packageName}.fileprovider"

    /** Whether the app declares the FileProvider sharing needs (see the manifest entry in the library's notes). */
    fun canShare(context: Context): Boolean {
        val authority = fileProviderAuthority(context)
        val provider = if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.resolveContentProvider(authority, PackageManager.ComponentInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.resolveContentProvider(authority, 0)
        }
        return provider != null
    }

    /** Opens the share sheet with the score as a MusicXML file. False when sharing is not set up or failed. */
    suspend fun share(context: Context, scores: ScoreRepository, score: Score): Boolean {
        if (!canShare(context)) return false
        val xml = musicXml(scores, score)
        val file = withContext(Dispatchers.IO) {
            val dir = File(context.cacheDir, "shared").apply { mkdirs() }
            File(dir, exportFileName(score)).apply { writeText(xml) }
        }
        return runCatching {
            val uri = FileProvider.getUriForFile(context, fileProviderAuthority(context), file)
            val send = Intent(Intent.ACTION_SEND)
                .setType(MUSICXML_MIME)
                .putExtra(Intent.EXTRA_STREAM, uri)
                .putExtra(Intent.EXTRA_TITLE, score.title)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            context.startActivity(Intent.createChooser(send, score.title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.onFailure { if (it !is IllegalArgumentException && it !is ActivityNotFoundException) throw it }.isSuccess
    }

    // endregion
}
