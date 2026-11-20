// LessonTexts.kt — turns the course's texts (core LessonText: string resource names, since :core has no Android
// resources) into words on screen. The names are learn_m_*, learn_l_* and learn_c_* in strings_learn.xml, and the
// lesson introductions' intro_* in strings_intro.xml; they are kept in release builds by res/raw/learn_keep.xml,
// since they are looked up by name.
package com.lukstrike.luksmusic.feature.learn

import android.annotation.SuppressLint
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import com.lukstrike.luksmusic.core.lessons.LessonText

/** The words of [text] in the language on screen; the key itself when no such string exists (a bug to fix). */
@SuppressLint("DiscouragedApi") // the course lives in :core, which can only name its strings
fun Context.lessonString(text: LessonText): String {
    if (text.isVerbatim) return text.key
    fun lookup(name: String): String {
        val id = resources.getIdentifier(name, "string", packageName)
        return if (id == 0) name else getString(id)
    }
    val main = lookup(text.key)
    return text.suffixKey?.let { "$main ${lookup(it)}" } ?: main
}

/** [lessonString] for composables; follows a change of the app's language. */
@Composable
@ReadOnlyComposable
fun lessonText(text: LessonText): String {
    LocalConfiguration.current // re-read when the language changes
    return LocalContext.current.lessonString(text)
}
