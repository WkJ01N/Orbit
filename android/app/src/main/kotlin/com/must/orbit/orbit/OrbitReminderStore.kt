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
        )
    }
}

object OrbitReminderStore {
    private const val preferencesName = "orbit_native_reminders"
    private const val recordsKey = "records_v1"
    private val lock = Any()

    fun load(context: Context): MutableMap<Int, OrbitReminderRecord> = synchronized(lock) {
        val raw = preferences(context).getString(recordsKey, null) ?: return@synchronized mutableMapOf()
        try {
            val array = JSONArray(raw)
            buildMap {
                for (index in 0 until array.length()) {
                    val record = OrbitReminderRecord.fromJson(array.getJSONObject(index))
                    put(record.alarmId, record)
                }
            }.toMutableMap()
        } catch (_: Exception) {
            preferences(context).edit().remove(recordsKey).commit()
            mutableMapOf()
        }
    }

    fun get(context: Context, alarmId: Int): OrbitReminderRecord? =
        load(context)[alarmId]

    fun upsert(context: Context, record: OrbitReminderRecord) = synchronized(lock) {
        val records = load(context)
        records[record.alarmId] = record
        write(context, records)
    }

    fun remove(context: Context, alarmId: Int) = synchronized(lock) {
        val records = load(context)
        if (records.remove(alarmId) != null) {
            write(context, records)
        }
    }

    fun removeWhere(
        context: Context,
        predicate: (OrbitReminderRecord) -> Boolean,
    ): List<OrbitReminderRecord> = synchronized(lock) {
        val records = load(context)
        val removed = records.values.filter(predicate)
        if (removed.isNotEmpty()) {
            removed.forEach { records.remove(it.alarmId) }
            write(context, records)
        }
        removed
    }

    private fun write(context: Context, records: Map<Int, OrbitReminderRecord>) {
        val editor = preferences(context).edit()
        if (records.isEmpty()) {
            editor.remove(recordsKey).commit()
            return
        }
        val array = JSONArray()
        records.values.sortedBy { it.alarmId }.forEach { array.put(it.toJson()) }
        editor.putString(recordsKey, array.toString()).commit()
    }

    @Suppress("DEPRECATION")
    private fun preferences(context: Context) = context.getSharedPreferences(
        preferencesName,
        Context.MODE_PRIVATE or Context.MODE_MULTI_PROCESS,
    )
}
