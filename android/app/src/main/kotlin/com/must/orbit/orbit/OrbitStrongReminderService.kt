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
        @Volatile var starting = false
        private val occurrences = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
        fun acknowledge(context: Context, rule: String, session: String): Boolean {
            if (!occurrences.remove("$rule|$session") || occurrences.isNotEmpty()) return false
            context.stopService(Intent(context, OrbitStrongReminderService::class.java))
            return true
        }
        fun start(context: Context, record: OrbitReminderRecord) {
            val intent = Intent(context, OrbitStrongReminderService::class.java)
                .putExtra("record", record.toJson().toString())
            try {
                starting = true
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            } catch (e: Exception) {
                starting = false
                context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE).edit()
                    .putString("strong_degraded", e.javaClass.simpleName).commit()
                OrbitReminderManager.postNormalFallback(context,record)
            }
        }
    }
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var vibration: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        starting = false
        if (intent?.action == "stop") { stopSelf(); return START_NOT_STICKY }
        val record = OrbitReminderRecord.fromJson(JSONObject(intent?.getStringExtra("record") ?: run { stopSelf(); return START_NOT_STICKY }))
        if(OrbitReminderLedger.acknowledged(this,record)) {
            if(!active) stopSelf()
            return START_NOT_STICKY
        }
        val meta = JSONObject(record.metadata)
        val key = if (meta.optString("ruleId").isNotEmpty() && meta.optString("ruleId") != "null")
            "${meta.optString("ruleId")}|${meta.optString("sessionId")}" else "@builtin|${record.payload}"
        occurrences.add(key)
        if (active) return START_NOT_STICKY
        val settings = meta.optJSONObject("strong") ?: JSONObject()
        val notification = OrbitReminderManager.buildNotification(this, record) ?: run { stopSelf(); return START_NOT_STICKY }
        try { startForeground(2_200_000, notification) }
        catch(e: Exception) {
            getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE).edit().putString("strong_degraded",e.javaClass.simpleName).commit()
            OrbitReminderManager.postNormalFallback(this,record)
            stopSelf();return START_NOT_STICKY
        }
        active = true
        getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE).edit().remove("strong_degraded").commit()
        val seconds = settings.optInt("durationSeconds", 30).coerceIn(5, 300)
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Orbit:StrongReminder")
            .also { it.acquire((seconds + 1) * 1000L) }
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
                getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE).edit().putString("strong_degraded", e.javaClass.simpleName).commit()
                OrbitReminderManager.postNormalFallback(this,record)
            }
        }
        if (permitted && settings.optBoolean("vibrationEnabled", true)) {
            vibration = if (Build.VERSION.SDK_INT >= 31) (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
                else @Suppress("DEPRECATION") (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
            if (Build.VERSION.SDK_INT >= 26) vibration?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 600, 300, 600, 700), 0))
            else @Suppress("DEPRECATION") vibration?.vibrate(longArrayOf(0, 600, 300, 600, 700), 0)
        }
        handler.postDelayed({ stopSelf() }, seconds * 1000L)
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null); player?.release(); player = null
        vibration?.cancel(); if (wakeLock?.isHeld == true) wakeLock?.release()
        occurrences.clear()
        active = false; stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy()
        exitDedicatedReminderProcessSoon()
    }
}
