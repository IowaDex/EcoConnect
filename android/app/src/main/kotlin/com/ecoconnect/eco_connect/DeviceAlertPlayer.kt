package com.ecoconnect.eco_connect

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import java.io.File

/**
 * Plays a looping alert tone and a repeating vibration straight from the
 * platform.
 *
 * The Dart side only decides *when* to ring. Once started, the sound and the
 * vibration are owned by Android, so they keep going while the app is in the
 * background or the screen is locked, and they stop the moment the call or the
 * SOS is handled. No Flutter timer is involved.
 */
class DeviceAlertPlayer(private val context: Context) {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var asset: String? = null

    fun start(assetPath: String, pattern: LongArray, emergency: Boolean) {
        if (asset == assetPath && player != null) return
        stop()
        asset = assetPath
        startVibration(pattern, emergency)
        startSound(assetPath, emergency)
    }

    fun stop() {
        asset = null
        player?.let { media ->
            try {
                if (media.isPlaying) media.stop()
            } catch (error: Exception) {
                Log.w(TAG, "Could not stop the alert sound", error)
            }
            try {
                media.release()
            } catch (error: Exception) {
                Log.w(TAG, "Could not release the alert player", error)
            }
        }
        player = null
        try {
            vibrator?.cancel()
        } catch (error: Exception) {
            Log.w(TAG, "Could not stop the alert vibration", error)
        }
        vibrator = null
    }

    private fun startSound(assetPath: String, emergency: Boolean) {
        try {
            val file = copyToCache(assetPath)
            val media = MediaPlayer()
            media.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(
                        if (emergency) {
                            AudioAttributes.USAGE_ALARM
                        } else {
                            AudioAttributes.USAGE_NOTIFICATION_RINGTONE
                        }
                    )
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            media.setDataSource(file.absolutePath)
            media.isLooping = true
            media.prepare()
            media.start()
            player = media
        } catch (error: Exception) {
            Log.e(TAG, "Could not play $assetPath", error)
        }
    }

    /**
     * MediaPlayer cannot open a compressed APK entry as a file, so the asset is
     * copied to the cache once and played from there.
     */
    private fun copyToCache(assetPath: String): File {
        val out = File(context.cacheDir, assetPath.substringAfterLast('/'))
        if (!out.exists() || out.length() == 0L) {
            context.assets.open("flutter_assets/$assetPath").use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            }
        }
        return out
    }

    private fun startVibration(pattern: LongArray, emergency: Boolean) {
        try {
            val device = vibrator() ?: return
            if (!device.hasVibrator()) return
            vibrator = device
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attributes = AudioAttributes.Builder()
                    .setUsage(
                        if (emergency) {
                            AudioAttributes.USAGE_ALARM
                        } else {
                            AudioAttributes.USAGE_NOTIFICATION_RINGTONE
                        }
                    )
                    .build()
                // Repeat index 0 loops the waveform from its first entry.
                device.vibrate(VibrationEffect.createWaveform(pattern, 0), attributes)
            } else {
                @Suppress("DEPRECATION")
                device.vibrate(pattern, 0)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not start the alert vibration", error)
        }
    }

    private fun vibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    companion object {
        private const val TAG = "DeviceAlertPlayer"
    }
}
