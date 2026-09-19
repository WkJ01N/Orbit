package com.must.orbit.orbit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class OrbitReminderKeepAliveService : Service() {
    override fun onCreate() {
        super.onCreate()
        OrbitReminderDiagnostics.attach(this)
        startForeground(notificationId, notification())
        OrbitReminderDiagnostics.event(this, "guard_started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isEnabled(this) || !hasFutureReminders(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        OrbitReminderDiagnostics.event(this, "guard_stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(): Notification {
        val config = OrbitReminderStore.metadata(this)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    config["guard_channel"] ?: "Reminder reliability",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = config["guard_body"] ?: "Keeps scheduled course reminders reliable."
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                },
            )
        }
        val disableIntent = Intent(this, OrbitReminderActionReceiver::class.java).apply {
            action = disableAction
        }
        val disable = PendingIntent.getBroadcast(
            this,
            notificationId,
            disableIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(config["guard_title"] ?: "Enhanced reminders enabled")
            .setContentText(config["guard_body"] ?: "Orbit is protecting future reminders.")
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    notificationId,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_LOW)
            .addAction(
                Notification.Action.Builder(
                    null,
                    config["guard_disable"] ?: "Turn off",
                    disable,
                ).build(),
            )
            .build()
    }

    companion object {
        const val disableAction = "com.must.orbit.orbit.DISABLE_REMINDER_GUARD"
        private const val channelId = "orbit_reminder_guard"
        private const val notificationId = 2_200_001

        fun isEnabled(context: Context): Boolean =
            OrbitReminderStore.metadata(context)["enhanced_reminder_mode"] == "true"

        fun setEnabled(
            context: Context,
            enabled: Boolean,
            labels: Map<String, String?> = emptyMap(),
        ) {
            OrbitReminderStore.updateMetadata(
                context,
                mapOf(
                    "enhanced_reminder_mode" to enabled.toString(),
                    "guard_channel" to labels["channel"],
                    "guard_title" to labels["title"],
                    "guard_body" to labels["body"],
                    "guard_disable" to labels["disable"],
                ).filterValues { it != null },
            )
            OrbitReminderDiagnostics.event(context, "guard_setting", reason = enabled.toString())
            reconcile(context)
        }

        fun reconcile(context: Context) {
            val shouldRun = isEnabled(context) && hasFutureReminders(context)
            val intent = Intent(context, OrbitReminderKeepAliveService::class.java)
            try {
                if (shouldRun) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                } else {
                    context.stopService(intent)
                    (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                        .cancel(notificationId)
                }
            } catch (error: Exception) {
                OrbitReminderDiagnostics.failure(context, "guard_reconcile", error = error)
            }
        }

        private fun hasFutureReminders(context: Context): Boolean {
            val now = System.currentTimeMillis()
            return OrbitReminderStore.load(context).values.any { it.fireAtMillis > now }
        }
    }
}
