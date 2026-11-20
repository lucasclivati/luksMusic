// AuthRepository.kt — sign-in with Firebase Auth over REST, like the iOS app (Services/Auth/AuthService.swift):
// Google, e-mail and password, or guest; sign out and account deletion. One instance for the whole app, from
// AppContainer.auth.
//
// PUBLIC API — the app shell and other features use these members; keep their signatures stable.
//
// Sign in with Apple does not exist on Android. Users who created their account with Apple on an iPhone are told so
// on the login screen and can use the app as guests.
package com.lukstrike.luksmusic.account

import android.content.Context
import com.lukstrike.luksmusic.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import okhttp3.HttpUrl.Companion.toHttpUrl
import java.util.Locale
import java.util.UUID
import kotlin.coroutines.cancellation.CancellationException

@Serializable
enum class AuthProvider { GOOGLE, EMAIL, APPLE, GUEST }

@Serializable
data class UserProfile(
    val uid: String,
    val email: String,
    val displayName: String,
    val authProvider: AuthProvider,
    val idToken: String? = null,
    val refreshToken: String? = null,
    /** Epoch ms when [idToken] expires. */
    val idTokenExpiry: Long? = null,
)

class AuthRepository(private val context: Context) {

    private val _currentUser = MutableStateFlow<UserProfile?>(null)
    /** Null until someone signs in (or continues as a guest). */
    val currentUser: StateFlow<UserProfile?> = _currentUser

    /** False until the saved user (if any) was read at startup, so the login screen does not flash. */
    private val _isRestored = MutableStateFlow(false)
    val isRestored: StateFlow<Boolean> = _isRestored

    private val _isAuthenticating = MutableStateFlow(false)
    /** A sign-in, re-authentication or deletion is in progress. */
    val isAuthenticating: StateFlow<Boolean> = _isAuthenticating

    private val _authError = MutableStateFlow<AccountMessage?>(null)
    /** The last sign-in or deletion failure, shown under the buttons. */
    val authError: StateFlow<AccountMessage?> = _authError

    /** Uploads the library to Firestore (iOS CloudSyncService.shared); deleting the account also clears its data. */
    val cloudSync: CloudSyncService by lazy { CloudSyncService(context, this) }

    private val store = SecureUserStore(context)
    @OptIn(ExperimentalCoroutinesApi::class)
    private val io = Dispatchers.IO.limitedParallelism(1) // one write at a time, in order
    private val scope = CoroutineScope(SupervisorJob() + io)
    private val refreshMutex = Mutex()
    private val json = Json { ignoreUnknownKeys = true }

    init {
        scope.launch {
            _currentUser.value = store.read()?.let { runCatching { json.decodeFromString<UserProfile>(it) }.getOrNull() }
            _isRestored.value = true
        }
    }

    fun clearError() {
        _authError.value = null
    }

    // region Google

    /** Google account picker (Credential Manager) → Firebase. [activityContext] must be an Activity. */
    suspend fun signInWithGoogle(activityContext: Context) = authenticate(R.string.account_error_google) {
        val googleIdToken = GoogleIdTokenProvider.idToken(activityContext)
        saveUser(exchangeGoogleTokenWithFirebase(googleIdToken))
    }

    private suspend fun exchangeGoogleTokenWithFirebase(googleIdToken: String): UserProfile {
        val response = FirebaseRest.postJson(
            FirebaseRest.identityToolkitUrl("v1/accounts:signInWithIdp"),
            mapOf(
                "postBody" to "id_token=$googleIdToken&providerId=google.com",
                "requestUri" to "http://localhost",
                "returnIdpCredential" to true,
                "returnSecureToken" to true,
            ),
        )
        if (!response.isSuccessful) throw AccountException(FirebaseRest.failureText(response))
        val json = response.json
        val email = json.string("email").orEmpty()
        return profile(
            uid = json.string("localId") ?: UUID.randomUUID().toString(),
            email = email,
            displayName = json.string("displayName") ?: nameFromEmail(email),
            provider = AuthProvider.GOOGLE,
            json = json,
        )
    }

    // endregion
    // region E-mail and password

    /** Signs in, or creates the account when signing in fails (as the iOS app does). */
    suspend fun signInWithEmail(email: String, password: String) = authenticate(R.string.account_error_auth) {
        saveUser(performFirebaseEmailAuth(email.trim(), password))
    }

    private suspend fun performFirebaseEmailAuth(email: String, password: String): UserProfile {
        val body = mapOf("email" to email, "password" to password, "returnSecureToken" to true)

        // First try signInWithPassword
        val signIn = FirebaseRest.postJson(FirebaseRest.identityToolkitUrl("v1/accounts:signInWithPassword"), body)
        if (signIn.isSuccessful) {
            val signedEmail = signIn.json.string("email") ?: email
            return profile(
                uid = signIn.json.string("localId") ?: UUID.randomUUID().toString(),
                email = signedEmail,
                displayName = signIn.json.string("displayName") ?: nameFromEmail(signedEmail),
                provider = AuthProvider.EMAIL,
                json = signIn.json,
            )
        }

        // If signIn failed, the user may need to be registered (signUp)
        val signUp = FirebaseRest.postJson(FirebaseRest.identityToolkitUrl("v1/accounts:signUp"), body)
        if (signUp.isSuccessful) {
            val signedEmail = signUp.json.string("email") ?: email
            return profile(
                uid = signUp.json.string("localId") ?: UUID.randomUUID().toString(),
                email = signedEmail,
                displayName = nameFromEmail(signedEmail),
                provider = AuthProvider.EMAIL,
                json = signUp.json,
            )
        }

        // Both failed: report why signing in failed (sign-up usually fails only because the e-mail exists)
        throw AccountException(
            signIn.errorMessage?.let(::firebaseErrorMessage) ?: AccountMessage.Res(R.string.account_error_invalid_credentials)
        )
    }

    // endregion
    // region Guest

    fun continueAsGuest() {
        clearError()
        saveUser(
            UserProfile(
                uid = "guest_" + UUID.randomUUID().toString().uppercase(Locale.ROOT).take(8),
                email = GUEST_EMAIL,
                displayName = context.getString(R.string.account_guest_name),
                authProvider = AuthProvider.GUEST,
            )
        )
    }

    // endregion
    // region Account deletion

    /** How the user confirms who they are; Firebase only deletes accounts with a recent sign-in. */
    sealed interface Reauthentication {
        data class Password(val password: String) : Reauthentication
        /** [activityContext] must be an Activity, for the Google account picker. */
        class Google(val activityContext: Context) : Reauthentication
    }

    /** Deletes the user's cloud data and Firebase account, then signs out. Returns false and sets [authError] on failure. */
    suspend fun deleteAccount(reauthentication: Reauthentication): Boolean {
        val user = _currentUser.value ?: return false
        var deleted = false
        authenticate(R.string.account_error_delete) {
            val confirmed = when (reauthentication) {
                is Reauthentication.Password -> signInWithPassword(user.email, reauthentication.password)
                is Reauthentication.Google ->
                    exchangeGoogleTokenWithFirebase(GoogleIdTokenProvider.idToken(reauthentication.activityContext))
            }
            val idToken = confirmed.idToken
            if (confirmed.uid != user.uid || idToken == null) {
                throw AccountException(AccountMessage.Res(R.string.account_error_same_account))
            }
            cloudSync.deleteRemoteData(user.uid, idToken)
            FirebaseRest.postIdentityToolkit("v1/accounts:delete", mapOf("idToken" to idToken))

            cloudSync.resetSyncState()
            signOut()
            deleted = true
        }
        return deleted
    }

    private suspend fun signInWithPassword(email: String, password: String): UserProfile {
        val json = FirebaseRest.postIdentityToolkit(
            "v1/accounts:signInWithPassword",
            mapOf("email" to email, "password" to password, "returnSecureToken" to true),
        )
        return profile(
            uid = json.string("localId").orEmpty(),
            email = email,
            displayName = json.string("displayName") ?: email,
            provider = AuthProvider.EMAIL,
            json = json,
        )
    }

    // endregion
    // region Session tokens

    /** A valid Firebase ID token, refreshed when needed (throws when signed out or offline). */
    suspend fun freshIdToken(): String = refreshMutex.withLock {
        val user = _currentUser.value
        val refreshToken = user?.refreshToken
            ?: throw AccountException(AccountMessage.Res(R.string.account_error_sign_in_to_continue))
        val idToken = user.idToken
        // ID tokens last an hour; refresh a minute early so a request never goes out with an expiring one
        val expiry = user.idTokenExpiry ?: idToken?.let(Jwt::expiryMillis)
        if (idToken != null && expiry != null && expiry - System.currentTimeMillis() > 60_000) return idToken

        val response = FirebaseRest.postForm(
            "${FirebaseConfig.SECURE_TOKEN_URL}?key=${FirebaseConfig.API_KEY}".toHttpUrl(),
            mapOf("grant_type" to "refresh_token", "refresh_token" to refreshToken),
        )
        val newIdToken = response.json.string("id_token")
        if (!response.isSuccessful || newIdToken == null) {
            throw AccountException(AccountMessage.Res(R.string.account_error_session_expired))
        }
        // Signed out (or someone else signed in) while refreshing: do not bring the old user back
        if (_currentUser.value?.uid != user.uid) {
            throw AccountException(AccountMessage.Res(R.string.account_error_sign_in_to_continue))
        }
        saveUser(
            user.copy(
                idToken = newIdToken,
                refreshToken = response.json.string("refresh_token") ?: refreshToken,
                idTokenExpiry = Jwt.expiryMillis(newIdToken),
            )
        )
        newIdToken
    }

    // endregion
    // region Sign out & persistence

    fun signOut() {
        _currentUser.value = null
        scope.launch { store.clear() }
    }

    private fun saveUser(user: UserProfile) {
        _currentUser.value = user
        val text = json.encodeToString(UserProfile.serializer(), user)
        scope.launch { runCatching { store.write(text) } }
    }

    /** Runs a sign-in style action: shows progress, and turns a failure into [authError] ("[prefix]: reason"). */
    private suspend fun authenticate(prefix: Int, action: suspend () -> Unit) {
        _isAuthenticating.value = true
        _authError.value = null
        try {
            action()
        } catch (e: GoogleIdTokenProvider.Cancelled) {
            // Closing the Google sheet is not an error
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _authError.value = AccountMessage.res(prefix, AccountMessage.describe(e))
        } finally {
            _isAuthenticating.value = false
        }
    }

    private fun profile(uid: String, email: String, displayName: String, provider: AuthProvider, json: JsonObject) =
        UserProfile(
            uid = uid,
            email = email,
            displayName = displayName,
            authProvider = provider,
            idToken = json.string("idToken"),
            refreshToken = json.string("refreshToken"),
            idTokenExpiry = json.string("idToken")?.let(Jwt::expiryMillis),
        )

    /** "maria.silva@x.com" → "Maria.silva", as iOS's `components(separatedBy: "@").first?.capitalized`. */
    private fun nameFromEmail(email: String): String =
        email.substringBefore('@').takeIf { it.isNotEmpty() }?.let(::capitalizeWords)
            ?: context.getString(R.string.account_default_name)

    // endregion

    companion object {
        const val GUEST_EMAIL = "guest@luksmusic.local"

        /** Foundation's `capitalized`: first letter of each word upper case, the rest lower case. */
        internal fun capitalizeWords(text: String): String =
            text.split(' ').joinToString(" ") { word ->
                word.lowercase().replaceFirstChar { it.titlecase() }
            }
    }
}
