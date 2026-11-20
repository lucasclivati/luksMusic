// AccountViewModel.kt — the login screen, Ajustes and the delete-account sheet talk to AuthRepository and
// CloudSyncService through here, so a sign-in or a sync keeps going when the screen is recreated (a language change
// recreates the activity).
package com.lukstrike.luksmusic.feature.account

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.account.AuthRepository
import com.lukstrike.luksmusic.appContainer
import kotlinx.coroutines.launch

class AccountViewModel(private val container: AppContainer) : ViewModel() {

    private val auth = container.auth
    private val cloudSync = auth.cloudSync

    val user = auth.currentUser
    val isAuthenticating = auth.isAuthenticating
    val authError = auth.authError
    val isSyncing = cloudSync.isSyncing
    val lastSyncDate = cloudSync.lastSyncDate
    val syncError = cloudSync.syncError
    val midiDevices = container.midi.connectedDevices

    fun signInWithEmail(email: String, password: String) {
        viewModelScope.launch { auth.signInWithEmail(email, password) }
    }

    /** [activityContext] must be an Activity, for the Google account picker. */
    fun signInWithGoogle(activityContext: Context) {
        viewModelScope.launch { auth.signInWithGoogle(activityContext) }
    }

    fun continueAsGuest() = auth.continueAsGuest()

    fun signOut() = auth.signOut()

    fun clearError() = auth.clearError()

    fun syncLibrary() {
        viewModelScope.launch { cloudSync.syncLibrary(container.scores.scores.value) }
    }

    fun deleteAccount(reauthentication: AuthRepository.Reauthentication, onDeleted: () -> Unit) {
        viewModelScope.launch { if (auth.deleteAccount(reauthentication)) onDeleted() }
    }

    companion object {
        val Factory = viewModelFactory {
            initializer { AccountViewModel(checkNotNull(this[APPLICATION_KEY]).appContainer) }
        }
    }
}
