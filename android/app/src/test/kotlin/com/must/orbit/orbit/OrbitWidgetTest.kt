package com.must.orbit.orbit

import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OrbitWidgetTest {
    private lateinit var context: Context
    private lateinit var dbFile: File
    private lateinit var db: SQLiteDatabase
    private val zone: ZoneId = ZoneId.of("Asia/Shanghai")

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        OrbitWidgetStore.clear(context)
        context.deleteDatabase("widget_test.db")
        dbFile = context.getDatabasePath("widget_test.db")
        dbFile.parentFile?.mkdirs()
        db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
        db.execSQL(
            """
            CREATE TABLE course_sessions (
                id TEXT PRIMARY KEY,
                class_type TEXT NOT NULL,
                room TEXT NOT NULL,
                date TEXT NOT NULL,
                weekday INTEGER NOT NULL,
                course_name TEXT NOT NULL,
                course_code TEXT NOT NULL,
                section TEXT NOT NULL,
                start_at TEXT NOT NULL,
                end_at TEXT NOT NULL,
                teachers TEXT NOT NULL,
                faculty TEXT NOT NULL,
                semester TEXT NOT NULL,
                deleted_at TEXT,
                recurrence_series_id TEXT,
                kind TEXT NOT NULL DEFAULT 'course',
                archived_at TEXT,
                archive_hidden INTEGER NOT NULL DEFAULT 0,
                linked_course_key TEXT
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE deadlines (
                id TEXT PRIMARY KEY,
                subject TEXT NOT NULL,
                title TEXT NOT NULL,
                due_at TEXT NOT NULL,
                lead_minutes TEXT NOT NULL,
                completed_at TEXT,
                deleted_at TEXT,
                archived_at TEXT,
                archive_hidden INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent(),
        )
        OrbitWidgetStore.save(
            context,
            OrbitWidgetConfig(
                databasePath = dbFile.absolutePath,
                localeTag = "zh_Hans",
                themeStyle = "colorful",
                showDeadlines = true,
                deadlineLookaheadDays = 3,
                courseColorsLight = mapOf("code:cs101|section:a" to 0xFF123456.toInt()),
                courseColorsDark = mapOf("code:cs101|section:a" to 0xFF654321.toInt()),
            ),
        )
    }

    @After
    fun teardown() {
        db.close()
        dbFile.delete()
        OrbitWidgetStore.clear(context)
    }

    private fun insertSession(
        id: String,
        date: String,
        start: String,
        end: String,
        name: String = "Algorithms",
        code: String = "CS101",
        section: String = "A",
        room: String = "A204",
        kind: String = "course",
        classType: String = "Lecture",
        deletedAt: String? = null,
        archivedAt: String? = null,
        archiveHidden: Int = 0,
    ) {
        db.execSQL(
            """
            INSERT INTO course_sessions(
                id, class_type, room, date, weekday, course_name, course_code, section,
                start_at, end_at, teachers, faculty, semester, deleted_at, kind,
                archived_at, archive_hidden
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """.trimIndent(),
            arrayOf<Any?>(
                id, classType, room, date, 5, name, code, section,
                start, end, "[\"Prof. Chen\"]", "FIE", "2026", deletedAt, kind,
                archivedAt, archiveHidden,
            ),
        )
    }

    private fun insertDeadline(
        id: String,
        title: String,
        dueUtcIso: String,
        subject: String = "Algorithms",
        completedAt: String? = null,
        deletedAt: String? = null,
        archivedAt: String? = null,
        archiveHidden: Int = 0,
    ) {
        db.execSQL(
            """
            INSERT INTO deadlines(
                id, subject, title, due_at, lead_minutes, completed_at, deleted_at, archived_at, archive_hidden
            ) VALUES(?,?,?,?,?,?,?,?,?)
            """.trimIndent(),
            arrayOf<Any?>(
                id, subject, title, dueUtcIso, "[60]", completedAt, deletedAt, archivedAt, archiveHidden,
            ),
        )
    }

    private fun millis(y: Int, m: Int, d: Int, h: Int, min: Int): Long =
        LocalDateTime.of(y, m, d, h, min).atZone(zone).toInstant().toEpochMilli()

    @Test
    fun repositorySelectsOngoingOverUpcomingFiltersDeletedHiddenAndFindsTomorrowFallback() {
        insertSession("ended", "2026-11-27", "2026-11-27T08:00:00", "2026-11-27T09:00:00", name = "Early")
        insertSession("ongoing", "2026-11-27", "2026-11-27T10:00:00", "2026-11-27T11:30:00", name = "Ongoing")
        insertSession("next", "2026-11-27", "2026-11-27T14:00:00", "2026-11-27T15:30:00", name = "Afternoon")
        insertSession("deleted", "2026-11-27", "2026-11-27T10:15:00", "2026-11-27T11:00:00", deletedAt = "2026-11-27T09:00:00")
        insertSession("hidden", "2026-11-27", "2026-11-27T12:00:00", "2026-11-27T13:00:00", archivedAt = "2026-11-27T01:00:00Z", archiveHidden = 1)
        insertSession("archived_visible", "2026-11-27", "2026-11-27T16:00:00", "2026-11-27T17:00:00", name = "VisibleArchive", archivedAt = "2026-11-27T01:00:00Z", archiveHidden = 0)
        insertSession("tomorrow_first", "2026-11-28", "2026-11-28T09:00:00", "2026-11-28T10:30:00", name = "Tomorrow")

        val config = OrbitWidgetStore.load(context)
        val duringOngoing = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = config,
            nowMillis = millis(2026, 11, 27, 10, 30),
            zoneId = zone,
        )
        assertEquals(listOf("ended", "ongoing", "next", "archived_visible"), duringOngoing.todaySessions.map { it.id })
        assertEquals("ongoing", duringOngoing.ongoingSession?.id)
        assertEquals("next", duringOngoing.nextTodaySession?.id)
        assertNull(duringOngoing.tomorrowFirstSession)

        val afterAllToday = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = config,
            nowMillis = millis(2026, 11, 27, 20, 0),
            zoneId = zone,
        )
        assertNull(afterAllToday.ongoingSession)
        assertNull(afterAllToday.nextTodaySession)
        assertEquals("tomorrow_first", afterAllToday.tomorrowFirstSession?.id)
    }

    @Test
    fun repositoryRespectsLookaheadWindowAndOverdueDeadlinesInUtc() {
        // 2026-11-27 23:00 Asia/Shanghai == 2026-11-27T15:00:00Z
        // Window of 1 day (today only) ends at 2026-11-27 23:59:59.999 Asia/Shanghai == 2026-11-27T15:59:59.999Z
        insertDeadline("overdue", "Past Lab", "2026-11-26T12:00:00Z")
        insertDeadline("today_late", "Tonight Report", "2026-11-27T15:00:00Z")
        insertDeadline("tomorrow", "Tomorrow Quiz", "2026-11-28T10:00:00Z")
        insertDeadline("far", "Next Week", "2026-12-03T10:00:00Z")
        insertDeadline("done", "Finished", "2026-11-27T12:00:00Z", completedAt = "2026-11-27T10:00:00Z")
        insertDeadline("deleted", "Removed", "2026-11-27T12:00:00Z", deletedAt = "2026-11-27T10:00:00Z")
        insertDeadline("hidden", "Hidden", "2026-11-27T12:00:00Z", archivedAt = "2026-11-27T10:00:00Z", archiveHidden = 1)

        val now = millis(2026, 11, 27, 12, 0)
        val threeDaySnap = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = OrbitWidgetStore.load(context).copy(deadlineLookaheadDays = 3),
            nowMillis = now,
            zoneId = zone,
        )
        assertEquals(listOf("overdue", "today_late", "tomorrow"), threeDaySnap.upcomingDeadlines.map { it.id })

        val oneDaySnap = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = OrbitWidgetStore.load(context).copy(deadlineLookaheadDays = 1),
            nowMillis = now,
            zoneId = zone,
        )
        assertEquals(listOf("overdue", "today_late"), oneDaySnap.upcomingDeadlines.map { it.id })

        val hiddenSnap = OrbitWidgetRepository.loadSnapshot(
            context = context,
            config = OrbitWidgetStore.load(context).copy(showDeadlines = false),
            nowMillis = now,
            zoneId = zone,
        )
        assertTrue(hiddenSnap.upcomingDeadlines.isEmpty())
    }

    @Test
    fun computeNextRefreshAtMillisPicksEarliestBoundary() {
        insertSession("c1", "2026-11-27", "2026-11-27T10:00:00", "2026-11-27T11:30:00")
        insertDeadline("d1", "Lab", LocalDateTime.of(2026, 11, 27, 10, 45).atZone(zone).withZoneSameInstant(ZoneOffset.UTC).toInstant().toString())
        val config = OrbitWidgetStore.load(context)

        val beforeStart = OrbitWidgetRepository.loadSnapshot(context, config, millis(2026, 11, 27, 9, 50), zone)
        assertEquals(millis(2026, 11, 27, 10, 0) + 2_000L, beforeStart.nextRefreshAtMillis)

        val duringBeforeDdl = OrbitWidgetRepository.loadSnapshot(context, config, millis(2026, 11, 27, 10, 10), zone)
        assertEquals(millis(2026, 11, 27, 10, 45) + 2_000L, duringBeforeDdl.nextRefreshAtMillis)

        val afterDdlBeforeEnd = OrbitWidgetRepository.loadSnapshot(context, config, millis(2026, 11, 27, 11, 0), zone)
        assertEquals(millis(2026, 11, 27, 11, 30) + 2_000L, afterDdlBeforeEnd.nextRefreshAtMillis)
    }

    @Test
    fun storeRoundTripAndCourseColorFallback() {
        val loaded = OrbitWidgetStore.load(context)
        assertEquals(0xFF123456.toInt(), OrbitWidgetStore.resolveCourseColor("code:cs101|section:a", "CS101", "Algorithms", false, loaded))
        assertEquals(0xFF654321.toInt(), OrbitWidgetStore.resolveCourseColor("code:cs101|section:a", "CS101", "Algorithms", true, loaded))

        val colorfulFallback = OrbitWidgetStore.resolveCourseColor("code:math201|section:b", "MATH201", "Calculus", false, loaded)
        assertTrue(colorfulFallback != loaded.paletteLight.primary)

        val standardMode = loaded.copy(themeStyle = "standard")
        assertEquals(
            loaded.paletteLight.primary,
            OrbitWidgetStore.resolveCourseColor("code:math201|section:b", "MATH201", "Calculus", false, standardMode),
        )
    }

    @Test
    fun updaterBuildsCompactAndSpaciousNextClassViewsAndDdlFallback() {
        insertSession("next", "2026-11-27", "2026-11-27T14:00:00", "2026-11-27T15:30:00", name = "Compiler Design", room = "B301")
        insertDeadline("d1", "Homework 5", "2026-11-27T15:00:00Z", subject = "Compilers")
        val config = OrbitWidgetStore.load(context)

        val beforeNext = OrbitWidgetRepository.loadSnapshot(context, config, millis(2026, 11, 27, 13, 45), zone)
        val compactViews = OrbitWidgetUpdater.buildNextClassViews(
            context = context,
            snapshot = beforeNext,
            config = config,
            options = Bundle().apply { putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 60) },
            zoneId = zone,
        )
        val compactRoot = compactViews.apply(context, FrameLayout(context))
        assertEquals("Compiler Design", compactRoot.findViewById<TextView>(R.id.widget_title).text.toString())
        assertEquals(View.GONE, compactRoot.findViewById<TextView>(R.id.widget_extra).visibility)

        val spaciousViews = OrbitWidgetUpdater.buildNextClassViews(
            context = context,
            snapshot = beforeNext,
            config = config,
            options = Bundle().apply { putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 120) },
            zoneId = zone,
        )
        val spaciousRoot = spaciousViews.apply(context, FrameLayout(context))
        assertEquals(View.VISIBLE, spaciousRoot.findViewById<TextView>(R.id.widget_extra).visibility)
        assertTrue(spaciousRoot.findViewById<TextView>(R.id.widget_extra).text.toString().contains("DDL"))

        val afterClasses = OrbitWidgetRepository.loadSnapshot(context, config, millis(2026, 11, 27, 20, 0), zone)
        val ddlFallback = OrbitWidgetUpdater.buildNextClassViews(context, afterClasses, config, zoneId = zone)
            .apply(context, FrameLayout(context))
        assertEquals("Homework 5", ddlFallback.findViewById<TextView>(R.id.widget_title).text.toString())
    }

    @Test
    fun todayScheduleFactoryAndUpdaterManageRowsAndBoundaryAlarm() {
        insertSession("s1", "2026-11-27", "2026-11-27T09:00:00", "2026-11-27T10:30:00", name = "Math")
        insertSession("e1", "2026-11-27", "2026-11-27T14:00:00", "2026-11-27T16:00:00", name = "Physics", kind = "exam", classType = "Final")
        insertDeadline("d1", "Submit essay", "2026-11-28T10:00:00Z", subject = "Ethics")

        val factory = OrbitTodayScheduleFactory(context)
        factory.loadRows(nowMillis = millis(2026, 11, 27, 11, 0))
        // 2 sessions + 1 section header + 1 DDL row
        assertEquals(4, factory.count)
        assertEquals(3, factory.viewTypeCount)
        assertNotNull(factory.getViewAt(0).apply(context, FrameLayout(context)))
        assertNotNull(factory.getViewAt(2).apply(context, FrameLayout(context)))
        assertNotNull(factory.getViewAt(3).apply(context, FrameLayout(context)))

        val appWidgetManager = AppWidgetManager.getInstance(context)
        shadowOf(appWidgetManager).createWidget(OrbitNextClassWidgetProvider::class.java, R.layout.widget_next_class)
        assertTrue(OrbitWidgetUpdater.hasActiveWidgets(context))

        OrbitWidgetUpdater.refreshAll(context, nowMillis = millis(2026, 11, 27, 11, 0), zoneId = zone)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        assertFalse(shadowOf(alarmManager).scheduledAlarms.isEmpty())

        OrbitWidgetUpdater.cancelBoundaryAlarm(context)
        assertTrue(shadowOf(alarmManager).scheduledAlarms.isEmpty())
    }
}
