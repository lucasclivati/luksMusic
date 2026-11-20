// Headphones.kt — whether sound goes to headphones (iOS AudioEngineService.hasHeadphones), so the metronome can stay
// silent while the microphone listens through the phone's speaker, and a callback when that changes.
package com.lukstrike.luksmusic.feature.practice

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper

class Headphones(context: Context) {
    private val audioManager = context.getSystemService(AudioManager::class.java)

    private val headphoneTypes = buildSet {
        add(AudioDeviceInfo.TYPE_WIRED_HEADPHONES)
        add(AudioDeviceInfo.TYPE_WIRED_HEADSET)
        add(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
        add(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
        add(AudioDeviceInfo.TYPE_USB_HEADSET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(AudioDeviceInfo.TYPE_BLE_HEADSET)
    }

    val areConnected: Boolean
        get() = audioManager?.getDevices(AudioManager.GET_DEVICES_OUTPUTS)?.any { it.type in headphoneTypes } == true

    private var callback: AudioDeviceCallback? = null

    /** Calls [onChange] on the main thread when headphones are plugged in or removed. */
    fun watch(onChange: () -> Unit) {
        stop()
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) = onChange()
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) = onChange()
        }
        audioManager?.registerAudioDeviceCallback(cb, Handler(Looper.getMainLooper()))
        callback = cb
    }

    fun stop() {
        callback?.let { audioManager?.unregisterAudioDeviceCallback(it) }
        callback = null
    }
}
