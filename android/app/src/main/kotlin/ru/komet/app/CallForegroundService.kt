package ru.komet.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.ServiceCompat

object CallState {
    @Volatile
    var inCall = false
}

class CallForegroundService : Service() {

    companion object {
        const val ACTION_START = "ru.komet.app.CALL_ONGOING_START"
        const val ACTION_STOP = "ru.komet.app.CALL_ONGOING_STOP"
        const val ACTION_SCREEN_SHARE = "ru.komet.app.CALL_SCREEN_SHARE"
        const val EXTRA_SCREEN_SHARE = "screenShare"
        const val ONGOING_ID = 424243

        @Volatile
        var screenShare = false

        @Volatile
        private var running: CallForegroundService? = null

        fun setScreenShare(ctx: Context, enabled: Boolean, caller: String) {
            screenShare = enabled
            val intent = Intent(ctx, CallForegroundService::class.java).apply {
                action = ACTION_SCREEN_SHARE
                putExtra(CallConst.EXTRA_CALLER, caller)
                putExtra(EXTRA_SCREEN_SHARE, enabled)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            } catch (e: Exception) {
                Log.w("KometFcm", "screen share FGS update failed: ${e.message}")
            }
        }

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
            screenShare = false
            val service = running
            if (service != null) {
                service.shutdown()
                return
            }
            NotificationManagerCompat.from(ctx).cancel(ONGOING_ID)
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

    override fun onCreate() {
        super.onCreate()
        running = this
    }

    override fun onDestroy() {
        if (running === this) running = null
        CallState.inCall = false
        super.onDestroy()
    }

    private fun shutdown() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> shutdown()
            ACTION_SCREEN_SHARE -> {
                screenShare = intent.getBooleanExtra(EXTRA_SCREEN_SHARE, false)
                val caller = intent.getStringExtra(CallConst.EXTRA_CALLER) ?: "Звонок"
                CallNotifier.ensureChannel(this)
                startAsForeground(caller)
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
                var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                if (screenShare) {
                    types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                }
                startForeground(ONGOING_ID, notif, types)
            } else {
                startForeground(ONGOING_ID, notif)
            }
        } catch (e: Exception) {
            Log.w("KometFcm", "startForeground failed: ${e.message}")
            stopSelf()
        }
    }
}
