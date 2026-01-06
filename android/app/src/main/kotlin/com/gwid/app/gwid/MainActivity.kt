package com.gwid.app.gwid

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gwid.app/notifications"
    private lateinit var notificationHelper: NotificationHelper
    private var methodChannel: MethodChannel? = null
    
    // Сохраняем payload для передачи во Flutter после инициализации
    private var pendingNotificationPayload: String? = null
    private var pendingChatId: Long? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        notificationHelper = NotificationHelper(this)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { channel ->
            // Register MethodChannel in NotificationReplyReceiver for handling inline reply
            NotificationReplyReceiver.setMethodChannel(channel)
            
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "showMessageNotification" -> {
                        // chatId может быть Long (большие отрицательные числа для групп)
                        val chatIdLong = call.argument<Number>("chatId")?.toLong() ?: 0L
                        val senderName = call.argument<String>("senderName") ?: "Unknown"
                        val messageText = call.argument<String>("messageText") ?: ""
                        val avatarPath = call.argument<String>("avatarPath")
                        val isGroupChat = call.argument<Boolean>("isGroupChat") ?: false
                        val groupTitle = call.argument<String>("groupTitle")
                        val enableVibration = call.argument<Boolean>("enableVibration") ?: true
                        val vibrationPattern = call.argument<List<Int>>("vibrationPattern")
                            ?.map { it.toLong() }
                        val canReply = call.argument<Boolean>("canReply") ?: true
                        val myName = call.argument<String>("myName")

                        notificationHelper.showMessageNotification(
                            chatId = chatIdLong,
                            senderName = senderName,
                            messageText = messageText,
                            avatarPath = avatarPath,
                            isGroupChat = isGroupChat,
                            groupTitle = groupTitle,
                            enableVibration = enableVibration,
                            vibrationPattern = vibrationPattern,
                            canReply = canReply,
                            myName = myName
                        )
                        result.success(true)
                    }
                    "clearNotificationMessages" -> {
                        // Очистить накопленные сообщения для чата (при открытии чата)
                        val chatIdLong = call.argument<Number>("chatId")?.toLong() ?: 0L
                        notificationHelper.clearMessagesForChat(chatIdLong)
                        result.success(true)
                    }
                    "cancelNotification" -> {
                        // Отменить уведомление для чата
                        val chatIdLong = call.argument<Number>("chatId")?.toLong() ?: 0L
                        notificationHelper.cancelNotification(chatIdLong)
                        result.success(true)
                    }
                    "getPendingNotification" -> {
                        // Вернуть сохранённый payload от уведомления
                        val payload = pendingNotificationPayload
                        val chatId = pendingChatId
                        // Очищаем после получения
                        pendingNotificationPayload = null
                        pendingChatId = null
                        
                        if (payload != null && chatId != null) {
                            result.success(mapOf(
                                "payload" to payload,
                                "chatId" to chatId
                            ))
                        } else {
                            result.success(null)
                        }
                    }
                    "updateForegroundServiceNotification" -> {
                        // Обновить уведомление фонового сервиса с кнопкой действия
                        val title = call.argument<String>("title") ?: "Komet"
                        val content = call.argument<String>("content") ?: ""
                        notificationHelper.updateForegroundServiceNotification(title, content)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        
        // Обрабатываем intent при запуске
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Важно: сохраняем новый intent
        android.util.Log.d("MainActivity", "onNewIntent вызван")
        // Обрабатываем intent когда приложение уже открыто
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        android.util.Log.d("MainActivity", "handleIntent вызван, intent: $intent")
        intent?.let {
            android.util.Log.d("MainActivity", "Intent extras: ${it.extras}")
            android.util.Log.d("MainActivity", "Intent action: ${it.action}")
            
            // Обработка inline reply
            if (it.action == "com.gwid.app.REPLY_ACTION") {
                android.util.Log.d("MainActivity", "Обработка inline reply")
                val remoteInput = androidx.core.app.RemoteInput.getResultsFromIntent(it)
                if (remoteInput != null) {
                    val replyText = remoteInput.getCharSequence("key_text_reply")?.toString()
                    val chatId = it.getLongExtra("chat_id", 0L)
                    
                    android.util.Log.d("MainActivity", "Reply text: $replyText, chatId: $chatId")
                    
                    if (replyText != null && replyText.isNotEmpty() && chatId != 0L) {
                        // Отправляем сообщение во Flutter
                        methodChannel?.let { channel ->
                            channel.invokeMethod("sendReplyFromNotification", mapOf(
                                "chatId" to chatId,
                                "text" to replyText
                            ))
                            android.util.Log.d("MainActivity", "Отправлен reply во Flutter")
                        }
                    }
                }
                return
            }
            
            val payload = it.getStringExtra("payload")
            val chatId = it.getLongExtra("chat_id", 0L)
            
            android.util.Log.d("MainActivity", "Extracted: payload=$payload, chatId=$chatId")
            
            if (payload != null && chatId != 0L) {
                android.util.Log.d("MainActivity", "Получен payload из уведомления: $payload, chatId: $chatId")
                
                // Сохраняем для случая если Flutter ещё не готов
                pendingNotificationPayload = payload
                pendingChatId = chatId
                
                // Если channel уже инициализирован, сразу отправляем во Flutter
                methodChannel?.let { channel ->
                    android.util.Log.d("MainActivity", "Отправляем onNotificationTap во Flutter")
                    channel.invokeMethod("onNotificationTap", mapOf(
                        "payload" to payload,
                        "chatId" to chatId
                    ))
                } ?: android.util.Log.d("MainActivity", "methodChannel ещё не инициализирован")
            } else {
                android.util.Log.d("MainActivity", "payload или chatId не найдены в intent")
            }
        }
    }
}

