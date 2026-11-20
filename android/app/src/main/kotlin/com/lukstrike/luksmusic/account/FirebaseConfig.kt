// FirebaseConfig.kt — the Firebase project shared with the iOS app (Services/Auth/AuthService.swift, FirebaseConfig).
// Both apps talk to the same project over REST, so an account and its synced scores are the same on either phone.
package com.lukstrike.luksmusic.account

object FirebaseConfig {
    const val API_KEY = "AIzaSyAT2rggY4Kd5bzHbB56KdAyl0jhU894344"
    const val PROJECT_ID = "luksmusic-5a7ff"

    /**
     * The Firebase project's **Web** OAuth client ID, which Credential Manager needs to hand back a Google ID token
     * that Firebase accepts (`serverClientId`). The iOS client ID cannot be used on Android.
     *
     * Where to find it: Firebase console → Authentication → Sign-in method → Google → "Web SDK configuration" →
     * "Web client ID" (it ends in `.apps.googleusercontent.com`).
     *
     * Google sign-in on Android also needs the Android app registered in the same Firebase project: Project
     * settings → Add app → Android, package `com.lukstrike.luksmusic`, with the SHA-1 of every signing key that
     * builds the app (debug keystore, release keystore and, for Play, the Play App Signing key).
     *
     * While this is empty the Google button shows a friendly message instead of trying to sign in.
     */
    const val GOOGLE_WEB_CLIENT_ID = "623234251480-t94vimsbkf9rlkk5d2hm6blr3rp08oqm.apps.googleusercontent.com"

    const val IDENTITY_TOOLKIT_URL = "https://identitytoolkit.googleapis.com"
    const val SECURE_TOKEN_URL = "https://securetoken.googleapis.com/v1/token"
    const val FIRESTORE_URL = "https://firestore.googleapis.com/v1"
    const val FIRESTORE_DOCUMENTS_URL = "$FIRESTORE_URL/projects/$PROJECT_ID/databases/(default)/documents"

    val isGoogleSignInConfigured: Boolean get() = GOOGLE_WEB_CLIENT_ID.isNotBlank()
}
