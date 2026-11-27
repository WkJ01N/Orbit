package com.must.orbit.orbit

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

class OrbitTodayScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        OrbitWidgetUpdater.refreshAllAsync(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        OrbitWidgetUpdater.refreshAllAsync(context)
    }

    override fun onEnabled(context: Context) {
        OrbitWidgetUpdater.refreshAllAsync(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        if (!OrbitWidgetUpdater.hasActiveWidgets(context)) {
            OrbitWidgetUpdater.cancelBoundaryAlarm(context)
        }
    }

    override fun onDisabled(context: Context) {
        if (!OrbitWidgetUpdater.hasActiveWidgets(context)) {
            OrbitWidgetUpdater.cancelBoundaryAlarm(context)
        }
    }
}
