package com.must.orbit.orbit

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.time.ZoneId
import java.util.concurrent.Executors
import kotlin.math.ceil

object OrbitWidgetUpdater {
    const val ACTION_BOUNDARY_REFRESH = "com.must.orbit.orbit.ACTION_WIDGET_BOUNDARY_REFRESH"
    const val ACTION_MANUAL_REFRESH = "com.must.orbit.orbit.ACTION_WIDGET_MANUAL_REFRESH"
    internal const val BOUNDARY_ALARM_REQUEST_CODE = 2_200_001
    private const val LAUNCH_REQUEST_CODE_BASE = 2_210_000

    private val refreshExecutor = Executors.newSingleThreadExecutor()

    fun refreshAllAsync(context: Context) {
        val appContext = context.applicationContext
        refreshExecutor.execute {
            refreshAll(appContext)
        }
    }

    fun hasActiveWidgets(context: Context): Boolean {
        val (nextCount, todayCount) = widgetCounts(context)
        return nextCount > 0 || todayCount > 0
    }

    fun widgetCounts(context: Context): Pair<Int, Int> {
        val manager = AppWidgetManager.getInstance(context) ?: return 0 to 0
        val nextIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitNextClassWidgetProvider::class.java),
        )
        val todayIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitTodayScheduleWidgetProvider::class.java),
        )
        return nextIds.size to todayIds.size
    }

    fun refreshAll(
        context: Context,
        nowMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault(),
    ) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        val nextIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitNextClassWidgetProvider::class.java),
        )
        val todayIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitTodayScheduleWidgetProvider::class.java),
        )
        if (nextIds.isEmpty() && todayIds.isEmpty()) {
            cancelBoundaryAlarm(context)
            return
        }

        val config = OrbitWidgetStore.load(context)
        val snapshot = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = config,
            nowMillis = nowMillis,
            zoneId = zoneId,
        )

        for (id in nextIds) {
            val options = manager.getAppWidgetOptions(id)
            val views = buildNextClassViews(
                context = context,
                snapshot = snapshot,
                config = config,
                options = options,
                zoneId = zoneId,
            )
            manager.updateAppWidget(id, views)
        }

        for (id in todayIds) {
            val views = buildTodayScheduleViews(
                context = context,
                appWidgetId = id,
                snapshot = snapshot,
                config = config,
            )
            manager.updateAppWidget(id, views)
        }
        if (todayIds.isNotEmpty()) {
            @Suppress("DEPRECATION")
            manager.notifyAppWidgetViewDataChanged(todayIds, R.id.widget_schedule_list)
        }

        scheduleNextBoundaryAlarm(context, snapshot.nextRefreshAtMillis)
    }

    internal fun buildNextClassViews(
        context: Context,
        snapshot: OrbitWidgetSnapshot,
        config: OrbitWidgetConfig,
        options: Bundle? = null,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_next_class)
        val strings = OrbitWidgetStrings.forConfig(config)
        val isDark = OrbitWidgetStore.isDark(context, config)
        val palette = if (isDark) config.paletteDark else config.paletteLight
        val bgAlpha = opacityAlpha(config.backgroundOpacity)
        val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        val spacious = minHeightDp >= 96

        views.setInt(R.id.widget_bg, "setColorFilter", opaqueColor(palette.surface))
        views.setInt(R.id.widget_bg, "setImageAlpha", bgAlpha)
        views.setInt(R.id.widget_refresh_btn, "setColorFilter", opaqueColor(palette.onSurfaceVariant))
        views.setOnClickPendingIntent(R.id.widget_refresh_btn, manualRefreshPendingIntent(context))

        val ongoing = snapshot.ongoingSession
        val nextToday = snapshot.nextTodaySession
        val urgentDdl = if (config.showDeadlines) snapshot.upcomingDeadlines.firstOrNull() else null
        val tomorrowFirst = snapshot.tomorrowFirstSession

        val focusSession = ongoing ?: nextToday
        if (focusSession != null) {
            val accent = OrbitWidgetStore.resolveCourseColor(
                seriesKey = focusSession.seriesKey,
                courseCode = focusSession.courseCode,
                courseName = focusSession.courseName,
                isDark = isDark,
                config = config,
            )
            val isOngoing = ongoing != null
            val badgeBg = when {
                isOngoing -> palette.primaryContainer
                focusSession.isExam -> palette.errorContainer
                else -> palette.surfaceContainer
            }
            val badgeTextColor = when {
                isOngoing -> palette.onPrimaryContainer
                focusSession.isExam -> palette.onErrorContainer
                else -> palette.onSurfaceVariant
            }
            val badgeLabel = when {
                isOngoing -> strings.ongoingBadge
                focusSession.isExam -> strings.examBadge
                else -> strings.nextClassBadge
            }
            val minutes = if (isOngoing) {
                ceil((focusSession.endMillis - snapshot.nowMillis) / 60_000.0).toLong()
            } else {
                ceil((focusSession.startMillis - snapshot.nowMillis) / 60_000.0).toLong()
            }
            val countdown = if (isOngoing) strings.endsIn(minutes) else strings.startsIn(minutes)

            views.setInt(R.id.widget_badge_bg, "setColorFilter", opaqueColor(badgeBg))
            views.setTextViewText(R.id.widget_badge_text, badgeLabel)
            views.setTextColor(R.id.widget_badge_text, badgeTextColor)
            views.setTextViewText(R.id.widget_countdown_text, countdown)
            views.setTextColor(
                R.id.widget_countdown_text,
                if (isOngoing) palette.primary else palette.onSurfaceVariant,
            )
            views.setInt(R.id.widget_accent_bar, "setColorFilter", opaqueColor(accent))
            views.setTextViewText(R.id.widget_title, focusSession.displayName)
            views.setTextColor(R.id.widget_title, palette.onSurface)
            views.setInt(R.id.widget_title, "setMaxLines", if (spacious) 2 else 1)

            val roomText = focusSession.room.ifBlank { strings.noLocationFallback }
            val timeRange = strings.formatTimeRange(focusSession.startAt, focusSession.endAt)
            views.setTextViewText(R.id.widget_subtitle, "$timeRange · $roomText")
            views.setTextColor(R.id.widget_subtitle, palette.onSurfaceVariant)

            val extraParts = buildList {
                if (isOngoing && nextToday != null) {
                    add("${strings.nextClassBadge}: ${strings.formatTime(nextToday.startAt)} ${nextToday.displayName}")
                } else if (focusSession.teachers.isNotEmpty()) {
                    add(focusSession.teachers.joinToString(", "))
                }
                if (config.showDeadlines && snapshot.upcomingDeadlines.isNotEmpty()) {
                    add(strings.pendingDeadlinesSummary(snapshot.upcomingDeadlines.size))
                }
            }
            if (spacious && extraParts.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_extra, View.VISIBLE)
                views.setTextViewText(R.id.widget_extra, extraParts.joinToString(" · "))
                views.setTextColor(R.id.widget_extra, palette.onSurfaceVariant)
            } else {
                views.setViewVisibility(R.id.widget_extra, View.GONE)
            }

            views.setOnClickPendingIntent(
                R.id.widget_body,
                launchActivityPendingIntent(
                    context = context,
                    requestCode = LAUNCH_REQUEST_CODE_BASE + 1,
                    payload = focusSession.id,
                ),
            )
            return views
        }

        if (urgentDdl != null) {
            val overdue = urgentDdl.dueAtMillis < snapshot.nowMillis
            val badgeBg = if (overdue) palette.errorContainer else palette.primaryContainer
            val badgeText = if (overdue) palette.onErrorContainer else palette.onPrimaryContainer
            val accent = if (overdue) palette.error else palette.primary
            val dueText = strings.formatDeadlineDue(
                dueLocal = urgentDdl.dueAtLocal,
                today = snapshot.today,
                nowMillis = snapshot.nowMillis,
                dueMillis = urgentDdl.dueAtMillis,
            )
            views.setInt(R.id.widget_badge_bg, "setColorFilter", opaqueColor(badgeBg))
            views.setTextViewText(
                R.id.widget_badge_text,
                if (overdue) strings.overdueLabel else strings.upcomingDdlBadge,
            )
            views.setTextColor(R.id.widget_badge_text, badgeText)
            views.setTextViewText(R.id.widget_countdown_text, dueText)
            views.setTextColor(R.id.widget_countdown_text, if (overdue) palette.error else palette.primary)
            views.setInt(R.id.widget_accent_bar, "setColorFilter", opaqueColor(accent))
            views.setTextViewText(R.id.widget_title, urgentDdl.title)
            views.setTextColor(R.id.widget_title, palette.onSurface)
            views.setInt(R.id.widget_title, "setMaxLines", if (spacious) 2 else 1)
            views.setTextViewText(
                R.id.widget_subtitle,
                urgentDdl.subject.ifBlank { strings.pendingDeadlinesSummary(snapshot.upcomingDeadlines.size) },
            )
            views.setTextColor(R.id.widget_subtitle, palette.onSurfaceVariant)
            if (spacious && tomorrowFirst != null) {
                views.setViewVisibility(R.id.widget_extra, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_extra,
                    strings.tomorrowPrefix("${strings.formatTime(tomorrowFirst.startAt)} ${tomorrowFirst.displayName}"),
                )
                views.setTextColor(R.id.widget_extra, palette.onSurfaceVariant)
            } else {
                views.setViewVisibility(R.id.widget_extra, View.GONE)
            }
            views.setOnClickPendingIntent(
                R.id.widget_body,
                launchActivityPendingIntent(
                    context = context,
                    requestCode = LAUNCH_REQUEST_CODE_BASE + 2,
                    payload = "deadline:${urgentDdl.id}",
                ),
            )
            return views
        }

        // Empty or finished day state
        views.setInt(R.id.widget_badge_bg, "setColorFilter", opaqueColor(palette.surfaceContainer))
        views.setTextViewText(R.id.widget_badge_text, strings.headerDate(snapshot.today))
        views.setTextColor(R.id.widget_badge_text, palette.onSurfaceVariant)
        views.setTextViewText(R.id.widget_countdown_text, "")
        views.setInt(R.id.widget_accent_bar, "setColorFilter", opaqueColor(palette.outlineVariant))

        val emptyTitle = if (snapshot.todaySessions.isNotEmpty()) {
            strings.todayFinishedTitle
        } else {
            strings.todayEmptyTitle
        }
        val emptySubtitle = if (tomorrowFirst != null) {
            strings.tomorrowPrefix("${strings.formatTime(tomorrowFirst.startAt)} ${tomorrowFirst.displayName}")
        } else {
            strings.todayEmptySubtitle
        }
        views.setTextViewText(R.id.widget_title, emptyTitle)
        views.setTextColor(R.id.widget_title, palette.onSurface)
        views.setTextViewText(R.id.widget_subtitle, emptySubtitle)
        views.setTextColor(R.id.widget_subtitle, palette.onSurfaceVariant)
        views.setViewVisibility(R.id.widget_extra, View.GONE)
        views.setOnClickPendingIntent(
            R.id.widget_body,
            launchActivityPendingIntent(
                context = context,
                requestCode = LAUNCH_REQUEST_CODE_BASE + 3,
                payload = tomorrowFirst?.id ?: "next_day",
            ),
        )
        return views
    }

    internal fun buildTodayScheduleViews(
        context: Context,
        appWidgetId: Int,
        snapshot: OrbitWidgetSnapshot,
        config: OrbitWidgetConfig,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today_schedule)
        val strings = OrbitWidgetStrings.forConfig(config)
        val palette = OrbitWidgetStore.paletteFor(context, config)
        val bgAlpha = opacityAlpha(config.backgroundOpacity)

        views.setInt(R.id.widget_bg, "setColorFilter", opaqueColor(palette.surface))
        views.setInt(R.id.widget_bg, "setImageAlpha", bgAlpha)
        views.setInt(R.id.widget_refresh_btn, "setColorFilter", opaqueColor(palette.onSurfaceVariant))
        views.setOnClickPendingIntent(R.id.widget_refresh_btn, manualRefreshPendingIntent(context))

        val remainingCount = snapshot.todaySessions.count { !it.isEnded(snapshot.nowMillis) }
        views.setTextViewText(R.id.widget_header_date, strings.headerDate(snapshot.today))
        views.setTextColor(R.id.widget_header_date, palette.onSurface)
        views.setTextViewText(
            R.id.widget_header_summary,
            strings.headerSummary(
                totalSessions = snapshot.todaySessions.size,
                remainingSessions = remainingCount,
                deadlineCount = snapshot.upcomingDeadlines.size,
            ),
        )
        views.setTextColor(R.id.widget_header_summary, palette.onSurfaceVariant)
        views.setOnClickPendingIntent(
            R.id.widget_header,
            launchActivityPendingIntent(
                context = context,
                requestCode = LAUNCH_REQUEST_CODE_BASE + 10,
                payload = "next_day",
            ),
        )

        val emptySubtitle = snapshot.tomorrowFirstSession?.let { next ->
            strings.tomorrowPrefix("${strings.formatTime(next.startAt)} ${next.displayName}")
        } ?: strings.todayEmptySubtitle
        views.setTextViewText(R.id.widget_empty_title, strings.todayEmptyTitle)
        views.setTextColor(R.id.widget_empty_title, palette.onSurface)
        views.setTextViewText(R.id.widget_empty_subtitle, emptySubtitle)
        views.setTextColor(R.id.widget_empty_subtitle, palette.onSurfaceVariant)
        views.setOnClickPendingIntent(
            R.id.widget_empty_view,
            launchActivityPendingIntent(
                context = context,
                requestCode = LAUNCH_REQUEST_CODE_BASE + 11,
                payload = "next_day",
            ),
        )

        val adapterIntent = Intent(context, OrbitTodayScheduleService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("orbit-widget://today/$appWidgetId")
        }
        @Suppress("DEPRECATION")
        views.setRemoteAdapter(R.id.widget_schedule_list, adapterIntent)
        views.setEmptyView(R.id.widget_schedule_list, R.id.widget_empty_view)
        views.setPendingIntentTemplate(
            R.id.widget_schedule_list,
            listTemplatePendingIntent(context),
        )
        return views
    }

    internal fun scheduleNextBoundaryAlarm(context: Context, triggerAtMillis: Long) {
        if (!hasActiveWidgets(context)) {
            cancelBoundaryAlarm(context)
            return
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = boundaryPendingIntent(context)
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        try {
            if (canExact) {
                alarmManager.setExact(AlarmManager.RTC, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC, triggerAtMillis, pendingIntent)
            }
        } catch (_: SecurityException) {
            alarmManager.set(AlarmManager.RTC, triggerAtMillis, pendingIntent)
        }
    }

    internal fun cancelBoundaryAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, OrbitWidgetBoundaryReceiver::class.java).apply {
            action = ACTION_BOUNDARY_REFRESH
        }
        val existing = PendingIntent.getBroadcast(
            context,
            BOUNDARY_ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        alarmManager.cancel(existing)
        existing.cancel()
    }

    private fun boundaryPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, OrbitWidgetBoundaryReceiver::class.java).apply {
            action = ACTION_BOUNDARY_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            BOUNDARY_ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun manualRefreshPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, OrbitWidgetBoundaryReceiver::class.java).apply {
            action = ACTION_MANUAL_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            BOUNDARY_ALARM_REQUEST_CODE + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun launchActivityPendingIntent(
        context: Context,
        requestCode: Int,
        payload: String?,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (payload != null) {
                putExtra(OrbitReminderManager.payloadExtra, payload)
            }
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun listTemplatePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val mutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        return PendingIntent.getActivity(
            context,
            LAUNCH_REQUEST_CODE_BASE + 20,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag,
        )
    }

    internal fun opacityAlpha(opacityPercent: Int): Int =
        (opacityPercent.coerceIn(35, 100) * 255) / 100

    internal fun opaqueColor(argb: Int): Int = argb or 0xFF000000.toInt()

    internal fun withAlpha(argb: Int, alpha: Int): Int =
        ((alpha.coerceIn(0, 255)) shl 24) or (argb and 0x00FFFFFF)
}
