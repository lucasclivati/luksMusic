package com.lukstrike.luksmusic.account

import com.lukstrike.luksmusic.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Base64

class AccountLogicTest {

    private fun jwt(payload: String): String {
        val encoder = Base64.getUrlEncoder().withoutPadding()
        return listOf("""{"alg":"RS256"}""", payload, "signature")
            .joinToString(".") { encoder.encodeToString(it.toByteArray()) }
    }

    @Test
    fun readsTheExpiryOfAToken() {
        assertEquals(1_700_000_000_000L, Jwt.expiryMillis(jwt("""{"exp":1700000000,"sub":"abc"}""")))
    }

    @Test
    fun payloadLengthsThatNeedPaddingStillDecode() {
        // Payloads of every length mod 4 (Firebase tokens drop the base64 padding)
        for (extra in 0..3) {
            val payload = """{"exp":1700000000,"x":"${"a".repeat(extra)}"}"""
            assertEquals(1_700_000_000_000L, Jwt.expiryMillis(jwt(payload)))
        }
    }

    @Test
    fun malformedTokensHaveNoExpiry() {
        assertNull(Jwt.expiryMillis("not-a-token"))
        assertNull(Jwt.expiryMillis(jwt("""{"sub":"abc"}""")))
        assertNull(Jwt.expiryMillis("a.%%%.c"))
    }

    @Test
    fun namesFromEmailsCapitalizeLikeFoundation() {
        assertEquals("Maria.silva", AuthRepository.capitalizeWords("maria.silva"))
        assertEquals("Joao", AuthRepository.capitalizeWords("JOAO"))
    }

    @Test
    fun knownFirebaseErrorsGetASentence() {
        assertEquals(AccountMessage.Res(R.string.account_fb_invalid_login), firebaseErrorMessage("INVALID_LOGIN_CREDENTIALS"))
        assertEquals(
            AccountMessage.Res(R.string.account_fb_weak_password),
            firebaseErrorMessage("WEAK_PASSWORD : Password should be at least 6 characters"),
        )
        assertEquals(AccountMessage.Raw("SOMETHING_NEW"), firebaseErrorMessage("SOMETHING_NEW"))
        assertEquals(AccountMessage.Res(R.string.account_error_unknown), firebaseErrorMessage(null))
    }
}
