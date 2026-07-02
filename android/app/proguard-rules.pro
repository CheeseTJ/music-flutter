# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# audio_service - uses reflection for notification building
-keep class com.ryanheise.audioservice.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.** { *; }

# just_audio
-keep class com.ryanheise.just_audio.** { *; }

# Keep MediaSession related
-keep class android.support.v4.media.session.** { *; }
-keep class androidx.media.session.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep notification related
-keep class android.app.Notification { *; }
-keep class android.support.v4.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat { *; }
