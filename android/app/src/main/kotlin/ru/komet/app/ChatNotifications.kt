package ru.komet.app

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.EventChannel

object ChatNotifications {
    const val EXTRA_CHAT = "komet_chat"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val ENABLED_KEY = "flutter.notifications_enabled"

    @Volatile
    var activeChatId: Long = 0L

    @Volatile
    var sink: EventChannel.EventSink? = null

    fun isDisplayed(chatId: Long): Boolean =
        AppState.resumed && activeChatId == chatId

    fun chatIdFrom(intent: Intent?): Long =
        intent?.getLongExtra(EXTRA_CHAT, 0L) ?: 0L

    fun enabled(ctx: Context): Boolean =
        ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getBoolean(ENABLED_KEY, true)
}
