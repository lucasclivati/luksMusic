package com.lukstrike.luksmusic

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.lukstrike.luksmusic.ui.navigation.LuksMusicRoot
import com.lukstrike.luksmusic.ui.theme.LuksMusicTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

// AppCompatActivity (not ComponentActivity) so the in-app language choice (AppCompatDelegate) works on every version.
class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleIntent(intent)
        setContent {
            LuksMusicTheme {
                LuksMusicRoot()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    /** A MusicXML file opened from another app is handed to the library, which imports it. */
    private fun handleIntent(intent: Intent?) {
        val uri: Uri? = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri != null) pendingImport.value = uri
    }

    companion object {
        private val pendingImport = MutableStateFlow<Uri?>(null)
        /** A file waiting to be imported into the library (the library clears it once imported). */
        val incomingFile: StateFlow<Uri?> = pendingImport
        fun clearIncomingFile() { pendingImport.value = null }
    }
}
