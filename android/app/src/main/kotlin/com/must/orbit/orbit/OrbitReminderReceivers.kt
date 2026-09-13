package com.must.orbit.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

private const val REMINDER_PROCESS_EXIT_DELAY_MILLIS = 250L

/**
 * The receivers live in a dedicated process. OriginOS freezes cached processes very
 * aggressively, including this process after a notification has been posted. Leaving
 * no cached receiver process lets AlarmManager start a fresh process for every alarm,
 * including while the screen is off.
 */
internal fun exitDedicatedReminderProcessSoon() {
    Handler(Looper.getMainLooper()).postDelayed(
        {
            if (!OrbitStrongReminderService.active && !OrbitStrongReminderService.starting) android.os.Process.killProcess(android.os.Process.myPid())
        },
        REMINDER_PROCESS_EXIT_DELAY_MILLIS,
    )
}

class OrbitReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val alarmId = intent.getIntExtra(OrbitReminderManager.alarmIdExtra, -1)
            if (alarmId < 0) return
            val record = OrbitReminderStore.get(context, alarmId) ?: return
            try {
                if (OrbitReminderManager.notificationsAllowed(context) && OrbitReminderLedger.claim(context, record)) OrbitReminderManager.postNotification(context, record)
            } finally {
                OrbitReminderStore.remove(context, alarmId)
                val meta=org.json.JSONObject(record.metadata)
                val rule=meta.optString("ruleId")
                if(OrbitReminderManager.notificationsAllowed(context) && rule.isNotEmpty() && rule!="null")
                    OrbitReminderLedger.replenish(context,rule,meta.getString("sessionId"))
            }
        } finally {
            exitDedicatedReminderProcessSoon()
        }
    }
}

class OrbitReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == "ack") {
                val rule=intent.getStringExtra("rule") ?: return
                val session=intent.getStringExtra("session") ?: return
                OrbitReminderLedger.acknowledge(context,rule,session)
                OrbitStrongReminderService.acknowledge(context,rule,session)
            } else if(intent.action=="stop") context.stopService(Intent(context, OrbitStrongReminderService::class.java))
        } finally { exitDedicatedReminderProcessSoon() }
    }
}

class OrbitReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending=goAsync()
        Thread {try {OrbitReminderManager.restorePersistedReminders(context)}
            finally {pending?.finish();exitDedicatedReminderProcessSoon()}}.start()
    }
}

class OrbitReminderMaintenanceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending=goAsync()
        Thread {try {OrbitReminderManager.restorePersistedReminders(context)}
            finally {pending?.finish();exitDedicatedReminderProcessSoon()}}.start()
    }
}
