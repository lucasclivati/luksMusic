// SecureUserStore.kt — keeps the signed-in user (with their Firebase tokens) on the device, encrypted with a key that
// lives in the Android Keystore and never leaves it. The iOS app keeps the same profile in UserDefaults.
//
// The file is in noBackupFilesDir: the Keystore key is not part of backups, so a restored copy could never be read
// on another phone anyway (after a restore the user simply signs in again).
package com.lukstrike.luksmusic.account

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.core.util.AtomicFile
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class SecureUserStore(context: Context) {

    private val file = AtomicFile(File(context.noBackupFilesDir, "account-user.bin"))

    /** The saved text, or null when there is none or it cannot be decrypted (key gone after a reinstall, say). */
    fun read(): String? = runCatching {
        if (!file.baseFile.exists()) return null
        val bytes = file.readFully()
        val ivLength = bytes[0].toInt()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, bytes, 1, ivLength))
        String(cipher.doFinal(bytes, 1 + ivLength, bytes.size - 1 - ivLength), Charsets.UTF_8)
    }.getOrNull()

    fun write(text: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val iv = cipher.iv
        val encrypted = cipher.doFinal(text.toByteArray(Charsets.UTF_8))
        val stream = file.startWrite()
        try {
            stream.write(iv.size)
            stream.write(iv)
            stream.write(encrypted)
            file.finishWrite(stream)
        } catch (e: Exception) {
            file.failWrite(stream)
            throw e
        }
    }

    fun clear() {
        file.delete()
    }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "luksmusic.account"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val TAG_BITS = 128
    }
}
