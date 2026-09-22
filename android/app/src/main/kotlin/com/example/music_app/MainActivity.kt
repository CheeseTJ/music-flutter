package com.example.music_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
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

        // 老系统没有 AudioManager 模式回调 API，只能轮询；见 startAudioModeWatch。
        private const val MODE_POLL_INTERVAL_MS = 1000L

        // 自研通知时期用过的渠道，现已废弃。保留这个常量只为了在用户设备上
        // 把它删掉（见 createNotificationChannel）。
        private const val LEGACY_CUSTOM_CHANNEL_ID = "com.example.music_app.channel.player"
    }

    private var notificationChannel: MethodChannel? = null

    // 通话模式监听是否已注册。进程内注册一次即可，不跟随 Activity 生命周期：
    // 放歌时 Activity 可能已经销毁，而事件要能继续推给后台的 Dart 侧。
    private var audioModeWatching = false

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
                "getAudioMode" -> {
                    result.success(currentAudioMode())
                }
                else -> result.notImplemented()
            }
        }
        startAudioModeWatch()
    }

    /**
     * 监听 AudioManager 模式，用来发现「来电 / 语音通话」。
     *
     * 为什么要在原生侧做：正常的音频焦点协商是系统主动给 app 发回调
     * （AUDIOFOCUS_LOSS_TRANSIENT），但部分厂商 ROM 进入通话时根本不给第三方
     * app 发，Dart 侧等不到任何信号，音乐就继续播。既然等不到回调，就只能自己
     * 看系统状态。模式回调 API 是 Android 12（API 31）才有的，12 以下退化成轮询。
     *
     * 只认 MODE_IN_CALL / MODE_IN_COMMUNICATION，不认 MODE_RINGTONE：后者在用户
     * 调整铃声音量时也会短暂出现，拿来暂停音乐属于误伤。代价是「只响铃、未接通」
     * 那段，如果 ROM 又不发焦点回调，就检测不到。
     *
     * 进程级注册一次即可，不跟随 Activity 生命周期：放歌时 Activity 可能已经销毁，
     * 而事件要能继续推给后台的 Dart 侧。
     */
    private fun startAudioModeWatch() {
        if (audioModeWatching) return
        val manager = applicationContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return
        val channel = notificationChannel ?: return
        audioModeWatching = true

        // 这个闭包刻意只捕获 channel 和 lastMode，不碰 MainActivity：按返回键退出后
        // Activity 会被销毁，而 audio_service 的前台服务让进程继续活着（后台放歌），
        // 监听器若持有 Activity 就是一处泄漏。channel 绑的是 AudioServicePlugin 里
        // 那个静态共享的 FlutterEngine，Activity 没了它照样能送到 Dart 侧。
        var lastMode = Int.MIN_VALUE
        val report: (Int) -> Unit = { mode ->
            if (mode != lastMode) {
                lastMode = mode
                Log.d(TAG, "AudioManager.mode -> $mode")
                channel.invokeMethod("onAudioModeChanged", mode)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ 有模式变化回调，免权限、零轮询。
            manager.addOnModeChangedListener(mainExecutor) { mode -> report(mode) }
        } else {
            // 老系统没有回调 API，只能轮询；只有模式真的变了才通知 Dart。
            lastMode = manager.mode
            val handler = Handler(Looper.getMainLooper())
            handler.postDelayed(object : Runnable {
                override fun run() {
                    report(manager.mode)
                    handler.postDelayed(this, MODE_POLL_INTERVAL_MS)
                }
            }, MODE_POLL_INTERVAL_MS)
        }
    }

    private fun currentAudioMode(): Int {
        val manager = applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return manager.mode
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
