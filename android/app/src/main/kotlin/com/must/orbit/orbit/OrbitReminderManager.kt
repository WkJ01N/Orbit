package com.must.orbit.orbit

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

data class OrbitReminderScheduleResult(
    val scheduled: Boolean,
    val usedInexactFallback: Boolean = false,
)

object OrbitReminderManager {
    const val channelId = "orbit_course_reminders"
    const val payloadExtra = "orbit_notification_payload"
    const val alarmIdExtra = "orbit_alarm_id"

    private const val classLeadAlarmBase = 1
    private const val checkInAlarmLimit = 1_000_000
    private const val nextDaySummaryAlarmBase = 1_000_000
    private const val nextDaySummaryAlarmLimit = nextDaySummaryAlarmBase + 30
    private const val maintenanceRequestCode = 2_100_000
    private const val maintenanceIntervalMillis = 6L * 60L * 60L * 1000L
    private const val retryRetentionMillis = 24L * 60L * 60L * 1000L

    private fun deliveryPending(record: OrbitReminderRecord): Boolean =
        org.json.JSONObject(record.metadata).optBoolean("deliveryPending")

    fun schedule(
        context: Context,
        record: OrbitReminderRecord,
        exactPreferred: Boolean,
        allowInexactFallback: Boolean,
    ): OrbitReminderScheduleResult {
        OrbitReminderDiagnostics.event(context, "schedule", record.alarmId)
        if (record.fireAtMillis <= System.currentTimeMillis()) {
            OrbitReminderStore.remove(context, record.alarmId)
            return OrbitReminderScheduleResult(scheduled = false)
        }

        cancelAlarmOnly(context, record.alarmId)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val operation = reminderPendingIntent(
            context,
            record.alarmId,
            PendingIntent.FLAG_UPDATE_CURRENT,
        ) ?: return OrbitReminderScheduleResult(scheduled = false)
        OrbitReminderStore.upsert(context, record)

        if (exactPreferred && canScheduleExact(alarmManager)) {
            try {
                val showIntent = contentPendingIntent(context, record)
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(record.fireAtMillis, showIntent),
                    operation,
                )
                OrbitReminderDiagnostics.event(context, "schedule_exact", record.alarmId)
                OrbitReminderKeepAliveService.reconcile(context)
                return OrbitReminderScheduleResult(scheduled = true)
            } catch (error: SecurityException) {
                OrbitReminderDiagnostics.event(context, "schedule_exact_rejected", record.alarmId, error.javaClass.simpleName)
                // Continue to the explicit inexact fallback below.
            } catch (error: RuntimeException) {
                OrbitReminderDiagnostics.event(context, "schedule_exact_rejected", record.alarmId, error.javaClass.simpleName)
                // OEM AlarmManager implementations can reject an exact alarm.
            }
        }

        if (!allowInexactFallback) {
            OrbitReminderStore.remove(context, record.alarmId)
            OrbitReminderDiagnostics.event(context, "schedule_rejected", record.alarmId, "exact_unavailable")
            OrbitReminderStore.updateMetadata(context, mapOf("schedule_failure" to "schedule:exact_unavailable"))
            return OrbitReminderScheduleResult(scheduled = false)
        }

        return try {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                record.fireAtMillis,
                operation,
            )
            OrbitReminderDiagnostics.event(context, "schedule_inexact", record.alarmId)
            OrbitReminderKeepAliveService.reconcile(context)
            OrbitReminderScheduleResult(
                scheduled = true,
                usedInexactFallback = true,
            )
        } catch (error: RuntimeException) {
            OrbitReminderDiagnostics.failure(context, "schedule_inexact", record.alarmId, error)
            OrbitReminderStore.remove(context, record.alarmId)
            OrbitReminderScheduleResult(scheduled = false)
        }
    }

    fun cancel(context: Context, alarmId: Int) {
        OrbitReminderDiagnostics.event(context, "cancel", alarmId)
        cancelAlarmOnly(context, alarmId)
        OrbitReminderStore.remove(context, alarmId)
        OrbitReminderKeepAliveService.reconcile(context)
    }

    fun cancelCourseReminders(context: Context) {
        OrbitReminderDiagnostics.event(context, "cancel_course_reminders")
        val records = OrbitReminderStore.removeWhere(context, ::isCourseReminder)
        records.forEach { cancelAlarmOnly(context, it.alarmId) }
        OrbitReminderKeepAliveService.reconcile(context)
    }

    fun pendingCourseReminderCount(context: Context): Int {
        pruneExpired(context)
        return OrbitReminderStore.load(context).values.count(::isCourseReminder)
    }

    fun contains(context: Context, alarmId: Int): Boolean {
        pruneExpired(context)
        return OrbitReminderStore.get(context, alarmId) != null &&
            reminderPendingIntent(context, alarmId, PendingIntent.FLAG_NO_CREATE) != null
    }

    fun buildNotification(context: Context, record: OrbitReminderRecord): Notification? {
        if(!notificationsAllowed(context))return null
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    record.channelName,
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = record.channelDescription
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(record.title)
            .setContentText(record.body)
            .setContentIntent(contentPendingIntent(context, record))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOnlyAlertOnce(!org.json.JSONObject(record.metadata).optBoolean("fallback"))
            .setPriority(Notification.PRIORITY_MAX)
        record.bigText?.let { builder.setStyle(Notification.BigTextStyle().bigText(it)) }
        val meta = org.json.JSONObject(record.metadata)
        if (Build.VERSION.SDK_INT >= 26 && meta.optJSONObject("strong")?.optBoolean("enabled") == true)
            builder.setGroup("orbit_strong").setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
        val rule = meta.optString("ruleId")
        if(rule.isNotEmpty() && rule!="null") builder.setStyle(Notification.BigTextStyle().bigText(record.body))
        fun action(name: String, label: String) {
            val intent = Intent(context, OrbitReminderActionReceiver::class.java).setAction(name)
                .putExtra("rule", rule).putExtra("session", meta.optString("sessionId"))
            intent.data = android.net.Uri.parse("orbit://reminder/${record.notificationId}/$name")
            val pending = PendingIntent.getBroadcast(context, record.notificationId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(Notification.Action.Builder(null, label, pending).build())
        }
        val acknowledge = meta.optString("acknowledgeLabel")
        if (rule.isNotEmpty() && rule != "null" && acknowledge.isNotEmpty()) action("ack", acknowledge)
        if (meta.optJSONObject("strong")?.optBoolean("enabled") == true) action("stop", meta.optString("stopLabel", "Stop"))
        return builder.build()
    }

    fun postNotification(context: Context, record: OrbitReminderRecord): Boolean {
        val notification = buildNotification(context, record) ?: run {
            OrbitReminderDiagnostics.event(context, "post_blocked", record.alarmId, "notifications_disabled")
            return false
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(record.notificationId, notification)
        OrbitReminderDiagnostics.event(context, "post", record.alarmId)
        if (org.json.JSONObject(record.metadata).optJSONObject("strong")?.optBoolean("enabled") == true)
            return OrbitStrongReminderService.start(context, record)
        return true
    }
    fun notificationsAllowed(context: Context): Boolean {
        if(Build.VERSION.SDK_INT>=33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return false
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if(!manager.areNotificationsEnabled())return false
        return Build.VERSION.SDK_INT<26 || manager.getNotificationChannel(channelId)?.importance!=NotificationManager.IMPORTANCE_NONE
    }
    fun postNormalFallback(context: Context,record: OrbitReminderRecord): Boolean {
        OrbitReminderDiagnostics.event(context, "strong_fallback", record.alarmId)
        return postNotification(context, fallbackRecord(record))
    }

    private fun fallbackRecord(record: OrbitReminderRecord): OrbitReminderRecord {
        val meta = org.json.JSONObject(record.metadata)
        meta.optJSONObject("strong")?.put("enabled",false)
        meta.put("fallback",true)
        return record.copy(metadata = meta.toString())
    }

    /** The original post may already be committed when the service fails asynchronously. */
    internal fun recoverNormalFallback(context: Context, record: OrbitReminderRecord) {
        try {
            if (postNormalFallback(context, record)) return
        } catch (error: Exception) {
            OrbitReminderDiagnostics.failure(context, "strong_fallback", record.alarmId, error)
        }
        deferDelivery(context, fallbackRecord(record))
    }

    /** Persist before retrying; permission denial waits for maintenance/foreground recovery. */
    internal fun deferDelivery(context: Context, record: OrbitReminderRecord) {
        val now = System.currentTimeMillis()
        val meta = org.json.JSONObject(record.metadata)
        val since = meta.optLong("deliveryPendingSince", now)
        if (now - since > retryRetentionMillis) {
            OrbitReminderStore.remove(context, record.alarmId)
            OrbitReminderDiagnostics.event(context, "retry_expired", record.alarmId)
            return
        }
        val attempt = meta.optInt("deliveryAttempt", 0).coerceIn(0, 4)
        meta.put("deliveryPending", true).put("deliveryPendingSince", since)
            .put("deliveryAttempt", attempt + 1)
        val retry = record.copy(fireAtMillis = now + (60_000L shl attempt), metadata = meta.toString())
        OrbitReminderStore.upsert(context, retry)
        if (notificationsAllowed(context)) {
            if (!schedule(context, retry, true, true).scheduled) OrbitReminderStore.upsert(context, retry)
        }
        OrbitReminderDiagnostics.event(context, "delivery_deferred", record.alarmId)
    }

    fun restorePersistedReminders(context: Context) {
        val now = System.currentTimeMillis()
        val records = OrbitReminderStore.load(context).values.toList()
        records.forEach { record ->
            try {
                when {
                    !record.restoreOnReboot -> cancel(context, record.alarmId)
                    deliveryPending(record) -> {
                        val since = org.json.JSONObject(record.metadata).optLong("deliveryPendingSince", now)
                        if (now - since > retryRetentionMillis) cancel(context, record.alarmId)
                        else if (notificationsAllowed(context)) {
                            val retry = record.copy(fireAtMillis = maxOf(now + 1000L, record.fireAtMillis))
                            if (!schedule(context, retry, true, true).scheduled) OrbitReminderStore.upsert(context, retry)
                        }
                    }
                    record.alarmId >= 3_000_000 -> cancel(context,record.alarmId)
                    record.fireAtMillis <= now -> OrbitReminderStore.remove(context, record.alarmId)
                    else -> schedule(
                        context,
                        rebaseRecord(record),
                        exactPreferred = true,
                        allowInexactFallback = true,
                    )
                }
            } catch (error: Exception) {
                OrbitReminderDiagnostics.failure(context, "restore_record", record.alarmId, error)
            }
        }
        ensureMaintenanceAlarm(context)
        OrbitReminderLedger.replenish(context)
        OrbitReminderKeepAliveService.reconcile(context)
    }
    private fun rebaseRecord(record: OrbitReminderRecord): OrbitReminderRecord {
        val time=org.json.JSONObject(record.metadata).optString("fireAt")
        if(time.isEmpty())return record
        val millis=try {java.time.OffsetDateTime.parse(time).toInstant().toEpochMilli()}
            catch(_: Exception){java.time.LocalDateTime.parse(time).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()}
        return record.copy(fireAtMillis=millis)
    }

    fun ensureMaintenanceAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, OrbitReminderMaintenanceReceiver::class.java).apply {
            action = "${context.packageName}.REMINDER_MAINTENANCE"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            maintenanceRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            android.os.SystemClock.elapsedRealtime() + maintenanceIntervalMillis,
            maintenanceIntervalMillis,
            pendingIntent,
        )
    }

    private fun canScheduleExact(alarmManager: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    private fun cancelAlarmOnly(context: Context, alarmId: Int) {
        val pendingIntent = reminderPendingIntent(context, alarmId, PendingIntent.FLAG_NO_CREATE)
        if (pendingIntent != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun reminderPendingIntent(
        context: Context,
        alarmId: Int,
        behaviorFlag: Int,
    ): PendingIntent? {
        val intent = Intent(context, OrbitReminderReceiver::class.java).apply {
            action = "${context.packageName}.REMINDER.$alarmId"
            putExtra(alarmIdExtra, alarmId)
        }
        return PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            behaviorFlag or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun contentPendingIntent(
        context: Context,
        record: OrbitReminderRecord,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "${context.packageName}.OPEN_REMINDER.${record.notificationId}"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(payloadExtra, record.payload)
        }
        return PendingIntent.getActivity(
            context,
            record.notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pruneExpired(context: Context) {
        val now = System.currentTimeMillis()
        OrbitReminderStore.removeWhere(context) { it.fireAtMillis <= now && !deliveryPending(it) }
    }

    private fun isCourseReminder(record: OrbitReminderRecord): Boolean =
        (record.alarmId >= classLeadAlarmBase && record.alarmId < checkInAlarmLimit) ||
            (record.alarmId >= nextDaySummaryAlarmBase &&
                record.alarmId < nextDaySummaryAlarmLimit) || record.alarmId >= 3_000_000
}
