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
private fun exitDedicatedReminderProcessSoon() {
    Handler(Looper.getMainLooper()).postDelayed(
        {
            android.os.Process.killProcess(android.os.Process.myPid())
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
                OrbitReminderManager.postNotification(context, record)
            } finally {
                OrbitReminderStore.remove(context, alarmId)
            }
        } finally {
            exitDedicatedReminderProcessSoon()
        }
    }
}

class OrbitReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            OrbitReminderManager.restorePersistedReminders(context)
        } finally {
            exitDedicatedReminderProcessSoon()
        }
    }
}

class OrbitReminderMaintenanceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            OrbitReminderManager.restorePersistedReminders(context)
        } finally {
            exitDedicatedReminderProcessSoon()
        }
    }
}
