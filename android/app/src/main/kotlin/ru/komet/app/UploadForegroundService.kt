package ru.komet.app

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class UploadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "komet_upload"
        const val NOTIFICATION_ID = 9001
        const val ACTION_START  = "ru.komet.app.UPLOAD_START"
        const val ACTION_UPDATE = "ru.komet.app.UPLOAD_UPDATE"
        const val ACTION_STOP   = "ru.komet.app.UPLOAD_STOP"
        const val EXTRA_FILENAME = "filename"
        const val EXTRA_PROGRESS = "progress"   // 0-100
        const val EXTRA_SPEED    = "speed"      // bytes/sec (Long)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val filename = intent.getStringExtra(EXTRA_FILENAME) ?: "Файл"
                val notification = buildNotification(filename, 0, 0, indeterminate = true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
            ACTION_UPDATE -> {
                val filename = intent.getStringExtra(EXTRA_FILENAME) ?: "Файл"
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val speed    = intent.getLongExtra(EXTRA_SPEED, 0L)
                val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, buildNotification(filename, progress, speed))
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Загрузка файлов",
                NotificationManager.IMPORTANCE_LOW
            ).apply { setShowBadge(false) }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(
        filename: String,
        progress: Int,
        speedBps: Long,
        indeterminate: Boolean = false
    ): Notification {
        val body = when {
            indeterminate       -> "Подготовка..."
            speedBps > 0        -> "$progress% · ${formatSpeed(speedBps)}"
            else                -> "$progress%"
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle(filename)
            .setContentText(body)
            .setProgress(100, progress, indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .build()
    }

    private fun formatSpeed(bps: Long): String = when {
        bps < 1_024L             -> "$bps Б/с"
        bps < 1_048_576L         -> "${bps / 1024} КБ/с"
        else                     -> "${"%.1f".format(bps / 1_048_576.0)} МБ/с"
    }
}
