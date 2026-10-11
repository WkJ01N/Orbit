package com.must.orbit.orbit

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.os.Process
import org.json.JSONArray
import org.json.JSONObject

/** DDL acknowledgement is independent of the course challenge. */
object OrbitDeadlineStrongSession {
    fun isDeadline(record: OrbitReminderRecord) = JSONObject(record.metadata).optString("acknowledgementMode") == "openApp"
    private fun key(record: OrbitReminderRecord) = "${record.alarmId}:${record.fireAtMillis}"
    private fun mutate(context: Context, change: (JSONObject) -> Unit): JSONObject =
        OrbitReminderStore.mutateJsonState(context, "deadline_strong_sessions") { old ->
            (old ?: JSONObject().put("sessions", JSONArray()).put("events", JSONArray())).also { root ->
                val kept = JSONArray()
                val sessions = root.getJSONArray("sessions")
                for (i in 0 until sessions.length()) {
                    val s = sessions.getJSONObject(i)
                    if (System.currentTimeMillis() < s.optLong("expiresAt") + 7 * 86400000L) kept.put(s)
                }
                root.put("sessions", kept)
                change(root)
            }
        }!!
    fun visibility(context: Context, visible: Boolean) {
        OrbitReminderStore.updateMetadata(context, mapOf("app_visible_pid" to if (visible) Process.myPid().toString() else null))
        if (visible) open(context)
    }
    fun foreground(context: Context): Boolean {
        val pid = OrbitReminderStore.metadata(context)["app_visible_pid"]?.toIntOrNull() ?: return false
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return manager.runningAppProcesses?.any { it.pid == pid && it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND } == true
    }
    private fun advance(s: JSONObject, now: Long) {
        if (s.optString("phase") in setOf("completed", "cancelled", "unconfirmed")) return
        val started = s.getLong("startedAt")
        val length = s.getLong("duration")
        if (now >= s.getLong("expiresAt")) { s.put("phase", "unconfirmed"); return }
        val round = ((now - started) / (length + 15000)).toInt().coerceIn(0,2) + 1
        s.put("round", round).put("roundEnd", started + (round - 1) * (length + 15000) + length)
    }
    fun active(s: JSONObject) = s.optString("phase") == "ringing" && System.currentTimeMillis() < s.optLong("expiresAt")
    fun shouldPlay(s: JSONObject) = active(s) && System.currentTimeMillis() < s.optLong("roundEnd")
    private fun confirm(root: JSONObject, s: JSONObject) {
        if (!active(s)) return
        s.put("phase", "completed")
        val r = s.getJSONObject("record")
        val meta = JSONObject(r.getString("metadata"))
        root.getJSONArray("events").put(JSONObject().put("id", s.getString("id"))
            .put("deadlineId", meta.getString("deadlineId")).put("leadMinutes", meta.getInt("leadMinutes"))
            .put("fireAtMillis", r.getLong("fireAtMillis")))
    }
    fun start(context: Context, record: OrbitReminderRecord): JSONObject {
        val visible = foreground(context)
        var selected: JSONObject? = null
        mutate(context) { root ->
            val sessions = root.getJSONArray("sessions")
            for (i in 0 until sessions.length()) if (sessions.getJSONObject(i).getString("id") == key(record)) selected = sessions.getJSONObject(i)
            if (selected == null) {
                val length = (JSONObject(record.metadata).getJSONObject("strong").optInt("durationSeconds",30).coerceIn(5,300) * 1000L)
                selected = JSONObject().put("id",key(record)).put("startedAt",record.fireAtMillis)
                    .put("expiresAt",record.fireAtMillis + length * 3 + 30000).put("duration",length)
                    .put("round",1).put("roundEnd",record.fireAtMillis+length).put("phase","ringing").put("record",record.toJson())
                sessions.put(selected)
            }
            advance(selected!!,System.currentTimeMillis())
            if (visible) confirm(root, selected!!)
        }
        return selected!!
    }
    fun states(context: Context): List<JSONObject> {
        val root = mutate(context) { root ->
            val sessions = root.getJSONArray("sessions")
            for (i in 0 until sessions.length()) advance(sessions.getJSONObject(i),System.currentTimeMillis())
        }
        val sessions = root.getJSONArray("sessions")
        return (0 until sessions.length()).map { sessions.getJSONObject(it) }
    }
    fun anyActive(context: Context) = states(context).any(::active)
    fun open(context: Context, refreshPlayer: Boolean = true): JSONObject {
        val removed = mutableListOf<Int>()
        val root = mutate(context) { root ->
            val sessions = root.getJSONArray("sessions")
            for (i in 0 until sessions.length()) {
                val s = sessions.getJSONObject(i)
                advance(s, System.currentTimeMillis())
                if (active(s)) { removed.add(s.getJSONObject("record").getInt("notificationId")); confirm(root,s) }
            }
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        removed.forEach(manager::cancel)
        if (removed.isNotEmpty() && refreshPlayer) OrbitStrongReminderService.stop(context)
        return JSONObject().put("events",root.getJSONArray("events"))
    }
    fun eventsHandled(context: Context, ids: Set<String>): JSONObject {
        val root = mutate(context) { root ->
            val remaining=JSONArray(); val events=root.getJSONArray("events")
            for(i in 0 until events.length()) if(events.getJSONObject(i).getString("id") !in ids) remaining.put(events.getJSONObject(i))
            root.put("events",remaining)
        }
        return JSONObject().put("events",root.getJSONArray("events"))
    }
    fun reconcile(context: Context, valid: Set<String>) {
        val cancelled=mutableListOf<Int>()
        mutate(context) { root ->
            val sessions=root.getJSONArray("sessions")
            for(i in 0 until sessions.length()) {
                val s=sessions.getJSONObject(i); if(!active(s)) continue
                val record=s.getJSONObject("record"); val meta=JSONObject(record.getString("metadata"))
                val identity="${meta.getString("deadlineId")}:${meta.getInt("leadMinutes")}:${record.getLong("fireAtMillis")}"
                if(identity !in valid) { s.put("phase","cancelled");cancelled.add(record.getInt("notificationId")) }
            }
        }
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        cancelled.forEach(manager::cancel)
        if(cancelled.isNotEmpty() && !anyActive(context) && !OrbitStrongSession.isActive(OrbitStrongSession.state(context))) OrbitStrongReminderService.stop(context)
    }
}
