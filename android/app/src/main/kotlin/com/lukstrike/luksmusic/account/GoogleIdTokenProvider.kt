// GoogleIdTokenProvider.kt — gets a Google ID token from Credential Manager ("Sign in with Google" sheet). The iOS app
// gets one through the OAuth web flow (ASWebAuthenticationSession + code exchange); both then hand it to Firebase's
// accounts:signInWithIdp, so the Firebase account is the same.
package com.lukstrike.luksmusic.account

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.lukstrike.luksmusic.R

internal object GoogleIdTokenProvider {

    /** Thrown when the user closes the Google sheet: not an error worth showing. */
    class Cancelled : Exception("Google sign-in cancelled")

    /**
     * Shows the Google account picker and returns the chosen account's ID token. [activityContext] must be an
     * Activity (Credential Manager draws its sheet over it).
     */
    suspend fun idToken(activityContext: Context): String {
        if (!FirebaseConfig.isGoogleSignInConfigured) {
            throw AccountException(AccountMessage.Res(R.string.account_google_not_configured))
        }
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(GetSignInWithGoogleOption.Builder(FirebaseConfig.GOOGLE_WEB_CLIENT_ID).build())
            .build()
        val credential = try {
            CredentialManager.create(activityContext).getCredential(activityContext, request).credential
        } catch (e: GetCredentialCancellationException) {
            throw Cancelled()
        } catch (e: NoCredentialException) {
            throw AccountException(AccountMessage.Res(R.string.account_google_no_account))
        }
        if (credential is CustomCredential && credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            return GoogleIdTokenCredential.createFrom(credential.data).idToken
        }
        throw AccountException(AccountMessage.Res(R.string.account_error_invalid_response))
    }
}
