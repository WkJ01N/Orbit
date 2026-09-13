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

    fun schedule(
        context: Context,
        record: OrbitReminderRecord,
        exactPreferred: Boolean,
        allowInexactFallback: Boolean,
    ): OrbitReminderScheduleResult {
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
                return OrbitReminderScheduleResult(scheduled = true)
            } catch (_: SecurityException) {
                // Continue to the explicit inexact fallback below.
            } catch (_: RuntimeException) {
                // OEM AlarmManager implementations can reject an exact alarm.
            }
        }

        if (!allowInexactFallback) {
            OrbitReminderStore.remove(context, record.alarmId)
            return OrbitReminderScheduleResult(scheduled = false)
        }

        return try {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                record.fireAtMillis,
                operation,
            )
            OrbitReminderScheduleResult(
                scheduled = true,
                usedInexactFallback = true,
            )
        } catch (_: RuntimeException) {
            OrbitReminderStore.remove(context, record.alarmId)
            OrbitReminderScheduleResult(scheduled = false)
        }
    }

    fun cancel(context: Context, alarmId: Int) {
        cancelAlarmOnly(context, alarmId)
        OrbitReminderStore.remove(context, alarmId)
    }

    fun cancelCourseReminders(context: Context) {
        val records = OrbitReminderStore.removeWhere(context, ::isCourseReminder)
        records.forEach { cancelAlarmOnly(context, it.alarmId) }
    }

    fun pendingCourseReminderCount(context: Context): Int {
        pruneExpired(context)
        return OrbitReminderStore.load(context).values.count(::isCourseReminder)
    }

    fun contains(context: Context, alarmId: Int): Boolean {
        pruneExpired(context)
        return OrbitReminderStore.get(context, alarmId) != null
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

    fun postNotification(context: Context, record: OrbitReminderRecord) {
        val notification = buildNotification(context, record) ?: return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(record.notificationId, notification)
        if (org.json.JSONObject(record.metadata).optJSONObject("strong")?.optBoolean("enabled") == true)
            OrbitStrongReminderService.start(context, record)
    }
    fun notificationsAllowed(context: Context): Boolean {
        if(Build.VERSION.SDK_INT>=33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return false
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if(!manager.areNotificationsEnabled())return false
        return Build.VERSION.SDK_INT<26 || manager.getNotificationChannel(channelId)?.importance!=NotificationManager.IMPORTANCE_NONE
    }
    fun postNormalFallback(context: Context,record: OrbitReminderRecord) {
        val meta = org.json.JSONObject(record.metadata)
        meta.optJSONObject("strong")?.put("enabled",false)
        meta.put("fallback",true)
        postNotification(context,record.copy(metadata=meta.toString()))
    }

    fun restorePersistedReminders(context: Context) {
        val now = System.currentTimeMillis()
        val records = OrbitReminderStore.load(context).values.toList()
        records.forEach { record ->
            when {
                record.alarmId >= 3_000_000 -> cancel(context,record.alarmId)
                record.fireAtMillis <= now -> OrbitReminderStore.remove(context, record.alarmId)
                !record.restoreOnReboot -> {
                    cancelAlarmOnly(context, record.alarmId)
                    OrbitReminderStore.remove(context, record.alarmId)
                }
                else -> schedule(
                    context,
                    rebaseRecord(record),
                    exactPreferred = true,
                    allowInexactFallback = true,
                )
            }
        }
        ensureMaintenanceAlarm(context)
        OrbitReminderLedger.replenish(context)
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
        OrbitReminderStore.removeWhere(context) { it.fireAtMillis <= now }
    }

    private fun isCourseReminder(record: OrbitReminderRecord): Boolean =
        (record.alarmId >= classLeadAlarmBase && record.alarmId < checkInAlarmLimit) ||
            (record.alarmId >= nextDaySummaryAlarmBase &&
                record.alarmId < nextDaySummaryAlarmLimit) || record.alarmId >= 3_000_000
}
