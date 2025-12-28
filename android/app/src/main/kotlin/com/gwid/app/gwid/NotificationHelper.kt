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
        const val CHANNEL_ID = "chat_messages_native"
        const val CHANNEL_NAME = "Сообщения чатов"
        const val CHANNEL_DESC = "Уведомления о новых сообщениях"
        
        // Хранилище сообщений для каждого чата (chatId -> список сообщений)
        private val chatMessages = mutableMapOf<Long, MutableList<MessageData>>()
        // Хранилище Person для каждого отправителя (senderKey -> Person)
        private val personCache = mutableMapOf<String, Person>()
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESC
                enableVibration(true)
                setShowBadge(true)
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
        groupTitle: String?
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

        // Создаём MessagingStyle с накопленными сообщениями
        val messagingStyle = NotificationCompat.MessagingStyle(person)
            .setConversationTitle(if (isGroupChat) groupTitle else senderName)
            .setGroupConversation(isGroupChat)
        
        // Добавляем все накопленные сообщения
        for (msg in messages) {
            // Получаем Person для этого отправителя (может быть разные отправители в группе)
            val msgPerson = personCache[msg.senderKey] ?: person
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

        // Строим уведомление
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(messagingStyle)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setShortcutId(shortcutId)

        // Добавляем largeIcon (показывается в свёрнутом виде)
        if (avatarBitmap != null) {
            builder.setLargeIcon(avatarBitmap)
        }

        // Показываем уведомление
        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        } catch (e: SecurityException) {
            // Нет разрешения на уведомления
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
}
