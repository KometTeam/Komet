package ru.komet.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

object FkmState {
    private const val PREFS = "komet_fkm"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_DELIVERED = "delivered"

    @Volatile
    var enabled = false
        private set

    @Volatile
    var connected = false

    @Volatile
    var delivered = 0
        private set

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun restore(ctx: Context) {
        val p = prefs(ctx)
        enabled = p.getBoolean(KEY_ENABLED, false)
        delivered = p.getInt(KEY_DELIVERED, 0)
    }

    fun applyEnabled(ctx: Context, value: Boolean) {
        enabled = value
        // Счётчик обнуляем только на выключении, чтобы перезапуск приложения
        // не сбрасывал накопленное.
        if (!value) {
            delivered = 0
            connected = false
        }
        prefs(ctx).edit()
            .putBoolean(KEY_ENABLED, value)
            .putInt(KEY_DELIVERED, delivered)
            .apply()
    }

    fun countDelivered(ctx: Context) {
        delivered += 1
        prefs(ctx).edit().putInt(KEY_DELIVERED, delivered).apply()
    }
}

object FkmNotification {
    const val CHANNEL_ID = "komet_fkm"
    const val NOTIFICATION_ID = 424244

    fun build(ctx: Context): Notification {
        ensureChannel(ctx)

        val status = if (FkmState.connected) {
            ctx.getString(R.string.fkm_status_active)
        } else {
            ctx.getString(R.string.fkm_status_inactive)
        }
        val title = ctx.getString(R.string.fkm_title)
        val text = ctx.getString(R.string.fkm_status_line, status, FkmState.delivered)

        val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(
            ctx,
            0,
            Intent(ctx, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            immutable,
        )
        val disable = PendingIntent.getBroadcast(
            ctx,
            1,
            Intent(ctx, FkmDisableReceiver::class.java).apply {
                action = FkmDisableReceiver.ACTION_DISABLE
            },
            immutable,
        )

        return NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(CallConst.ACCENT)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText("$text\n\n${ctx.getString(R.string.fkm_explain)}"),
            )
            .setContentIntent(open)
            .addAction(0, ctx.getString(R.string.fkm_disable), disable)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = manager(ctx)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                ctx.getString(R.string.fkm_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = ctx.getString(R.string.fkm_channel_description)
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
            },
        )
    }

    fun manager(ctx: Context): NotificationManager =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}

class FkmService : Service() {

    companion object {
        fun start(ctx: Context) {
            val intent = Intent(ctx, FkmService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            } catch (e: Exception) {
                Log.w("Fkm", "service start failed: ${e.message}")
            }
        }

        // Перерисовка уже висящего уведомления, без перезапуска сервиса.
        fun refresh(ctx: Context) {
            if (!FkmState.enabled) return
            try {
                FkmNotification.manager(ctx)
                    .notify(FkmNotification.NOTIFICATION_ID, FkmNotification.build(ctx))
            } catch (e: Exception) {
                Log.w("Fkm", "notification refresh failed: ${e.message}")
            }
        }

        fun stop(ctx: Context) {
            try {
                ctx.stopService(Intent(ctx, FkmService::class.java))
            } catch (e: Exception) {
                Log.w("Fkm", "service stop failed: ${e.message}")
            }
        }
    }

    private var inForeground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        FkmState.restore(applicationContext)
        FkmNotification.ensureChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!FkmState.enabled) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
            stopSelf()
            return START_NOT_STICKY
        }
        goForeground()
        return START_STICKY
    }

    override fun onDestroy() {
        if (inForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        super.onDestroy()
    }

    private fun goForeground() {
        val notification = FkmNotification.build(this)
        if (inForeground) {
            FkmNotification.manager(this)
                .notify(FkmNotification.NOTIFICATION_ID, notification)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    FkmNotification.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(FkmNotification.NOTIFICATION_ID, notification)
            }
            inForeground = true
        } catch (e: Exception) {
            Log.w("Fkm", "startForeground failed: ${e.message}")
            stopSelf()
        }
    }
}

class FkmDisableReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISABLE = "ru.komet.app.FKM_DISABLE"
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action != ACTION_DISABLE) return
        val app = ctx.applicationContext
        FkmState.applyEnabled(app, false)
        FkmService.stop(app)
        FkmChannel.notifyDisabled()
    }
}

class FkmBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val app = ctx.applicationContext
        FkmState.restore(app)
        if (!FkmState.enabled) return
        // Движка после ребута нет — уведомление честно скажет «не активно»,
        // пока приложение не откроют.
        FkmState.connected = false
        FkmService.start(app)
    }
}
