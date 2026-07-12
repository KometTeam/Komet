package ru.komet.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person

object CallState {
    @Volatile
    var inCall = false
}

class CallForegroundService : Service() {

    companion object {
        const val ACTION_START = "ru.komet.app.CALL_ONGOING_START"
        const val ACTION_STOP = "ru.komet.app.CALL_ONGOING_STOP"
        const val ONGOING_ID = 424243

        fun start(ctx: Context, caller: String) {
            CallState.inCall = true
            val intent = Intent(ctx, CallForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(CallConst.EXTRA_CALLER, caller)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            } catch (e: Exception) {
                Log.w("KometFcm", "ongoing FGS start failed: ${e.message}")
            }
        }

        fun stop(ctx: Context) {
            CallState.inCall = false
            try {
                ctx.startService(
                    Intent(ctx, CallForegroundService::class.java).apply {
                        action = ACTION_STOP
                    },
                )
            } catch (_: Exception) {
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        CallState.inCall = false
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                @Suppress("DEPRECATION")
                stopForeground(true)
                stopSelf()
            }
            else -> {
                val caller = intent?.getStringExtra(CallConst.EXTRA_CALLER) ?: "Звонок"
                CallNotifier.ensureChannel(this)
                startAsForeground(caller)
            }
        }
        return START_NOT_STICKY
    }

    private fun startAsForeground(caller: String) {
        val immutable = android.app.PendingIntent.FLAG_UPDATE_CURRENT or
            android.app.PendingIntent.FLAG_IMMUTABLE
        val open = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pi = android.app.PendingIntent.getActivity(this, 4, open, immutable)
        val hangup = android.app.PendingIntent.getBroadcast(
            this, 5,
            Intent(this, CallActionReceiver::class.java).apply {
                action = CallConst.ACTION_HANGUP
            },
            immutable,
        )
        val person = Person.Builder().setName(caller).build()
        val notif = NotificationCompat.Builder(this, CallConst.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(CallConst.ACCENT)
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pi)
            .setStyle(NotificationCompat.CallStyle.forOngoingCall(person, hangup))
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    ONGOING_ID, notif,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(ONGOING_ID, notif)
            }
        } catch (e: Exception) {
            Log.w("KometFcm", "startForeground(mic) failed: ${e.message}")
            stopSelf()
        }
    }
}
