package com.must.orbit.orbit

import android.content.Context
import android.util.Log

/** Deliberately excludes titles, bodies, payloads and exception messages. */
internal object OrbitReminderDiagnostics {
    @Volatile private var applicationContext: Context? = null

    fun attach(context: Context) {
        applicationContext = context.applicationContext
    }

    fun event(stage: String, alarmId: Int? = null, reason: String? = null) {
        Log.i("OrbitReminders", "stage=$stage pid=${android.os.Process.myPid()} alarm=${alarmId ?: "-"} reason=${reason ?: "-"}")
        try {
            applicationContext?.let { OrbitReminderStore.appendDiagnostic(it, stage, alarmId, reason) }
        } catch (_: Exception) {
            Log.w("OrbitReminders", "diagnostics persistence failed")
        }
    }

    fun event(context: Context, stage: String, alarmId: Int? = null, reason: String? = null) {
        attach(context)
        event(stage, alarmId, reason)
    }

    fun failure(context: Context, stage: String, alarmId: Int? = null, error: Exception) {
        val reason = error.javaClass.simpleName
        event(context, stage, alarmId, reason)
        // Failure reporting must never obscure the original delivery failure.
        try {
            OrbitReminderStore.updateMetadata(context, mapOf("schedule_failure" to "$stage:$reason"))
        } catch (_: Exception) {
            event("diagnostics_write_failed", alarmId)
        }
    }

    fun strongFailure(context: Context, stage: String, alarmId: Int, error: Exception) {
        event("strong_${stage}_failed", alarmId, error.javaClass.simpleName)
        try {
            OrbitReminderStore.updateMetadata(context, mapOf("strong_degraded" to "$stage:${error.javaClass.simpleName}"))
        } catch (_: Exception) {
            event("diagnostics_write_failed", alarmId)
        }
    }
}
