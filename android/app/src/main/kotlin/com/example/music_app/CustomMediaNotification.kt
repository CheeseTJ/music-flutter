package com.example.music_app

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import java.io.InputStream
import java.net.URL

class CustomMediaNotification(private val context: Context) {
    companion object {
        private const val TAG = "CustomMediaNotif"
        private const val CHANNEL_ID = "com.example.music_app.channel.player"
        const val NOTIFICATION_ID = 1002
        const val ACTION_PLAY = "com.example.music_app.PLAY"
        const val ACTION_PAUSE = "com.example.music_app.PAUSE"
        const val ACTION_SKIP_NEXT = "com.example.music_app.SKIP_NEXT"
        const val ACTION_SKIP_PREV = "com.example.music_app.SKIP_PREV"
    }

    private val pendingIntent: PendingIntent = PendingIntent.getActivity(
        context, 0,
        Intent(context, context.javaClass).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private val mediaSession: MediaSessionCompat = MediaSessionCompat(
        context, "CustomMediaSession"
    ).apply {
        setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                            PlaybackStateCompat.ACTION_PAUSE or
                            PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                            PlaybackStateCompat.ACTION_PLAY_PAUSE
                )
                .build()
        )
        isActive = true
    }

    private var smallIconResId: Int = 0
    private var title: String = ""
    private var artist: String = ""
    private var album: String = ""
    private var coverUrl: String? = null
    private var isPlaying: Boolean = false
    private var cachedCover: Bitmap? = null

    init {
        // Resolve the notification icon; fallback to android built-in music icon
        smallIconResId = context.resources.getIdentifier(
            "ic_stat_music_note", "drawable", context.packageName
        )
        if (smallIconResId == 0) {
            smallIconResId = context.applicationInfo.icon
            Log.w(TAG, "ic_stat_music_note not found, using app icon as fallback")
        }
        Log.d(TAG, "Created. smallIconResId=$smallIconResId, channel=$CHANNEL_ID")
    }

    fun buildPlayAction(): NotificationCompat.Action {
        return NotificationCompat.Action(
            android.R.drawable.ic_media_play,
            "播放",
            PendingIntent.getBroadcast(
                context, 1,
                Intent(ACTION_PLAY),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
    }

    fun buildPauseAction(): NotificationCompat.Action {
        return NotificationCompat.Action(
            android.R.drawable.ic_media_pause,
            "暂停",
            PendingIntent.getBroadcast(
                context, 2,
                Intent(ACTION_PAUSE),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
    }

    fun buildSkipNextAction(): NotificationCompat.Action {
        return NotificationCompat.Action(
            android.R.drawable.ic_media_next,
            "下一首",
            PendingIntent.getBroadcast(
                context, 3,
                Intent(ACTION_SKIP_NEXT),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
    }

    fun buildSkipPrevAction(): NotificationCompat.Action {
        return NotificationCompat.Action(
            android.R.drawable.ic_media_previous,
            "上一首",
            PendingIntent.getBroadcast(
                context, 4,
                Intent(ACTION_SKIP_PREV),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
    }

    fun updateMeta(
        newTitle: String,
        newArtist: String,
        newAlbum: String = "",
        newCoverUrl: String? = null,
        playing: Boolean = true
    ) {
        title = newTitle
        artist = newArtist
        album = newAlbum
        coverUrl = newCoverUrl
        isPlaying = playing
        cachedCover = null
        Log.d(TAG, "updateMeta: title=$title, artist=$artist, playing=$playing, coverUrl=$coverUrl")

        if (newCoverUrl != null) {
            fetchCoverAsync(newCoverUrl)
        }
        notifyUpdate()
    }

    fun updatePlayState(playing: Boolean) {
        isPlaying = playing
        Log.d(TAG, "updatePlayState: playing=$playing")
        notifyUpdate()
    }

    fun cancel() {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        nm.cancel(NOTIFICATION_ID)
        Log.d(TAG, "Notification cancelled")
    }

    private fun notifyUpdate() {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val notif = buildNotification()
            nm.notify(NOTIFICATION_ID, notif)
            Log.d(TAG, "Notification posted: $title, playing=$isPlaying, iconId=$smallIconResId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post notification: ${e.javaClass.simpleName} - ${e.message}", e)
        }
    }

    private fun buildNotification(): Notification {
        val actionList = mutableListOf(
            buildSkipPrevAction(),
            if (isPlaying) buildPauseAction() else buildPlayAction(),
            buildSkipNextAction()
        )

        Log.d(TAG, "buildNotification: title=$title, artist=$artist, icon=$smallIconResId, actions=${actionList.size}")

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSubText(album.ifEmpty { null })
            .setSmallIcon(smallIconResId)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .addAction(actionList[0])
            .addAction(actionList[1])
            .addAction(actionList[2])
            .apply {
                if (cachedCover != null) {
                    setLargeIcon(cachedCover)
                }
            }
            .build()
    }

    private fun fetchCoverAsync(url: String) {
        Thread {
            try {
                val bitmap = downloadCover(url)
                if (bitmap != null) {
                    cachedCover = bitmap
                    notifyUpdate()
                    Log.d(TAG, "Cover loaded and notification updated")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Cover download failed: ${e.message}")
            }
        }.start()
    }

    private fun downloadCover(url: String): Bitmap? {
        return try {
            val connection = URL(url).openConnection()
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            val input: InputStream = connection.getInputStream()
            val bitmap = BitmapFactory.decodeStream(input)
            input.close()
            if (bitmap != null) {
                val size = 256
                val scaled = Bitmap.createScaledBitmap(bitmap, size, size, true)
                if (scaled != bitmap) bitmap.recycle()
                scaled
            } else null
        } catch (e: Exception) {
            Log.e(TAG, "downloadCover error: ${e.message}")
            null
        }
    }
}
