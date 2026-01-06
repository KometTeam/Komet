package com.gwid.app.gwid

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import java.io.File

// Данные одного сообщения для накопления в уведомлении
data class MessageData(
    val senderName: String,
    val text: String,
    val timestamp: Long,
    val senderKey: String
)

class NotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "chat_messages_native_v2"
        const val CHANNEL_NAME = "Сообщения чатов"
        const val CHANNEL_DESC = "Уведомления о новых сообщениях"

        const val BACKGROUND_SERVICE_CHANNEL_ID = "background_service"
        const val BACKGROUND_SERVICE_CHANNEL_NAME = "Фоновый сервис"
        const val BACKGROUND_SERVICE_CHANNEL_DESC = "Поддерживает приложение активным в фоне"
        const val BACKGROUND_SERVICE_NOTIFICATION_ID = 888

        // Хранилище сообщений для каждого чата (chatId -> список сообщений)
        private val chatMessages = mutableMapOf<Long, MutableList<MessageData>>()
        // Хранилище Person для каждого отправителя (senderKey -> Person)
        private val personCache = mutableMapOf<String, Person>()
    }

    private fun safeMyDisplayName(myName: String?, conversationTitle: String?): String {
        return myName
            ?.takeIf { it.isNotBlank() && (conversationTitle == null || it != conversationTitle) }
            ?: "Я"
    }

    init {
        createNotificationChannel()
        createBackgroundServiceChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESC
                // Не включаем вибрацию на канале, чтобы можно было управлять ей в каждом уведомлении отдельно
                enableVibration(false)
                setShowBadge(true)
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createBackgroundServiceChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_MIN
            val channel = NotificationChannel(BACKGROUND_SERVICE_CHANNEL_ID, BACKGROUND_SERVICE_CHANNEL_NAME, importance).apply {
                description = BACKGROUND_SERVICE_CHANNEL_DESC
                enableVibration(false)
                setShowBadge(false)
                setSound(null, null)
                enableLights(false)
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    // Очистить накопленные сообщения для чата (вызывается когда пользователь открыл чат)
    fun clearMessagesForChat(chatId: Long) {
        android.util.Log.d("NotificationHelper", "clearMessagesForChat вызван для chatId: $chatId")
        chatMessages.remove(chatId)
        // Также отменяем уведомление
        cancelNotification(chatId)
    }

    // Отменить уведомление для чата
    fun cancelNotification(chatId: Long) {
        val notificationId = chatId.hashCode()
        android.util.Log.d("NotificationHelper", "cancelNotification: chatId=$chatId, notificationId=$notificationId")
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            android.util.Log.d("NotificationHelper", "Уведомление успешно отменено для чата $chatId (id: $notificationId)")
        } catch (e: Exception) {
            android.util.Log.e("NotificationHelper", "Ошибка отмены уведомления: ${e.message}")
            e.printStackTrace()
        }
    }

    fun showMessageNotification(
        chatId: Long,
        senderName: String,
        messageText: String,
        avatarPath: String?,
        isGroupChat: Boolean,
        groupTitle: String?,
        enableVibration: Boolean = true,
        vibrationPattern: List<Long>? = null,
        canReply: Boolean = true,
        myName: String? = null
    ) {
        // Преобразуем Long в Int для notification ID (используем hashCode)
        val notificationId = chatId.hashCode()

        // Создаём ключ для отправителя
        val senderKey = "sender_${senderName.hashCode()}_$chatId"

        // Создаём круглую аватарку
        val avatarBitmap = avatarPath?.let { path ->
            val file = File(path)
            if (file.exists()) {
                val original = BitmapFactory.decodeFile(path)
                original?.let { getCircularBitmap(it) }
            } else null
        }

        // Получаем или создаём Person для отправителя
        val person = personCache.getOrPut(senderKey) {
            val personBuilder = Person.Builder()
                .setName(senderName)
                .setKey(senderKey)
                .setImportant(true)

            if (avatarBitmap != null) {
                personBuilder.setIcon(IconCompat.createWithBitmap(avatarBitmap))
            }

            personBuilder.build()
        }

        // Добавляем сообщение в историю чата
        val messageData = MessageData(
            senderName = senderName,
            text = messageText,
            timestamp = System.currentTimeMillis(),
            senderKey = senderKey
        )

        val messages = chatMessages.getOrPut(chatId) { mutableListOf() }
        messages.add(messageData)

        // Ограничиваем количество сообщений (последние 10)
        if (messages.size > 10) {
            messages.removeAt(0)
        }

        // Создаём shortcut для Conversation notification (Android 11+)
        val shortcutId = "shortcut_chat_$notificationId"
        // Для групп shortcut показывает название группы, для личных - имя отправителя
        val shortcutLabel = if (isGroupChat && groupTitle != null) groupTitle else senderName

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val shortcut = ShortcutInfoCompat.Builder(context, shortcutId)
                .setShortLabel(shortcutLabel)
                .setLongLived(true)
                .setPerson(person)
                .setIntent(Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("chat_id", chatId) // Long
                })
                .build()

            ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
        }

        // Conversation title (название чата) используется системой отдельно.
        // Для исходящих сообщений берём имя текущего пользователя. Если оно совпадает с названием чата,
        // Android-UI может визуально «дублировать» заголовок, поэтому подставляем "Я".
        val conversationTitle = if (isGroupChat) groupTitle else senderName
        val safeMyName = safeMyDisplayName(myName, conversationTitle)

        // Создаём Person для текущего пользователя (я) для MessagingStyle
        val mePerson = Person.Builder()
            .setName(safeMyName)
            .setKey("me")
            .build()

        // Создаём MessagingStyle с текущим пользователем (я), а не отправителем
        val messagingStyle = NotificationCompat.MessagingStyle(mePerson)
            .setConversationTitle(conversationTitle)
            .setGroupConversation(isGroupChat)

        // Добавляем все накопленные сообщения
        for (msg in messages) {
            val msgPerson = when (msg.senderKey) {
                "me" -> mePerson
                else -> {
                    personCache[msg.senderKey]
                        ?: Person.Builder()
                            .setName(msg.senderName)
                            .setKey(msg.senderKey)
                            .setImportant(true)
                            .build()
                            .also { personCache[msg.senderKey] = it }
                }
            }
            messagingStyle.addMessage(msg.text, msg.timestamp, msgPerson)
        }

        // Intent при нажатии на уведомление
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("chat_id", chatId) // Long
            putExtra("payload", "chat_$chatId")
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId, // Int для requestCode
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Группировка уведомлений - используем chatId как groupKey
        val groupKey = "chat_group_$chatId"

        // Строим уведомление
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setStyle(messagingStyle)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setShortcutId(shortcutId)
            .setGroup(groupKey) // Группировка по chatId
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)

        // Добавляем largeIcon (показывается в свёрнутом виде)
        if (avatarBitmap != null) {
            builder.setLargeIcon(avatarBitmap)
        }

        // Настройка вибрации
        if (enableVibration && vibrationPattern != null && vibrationPattern.isNotEmpty()) {
            builder.setVibrate(vibrationPattern.toLongArray())
        } else if (!enableVibration) {
            builder.setVibrate(longArrayOf(0)) // Без вибрации
        }

        // Добавляем inline reply action, если чат позволяет отправлять сообщения
        if (canReply) {
            val replyLabel = "Ответить"
            val remoteInput = androidx.core.app.RemoteInput.Builder("key_text_reply")
                .setLabel(replyLabel)
                .build()

            val replyIntent = Intent(context, NotificationReplyReceiver::class.java).apply {
                action = "com.gwid.app.REPLY_ACTION"
                putExtra("chat_id", chatId)
                putExtra("sender_name", senderName)
                putExtra("is_group_chat", isGroupChat)
                putExtra("group_title", groupTitle)
                putExtra("my_name", safeMyName)
                putExtra("avatar_path", avatarPath)
            }

            val replyPendingIntent = PendingIntent.getBroadcast(
                context,
                (chatId.hashCode() + 1),
                replyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )

            val replyAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_menu_send,
                replyLabel,
                replyPendingIntent
            )
                .addRemoteInput(remoteInput)
                .setAllowGeneratedReplies(true)
                .build()

            builder.addAction(replyAction)
        }

        // Показываем уведомление
        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())

            // Если есть несколько сообщений в этом чате, создаём summary notification
            if (messages.size > 1) {
                createGroupSummaryNotification(chatId, groupKey, messages.size, shortcutLabel)
            }
        } catch (e: SecurityException) {
            // Нет разрешения на уведомления
            e.printStackTrace()
        }
    }

    fun addOutgoingReplyAndUpdateNotification(
        chatId: Long,
        replyText: String,
        senderName: String,
        isGroupChat: Boolean,
        groupTitle: String?,
        avatarPath: String?,
        myName: String?
    ) {
        val notificationId = chatId.hashCode()
        val conversationTitle = if (isGroupChat) groupTitle else senderName
        val safeMyName = safeMyDisplayName(myName, conversationTitle)

        val avatarBitmap = avatarPath?.let { path ->
            val file = File(path)
            if (file.exists()) {
                val original = BitmapFactory.decodeFile(path)
                original?.let { getCircularBitmap(it) }
            } else null
        }

        // Ensure sender Person exists (for 1:1 title/shortcut consistency)
        val senderKey = "sender_${senderName.hashCode()}_$chatId"
        if (!personCache.containsKey(senderKey)) {
            val personBuilder = Person.Builder()
                .setName(senderName)
                .setKey(senderKey)
                .setImportant(true)
            if (avatarBitmap != null) {
                personBuilder.setIcon(IconCompat.createWithBitmap(avatarBitmap))
            }
            personCache[senderKey] = personBuilder.build()
        }

        val messages = chatMessages.getOrPut(chatId) { mutableListOf() }
        messages.add(
            MessageData(
                senderName = safeMyName,
                text = replyText,
                timestamp = System.currentTimeMillis(),
                senderKey = "me"
            )
        )
        if (messages.size > 10) {
            messages.removeAt(0)
        }

        val mePerson = Person.Builder()
            .setName(safeMyName)
            .setKey("me")
            .build()

        val messagingStyle = NotificationCompat.MessagingStyle(mePerson)
            .setConversationTitle(conversationTitle)
            .setGroupConversation(isGroupChat)

        for (msg in messages) {
            val msgPerson = when (msg.senderKey) {
                "me" -> mePerson
                else -> {
                    personCache[msg.senderKey]
                        ?: Person.Builder()
                            .setName(msg.senderName)
                            .setKey(msg.senderKey)
                            .setImportant(true)
                            .build()
                            .also { personCache[msg.senderKey] = it }
                }
            }
            messagingStyle.addMessage(msg.text, msg.timestamp, msgPerson)
        }

        val shortcutId = "shortcut_chat_$notificationId"
        val shortcutLabel = if (isGroupChat && groupTitle != null) groupTitle else senderName
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val shortcut = ShortcutInfoCompat.Builder(context, shortcutId)
                .setShortLabel(shortcutLabel)
                .setLongLived(true)
                .setPerson(personCache[senderKey]!!)
                .setIntent(Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("chat_id", chatId)
                })
                .build()
            ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("chat_id", chatId)
            putExtra("payload", "chat_$chatId")
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val groupKey = "chat_group_$chatId"
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setStyle(messagingStyle)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setShortcutId(shortcutId)
            .setGroup(groupKey)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)

        if (avatarBitmap != null) {
            builder.setLargeIcon(avatarBitmap)
        }

        // Inline reply action (keeps working after update)
        val replyLabel = "Ответить"
        val remoteInput = androidx.core.app.RemoteInput.Builder("key_text_reply")
            .setLabel(replyLabel)
            .build()

        val replyIntent = Intent(context, NotificationReplyReceiver::class.java).apply {
            action = "com.gwid.app.REPLY_ACTION"
            putExtra("chat_id", chatId)
            putExtra("sender_name", senderName)
            putExtra("is_group_chat", isGroupChat)
            putExtra("group_title", groupTitle)
            putExtra("my_name", safeMyName)
            putExtra("avatar_path", avatarPath)
        }
        val replyPendingIntent = PendingIntent.getBroadcast(
            context,
            (chatId.hashCode() + 1),
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            replyLabel,
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()
        builder.addAction(replyAction)

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        } catch (_: SecurityException) {
        }
    }

    // Создание summary notification для группы уведомлений
    private fun createGroupSummaryNotification(
        chatId: Long,
        groupKey: String,
        messageCount: Int,
        chatTitle: String
    ) {
        val summaryNotificationId = (chatId.hashCode() + 1000000) // Уникальный ID для summary

        val summaryBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(chatTitle)
            .setContentText("$messageCount ${if (messageCount == 1) "сообщение" else if (messageCount < 5) "сообщения" else "сообщений"}")
            .setGroup(groupKey)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)

        try {
            NotificationManagerCompat.from(context).notify(summaryNotificationId, summaryBuilder.build())
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun getCircularBitmap(bitmap: Bitmap): Bitmap {
        val size = minOf(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val paint = Paint().apply {
            isAntiAlias = true
            isFilterBitmap = true
        }

        val rect = Rect(0, 0, size, size)
        val rectF = RectF(rect)

        // Рисуем круг
        canvas.drawOval(rectF, paint)

        // Устанавливаем режим наложения
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        // Центрируем изображение
        val left = (bitmap.width - size) / 2
        val top = (bitmap.height - size) / 2
        val srcRect = Rect(left, top, left + size, top + size)

        canvas.drawBitmap(bitmap, srcRect, rect, paint)

        return output
    }

    // Обновить уведомление фонового сервиса с кнопкой действия
    fun updateForegroundServiceNotification(title: String, content: String) {
        try {
            // Создаём Intent для открытия настроек конкретного канала уведомлений
            val settingsIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Используем ACTION_CHANNEL_NOTIFICATION_SETTINGS для открытия настроек конкретного канала
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, BACKGROUND_SERVICE_CHANNEL_ID)
                }
            } else {
                // Для старых версий Android открываем общие настройки приложения
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:${context.packageName}")
                }
            }

            val settingsPendingIntent = PendingIntent.getActivity(
                context,
                0,
                settingsIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val compactTitle = "$title активен" // "Komet активен"

            val expandedStyle = NotificationCompat.BigTextStyle()
                .bigText("Нажмите, чтобы отключить это уведомление")
                .setSummaryText(null)

            val builder = NotificationCompat.Builder(context, BACKGROUND_SERVICE_CHANNEL_ID)
                .setSmallIcon(R.drawable.notification_icon)
                .setContentTitle(compactTitle) // "Komet активен"
                .setStyle(expandedStyle)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true) // Уведомление нельзя смахнуть
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setShowWhen(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(settingsPendingIntent) // При нажатии на уведомление открываем настройки канала

            // Показываем уведомление
            NotificationManagerCompat.from(context).notify(
                BACKGROUND_SERVICE_NOTIFICATION_ID,
                builder.build()
            )

            android.util.Log.d("NotificationHelper", "Уведомление фонового сервиса обновлено с кнопкой действия")
        } catch (e: Exception) {
            android.util.Log.e("NotificationHelper", "Ошибка обновления уведомления фонового сервиса: ${e.message}")
            e.printStackTrace()
        }
    }
}
