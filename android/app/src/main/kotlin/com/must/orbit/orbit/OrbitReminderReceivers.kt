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
                val active=OrbitStrongSession.state(context)
                val records=active?.optJSONArray("records")
                val strong=OrbitStrongSession.isActive(active) && records!=null && (0 until records.length()).any {
                    val meta=JSONObject(records.getJSONObject(it).optString("metadata","{}"))
                    meta.optString("ruleId")==rule && meta.optString("sessionId")==session
                }
                if(strong) {
                    OrbitStrongSession.open(context)
                    context.startActivity(Intent(context,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                } else {
                    OrbitReminderLedger.acknowledge(context,rule,session)
                    OrbitStrongReminderService.acknowledge(context,rule,session)
                }
            } else if(intent.action=="strong_dismiss") {
                val pending=goAsync()
                OrbitReminderProcess.lifecycle.beginTask()
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        for(s in OrbitDeadlineStrongSession.states(context).filter(OrbitDeadlineStrongSession::active)) {
                            val record=OrbitReminderRecord.fromJson(s.getJSONObject("record"))
                            OrbitReminderManager.buildNotification(context,record)?.let { (context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager).notify(record.notificationId,it) }
                        }
                        val state=OrbitStrongSession.state(context)
                        if(OrbitStrongSession.isActive(state)) {
                            val records=state!!.getJSONArray("records")
                            for(i in 0 until records.length()) {
                                val record=OrbitReminderRecord.fromJson(records.getJSONObject(i))
                                OrbitReminderManager.buildNotification(context,record)?.let { (context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager).notify(record.notificationId,it) }
                            }
                        }
                    } catch(error: Exception) {
                        OrbitReminderDiagnostics.failure(context,"strong_repost",error=error)
                    } finally {
                        try { pending?.finish() } finally { OrbitReminderProcess.lifecycle.endTask() }
                    }
                },2000)
            } else if(intent.action=="stop") { /* Old notification: open the confirmation instead. */ OrbitStrongSession.open(context) }
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
