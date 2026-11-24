package com.ecoconnect.eco_connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var alert: DeviceAlertPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createCallChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALERT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val asset = call.argument<String>("asset")
                        val pattern = call.argument<List<Int>>("pattern")
                        val emergency = call.argument<Boolean>("emergency") ?: false
                        if (asset == null || pattern == null) {
                            result.error("bad_args", "asset and pattern are required", null)
                        } else {
                            player().start(
                                asset,
                                pattern.map { it.toLong() }.toLongArray(),
                                emergency,
                            )
                            result.success(null)
                        }
                    }

                    "stop" -> {
                        alert?.stop()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun player(): DeviceAlertPlayer =
        alert ?: DeviceAlertPlayer(applicationContext).also { alert = it }

    override fun onDestroy() {
        alert?.stop()
        alert = null
        super.onDestroy()
    }

    // Android 8+ ignores a notification's sound and vibration unless they are
    // declared on its channel. The push for an incoming call names this
    // channel, so the phone still rings with the app in the background.
    private fun createCallChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            getSystemService(NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (manager.getNotificationChannel(CHANNEL_CALLS) != null) return

        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            CHANNEL_CALLS,
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Rings when someone calls this desk"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 700, 350, 700, 1600)
            setSound(sound, attributes)
            enableLights(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val ALERT_CHANNEL = "ecoconnect/alert"
        private const val CHANNEL_CALLS = "ecoconnect_calls"
    }
}
