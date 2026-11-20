// AccountMessage.kt — texts the account services show (errors), kept as string resources until a screen draws them,
// so they always follow the language on screen (the services outlive any language change).
package com.lukstrike.luksmusic.account

import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.lukstrike.luksmusic.R
import java.io.IOException

sealed interface AccountMessage {
    /** A string resource; each argument is a String or another [AccountMessage]. */
    data class Res(@param:StringRes val id: Int, val args: List<Any> = emptyList()) : AccountMessage
    /** Text from the server that has no translation (an unknown Firebase error code, say). */
    data class Raw(val text: String) : AccountMessage

    fun resolve(context: Context): String = when (this) {
        is Raw -> text
        is Res -> if (args.isEmpty()) context.getString(id) else context.getString(
            id, *args.map { if (it is AccountMessage) it.resolve(context) else it }.toTypedArray(),
        )
    }

    companion object {
        fun res(@StringRes id: Int, vararg args: Any): AccountMessage = Res(id, args.toList())

        /** What went wrong, for the "…: %s" messages (iOS shows the error's localizedDescription). */
        fun describe(error: Throwable): AccountMessage = when (error) {
            is AccountException -> error.text
            is IOException -> Res(R.string.account_error_network)
            else -> error.message?.let(::Raw) ?: Res(R.string.account_error_unknown)
        }
    }
}

@Composable
fun AccountMessage.asString(): String = resolve(LocalContext.current)

/** An expected failure with a text for the user. */
class AccountException(val text: AccountMessage) : Exception(text.toString())

/**
 * Firebase answers errors with a code such as `INVALID_LOGIN_CREDENTIALS` or `WEAK_PASSWORD : Password should be…`.
 * The iOS app shows the code as it comes; the common ones get a sentence here, the rest still show the code.
 */
internal fun firebaseErrorMessage(code: String?): AccountMessage {
    if (code.isNullOrBlank()) return AccountMessage.Res(R.string.account_error_unknown)
    val id = when (code.substringBefore(' ').substringBefore(':').trim()) {
        "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND" -> R.string.account_fb_invalid_login
        "INVALID_EMAIL", "MISSING_EMAIL" -> R.string.account_fb_invalid_email
        "WEAK_PASSWORD", "MISSING_PASSWORD" -> R.string.account_fb_weak_password
        "EMAIL_EXISTS" -> R.string.account_fb_email_exists
        "USER_DISABLED" -> R.string.account_fb_user_disabled
        "TOO_MANY_ATTEMPTS_TRY_LATER" -> R.string.account_fb_too_many
        "CREDENTIAL_TOO_OLD_LOGIN_AGAIN", "TOKEN_EXPIRED", "INVALID_ID_TOKEN", "USER_NOT_FOUND",
        "INVALID_REFRESH_TOKEN" -> R.string.account_error_session_expired
        else -> return AccountMessage.Raw(code)
    }
    return AccountMessage.Res(id)
}
