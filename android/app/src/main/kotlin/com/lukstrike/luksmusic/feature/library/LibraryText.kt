// LibraryText.kt — a message the library shows, kept as a string resource (not as text) until it is drawn, so it
// follows the language on screen even when it was made by a service or a ViewModel.
package com.lukstrike.luksmusic.feature.library

import android.content.res.Resources
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.musicxml.MusicXMLException
import com.lukstrike.luksmusic.core.musicxml.ZipArchiveException

/** A string resource and its arguments; an argument may itself be a [LibraryText]. */
data class LibraryText(@param:StringRes val id: Int, val args: List<Any> = emptyList()) {
    constructor(@StringRes id: Int, vararg args: Any) : this(id, args.toList())

    fun resolve(resources: Resources): String {
        if (args.isEmpty()) return resources.getString(id)
        val resolved = args.map { if (it is LibraryText) it.resolve(resources) else it }
        return resources.getString(id, *resolved.toTypedArray())
    }
}

@Composable
fun LibraryText.resolve(): String = resolve(LocalContext.current.resources)

/** What went wrong reading a MusicXML file, in words (iOS MusicXMLParserError / ZipArchiveError descriptions). */
fun Throwable.importMessage(): LibraryText = when (this) {
    is ImportException -> LibraryText(reason.message)
    is MusicXMLException -> LibraryText(
        when (reason) {
            MusicXMLException.Reason.DATA_CORRUPTED -> R.string.library_musicxml_error_corrupted
            MusicXMLException.Reason.MISSING_PART -> R.string.library_musicxml_error_missing_part
            MusicXMLException.Reason.MISSING_SCORE_FILE -> R.string.library_musicxml_error_missing_score_file
        }
    )
    is ZipArchiveException -> LibraryText(
        when (reason) {
            ZipArchiveException.Reason.CORRUPTED -> R.string.library_zip_error_corrupted
            ZipArchiveException.Reason.UNSUPPORTED -> R.string.library_zip_error_unsupported
        }
    )
    else -> LibraryText(R.string.library_import_error_unexpected, localizedMessage ?: javaClass.simpleName)
}

/** Why a file could not be imported before it was even read as MusicXML (iOS ImportError). */
class ImportException(val reason: Reason) : Exception(reason.name) {
    enum class Reason(@param:StringRes val message: Int) {
        FILE_NOT_READABLE(R.string.library_import_error_not_readable),
        UNSUPPORTED_FORMAT(R.string.library_import_error_unsupported),
        TOO_LARGE(R.string.library_import_error_too_large),
    }
}
