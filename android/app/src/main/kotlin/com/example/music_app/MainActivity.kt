package com.example.music_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "MusicActivity"
        private const val REQ_POST_NOTIFICATIONS = 1001
        private const val CHANNEL_ID = "com.example.music_app.channel.audio"
        private const val CHANNEL_NAME = "音乐播放"
        private const val METHOD_CHANNEL = "com.example.music_app/notification"

        // 自研通知时期用过的渠道，现已废弃。保留这个常量只为了在用户设备上
        // 把它删掉（见 createNotificationChannel）。
        private const val LEGACY_CUSTOM_CHANNEL_ID = "com.example.music_app.channel.player"
    }

    private var notificationChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        )
        notificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationPermissionGranted" -> {
                    result.success(isNotificationPermissionGranted())
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                "isNotificationChannelEnabled" -> {
                    result.success(isNotificationChannelEnabled())
                }
                "debugInfo" -> {
                    result.success(getDebugInfo())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate: SDK_INT=${Build.VERSION.SDK_INT}")
        createNotificationChannel()
        requestNotificationPermission()
        logNotificationStatus()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            // 删掉历史遗留的自研通知渠道，避免它在通知设置里继续占一行。
            manager.deleteNotificationChannel(LEGACY_CUSTOM_CHANNEL_ID)
            // Delete old channels so importance level takes effect
            manager.deleteNotificationChannel(CHANNEL_ID)
            // 播放通知渠道（由 audio_service 使用）
            val audioChannel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "音乐播放控制通知"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            manager.createNotificationChannel(audioChannel)
            Log.d(TAG, "Audio channel created: $CHANNEL_ID")
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "POST_NOTIFICATIONS permission granted: $granted")
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_POST_NOTIFICATIONS
                )
            }
        }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun isNotificationChannelEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = manager.getNotificationChannel(CHANNEL_ID)
            val enabled = channel != null && channel.importance != NotificationManager.IMPORTANCE_NONE
            Log.d(TAG, "Channel $CHANNEL_ID enabled: $enabled, importance: ${channel?.importance}")
            return enabled
        }
        return true
    }

    private fun openNotificationSettings() {
        val intent = Intent().apply {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                    action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                else -> {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.fromParts("package", packageName, null)
                }
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun logNotificationStatus() {
        Log.d(TAG, "Notification permission: ${isNotificationPermissionGranted()}")
        Log.d(TAG, "Notification channel enabled: ${isNotificationChannelEnabled()}")
        Log.d(
            TAG,
            "Notifications globally enabled: ${
                NotificationManagerCompat.from(this).areNotificationsEnabled()
            }"
        )
    }

    private fun getDebugInfo(): String {
        return buildString {
            appendLine("SDK: ${Build.VERSION.SDK_INT}")
            appendLine("Manufacturer: ${Build.MANUFACTURER}")
            appendLine("Model: ${Build.MODEL}")
            appendLine("Permission: ${isNotificationPermissionGranted()}")
            appendLine("ChannelEnabled: ${isNotificationChannelEnabled()}")
            appendLine(
                "NotificationsEnabled: ${
                    NotificationManagerCompat.from(this@MainActivity).areNotificationsEnabled()
                }"
            )
        }
    }
}
