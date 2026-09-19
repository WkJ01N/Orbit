package com.must.orbit.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

class OrbitReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        OrbitReminderProcess.beginTask(context)
        val alarmId = intent.getIntExtra(OrbitReminderManager.alarmIdExtra, -1)
        OrbitReminderDiagnostics.event("receive", alarmId)
        try {
            if (alarmId < 0) return
            val record = OrbitReminderStore.get(context, alarmId) ?: run {
                OrbitReminderDiagnostics.event("receive_missing_record", alarmId)
                return
            }
            val result = try {
                OrbitReminderLedger.deliver(context, record) {
                    OrbitReminderManager.postNotification(context, record)
                }
            } catch (error: Exception) {
                OrbitReminderDiagnostics.failure(context, "delivery", alarmId, error)
                OrbitReminderDeliveryResult.RETRY
            }
            if (result == OrbitReminderDeliveryResult.RETRY) {
                OrbitReminderManager.deferDelivery(context, record)
                return
            }
            OrbitReminderStore.remove(context, alarmId)
            val meta = JSONObject(record.metadata)
            val rule = meta.optString("ruleId")
            if (rule.isNotEmpty() && rule != "null") {
                OrbitReminderLedger.replenish(context, rule, meta.getString("sessionId"))
            }
        } catch (error: Exception) {
            OrbitReminderDiagnostics.failure(context, "receive", alarmId, error)
        } finally {
            OrbitReminderProcess.lifecycle.endTask()
        }
    }
}

class OrbitReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        OrbitReminderProcess.beginTask(context)
        OrbitReminderDiagnostics.event("action", reason = intent.action)
        try {
            if (intent.action == OrbitReminderKeepAliveService.disableAction) {
                OrbitReminderKeepAliveService.setEnabled(context, false)
            } else if (intent.action == "ack") {
                val rule=intent.getStringExtra("rule") ?: return
                val session=intent.getStringExtra("session") ?: return
                OrbitReminderLedger.acknowledge(context,rule,session)
                OrbitStrongReminderService.acknowledge(context,rule,session)
            } else if(intent.action=="stop") OrbitStrongReminderService.stop(context)
        } catch (error: Exception) {
            OrbitReminderDiagnostics.failure(context, "action", error = error)
        } finally { OrbitReminderProcess.lifecycle.endTask() }
    }
}

private fun BroadcastReceiver.restoreAsync(context: Context, stage: String) {
    OrbitReminderProcess.beginTask(context)
    val pending = goAsync()
    try {
        Thread {
            try {
                OrbitReminderDiagnostics.event(stage)
                OrbitReminderManager.restorePersistedReminders(context)
            } catch (error: Exception) {
                OrbitReminderDiagnostics.failure(context, stage, error = error)
            } finally {
                try { pending?.finish() }
                finally { OrbitReminderProcess.lifecycle.endTask() }
            }
        }.start()
    } catch (error: Exception) {
        try {
            pending?.finish()
            OrbitReminderDiagnostics.failure(context, stage, error = error)
        } finally { OrbitReminderProcess.lifecycle.endTask() }
    }
}

class OrbitReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = restoreAsync(context, "restore")
}

class OrbitReminderMaintenanceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = restoreAsync(context, "maintenance")
}
