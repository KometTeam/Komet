package ru.komet.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Typeface
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.content.LocusIdCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray
import org.json.JSONObject

class KometFcmService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        Log.d("KometFcm", "onMessageReceived type=${data["type"]} keys=${data.keys}")
        if (data.isEmpty()) return
        KometNotifier(applicationContext).handle(data)
    }
}

class KometNotifier(private val ctx: Context) {

    companion object {
        private const val CHANNEL_ID = "komet_messages"
        private const val CHANNEL_NAME = "Сообщения"
        private const val GROUP_KEY = "komet_messages_group"
        private const val SUMMARY_ID = 424200
        private const val PREFS = "komet_push"
        private const val FLN_RECEIVER =
            "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"
        private const val FLN_ACTION_TAPPED =
            "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED"
        private const val FLN_INPUT_RESULT = "FlutterLocalNotificationsPluginInputResult"
        private const val HISTORY_LIMIT = 8
        private const val ACCENT = 0xFF7C6BF0.toInt()
    }

    private data class Hist(val text: String, val key: String, val name: String, val ts: Long)

    fun handle(data: Map<String, String>) {
        when (data["type"]) {
            "InboundCall" -> CallNotifier.showIncoming(ctx, data)
            "CallFinished" -> CallNotifier.finishCall(ctx, data)
            else -> showMessage(data)
        }
    }

    private fun manager(): NotificationManager =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager().getNotificationChannel(CHANNEL_ID) == null) {
            manager().createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH),
            )
        }
    }

    private fun showMessage(data: Map<String, String>) {
        val chatId = data["mc"]?.toLongOrNull() ?: return
        val senderId = data["suid"] ?: ""
        val senderName = data["userName"] ?: data["title"] ?: "MAX"
        val chatTitle = data["title"] ?: senderName
        val text = data["msg"] ?: data["body"] ?: data["text"] ?: "Новое сообщение"
        val ts = data["ctime"]?.toLongOrNull() ?: data["ttime"]?.toLongOrNull()
            ?: System.currentTimeMillis()
        val isGroup = chatTitle != senderName
        val notifId = (chatId and 0x7fffffff).toInt()

        ensureChannel()

        val active = activeIds()
        if (!active.contains(notifId)) clearHistory(chatId)
        val history = appendHistory(chatId, Hist(text, senderId, senderName, ts))

        val avatarCache = HashMap<String, Bitmap>()
        val personCache = HashMap<String, Person>()
        fun avatarFor(key: String, name: String): Bitmap =
            avatarCache.getOrPut(key) { NotifAvatars.load(ctx, key, name) }
        fun personFor(key: String, name: String): Person =
            personCache.getOrPut(key) {
                Person.Builder()
                    .setName(name)
                    .setKey(key)
                    .setIcon(IconCompat.createWithBitmap(avatarFor(key, name)))
                    .build()
            }

        val senderPerson = personFor(senderId, senderName)
        val shortcutId = "chat_$chatId"
        publishShortcut(shortcutId, chatId, chatTitle, senderPerson)

        val style = NotificationCompat.MessagingStyle(Person.Builder().setName("Вы").build())
        if (isGroup) {
            style.conversationTitle = chatTitle
            style.isGroupConversation = true
        }
        for (h in history) {
            style.addMessage(h.text, h.ts, personFor(h.key, h.name))
        }

        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ACCENT)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setGroup(GROUP_KEY)
            .setWhen(ts)
            .setShowWhen(true)
            .setContentIntent(openIntent(notifId, chatId))
            .setShortcutId(shortcutId)
            .setLocusId(LocusIdCompat(shortcutId))
            .setStyle(style)
            .setLargeIcon(avatarFor(senderId, senderName))

        val account = data["c"]?.toIntOrNull() ?: 0
        if (account != 0) {
            builder.addAction(replyAction(notifId, account, chatId, data["msgid"]?.toLongOrNull()))
        }

        manager().notify(notifId, builder.build())
        updateSummary(notifId, chatId, senderName, text, ts, active)
    }

    private fun updateSummary(
        notifId: Int,
        chatId: Long,
        senderName: String,
        text: String,
        ts: Long,
        activeBefore: Set<Int>,
    ) {
        val reg = loadRegistry()
        val kept = JSONObject()
        val keys = reg.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            val id = k.toIntOrNull() ?: continue
            if (id == notifId) continue
            if (activeBefore.contains(id)) kept.put(k, reg.getJSONObject(k))
        }
        kept.put(
            notifId.toString(),
            JSONObject().put("n", senderName).put("t", text).put("ts", ts),
        )
        saveRegistry(kept)

        if (kept.length() < 2) {
            manager().cancel(SUMMARY_ID)
            return
        }

        val entries = ArrayList<Triple<String, String, Long>>()
        val kk = kept.keys()
        while (kk.hasNext()) {
            val k = kk.next()
            val o = kept.getJSONObject(k)
            entries.add(Triple(o.optString("n"), o.optString("t"), o.optLong("ts")))
        }
        entries.sortByDescending { it.third }

        val inbox = NotificationCompat.InboxStyle()
        for (e in entries.take(6)) inbox.addLine(boldLine(e.first, e.second))

        val summary = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ACCENT)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setGroup(GROUP_KEY)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setWhen(ts)
            .setShowWhen(true)
            .setNumber(entries.size)
            .setContentTitle("Komet")
            .setContentText(boldLine(senderName, text))
            .setStyle(inbox)
            .build()
        manager().notify(SUMMARY_ID, summary)
    }

    private fun boldLine(name: String, text: String): CharSequence {
        val sb = SpannableStringBuilder()
        sb.append(name)
        sb.setSpan(StyleSpan(Typeface.BOLD), 0, name.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        sb.append(": ")
        sb.append(text)
        return sb
    }

    private fun replyAction(
        notifId: Int,
        account: Int,
        chatId: Long,
        replyTo: Long?,
    ): NotificationCompat.Action {
        val payload = JSONObject()
            .put("c", account)
            .put("chat", chatId)
            .apply { if (replyTo != null) put("mid", replyTo) }
            .toString()
        val intent = Intent(FLN_ACTION_TAPPED).apply {
            setClassName(ctx, FLN_RECEIVER)
            putExtra("notificationId", notifId)
            putExtra("actionId", "reply")
            putExtra("payload", payload)
            putExtra("cancelNotification", false)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        val pi = PendingIntent.getBroadcast(ctx, notifId, intent, flags)
        val remoteInput = RemoteInput.Builder(FLN_INPUT_RESULT)
            .setLabel("Сообщение…")
            .build()
        return NotificationCompat.Action.Builder(R.drawable.ic_notification, "Ответить", pi)
            .addRemoteInput(remoteInput)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setAllowGeneratedReplies(true)
            .build()
    }

    private fun publishShortcut(id: String, chatId: Long, title: String, person: Person) {
        try {
            val intent = (ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
                ?: Intent(Intent.ACTION_VIEW)).apply {
                action = Intent.ACTION_VIEW
                putExtra("komet_chat", chatId)
            }
            val shortcut = ShortcutInfoCompat.Builder(ctx, id)
                .setShortLabel(title)
                .setLongLived(true)
                .setIntent(intent)
                .setPerson(person)
                .setIcon(person.icon)
                .build()
            ShortcutManagerCompat.pushDynamicShortcut(ctx, shortcut)
        } catch (e: Exception) {
            Log.w("KometFcm", "shortcut push failed: $e")
        }
    }

    private fun openIntent(notifId: Int, chatId: Long): PendingIntent? {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        launch.putExtra("komet_chat", chatId)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(ctx, notifId, launch, flags)
    }

    private fun activeIds(): Set<Int> = try {
        manager().activeNotifications.map { it.id }.toSet()
    } catch (e: Exception) {
        emptySet()
    }

    private fun pushPrefs() = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun appendHistory(chatId: Long, item: Hist): List<Hist> {
        val prefs = pushPrefs()
        val key = "hist_$chatId"
        val arr = try {
            JSONArray(prefs.getString(key, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        arr.put(
            JSONObject().put("t", item.text).put("k", item.key)
                .put("n", item.name).put("ts", item.ts),
        )
        while (arr.length() > HISTORY_LIMIT) arr.remove(0)
        prefs.edit().putString(key, arr.toString()).apply()
        val out = ArrayList<Hist>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(Hist(o.optString("t"), o.optString("k"), o.optString("n"), o.optLong("ts")))
        }
        return out
    }

    private fun clearHistory(chatId: Long) {
        pushPrefs().edit().remove("hist_$chatId").apply()
    }

    private fun loadRegistry(): JSONObject = try {
        JSONObject(pushPrefs().getString("registry", "{}") ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    private fun saveRegistry(reg: JSONObject) {
        pushPrefs().edit().putString("registry", reg.toString()).apply()
    }

}
