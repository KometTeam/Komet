package ru.komet.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import org.json.JSONObject

object AppState {
    @Volatile
    var resumed = false
}

object CallEvents {
    @Volatile
    var sink: io.flutter.plugin.common.EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())

    fun emit(action: String) {
        val s = sink ?: return
        main.post {
            try {
                s.success(mapOf("action" to action))
            } catch (_: Exception) {
            }
        }
    }
}

object CallConst {
    const val CHANNEL_ID = "komet_calls"
    const val CHANNEL_NAME = "Звонки"
    const val NOTIF_ID = 424242
    const val ACCENT = 0xFF7C6BF0.toInt()

    const val EXTRA_CALL = "komet_call"
    const val EXTRA_ACTION = "komet_call_action"
    const val EXTRA_DECLINE_PAYLOAD = "komet_decline_payload"
    const val EXTRA_NOTIF_ID = "komet_notif_id"
    const val EXTRA_CALLER = "komet_caller"

    const val ACTION_RING = "ring"
    const val ACTION_ANSWER = "answer"
    const val ACTION_DECLINE = "ru.komet.app.CALL_DECLINE"
    const val ACTION_HANGUP = "ru.komet.app.CALL_HANGUP"

    const val FLN_RECEIVER =
        "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"
    const val FLN_ACTION_TAPPED =
        "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED"
}

object CallNotifier {

    fun showIncoming(ctx: Context, data: Map<String, String>) {
        if (AppState.resumed) {
            Log.d("KometFcm", "call push suppressed (app foreground)")
            return
        }
        val name = data["userName"] ?: data["title"] ?: "Неизвестный"
        val callerId = data["suid"] ?: data["callerId"] ?: ""
        val conversationId = data["conversationId"] ?: data["vcId"] ?: ""
        val vcp = data["vcp"] ?: ""
        val account = data["c"] ?: ""
        val callJson = JSONObject(data as Map<*, *>).toString()

        Log.d("KometFcm", "showIncoming caller=$callerId conv=$conversationId keys=${data.keys}")

        ensureChannel(ctx)

        val avatar = NotifAvatars.load(ctx, callerId, name)
        val person = Person.Builder()
            .setName(name)
            .setKey(callerId)
            .setIcon(IconCompat.createWithBitmap(avatar))
            .build()

        val fullScreen = launchIntent(ctx, callJson, CallConst.ACTION_RING, name, 1)
        val answer = launchIntent(ctx, callJson, CallConst.ACTION_ANSWER, name, 2)
        val decline = declineIntent(ctx, vcp, conversationId, account)

        val builder = NotificationCompat.Builder(ctx, CallConst.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(CallConst.ACCENT)
            .setColorized(true)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(fullScreen)
            .setFullScreenIntent(fullScreen, true)
            .setStyle(
                NotificationCompat.CallStyle.forIncomingCall(person, decline, answer)
                    .setIsVideo(isVideo(data)),
            )

        NotificationManagerCompat.from(ctx).notify(CallConst.NOTIF_ID, builder.build())
        CallRinger.start(ctx, conversationId)
    }

    fun finishCall(ctx: Context, data: Map<String, String>) {
        Log.d("KometFcm", "finishCall keys=${data.keys}")
        CallRinger.stop()
        NotificationManagerCompat.from(ctx).cancel(CallConst.NOTIF_ID)
        CallEvents.emit("ended")
    }

    private fun isVideo(data: Map<String, String>): Boolean {
        val t = data["type"] ?: data["callType"]
        if (t == "VIDEO") return true
        val iv = data["iv"]
        return iv == "true" || iv == "1"
    }

    private fun launchIntent(
        ctx: Context,
        callJson: String,
        action: String,
        caller: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(CallConst.EXTRA_CALL, callJson)
            putExtra(CallConst.EXTRA_ACTION, action)
            putExtra(CallConst.EXTRA_CALLER, caller)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(ctx, requestCode, intent, flags)
    }

    private fun declineIntent(
        ctx: Context,
        vcp: String,
        conversationId: String,
        account: String,
    ): PendingIntent {
        val payload = JSONObject()
            .put("vcp", vcp)
            .put("conversationId", conversationId)
            .put("c", account.toLongOrNull() ?: account)
            .toString()
        val intent = Intent(ctx, CallActionReceiver::class.java).apply {
            action = CallConst.ACTION_DECLINE
            putExtra(CallConst.EXTRA_DECLINE_PAYLOAD, payload)
            putExtra(CallConst.EXTRA_NOTIF_ID, CallConst.NOTIF_ID)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(ctx, 3, intent, flags)
    }

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CallConst.CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CallConst.CHANNEL_ID,
            CallConst.CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Входящие звонки"
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        mgr.createNotificationChannel(channel)
    }
}

object CallRinger {
    private val handler = Handler(Looper.getMainLooper())
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var timeout: Runnable? = null

    @Volatile
    var activeConversationId: String? = null
        private set

    fun start(ctx: Context, conversationId: String) {
        stop()
        activeConversationId = conversationId

        val power = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "komet:call").apply {
            setReferenceCounted(false)
            acquire(60_000L)
        }

        val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val mode = audio.ringerMode
        if (mode == AudioManager.RINGER_MODE_NORMAL) {
            playRingtone(ctx)
            vibrate(ctx)
        } else if (mode == AudioManager.RINGER_MODE_VIBRATE) {
            vibrate(ctx)
        }

        val t = Runnable { onTimeout(ctx) }
        timeout = t
        handler.postDelayed(t, 45_000L)
    }

    fun stop() {
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        try {
            ringtone?.stop()
        } catch (_: Exception) {
        }
        ringtone = null
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        wakeLock = null
        activeConversationId = null
    }

    private fun onTimeout(ctx: Context) {
        stop()
        NotificationManagerCompat.from(ctx).cancel(CallConst.NOTIF_ID)
    }

    private fun playRingtone(ctx: Context) {
        try {
            val uri = RingtoneManager.getActualDefaultRingtoneUri(
                ctx, RingtoneManager.TYPE_RINGTONE,
            ) ?: RingtoneManager.getActualDefaultRingtoneUri(
                ctx, RingtoneManager.TYPE_NOTIFICATION,
            ) ?: return
            val rt = RingtoneManager.getRingtone(ctx, uri) ?: return
            rt.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                rt.isLooping = true
            }
            rt.play()
            ringtone = rt
        } catch (e: Exception) {
            Log.w("KometFcm", "ringtone failed: ${e.message}")
        }
    }

    private fun vibrate(ctx: Context) {
        try {
            val vib = ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (!vib.hasVibrator()) return
            val pattern = longArrayOf(0, 1000, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(pattern, 0)
            }
            vibrator = vib
        } catch (e: Exception) {
            Log.w("KometFcm", "vibrate failed: ${e.message}")
        }
    }
}

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == CallConst.ACTION_HANGUP) {
            CallEvents.emit("hangup")
            return
        }
        if (intent.action != CallConst.ACTION_DECLINE) return
        CallRinger.stop()
        val notifId = intent.getIntExtra(CallConst.EXTRA_NOTIF_ID, CallConst.NOTIF_ID)
        NotificationManagerCompat.from(ctx).cancel(notifId)

        val payload = intent.getStringExtra(CallConst.EXTRA_DECLINE_PAYLOAD) ?: return
        val fln = Intent(CallConst.FLN_ACTION_TAPPED).apply {
            setClassName(ctx, CallConst.FLN_RECEIVER)
            putExtra("notificationId", notifId)
            putExtra("actionId", "call_decline")
            putExtra("payload", payload)
            putExtra("cancelNotification", true)
        }
        try {
            ctx.sendBroadcast(fln)
        } catch (e: Exception) {
            Log.w("KometFcm", "decline broadcast failed: ${e.message}")
        }
    }
}
