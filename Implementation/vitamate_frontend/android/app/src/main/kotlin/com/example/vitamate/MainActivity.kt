package com.example.vitamate

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val audioChannelName = "vitamate/motivation_audio"
    private val notificationSettingsChannelName = "vitamate/notification_settings"
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method != "play") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val type = call.argument<String>("type").orEmpty()
            playMotivationTone(type)
            result.success(null)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationSettingsChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                startActivity(intent)
                result.success(null)
            } catch (error: RuntimeException) {
                result.error("settings_unavailable", error.message, null)
            }
        }
    }

    private fun playMotivationTone(type: String) {
        when (type) {
            "mission_completed" -> playMissionCompletedTone()
            else -> playPointAwardedTone()
        }
    }

    private fun playPointAwardedTone() {
        playTone(ToneGenerator.TONE_PROP_BEEP, 130, 72)
    }

    private fun playMissionCompletedTone() {
        playTone(ToneGenerator.TONE_PROP_ACK, 150, 88)
        handler.postDelayed({
            playTone(ToneGenerator.TONE_CDMA_CONFIRM, 180, 88)
        }, 170)
    }

    private fun playTone(toneType: Int, durationMs: Int, volume: Int) {
        try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, volume)
            toneGenerator.startTone(toneType, durationMs)
            handler.postDelayed({
                try {
                    toneGenerator.release()
                } catch (_: RuntimeException) {
                    // Best effort only.
                }
            }, durationMs.toLong() + 80)
        } catch (_: RuntimeException) {
            // Best effort only; UI feedback must continue even if audio fails.
        }
    }
}
