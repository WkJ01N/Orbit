package com.must.orbit.orbit

import android.content.Context
import android.content.Intent
import android.os.Binder
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

sealed interface OrbitTodayWidgetRow {
    data class SessionRow(val item: WidgetSessionItem) : OrbitTodayWidgetRow
    data class SectionHeaderRow(val title: String) : OrbitTodayWidgetRow
    data class DeadlineRow(val item: WidgetDeadlineItem) : OrbitTodayWidgetRow
}

class OrbitTodayScheduleService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        OrbitTodayScheduleFactory(applicationContext)
}

internal class OrbitTodayScheduleFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var config: OrbitWidgetConfig = OrbitWidgetConfig()
    private var snapshot: OrbitWidgetSnapshot = OrbitWidgetRepository.loadSnapshot(context, config)
    private var rows: List<OrbitTodayWidgetRow> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val token = Binder.clearCallingIdentity()
        try {
            loadRows(nowMillis = System.currentTimeMillis())
        } finally {
            Binder.restoreCallingIdentity(token)
        }
    }

    internal fun loadRows(nowMillis: Long = System.currentTimeMillis()) {
        val loadedConfig = OrbitWidgetStore.load(context)
        val loadedSnapshot = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = loadedConfig,
            nowMillis = nowMillis,
        )
        config = loadedConfig
        snapshot = loadedSnapshot
        val strings = OrbitWidgetStrings.forConfig(loadedConfig)
        rows = buildList {
            for (session in loadedSnapshot.todaySessions) {
                add(OrbitTodayWidgetRow.SessionRow(session))
            }
            if (loadedConfig.showDeadlines && loadedSnapshot.upcomingDeadlines.isNotEmpty()) {
                add(OrbitTodayWidgetRow.SectionHeaderRow(strings.ddlSectionHeader))
                for (deadline in loadedSnapshot.upcomingDeadlines) {
                    add(OrbitTodayWidgetRow.DeadlineRow(deadline))
                }
            }
        }
    }

    internal fun rowsSnapshot(): List<OrbitTodayWidgetRow> = rows

    override fun onDestroy() {
        rows = emptyList()
    }

    override fun getCount(): Int = rows.size

    override fun getViewTypeCount(): Int = 3

    override fun getLoadingView(): RemoteViews? = null

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun getViewAt(position: Int): RemoteViews {
        val row = rows.getOrNull(position) ?: return RemoteViews(context.packageName, R.layout.widget_section_header)
        val strings = OrbitWidgetStrings.forConfig(config)
        val isDark = OrbitWidgetStore.isDark(context, config)
        val palette = if (isDark) config.paletteDark else config.paletteLight
        val baseOpacityFactor = OrbitWidgetUpdater.opacityAlpha(config.backgroundOpacity)

        return when (row) {
            is OrbitTodayWidgetRow.SessionRow -> buildSessionRow(
                session = row.item,
                strings = strings,
                isDark = isDark,
                palette = palette,
                baseOpacityFactor = baseOpacityFactor,
            )
            is OrbitTodayWidgetRow.SectionHeaderRow -> {
                RemoteViews(context.packageName, R.layout.widget_section_header).apply {
                    setTextViewText(R.id.widget_section_title, row.title)
                    setTextColor(R.id.widget_section_title, palette.primary)
                }
            }
            is OrbitTodayWidgetRow.DeadlineRow -> buildDeadlineRow(
                deadline = row.item,
                strings = strings,
                palette = palette,
                baseOpacityFactor = baseOpacityFactor,
            )
        }
    }

    private fun buildSessionRow(
        session: WidgetSessionItem,
        strings: OrbitWidgetStrings,
        isDark: Boolean,
        palette: OrbitWidgetPalette,
        baseOpacityFactor: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_row)
        val ongoing = session.isOngoing(snapshot.nowMillis)
        val ended = session.isEnded(snapshot.nowMillis)
        val accent = OrbitWidgetStore.resolveCourseColor(
            seriesKey = session.seriesKey,
            courseCode = session.courseCode,
            courseName = session.courseName,
            isDark = isDark,
            config = config,
        )
        val rowBg = if (ongoing) palette.primaryContainer else palette.surfaceContainer
        val rowAlpha = if (ended) (baseOpacityFactor * 140) / 255 else (baseOpacityFactor * 230) / 255
        val titleColor = if (ongoing) {
            palette.onPrimaryContainer
        } else if (ended) {
            OrbitWidgetUpdater.withAlpha(palette.onSurface, 145)
        } else {
            palette.onSurface
        }
        val metaColor = if (ongoing) {
            palette.onPrimaryContainer
        } else if (ended) {
            OrbitWidgetUpdater.withAlpha(palette.onSurfaceVariant, 130)
        } else {
            palette.onSurfaceVariant
        }

        views.setInt(R.id.widget_row_bg, "setColorFilter", OrbitWidgetUpdater.opaqueColor(rowBg))
        views.setInt(R.id.widget_row_bg, "setImageAlpha", rowAlpha.coerceIn(70, 255))
        views.setInt(R.id.widget_row_accent, "setColorFilter", OrbitWidgetUpdater.opaqueColor(accent))
        views.setInt(R.id.widget_row_accent, "setImageAlpha", if (ended) 120 else 255)

        views.setTextViewText(R.id.widget_row_start, strings.formatTime(session.startAt))
        views.setTextColor(R.id.widget_row_start, titleColor)
        views.setTextViewText(R.id.widget_row_end, strings.formatTime(session.endAt))
        views.setTextColor(R.id.widget_row_end, metaColor)

        views.setTextViewText(R.id.widget_row_title, session.displayName)
        views.setTextColor(R.id.widget_row_title, titleColor)
        val room = session.room.ifBlank { strings.noLocationFallback }
        views.setTextViewText(R.id.widget_row_meta, room)
        views.setTextColor(R.id.widget_row_meta, metaColor)

        when {
            ongoing -> {
                views.setViewVisibility(R.id.widget_row_status, View.VISIBLE)
                views.setTextViewText(R.id.widget_row_status, strings.ongoingBadge)
                views.setTextColor(R.id.widget_row_status, palette.primary)
            }
            ended -> {
                views.setViewVisibility(R.id.widget_row_status, View.VISIBLE)
                views.setTextViewText(R.id.widget_row_status, strings.endedLabel)
                views.setTextColor(R.id.widget_row_status, metaColor)
            }
            session.isExam -> {
                views.setViewVisibility(R.id.widget_row_status, View.VISIBLE)
                views.setTextViewText(R.id.widget_row_status, strings.examBadge)
                views.setTextColor(R.id.widget_row_status, palette.error)
            }
            else -> views.setViewVisibility(R.id.widget_row_status, View.GONE)
        }

        views.setOnClickFillInIntent(
            R.id.widget_row_root,
            Intent().putExtra(OrbitReminderManager.payloadExtra, session.id),
        )
        return views
    }

    private fun buildDeadlineRow(
        deadline: WidgetDeadlineItem,
        strings: OrbitWidgetStrings,
        palette: OrbitWidgetPalette,
        baseOpacityFactor: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_deadline_row)
        val overdue = deadline.dueAtMillis < snapshot.nowMillis
        val accent = if (overdue) palette.error else palette.primary
        val rowBg = if (overdue) palette.errorContainer else palette.surfaceContainer
        val titleColor = if (overdue) palette.onErrorContainer else palette.onSurface
        val subColor = if (overdue) palette.onErrorContainer else palette.onSurfaceVariant
        val dueText = strings.formatDeadlineDue(
            dueLocal = deadline.dueAtLocal,
            today = snapshot.today,
            nowMillis = snapshot.nowMillis,
            dueMillis = deadline.dueAtMillis,
        )

        views.setInt(R.id.widget_ddl_bg, "setColorFilter", OrbitWidgetUpdater.opaqueColor(rowBg))
        views.setInt(
            R.id.widget_ddl_bg,
            "setImageAlpha",
            ((baseOpacityFactor * 225) / 255).coerceIn(80, 255),
        )
        views.setInt(R.id.widget_ddl_accent, "setColorFilter", OrbitWidgetUpdater.opaqueColor(accent))
        views.setTextViewText(R.id.widget_ddl_title, deadline.title)
        views.setTextColor(R.id.widget_ddl_title, titleColor)
        views.setTextViewText(R.id.widget_ddl_subject, deadline.subject)
        views.setTextColor(R.id.widget_ddl_subject, subColor)
        views.setTextViewText(R.id.widget_ddl_due, dueText)
        views.setTextColor(R.id.widget_ddl_due, accent)

        views.setOnClickFillInIntent(
            R.id.widget_ddl_root,
            Intent().putExtra(OrbitReminderManager.payloadExtra, "deadline:${deadline.id}"),
        )
        return views
    }
}
