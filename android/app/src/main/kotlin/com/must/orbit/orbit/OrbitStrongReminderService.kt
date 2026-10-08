package com.must.orbit.orbit

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.*
import org.json.JSONObject

/** One shared player; further deliveries never renew an active deadline. */
class OrbitStrongReminderService : Service() {
    companion object {
        @Volatile var active = false
            private set
        private val occurrences = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
        fun acknowledge(context: Context, rule: String, session: String): Boolean {
            if (!occurrences.remove("$rule|$session") || occurrences.isNotEmpty()) return false
            stop(context)
            return true
        }
        fun stopTests(context: Context) { OrbitStrongSession.stopTests(context) }
        fun stop(context: Context) {
            if (context.stopService(Intent(context, OrbitStrongReminderService::class.java))) {
                OrbitReminderProcess.lifecycle.cancelServiceStarts()
                OrbitReminderDiagnostics.event("strong_stop_requested")
            }
        }
        fun start(context: Context, record: OrbitReminderRecord, opened: Boolean = false): Boolean {
            val intent = Intent(context, OrbitStrongReminderService::class.java)
                .putExtra("record", record.toJson().toString()).putExtra("opened", opened)
            OrbitReminderProcess.lifecycle.beginServiceStart()
            try {
                val component = if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                if (component == null) throw IllegalStateException("Service not started")
                OrbitReminderDiagnostics.event("strong_start_requested", record.alarmId)
                return true
            } catch (e: Exception) {
                OrbitReminderProcess.lifecycle.endServiceStart()
                OrbitReminderDiagnostics.strongFailure(context, "start", record.alarmId, e)
                return OrbitReminderManager.postNormalFallback(context,record)
            }
        }
    }
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var vibration: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var attemptedRound = -1
    private var wasMuted = true
    private val finalNotices = mutableListOf<Pair<Int,Notification>>()
    override fun onCreate() {
        super.onCreate()
        OrbitReminderProcess.serviceCreated(this)
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if(intent!=null) OrbitReminderProcess.lifecycle.endServiceStart()
        if(intent?.getBooleanExtra("opened",false)==true) { mute(); wasMuted=true }
        return try {
            val resumeIntent=if(intent==null) {
                val state=OrbitStrongSession.state(this)
                if(!OrbitStrongSession.isActive(state)) { stopSelf(); return START_NOT_STICKY }
                Intent(this,OrbitStrongReminderService::class.java).putExtra("record",state!!.getJSONArray("records").getJSONObject(0).toString())
            } else intent
            startReminder(resumeIntent)
        } catch (error: Exception) {
            OrbitReminderDiagnostics.failure(this, "strong_service", error = error)
            try {
                intent?.getStringExtra("record")?.let {
                    OrbitReminderManager.recoverNormalFallback(this, OrbitReminderRecord.fromJson(JSONObject(it)))
                }
            } catch (fallbackError: Exception) {
                OrbitReminderDiagnostics.failure(this, "strong_service_fallback", error = fallbackError)
            }
            stopSelf()
            START_NOT_STICKY
        }
    }
    private fun startReminder(intent: Intent?): Int {
        if (intent?.action == "stop") { stopSelf(); return START_NOT_STICKY }
        val record = OrbitReminderRecord.fromJson(JSONObject(intent?.getStringExtra("record") ?: run { stopSelf(); return START_NOT_STICKY }))
        if(OrbitReminderLedger.acknowledged(this,record)) {
            if(!active) stopSelf()
            return START_NOT_STICKY
        }
        val meta = JSONObject(record.metadata)
        val key = if (meta.optString("ruleId").isNotEmpty() && meta.optString("ruleId") != "null")
            "${meta.optString("ruleId")}|${meta.optString("sessionId")}" else "@builtin|${record.payload}"
        val session = OrbitStrongSession.start(this, record)
        if (!OrbitStrongSession.isActive(session)) { if (!active) stopSelf(); return START_NOT_STICKY }
        occurrences.add(key)
        if (active) { if(!OrbitStrongSession.shouldPlay(session!!)) mute(); return START_STICKY }
        val notification = OrbitReminderManager.buildNotification(this, record) ?: run { stopSelf(); return START_NOT_STICKY }
        try { startForeground(record.notificationId, notification) }
        catch(e: Exception) {
            OrbitReminderDiagnostics.strongFailure(this, "foreground", record.alarmId, e)
            OrbitReminderManager.recoverNormalFallback(this,record)
            stopSelf();return START_NOT_STICKY
        }
        active = true
        OrbitReminderStore.updateMetadata(this, mapOf("strong_degraded" to null))
        OrbitReminderDiagnostics.event("strong_active", record.alarmId)
        val remaining = session!!.getLong("expiresAt")-System.currentTimeMillis()
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Orbit:StrongReminder")
            .also { it.acquire(remaining.coerceAtLeast(1)+1000) }
        var foregroundId=record.notificationId
        fun tick() {
            val state=OrbitStrongSession.state(this)
            if(!OrbitStrongSession.isActive(state)) {
                mute()
                if(state?.optString("phase")=="unconfirmed") {
                    val records=state.getJSONArray("records")
                    for(i in 0 until records.length()) {
                        val r=OrbitReminderRecord.fromJson(records.getJSONObject(i))
                        OrbitReminderManager.buildNotification(this,r)?.let {
                            val locale=JSONObject(r.metadata).optString("localeTag","en")
                            val label=if(locale.startsWith("en")) "Not confirmed" else if(locale.contains("Hans")) "未确认" else "未確認"
                            val notice=android.app.Notification.Builder.recoverBuilder(this,it)
                                .setContentTitle("${r.title} · $label").setContentText(r.body)
                                .setStyle(Notification.BigTextStyle().bigText(r.body)).setDeleteIntent(null)
                                .setActions(*emptyArray<Notification.Action>()).setSound(null).setVibrate(null).build()
                            finalNotices.add(r.notificationId to notice)
                        }
                    }
                }
                stopSelf(); return
            }
            val currentRecords=state!!.getJSONArray("records")
            val effectiveRecord=if(currentRecords.length()>0) OrbitReminderRecord.fromJson(currentRecords.getJSONObject(0)) else record
            if(effectiveRecord.notificationId!=foregroundId) {
                foregroundId=effectiveRecord.notificationId
                OrbitReminderManager.buildNotification(this,effectiveRecord)?.let { startForeground(foregroundId,it) }
            }
            if(OrbitStrongSession.shouldPlay(state)) {
                val round=state.getInt("round")
                if(attemptedRound!=round || wasMuted) { attemptedRound=round; wasMuted=false; play(effectiveRecord) }
            } else { mute(); wasMuted=true }
            handler.postDelayed({ tick() },250)
        }
        tick()
        return START_STICKY
    }
    private fun mute() { player?.release(); player=null; vibration?.cancel(); vibration=null }
    private fun play(record: OrbitReminderRecord) {
        val settings=JSONObject(record.metadata).optJSONObject("strong") ?: JSONObject()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(OrbitReminderManager.channelId) else null
        val audio = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        val permitted = manager.areNotificationsEnabled() && (channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE) &&
            (Build.VERSION.SDK_INT < 23 || manager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL)
        if (permitted && settings.optBoolean("soundEnabled", true) && (channel == null || channel.sound != null) && audio.getStreamVolume(android.media.AudioManager.STREAM_ALARM) > 0) {
            try {
                val sound = settings.optJSONObject("sound") ?: JSONObject()
                val value = sound.optString("value")
                val uri = if (value.isEmpty()) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    else if (sound.optString("kind") == "file") Uri.fromFile(java.io.File(value)) else Uri.parse(value)
                player = MediaPlayer()
                player!!.apply {
                    setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    try { setDataSource(this@OrbitStrongReminderService, uri) }
                    catch (_: Exception) { reset(); setDataSource(this@OrbitStrongReminderService, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)) }
                    isLooping = true; prepare(); start()
                }
            } catch (e: Exception) {
                player?.release(); player = null
                OrbitReminderDiagnostics.strongFailure(this, "audio", record.alarmId, e)
                OrbitReminderManager.recoverNormalFallback(this,record)
            }
        }
        if (permitted && settings.optBoolean("vibrationEnabled", true)) {
            vibration = if (Build.VERSION.SDK_INT >= 31) (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
                else @Suppress("DEPRECATION") (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
            if (Build.VERSION.SDK_INT >= 26) vibration?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 600, 300, 600, 700), 0))
            else @Suppress("DEPRECATION") vibration?.vibrate(longArrayOf(0, 600, 300, 600, 700), 0)
        }
    }
    override fun onDestroy() {
        try {
            handler.removeCallbacksAndMessages(null)
            player?.release(); player = null
            vibration?.cancel()
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } finally {
            occurrences.clear()
            active = false
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
                val manager=getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                finalNotices.forEach { (id,notice)-> manager.notify(id,notice) }
                super.onDestroy()
            } finally {
                OrbitReminderDiagnostics.event("strong_destroyed")
                OrbitReminderProcess.lifecycle.serviceDestroyed()
            }
        }
    }
}
