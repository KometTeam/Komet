# Flutter-специфичные правила
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Игнорировать предупреждения о недостающих классах Play Core
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Правила для video_player плагина
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class io.flutter.plugins.videoplayer.VideoPlayerPlugin { *; }
-keep class io.flutter.plugins.videoplayer.VideoPlayerApi { *; }
-dontwarn io.flutter.plugins.videoplayer.**

# Правила для ExoPlayer (используется video_player на Android)
# Поддержка старых версий ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Поддержка новых версий ExoPlayer (3.x)
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Сохранить все классы, используемые ExoPlayer через рефлексию
-keepclassmembers class * {
    @com.google.android.exoplayer2.util.UnknownNull *;
}
-keepclassmembers class * {
    @androidx.media3.common.util.UnknownNull *;
}

# Правила для chewie
-keep class com.brianegan.chewie.** { *; }
-dontwarn com.brianegan.chewie.**

# Сохранить все классы, используемые через рефлексию
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Сохранить нативные методы
-keepclasseswithmembernames class * {
    native <methods>;
}

# Сохранить классы с аннотациями @Keep
-keep @androidx.annotation.Keep class *
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Правила для Apache Tika
-dontwarn javax.xml.stream.XMLStreamException
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**

# Игнорировать предупреждения о недостающих классах XML
-dontwarn javax.xml.**
-dontwarn org.w3c.dom.**