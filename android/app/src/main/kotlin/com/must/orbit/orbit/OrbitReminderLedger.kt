package com.must.orbit.orbit

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Shares the v5 delivery ledger with Flutter. SQLite serializes cross-process actions. */
object OrbitReminderLedger {
    private fun open(context: Context): SQLiteDatabase? {
        @Suppress("DEPRECATION")
        val path = context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE or Context.MODE_MULTI_PROCESS).getString("database_path", null) ?: return null
        return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE)
    }
    private fun identity(record: OrbitReminderRecord): JSONObject = JSONObject(record.metadata)
    fun acknowledged(context: Context, record: OrbitReminderRecord): Boolean {
        val meta=identity(record)
        val rule=meta.optString("ruleId")
        if(rule.isEmpty() || rule=="null") return false
        open(context)?.use { db ->
            db.rawQuery("SELECT acknowledged FROM reminder_delivery WHERE rule_id=? AND session_id=?",arrayOf(rule,meta.optString("sessionId"))).use {
                return it.moveToFirst() && it.getInt(0)==1
            }
        }
        return false
    }
    fun claim(context: Context, record: OrbitReminderRecord): Boolean {
        val meta = identity(record)
        val rule = meta.optString("ruleId")
        if (rule.isEmpty() || rule == "null") return true
        val session = meta.getString("sessionId")
        val index = meta.optInt("sendIndex", 1)
        val db = open(context) ?: return false
        db.use {
            it.beginTransaction()
            try {
                it.rawQuery("SELECT acknowledged,processed_index FROM reminder_delivery WHERE rule_id=? AND session_id=?", arrayOf(rule, session)).use { cursor ->
                    if (cursor.moveToFirst() && (cursor.getInt(0) == 1 || cursor.getInt(1) >= index)) return false
                }
                it.execSQL("INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)",arrayOf(rule,session))
                it.execSQL("UPDATE reminder_delivery SET processed_index=MAX(processed_index,?),catchup_index=MAX(catchup_index,?) WHERE rule_id=? AND session_id=?",arrayOf<Any>(index,if(meta.optBoolean("catchUp")) index else 0,rule,session))
                it.delete("reminder_schedule", "rule_id=? AND session_id=? AND send_index<=?", arrayOf(rule, session, index.toString()))
                it.setTransactionSuccessful()
                return true
            } finally { it.endTransaction() }
        }
    }
    fun acknowledge(context: Context, rule: String, session: String) {
        open(context)?.use { db ->
            db.beginTransaction()
            try {
                db.execSQL("INSERT OR IGNORE INTO reminder_delivery(rule_id,session_id) VALUES(?,?)",arrayOf(rule,session))
                db.execSQL("UPDATE reminder_delivery SET acknowledged=1 WHERE rule_id=? AND session_id=?",arrayOf(rule,session))
                db.delete("reminder_schedule", "rule_id=? AND session_id=?", arrayOf(rule, session))
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        OrbitReminderStore.load(context).values.filter {
            val meta = identity(it); meta.optString("ruleId") == rule && meta.optString("sessionId") == session
        }.forEach { OrbitReminderManager.cancel(context, it.alarmId) }
    }
    fun replenish(context: Context,ruleId: String?=null,sessionId: String?=null) {
        val db = open(context) ?: return
        val now = System.currentTimeMillis()
        val groups = linkedMapOf<String, MutableList<JSONObject>>()
        db.use {
            val filter=if(ruleId!=null && sessionId!=null) " AND s.rule_id=? AND s.session_id=?" else ""
            val args=if(filter.isNotEmpty())arrayOf(ruleId!!,sessionId!!) else null
            it.rawQuery("SELECT s.spec FROM reminder_schedule s LEFT JOIN reminder_delivery d ON s.rule_id=d.rule_id AND s.session_id=d.session_id WHERE COALESCE(d.acknowledged,0)=0 AND s.send_index>COALESCE(d.processed_index,0)"+filter+" ORDER BY s.fire_at", args).use { cursor ->
                while (cursor.moveToNext()) {
                    val meta = JSONObject(cursor.getString(0))
                    groups.getOrPut(meta.getString("ruleId") + "|" + meta.getString("sessionId")) { mutableListOf() }.add(meta)
                }
            }
        }
        @Suppress("DEPRECATION")
        val prefs = context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE or Context.MODE_MULTI_PROCESS)
        groups.values.forEach { entries ->
            fun time(meta: JSONObject) = java.time.OffsetDateTime.parse(meta.getString("fireAt")).toInstant().toEpochMilli()
            // Dart serializes local dates without an offset, so interpret those in the local zone.
            fun millis(meta: JSONObject): Long = try { time(meta) } catch (_: Exception) {
                java.time.LocalDateTime.parse(meta.getString("fireAt")).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
            }
            fun original(meta: JSONObject): Long {
                val value=meta.optString("originalFireAt")
                if(value.isEmpty() || value=="null")return millis(meta)
                return try {java.time.OffsetDateTime.parse(value).toInstant().toEpochMilli()}
                    catch(_: Exception){java.time.LocalDateTime.parse(value).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()}
            }
            entries.sortBy { original(it) }
            val missed = entries.lastOrNull { original(it) <= now && now - original(it) <= 86_400_000 }
            val next = missed ?: entries.firstOrNull { original(it) > now } ?: return@forEach
            var title = next.getString("title")
            var body = next.getString("body")
            val at = original(next)
            val catchUp = at <= now
            if (catchUp) {
                val format = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                if(!next.optBoolean("catchUp"))title = "[${prefs.getString("catchup_label", "Catch-up")}] $title"
                else body=body.lines().dropLast(3).joinToString("\n")
                body += "\n${prefs.getString("original_label", "Originally scheduled")}: ${format.format(Date(at))}\n" +
                    "${prefs.getString("delivered_label", "Delivered")}: ${format.format(Date(now))}\n${prefs.getString("catchup_notice", "This is a catch-up message, not a real-time reminder.")}"
                next.put("catchUp", true)
            }
            val record = OrbitReminderRecord(next.getInt("alarmId"),next.getInt("notificationId"),
                if(catchUp) now+1000 else at,title,body,null,next.getString("payload"),
                prefs.getString("channel_name", "Course reminders")!!,prefs.getString("channel_description", "Course reminders")!!,true,next.toString())
            val existing=OrbitReminderStore.get(context,record.alarmId)
            if(existing==null || existing.fireAtMillis<=now || (!catchUp && existing.fireAtMillis!=at))
                if (!OrbitReminderManager.schedule(context,record,true,true).scheduled) {
                    prefs.edit().putString("schedule_failure", "replenish").commit()
                }
        }
    }
}
