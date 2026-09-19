package com.must.orbit.orbit

import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.net.Uri
import android.os.PowerManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var ringtoneResult: MethodChannel.Result? = null
    private var preview: android.media.MediaPlayer? = null
    private var reminderChannel: MethodChannel? = null
    private var pendingNotificationPayload: String? = null
    private val reminderStatusExecutor = Executors.newSingleThreadExecutor()

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNotificationPayload(intent, notifyDart = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        OrbitReminderDiagnostics.attach(this)
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
                    "runtimeStatus" -> {
                        val config = OrbitReminderStore.metadata(this)
                        result.success(config["schedule_failure"] ?: config["strong_degraded"])
                    }
                    "reminderReliabilityStatus" -> loadReminderReliabilityStatus(result)
                    "enhancedReminderMode" ->
                        result.success(OrbitReminderKeepAliveService.isEnabled(this))
                    "setEnhancedReminderMode" -> {
                        OrbitReminderKeepAliveService.setEnabled(
                            this,
                            call.argument<Boolean>("enabled") == true,
                            mapOf(
                                "channel" to call.argument<String>("channel"),
                                "title" to call.argument<String>("title"),
                                "body" to call.argument<String>("body"),
                                "disable" to call.argument<String>("disable"),
                            ),
                        )
                        result.success(null)
                    }
                    "openAutostartSettings" -> result.success(openAutostartSettings())
                    "configureDatabase" -> {
                        val values = mutableMapOf<String, String?>(
                            "schedule_failure" to null,
                            "database_path" to call.argument<String>("path"),
                        )
                        for (key in listOf("catchup_label","catchup_notice","original_label","delivered_label","channel_name","channel_description"))
                            values[key] = call.argument<String>(key)
                        OrbitReminderStore.updateMetadata(this, values)
                        OrbitReminderDiagnostics.event("configure_database")
                        result.success(null)
                    }
                    "chooseRingtone" -> {
                        if (ringtoneResult != null) { result.error("busy", "Picker already open", null) }
                        else {
                            ringtoneResult = result
                            val picker = Intent(android.media.RingtoneManager.ACTION_RINGTONE_PICKER)
                                .putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_TYPE, android.media.RingtoneManager.TYPE_ALARM)
                                .putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            @Suppress("DEPRECATION")
                            startActivityForResult(picker, 6201)
                        }
                    }
                    "previewSound" -> {
                        try {
                            preview?.release()
                            val value = call.argument<String>("value") ?: ""
                            val uri = if (value.isEmpty()) android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                                else if (call.argument<String>("kind") == "file") android.net.Uri.fromFile(java.io.File(value)) else android.net.Uri.parse(value)
                            preview = android.media.MediaPlayer()
                            preview!!.apply {
                                setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_ALARM).build())
                                setDataSource(this@MainActivity,uri);prepare();start()
                            }
                            result.success(null)
                        } catch (e: Exception) { preview?.release();preview=null;result.error("preview", e.message, null) }
                    }
                    "validateAudio" -> {
                        val retriever=android.media.MediaMetadataRetriever()
                        try {
                            retriever.setDataSource(call.argument<String>("path"))
                            val duration=retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
                            val hasAudio=retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
                            if(duration<=0 || hasAudio!="yes")result.error("audio_type","Invalid audio",null) else result.success(null)
                        }catch(e: Exception){result.error("audio_type",e.message,null)}
                        finally { retriever.release() }
                    }
                    "stopPreview" -> { preview?.release(); preview = null; result.success(null) }
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
                metadata = values["metadata"] as? String ?: "{}",
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

    private fun loadReminderReliabilityStatus(result: MethodChannel.Result) {
        reminderStatusExecutor.execute {
            try {
                val status = reminderReliabilityStatus()
                runOnUiThread { result.success(status) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "reliability_status_failed",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }
    }

    private fun reminderReliabilityStatus(): Map<String, Any?> {
        val records = OrbitReminderStore.load(this).values
        val registered = records.count {
            it.fireAtMillis > System.currentTimeMillis() &&
                OrbitReminderManager.contains(this, it.alarmId)
        }
        val exit = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            manager.getHistoricalProcessExitReasons(packageName, 0, 8).firstOrNull()
        } else null
        val description = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            exit?.description?.toString()
        } else null
        val forcedStop = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            exit?.reason == ApplicationExitInfo.REASON_USER_REQUESTED &&
                (description?.contains("force stop", ignoreCase = true) == true ||
                    description?.contains("single-cleaner", ignoreCase = true) == true ||
                    description?.contains("stop ", ignoreCase = true) == true)
        } else false
        return mapOf(
            "enhancedMode" to OrbitReminderKeepAliveService.isEnabled(this),
            "storedReminderCount" to records.count { it.fireAtMillis > System.currentTimeMillis() },
            "registeredReminderCount" to registered,
            "forcedStopDetected" to forcedStop,
            "exitTimestamp" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) exit?.timestamp else null,
            "exitReason" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) exit?.reason else null,
            "exitDescription" to description?.take(160),
            "events" to OrbitReminderStore.diagnostics(this),
        )
    }

    override fun onDestroy() {
        reminderStatusExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun openAutostartSettings(): Boolean {
        val candidates = listOf(
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            ),
            ComponentName(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            ),
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.PurviewTabActivity",
            ),
        )
        for (component in candidates) {
            try {
                startActivity(Intent().setComponent(component))
                return true
            } catch (_: Exception) { }
        }
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
            false
        } catch (_: Exception) {
            false
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 6201) {
            @Suppress("DEPRECATION")
            val uri = data?.getParcelableExtra<android.net.Uri>(android.media.RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            ringtoneResult?.success(if (resultCode == RESULT_OK && uri != null)
                mapOf("kind" to "system", "value" to uri.toString(), "name" to android.media.RingtoneManager.getRingtone(this, uri)?.getTitle(this)) else null)
            ringtoneResult = null
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
