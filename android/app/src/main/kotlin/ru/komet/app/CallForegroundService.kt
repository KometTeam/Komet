package ru.komet.app

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

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
        private const val DEFAULT_CALLER = "Звонок"
        private const val TAG = "KometFcm"

        @Volatile
        var screenShare = false

        @Volatile
        private var caller = DEFAULT_CALLER

        @Volatile
        private var running: CallForegroundService? = null

        private fun remember(name: String?) {
            if (!name.isNullOrBlank()) caller = name
        }

        fun setScreenShare(ctx: Context, enabled: Boolean, name: String?): Boolean {
            remember(name)
            screenShare = enabled
            val service = running
            if (service != null) {
                return service.startAsForeground()
            }
            val intent = Intent(ctx, CallForegroundService::class.java).apply {
                action = ACTION_SCREEN_SHARE
                putExtra(EXTRA_SCREEN_SHARE, enabled)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "screen share FGS update failed: ${e.message}")
                screenShare = false
                return !enabled
            }
            return true
        }

        fun start(ctx: Context, name: String?) {
            CallState.inCall = true
            remember(name)
            val service = running
            if (service != null) {
                service.startAsForeground()
                return
            }
            val intent = Intent(ctx, CallForegroundService::class.java).apply {
                action = ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "ongoing FGS start failed: ${e.message}")
            }
        }

        fun refreshTypes() {
            running?.updateTypes()
        }

        fun stop(ctx: Context) {
            CallState.inCall = false
            screenShare = false
            caller = DEFAULT_CALLER
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

    private var foreground = false
    private var activeTypes = 0

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
        foreground = false
        activeTypes = 0
        stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_SCREEN_SHARE) {
            screenShare = intent.getBooleanExtra(EXTRA_SCREEN_SHARE, false)
        }
        CallNotifier.ensureChannel(this)
        startAsForeground()
        return START_NOT_STICKY
    }

    private fun updateTypes() {
        if (!foreground || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        if (foregroundTypes().first() == activeTypes) return
        startAsForeground()
    }

    private fun micGranted(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun foregroundTypes(): List<Int> {
        val playback = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        val base = if (micGranted()) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else playback
        return buildList {
            if (screenShare) add(base or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            add(base)
            if (base != playback) add(playback)
        }
    }

    private fun startAsForeground(): Boolean {
        val immutable = android.app.PendingIntent.FLAG_UPDATE_CURRENT or
            android.app.PendingIntent.FLAG_IMMUTABLE
        val open = LaunchIntents.app(this).apply {
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

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return try {
                startForeground(ONGOING_ID, notif)
                foreground = true
                true
            } catch (e: Exception) {
                Log.w(TAG, "startForeground failed: ${e.message}")
                if (!foreground) stopSelf()
                false
            }
        }

        val wantedScreen = screenShare
        for (types in foregroundTypes()) {
            try {
                startForeground(ONGOING_ID, notif, types)
            } catch (e: Exception) {
                Log.w(TAG, "startForeground(types=$types) failed: ${e.message}")
                continue
            }
            foreground = true
            activeTypes = types
            val sharing = (types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION) != 0
            screenShare = sharing
            return sharing || !wantedScreen
        }
        screenShare = false
        if (!foreground) stopSelf()
        return false
    }
}
