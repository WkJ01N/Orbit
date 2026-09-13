package com.must.orbit.orbit

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class OrbitReminderRecord(
    val alarmId: Int,
    val notificationId: Int,
    val fireAtMillis: Long,
    val title: String,
    val body: String,
    val bigText: String?,
    val payload: String,
    val channelName: String,
    val channelDescription: String,
    val restoreOnReboot: Boolean,
    val metadata: String = "{}",
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("alarmId", alarmId)
        put("notificationId", notificationId)
        put("fireAtMillis", fireAtMillis)
        put("title", title)
        put("body", body)
        put("bigText", bigText)
        put("payload", payload)
        put("channelName", channelName)
        put("channelDescription", channelDescription)
        put("restoreOnReboot", restoreOnReboot)
        put("metadata", metadata)
    }

    companion object {
        fun fromJson(json: JSONObject): OrbitReminderRecord = OrbitReminderRecord(
            alarmId = json.getInt("alarmId"),
            notificationId = json.getInt("notificationId"),
            fireAtMillis = json.getLong("fireAtMillis"),
            title = json.getString("title"),
            body = json.getString("body"),
            bigText = if (json.isNull("bigText")) null else json.getString("bigText"),
            payload = json.getString("payload"),
            channelName = json.getString("channelName"),
            channelDescription = json.getString("channelDescription"),
            restoreOnReboot = json.optBoolean("restoreOnReboot", true),
            metadata = json.optString("metadata", "{}"),
        )
    }
}

object OrbitReminderStore {
    private fun open(context: Context): android.database.sqlite.SQLiteDatabase {
        val file = context.getDatabasePath("orbit_native_reminders.db")
        file.parentFile?.mkdirs()
        val db = android.database.sqlite.SQLiteDatabase.openOrCreateDatabase(file, null)
        db.execSQL("CREATE TABLE IF NOT EXISTS records(id INTEGER PRIMARY KEY, record TEXT NOT NULL)")
        db.execSQL("CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        db.beginTransaction()
        try {
            val migrated = db.rawQuery("SELECT value FROM metadata WHERE key='migrated'", null).use { it.moveToFirst() }
            if (!migrated) {
                val prefs = context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE)
                val raw = prefs.getString("records_v1", null)
                if (raw != null) {
                    val records = JSONArray(raw)
                    for (i in 0 until records.length()) {
                        val record = records.getJSONObject(i)
                        db.execSQL("INSERT OR IGNORE INTO records(id,record) VALUES(?,?)", arrayOf<Any>(record.getInt("alarmId"),record.toString()))
                    }
                }
                db.execSQL("INSERT INTO metadata(key,value) VALUES('migrated','1')")
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        return db
    }
    fun load(context: Context): MutableMap<Int,OrbitReminderRecord> = open(context).use { db ->
        val result = mutableMapOf<Int,OrbitReminderRecord>()
        db.rawQuery("SELECT record FROM records", null).use { cursor ->
            while(cursor.moveToNext()) {
                val record = OrbitReminderRecord.fromJson(JSONObject(cursor.getString(0)))
                result[record.alarmId] = record
            }
        }
        result
    }
    fun get(context: Context,alarmId: Int): OrbitReminderRecord? = open(context).use { db ->
        db.rawQuery("SELECT record FROM records WHERE id=?", arrayOf(alarmId.toString())).use { cursor ->
            if(cursor.moveToFirst()) OrbitReminderRecord.fromJson(JSONObject(cursor.getString(0))) else null
        }
    }
    fun upsert(context: Context,record: OrbitReminderRecord) = open(context).use { db ->
        db.execSQL("INSERT OR REPLACE INTO records(id,record) VALUES(?,?)", arrayOf<Any>(record.alarmId,record.toJson().toString()))
    }
    fun remove(context: Context,alarmId: Int) = open(context).use { db -> db.delete("records","id=?",arrayOf(alarmId.toString())) }
    fun removeWhere(context: Context,predicate: (OrbitReminderRecord)->Boolean): List<OrbitReminderRecord> = open(context).use { db ->
        db.beginTransaction()
        try {
            val removed = mutableListOf<OrbitReminderRecord>()
            db.rawQuery("SELECT record FROM records",null).use { cursor ->
                while(cursor.moveToNext()) {
                    val record = OrbitReminderRecord.fromJson(JSONObject(cursor.getString(0)))
                    if(predicate(record)) removed.add(record)
                }
            }
            removed.forEach { db.delete("records","id=?",arrayOf(it.alarmId.toString())) }
            db.setTransactionSuccessful()
            removed
        } finally { db.endTransaction() }
    }
}
