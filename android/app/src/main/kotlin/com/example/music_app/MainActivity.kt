package com.example.music_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
    }

    private var notificationChannel: MethodChannel? = null
    private var customNotif: CustomMediaNotification? = null
    private var flutterCallback: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val notificationActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "Notification action: ${intent.action}")
            when (intent.action) {
                CustomMediaNotification.ACTION_PLAY -> {
                    notificationChannel?.invokeMethod("onPlay", null)
                }
                CustomMediaNotification.ACTION_PAUSE -> {
                    notificationChannel?.invokeMethod("onPause", null)
                }
                CustomMediaNotification.ACTION_SKIP_NEXT -> {
                    notificationChannel?.invokeMethod("onSkipNext", null)
                }
                CustomMediaNotification.ACTION_SKIP_PREV -> {
                    notificationChannel?.invokeMethod("onSkipPrev", null)
                }
            }
        }
    }

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
                // Custom notification methods
                "showCustomNotification" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val album = call.argument<String>("album") ?: ""
                    val coverUrl = call.argument<String>("coverUrl")
                    val playing = call.argument<Boolean>("playing") ?: true
                    showCustomNotification(title, artist, album, coverUrl, playing)
                    result.success(true)
                }
                "updateCustomPlayState" -> {
                    val playing = call.argument<Boolean>("playing") ?: false
                    updateCustomPlayState(playing)
                    result.success(true)
                }
                "hideCustomNotification" -> {
                    hideCustomNotification()
                    result.success(true)
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

        val filter = IntentFilter().apply {
            addAction(CustomMediaNotification.ACTION_PLAY)
            addAction(CustomMediaNotification.ACTION_PAUSE)
            addAction(CustomMediaNotification.ACTION_SKIP_NEXT)
            addAction(CustomMediaNotification.ACTION_SKIP_PREV)
        }
        registerReceiver(notificationActionReceiver, filter)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(notificationActionReceiver)
        } catch (_: Exception) {}
        customNotif?.cancel()
        super.onDestroy()
    }

    private fun showCustomNotification(
        title: String, artist: String, album: String,
        coverUrl: String?, playing: Boolean
    ) {
        try {
            if (customNotif == null) {
                customNotif = CustomMediaNotification(this)
            }
            customNotif?.updateMeta(title, artist, album, coverUrl, playing)
            Log.d(TAG, "Custom notification shown: $title")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show custom notification: ${e.message}")
        }
    }

    private fun updateCustomPlayState(playing: Boolean) {
        customNotif?.updatePlayState(playing)
    }

    private fun hideCustomNotification() {
        customNotif?.cancel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            // Delete old channels so importance level takes effect
            manager.deleteNotificationChannel(CHANNEL_ID)
            manager.deleteNotificationChannel("com.example.music_app.channel.player")
            // Audio service channel
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
            // Custom notification channel
            val customChannel = NotificationChannel(
                "com.example.music_app.channel.player",
                "播放控制",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "自定义播放控制通知"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            manager.createNotificationChannel(customChannel)
            Log.d(TAG, "Custom channel created: com.example.music_app.channel.player")
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
