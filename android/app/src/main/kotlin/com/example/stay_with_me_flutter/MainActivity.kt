package com.example.stay_with_me_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            // High-priority channel for normal mode (with sound and vibration)
            val highPriorityChannel = NotificationChannel(
                "timer_alerts",
                "Timer Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Important timer notifications"
                enableVibration(true)
                enableLights(true)
            }

            // Low-priority channel for stealth mode (silent)
            val lowPriorityChannel = NotificationChannel(
                "timer_stealth",
                "Timer (Silent)",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Silent timer notifications"
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
            }

            notificationManager.createNotificationChannel(highPriorityChannel)
            notificationManager.createNotificationChannel(lowPriorityChannel)
        }
    }
}
