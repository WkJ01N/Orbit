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
    private val legacyMetadataKeys = listOf(
        "database_path", "catchup_label", "catchup_notice", "original_label",
        "delivered_label", "channel_name", "channel_description",
        "schedule_failure", "strong_degraded",
    )

    private fun open(context: Context): android.database.sqlite.SQLiteDatabase {
        val file = context.getDatabasePath("orbit_native_reminders.db")
        file.parentFile?.mkdirs()
        val db = android.database.sqlite.SQLiteDatabase.openOrCreateDatabase(file, null)
        try {
            db.execSQL("CREATE TABLE IF NOT EXISTS records(id INTEGER PRIMARY KEY, record TEXT NOT NULL)")
            db.execSQL("CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            db.execSQL("CREATE TABLE IF NOT EXISTS diagnostics(timestamp INTEGER NOT NULL, stage TEXT NOT NULL, alarm_id INTEGER, reason TEXT)")
            db.execSQL("CREATE INDEX IF NOT EXISTS diagnostics_timestamp ON diagnostics(timestamp DESC)")
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
                val configMigrated = db.rawQuery(
                    "SELECT value FROM metadata WHERE key='config_migrated_v1'", null,
                ).use { it.moveToFirst() }
                if (!configMigrated) {
                    val prefs = context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE)
                    for (key in legacyMetadataKeys) {
                        prefs.getString(key, null)?.let { value ->
                            db.execSQL("INSERT OR IGNORE INTO metadata(key,value) VALUES(?,?)", arrayOf(key, value))
                        }
                    }
                    db.execSQL("INSERT INTO metadata(key,value) VALUES('config_migrated_v1','1')")
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        } catch (error: Exception) {
            db.close()
            throw error
        }
        return db
    }

    /** Read afresh: SharedPreferences caches cannot synchronize the two processes. */
    fun metadata(context: Context): Map<String, String> = open(context).use { db ->
        buildMap {
            db.rawQuery("SELECT key,value FROM metadata", null).use { cursor ->
                while (cursor.moveToNext()) put(cursor.getString(0), cursor.getString(1))
            }
        }
    }

    fun updateMetadata(context: Context, values: Map<String, String?>) = open(context).use { db ->
        db.beginTransaction()
        try {
            for ((key, value) in values) {
                if (value == null) db.delete("metadata", "key=?", arrayOf(key))
                else db.execSQL("INSERT OR REPLACE INTO metadata(key,value) VALUES(?,?)", arrayOf(key, value))
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    fun appendDiagnostic(
        context: Context,
        stage: String,
        alarmId: Int?,
        reason: String?,
    ) = open(context).use { db ->
        db.beginTransaction()
        try {
            db.execSQL(
                "INSERT INTO diagnostics(timestamp,stage,alarm_id,reason) VALUES(?,?,?,?)",
                arrayOf<Any?>(System.currentTimeMillis(), stage.take(64), alarmId, reason?.take(96)),
            )
            db.execSQL(
                "DELETE FROM diagnostics WHERE rowid NOT IN (SELECT rowid FROM diagnostics ORDER BY timestamp DESC LIMIT 64)",
            )
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    fun diagnostics(context: Context, limit: Int = 32): List<Map<String, Any?>> =
        open(context).use { db ->
            buildList {
                db.rawQuery(
                    "SELECT timestamp,stage,alarm_id,reason FROM diagnostics ORDER BY timestamp DESC LIMIT ?",
                    arrayOf(limit.coerceIn(1, 64).toString()),
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        add(
                            mapOf(
                                "timestamp" to cursor.getLong(0),
                                "stage" to cursor.getString(1),
                                "alarmId" to if (cursor.isNull(2)) null else cursor.getInt(2),
                                "reason" to if (cursor.isNull(3)) null else cursor.getString(3),
                            ),
                        )
                    }
                }
            }
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
