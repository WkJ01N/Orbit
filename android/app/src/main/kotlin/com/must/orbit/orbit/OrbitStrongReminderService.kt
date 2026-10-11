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
            if (!OrbitDeadlineStrongSession.anyActive(context)) stop(context)
            return true
        }
        fun stopTests(context: Context) { OrbitStrongSession.stopTests(context) }
        fun stop(context: Context) {
            // Re-evaluate both states in the service rather than stopping a
            // player that may now belong to a simultaneous course or DDL.
            OrbitReminderProcess.lifecycle.beginServiceStart()
            try {
                if (context.startService(Intent(context, OrbitStrongReminderService::class.java).setAction("refresh")) == null)
                    throw IllegalStateException("Cannot refresh strong reminders")
                OrbitReminderDiagnostics.event("strong_refresh_requested")
            } catch(e: Exception) {
                OrbitReminderProcess.lifecycle.endServiceStart()
                throw e
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
    private var attemptedKey = ""
    private var foregroundId = -1
    private var latestStartId = 0
    private val reportedFinals = mutableSetOf<String>()
    private var wasMuted = true
    private val finalNotices = mutableListOf<Pair<Int,Notification>>()
    override fun onCreate() {
        super.onCreate()
        OrbitReminderProcess.serviceCreated(this)
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        latestStartId = startId
        if(intent!=null) OrbitReminderProcess.lifecycle.endServiceStart()
        if(intent?.action == "refresh" && active) { handler.removeCallbacksAndMessages(null); tick(); return START_STICKY }
        if(intent?.getBooleanExtra("opened",false)==true) { mute(); wasMuted=true }
        return try {
            val resumeIntent=if(intent==null || intent.action=="refresh") {
                val state=OrbitStrongSession.state(this)
                val record = if (OrbitStrongSession.isActive(state)) state!!.getJSONArray("records").getJSONObject(0)
                    else OrbitDeadlineStrongSession.states(this).firstOrNull(OrbitDeadlineStrongSession::active)?.getJSONObject("record")
                if(record == null) { stopSelfResult(startId); return START_NOT_STICKY }
                Intent(this,OrbitStrongReminderService::class.java).putExtra("record",record.toString())
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
        val deadline = OrbitDeadlineStrongSession.isDeadline(record)
        val session = if (deadline) OrbitDeadlineStrongSession.start(this,record) else OrbitStrongSession.start(this,record)
        val sessionActive = if (deadline) OrbitDeadlineStrongSession.active(session!!) else OrbitStrongSession.isActive(session)
        if (!sessionActive) { if (!active) stopSelf(); return START_NOT_STICKY }
        if (!deadline) {
            val meta=JSONObject(record.metadata)
            occurrences.add(if(meta.optString("ruleId").isNotEmpty() && meta.optString("ruleId")!="null") "${meta.optString("ruleId")}|${meta.optString("sessionId")}" else "@builtin|${record.payload}")
        }
        if (active) return START_STICKY
        val notification = OrbitReminderManager.buildNotification(this, record) ?: run { stopSelf(); return START_NOT_STICKY }
        try { startForeground(record.notificationId, notification) }
        catch(e: Exception) {
            OrbitReminderDiagnostics.strongFailure(this, "foreground", record.alarmId, e)
            OrbitReminderManager.recoverNormalFallback(this,record)
            stopSelf();return START_NOT_STICKY
        }
        active = true
        foregroundId=record.notificationId
        OrbitReminderStore.updateMetadata(this, mapOf("strong_degraded" to null))
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Orbit:StrongReminder")
        tick()
        return START_STICKY
    }
    private fun terminalNotice(record: OrbitReminderRecord, identity: String) {
        if (!reportedFinals.add(identity)) return
        OrbitReminderManager.buildNotification(this,record)?.let {
            val locale=JSONObject(record.metadata).optString("localeTag","en")
            val label=if(locale.startsWith("en")) "Not confirmed" else if(locale.contains("Hans")) "未确认" else "未確認"
            val notice=Notification.Builder.recoverBuilder(this,it)
                .setContentTitle("${record.title} · $label").setContentText(record.body)
                .setStyle(Notification.BigTextStyle().bigText(record.body)).setDeleteIntent(null)
                .setActions(*emptyArray<Notification.Action>()).setSound(null).setVibrate(null).build()
            finalNotices.add(record.notificationId to notice)
        }
    }
    private fun tick() {
        try {
            // Native foreground detection also covers a delivery racing onResume.
            if (OrbitDeadlineStrongSession.foreground(this)) OrbitDeadlineStrongSession.open(this, refreshPlayer=false)
            val course=OrbitStrongSession.state(this)
            val deadlines=OrbitDeadlineStrongSession.states(this)
            val courseActive=OrbitStrongSession.isActive(course)
            val ddlActive=deadlines.filter(OrbitDeadlineStrongSession::active)
            if(course?.optString("phase")=="unconfirmed") {
                val records=course.getJSONArray("records")
                for(i in 0 until records.length()) terminalNotice(OrbitReminderRecord.fromJson(records.getJSONObject(i)), "course:${course.getString("id")}:$i")
            }
            for(s in deadlines.filter { it.optString("phase")=="unconfirmed" }) terminalNotice(OrbitReminderRecord.fromJson(s.getJSONObject("record")),s.getString("id"))
            if (!courseActive && ddlActive.isEmpty()) { mute(); stopSelfResult(latestStartId); return }
            val courseRecord=if(courseActive) OrbitReminderRecord.fromJson(course!!.getJSONArray("records").getJSONObject(0)) else null
            val playingDeadline=ddlActive.firstOrNull(OrbitDeadlineStrongSession::shouldPlay)
            val coursePlaying=courseActive && OrbitStrongSession.shouldPlay(course!!)
            val effective=if(coursePlaying) courseRecord!! else if(playingDeadline!=null) OrbitReminderRecord.fromJson(playingDeadline.getJSONObject("record")) else courseRecord ?: OrbitReminderRecord.fromJson(ddlActive.first().getJSONObject("record"))
            val round=if(coursePlaying) course!!.getInt("round") else playingDeadline?.getInt("round") ?: 0
            val playing=coursePlaying || playingDeadline!=null
            val identity="${effective.alarmId}:${effective.fireAtMillis}:$round"
            if(effective.notificationId!=foregroundId) {
                val oldForeground=foregroundId
                foregroundId=effective.notificationId
                OrbitReminderManager.buildNotification(this,effective)?.let { startForeground(foregroundId,it) }
                // Foreground notification replacement must not remove a live course.
                if(courseRecord?.notificationId!=oldForeground && ddlActive.none { it.getJSONObject("record").getInt("notificationId")==oldForeground })
                    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(oldForeground)
            }
            if(playing && (attemptedKey!=identity || wasMuted)) {
                mute(); attemptedKey=identity;wasMuted=false;play(effective)
            } else if(!playing) { mute();wasMuted=true }
            // A new DDL can extend the service's wake lock, never another occurrence's deadline.
            if(wakeLock?.isHeld!=true) wakeLock?.acquire(2000)
        } catch(e: Exception) {
            OrbitReminderDiagnostics.failure(this,"strong_tick",error=e)
            mute();wasMuted=true
        }
        handler.postDelayed({ tick() },250)
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
