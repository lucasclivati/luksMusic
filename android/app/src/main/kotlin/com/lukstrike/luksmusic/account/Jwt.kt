// Jwt.kt — reads the expiry of a Firebase ID token (iOS AuthService.expiryDate(of:)).
package com.lukstrike.luksmusic.account

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.Base64

internal object Jwt {
    /** Epoch ms of the `exp` claim, read without verifying the token (the server still checks it). */
    fun expiryMillis(jwt: String): Long? = runCatching {
        val parts = jwt.split('.')
        if (parts.size != 3) return null
        val payload = String(Base64.getUrlDecoder().decode(parts[1].trimEnd('=')), Charsets.UTF_8)
        val exp = Json.parseToJsonElement(payload).jsonObject["exp"]?.jsonPrimitive?.doubleOrNull ?: return null
        (exp * 1000).toLong()
    }.getOrNull()
}
