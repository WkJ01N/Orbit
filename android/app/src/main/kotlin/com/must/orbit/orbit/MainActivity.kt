package com.must.orbit.orbit

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var reminderChannel: MethodChannel? = null
    private var pendingNotificationPayload: String? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNotificationPayload(intent, notifyDart = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureNotificationPayload(intent, notifyDart = false)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager =
                        getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(
                        powerManager.isIgnoringBatteryOptimizations(packageName),
                    )
                }
                else -> result.notImplemented()
            }
        }

        reminderChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REMINDER_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize", "ensureMaintenanceAlarm" -> {
                        OrbitReminderManager.ensureMaintenanceAlarm(this)
                        result.success(null)
                    }
                    "scheduleReminder" -> scheduleReminder(call.arguments, result)
                    "cancelReminder" -> {
                        OrbitReminderManager.cancel(this, call.argument<Int>("alarmId") ?: -1)
                        result.success(null)
                    }
                    "cancelCourseReminders" -> {
                        OrbitReminderManager.cancelCourseReminders(this)
                        result.success(null)
                    }
                    "pendingCourseReminderCount" ->
                        result.success(OrbitReminderManager.pendingCourseReminderCount(this))
                    "containsReminder" -> result.success(
                        OrbitReminderManager.contains(
                            this,
                            call.argument<Int>("alarmId") ?: -1,
                        ),
                    )
                    "consumeLaunchPayload" -> {
                        result.success(pendingNotificationPayload)
                        pendingNotificationPayload = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun scheduleReminder(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *> ?: run {
            result.error("invalid_arguments", "Reminder arguments are missing", null)
            return
        }
        try {
            val record = OrbitReminderRecord(
                alarmId = (values["alarmId"] as Number).toInt(),
                notificationId = (values["notificationId"] as Number).toInt(),
                fireAtMillis = (values["fireAtMillis"] as Number).toLong(),
                title = values["title"] as String,
                body = values["body"] as String,
                bigText = values["bigText"] as String?,
                payload = values["payload"] as String,
                channelName = values["channelName"] as String,
                channelDescription = values["channelDescription"] as String,
                restoreOnReboot = values["restoreOnReboot"] as? Boolean ?: true,
            )
            val scheduleResult = OrbitReminderManager.schedule(
                this,
                record,
                exactPreferred = values["exactPreferred"] as? Boolean ?: true,
                allowInexactFallback = values["allowInexactFallback"] as? Boolean ?: true,
            )
            result.success(
                mapOf(
                    "scheduled" to scheduleResult.scheduled,
                    "usedInexactFallback" to scheduleResult.usedInexactFallback,
                ),
            )
        } catch (error: Exception) {
            result.error("schedule_failed", error.message, null)
        }
    }

    private fun captureNotificationPayload(intent: Intent?, notifyDart: Boolean) {
        val payload = intent?.getStringExtra(OrbitReminderManager.payloadExtra) ?: return
        pendingNotificationPayload = payload
        intent.removeExtra(OrbitReminderManager.payloadExtra)
        if (notifyDart) {
            reminderChannel?.invokeMethod("notificationTap", payload)
        }
    }

    companion object {
        private const val BATTERY_CHANNEL = "com.must.orbit.orbit/battery"
        private const val REMINDER_CHANNEL = "com.must.orbit.orbit/reminders"
    }
}
