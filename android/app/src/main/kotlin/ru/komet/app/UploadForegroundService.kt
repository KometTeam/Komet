package ru.komet.app

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class UploadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "komet_upload"
        const val NOTIFICATION_ID = 9001
        const val ACTION_START  = "ru.komet.app.UPLOAD_START"
        const val ACTION_UPDATE = "ru.komet.app.UPLOAD_UPDATE"
        const val ACTION_STOP   = "ru.komet.app.UPLOAD_STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_INDETERMINATE = "indeterminate"
    }

    private var inForeground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE -> {
                val notification = buildNotification(
                    title = intent.getStringExtra(EXTRA_TITLE)
                        ?: applicationInfo.loadLabel(packageManager).toString(),
                    body = intent.getStringExtra(EXTRA_BODY) ?: "",
                    progress = intent.getIntExtra(EXTRA_PROGRESS, 0),
                    indeterminate = intent.getBooleanExtra(EXTRA_INDETERMINATE, true),
                )
                if (inForeground) {
                    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                        .notify(NOTIFICATION_ID, notification)
                } else {
                    goForeground(notification)
                }
            }
            ACTION_STOP -> stopEverything()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopEverything()
        super.onTaskRemoved(rootIntent)
    }

    private fun goForeground(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            inForeground = true
        } catch (e: Exception) {
            Log.w("UploadService", "startForeground failed: ${e.message}")
        }
    }

    private fun stopEverything() {
        if (inForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.upload_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        body: String,
        progress: Int,
        indeterminate: Boolean,
    ): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setProgress(100, progress, indeterminate)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setDefaults(0)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_DEFERRED)
        }
        return builder.build()
    }
}
