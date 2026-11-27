package com.must.orbit.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class OrbitWidgetBoundaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!OrbitWidgetUpdater.hasActiveWidgets(context)) {
            OrbitWidgetUpdater.cancelBoundaryAlarm(context)
            return
        }
        val pending = goAsync()
        Thread {
            try {
                OrbitWidgetUpdater.refreshAll(context.applicationContext)
            } catch (_: Exception) {
            } finally {
                pending?.finish()
            }
        }.start()
    }
}
