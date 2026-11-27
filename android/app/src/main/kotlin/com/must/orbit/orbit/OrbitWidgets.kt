package com.must.orbit.orbit

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object OrbitWidgets {
    private const val CHANNEL = "com.must.orbit.orbit/widgets"

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "syncConfig" -> {
                        val values = call.arguments as? Map<*, *>
                            ?: return@setMethodCallHandler result.error(
                                "invalid_arguments",
                                "Widget config arguments are missing",
                                null,
                            )
                        val config = OrbitWidgetConfig.fromMap(values)
                        OrbitWidgetStore.save(activity, config)
                        OrbitWidgetUpdater.refreshAllAsync(activity)
                        result.success(null)
                    }
                    "refreshWidgets" -> {
                        OrbitWidgetUpdater.refreshAllAsync(activity)
                        result.success(null)
                    }
                    "widgetStatus" -> {
                        val manager = AppWidgetManager.getInstance(activity)
                        val canPin = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            manager?.isRequestPinAppWidgetSupported == true
                        val (nextCount, todayCount) = OrbitWidgetUpdater.widgetCounts(activity)
                        result.success(
                            mapOf(
                                "canPin" to canPin,
                                "nextClassCount" to nextCount,
                                "todayScheduleCount" to todayCount,
                            ),
                        )
                    }
                    "requestPinWidget" -> {
                        val kind = call.argument<String>("kind")
                        val providerClass = when (kind) {
                            "nextClass" -> OrbitNextClassWidgetProvider::class.java
                            "todaySchedule" -> OrbitTodayScheduleWidgetProvider::class.java
                            else -> return@setMethodCallHandler result.error(
                                "invalid_arguments",
                                "Unknown widget kind: $kind",
                                null,
                            )
                        }
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val manager = AppWidgetManager.getInstance(activity)
                        if (manager == null || !manager.isRequestPinAppWidgetSupported) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val accepted = manager.requestPinAppWidget(
                            ComponentName(activity, providerClass),
                            null,
                            null,
                        )
                        result.success(accepted)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("widget_error", error.message ?: "Widget operation failed", null)
            }
        }
    }
}
