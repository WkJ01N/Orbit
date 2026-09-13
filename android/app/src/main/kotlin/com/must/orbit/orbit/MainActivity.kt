package com.must.orbit.orbit

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtoneResult: MethodChannel.Result? = null
    private var preview: android.media.MediaPlayer? = null
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
                    "runtimeStatus" -> {
                        @Suppress("DEPRECATION")
                        val prefs=getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE or Context.MODE_MULTI_PROCESS)
                        result.success(prefs.getString("schedule_failure",null) ?: prefs.getString("strong_degraded",null))
                    }
                    "configureDatabase" -> {
                        val editor = getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE).edit()
                        editor.remove("schedule_failure")
                        editor.putString("database_path", call.argument<String>("path"))
                        for (key in listOf("catchup_label","catchup_notice","original_label","delivered_label","channel_name","channel_description"))
                            editor.putString(key, call.argument<String>(key))
                        editor.commit()
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
