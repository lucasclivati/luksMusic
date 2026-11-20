// AppLanguage.kt — Portuguese or English, chosen in Ajustes or following the device (iOS Models/AppLanguage.swift).
// Android applies the choice at once (AppCompatDelegate per-app locales), no restart needed.
package com.lukstrike.luksmusic.ui

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.core.os.LocaleListCompat

enum class AppLanguage(val tag: String?) {
    /** The device's language (English for any language other than Portuguese). */
    SYSTEM(null),
    PORTUGUESE("pt-BR"),
    ENGLISH("en");

    companion object {
        /** The choice made in Ajustes. */
        val chosen: AppLanguage
            get() {
                val locales = AppCompatDelegate.getApplicationLocales()
                if (locales.isEmpty) return SYSTEM
                return if (locales[0]?.language == "pt") PORTUGUESE else ENGLISH
            }

        fun choose(language: AppLanguage) {
            AppCompatDelegate.setApplicationLocales(
                language.tag?.let { LocaleListCompat.forLanguageTags(it) } ?: LocaleListCompat.getEmptyLocaleList()
            )
        }

        /** Whether the app is showing English (note names in letters) rather than Portuguese (solfège). */
        fun usesLetterNames(context: Context): Boolean =
            context.resources.configuration.locales[0]?.language != "pt"
    }
}

/** Note names in letters (English) or solfège (Portuguese), following the language on screen. */
@Composable
fun usesLetterNames(): Boolean = LocalConfiguration.current.locales[0]?.language != "pt"
