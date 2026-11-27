package com.must.orbit.orbit

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

data class WidgetSessionItem(
    val id: String,
    val courseName: String,
    val courseCode: String,
    val section: String,
    val classType: String,
    val room: String,
    val teachers: List<String>,
    val kind: String,
    val semester: String,
    val startAt: LocalDateTime,
    val endAt: LocalDateTime,
    val startMillis: Long,
    val endMillis: Long,
    val seriesKey: String,
) {
    val isExam: Boolean get() = kind == "exam"

    val displayName: String
        get() = if (isExam) {
            val prefix = classType.ifBlank { "Exam" }
            "[$prefix] $courseName"
        } else {
            courseName
        }

    fun isOngoing(nowMillis: Long): Boolean = startMillis <= nowMillis && endMillis > nowMillis
    fun isEnded(nowMillis: Long): Boolean = endMillis <= nowMillis
    fun isUpcoming(nowMillis: Long): Boolean = startMillis > nowMillis
}

data class WidgetDeadlineItem(
    val id: String,
    val subject: String,
    val title: String,
    val dueAtMillis: Long,
    val dueAtLocal: LocalDateTime,
)

data class OrbitWidgetSnapshot(
    val nowMillis: Long,
    val today: LocalDate,
    val todaySessions: List<WidgetSessionItem>,
    val ongoingSession: WidgetSessionItem?,
    val nextTodaySession: WidgetSessionItem?,
    val tomorrowFirstSession: WidgetSessionItem?,
    val upcomingDeadlines: List<WidgetDeadlineItem>,
    val nextRefreshAtMillis: Long,
)

object OrbitWidgetRepository {
    private val dateKeyFormatter = DateTimeFormatter.ISO_LOCAL_DATE

    fun loadSnapshot(
        context: Context,
        config: OrbitWidgetConfig = OrbitWidgetStore.load(context),
        nowMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): OrbitWidgetSnapshot {
        val dbPath = OrbitWidgetStore.resolveDatabasePath(context, config)
        val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        if (dbPath == null) {
            return OrbitWidgetSnapshot(
                nowMillis = nowMillis,
                today = today,
                todaySessions = emptyList(),
                ongoingSession = null,
                nextTodaySession = null,
                tomorrowFirstSession = null,
                upcomingDeadlines = emptyList(),
                nextRefreshAtMillis = computeNextRefreshAtMillis(nowMillis, zoneId, emptyList(), emptyList()),
            )
        }
        return loadSnapshotFromPath(
            dbPath = dbPath,
            config = config,
            nowMillis = nowMillis,
            zoneId = zoneId,
        )
    }

    internal fun loadSnapshotFromPath(
        dbPath: String,
        config: OrbitWidgetConfig,
        nowMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): OrbitWidgetSnapshot {
        val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        val tomorrow = today.plusDays(1)
        val db = try {
            SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
        } catch (_: Exception) {
            return emptySnapshot(nowMillis, today, zoneId)
        }

        return db.use { database ->
            try {
                database.rawQuery("PRAGMA busy_timeout = 5000", null).close()
            } catch (_: Exception) {
            }

            val todaySessions = querySessionsForDate(database, today.format(dateKeyFormatter), zoneId)
            val ongoingSession = todaySessions.firstOrNull { it.isOngoing(nowMillis) }
            val nextTodaySession = todaySessions.firstOrNull { it.isUpcoming(nowMillis) }
            val tomorrowFirst = if (ongoingSession == null && nextTodaySession == null) {
                querySessionsForDate(database, tomorrow.format(dateKeyFormatter), zoneId, limit = 1)
                    .firstOrNull()
            } else {
                null
            }
            val deadlines = if (config.showDeadlines) {
                queryDeadlines(database, today, config.deadlineLookaheadDays, zoneId)
            } else {
                emptyList()
            }
            OrbitWidgetSnapshot(
                nowMillis = nowMillis,
                today = today,
                todaySessions = todaySessions,
                ongoingSession = ongoingSession,
                nextTodaySession = nextTodaySession,
                tomorrowFirstSession = tomorrowFirst,
                upcomingDeadlines = deadlines,
                nextRefreshAtMillis = computeNextRefreshAtMillis(
                    nowMillis = nowMillis,
                    zoneId = zoneId,
                    todaySessions = todaySessions,
                    upcomingDeadlines = deadlines,
                ),
            )
        }
    }

    private fun emptySnapshot(nowMillis: Long, today: LocalDate, zoneId: ZoneId) = OrbitWidgetSnapshot(
        nowMillis = nowMillis,
        today = today,
        todaySessions = emptyList(),
        ongoingSession = null,
        nextTodaySession = null,
        tomorrowFirstSession = null,
        upcomingDeadlines = emptyList(),
        nextRefreshAtMillis = computeNextRefreshAtMillis(nowMillis, zoneId, emptyList(), emptyList()),
    )

    private fun querySessionsForDate(
        db: SQLiteDatabase,
        dateKey: String,
        zoneId: ZoneId,
        limit: Int? = null,
    ): List<WidgetSessionItem> = try {
        val columns = tableColumns(db, "course_sessions")
        if (columns.isEmpty()) return emptyList()
        val selectCols = listOfNotNull(
            "id",
            "class_type",
            "room",
            "course_name",
            "course_code",
            "section",
            "start_at",
            "end_at",
            "teachers",
            "semester",
            if (columns.contains("kind")) "kind" else "'course' AS kind",
            if (columns.contains("recurrence_series_id")) "recurrence_series_id" else "NULL AS recurrence_series_id",
            if (columns.contains("linked_course_key")) "linked_course_key" else "NULL AS linked_course_key",
        ).joinToString(", ")
        val archiveFilter = if (columns.contains("archived_at") && columns.contains("archive_hidden")) {
            " AND (archived_at IS NULL OR archive_hidden = 0)"
        } else {
            ""
        }
        val deletedFilter = if (columns.contains("deleted_at")) " AND deleted_at IS NULL" else ""
        val limitClause = if (limit != null) " LIMIT $limit" else ""
        val sql = "SELECT $selectCols FROM course_sessions WHERE date = ?$deletedFilter$archiveFilter ORDER BY start_at ASC$limitClause"

        buildList {
            db.rawQuery(sql, arrayOf(dateKey)).use { cursor ->
                while (cursor.moveToNext()) {
                    val startAt = parseLocalDateTime(cursor.getString(6), zoneId) ?: continue
                    val endAt = parseLocalDateTime(cursor.getString(7), zoneId) ?: continue
                    val id = cursor.getString(0)
                    val classType = cursor.getString(1) ?: ""
                    val room = cursor.getString(2) ?: ""
                    val courseName = cursor.getString(3) ?: ""
                    val courseCode = cursor.getString(4) ?: ""
                    val section = cursor.getString(5) ?: ""
                    val teachers = parseTeachers(cursor.getString(8))
                    val semester = cursor.getString(9) ?: ""
                    val kind = cursor.getString(10) ?: "course"
                    val recurrenceSeriesId = cursor.getString(11)
                    val linkedCourseKey = cursor.getString(12)
                    add(
                        WidgetSessionItem(
                            id = id,
                            courseName = courseName,
                            courseCode = courseCode,
                            section = section,
                            classType = classType,
                            room = room,
                            teachers = teachers,
                            kind = kind,
                            semester = semester,
                            startAt = startAt,
                            endAt = endAt,
                            startMillis = startAt.atZone(zoneId).toInstant().toEpochMilli(),
                            endMillis = endAt.atZone(zoneId).toInstant().toEpochMilli(),
                            seriesKey = computeSeriesKey(
                                id = id,
                                kind = kind,
                                linkedCourseKey = linkedCourseKey,
                                recurrenceSeriesId = recurrenceSeriesId,
                                courseCode = courseCode,
                                courseName = courseName,
                                section = section,
                            ),
                        ),
                    )
                }
            }
        }
    } catch (_: Exception) {
        emptyList()
    }

    private fun queryDeadlines(
        db: SQLiteDatabase,
        today: LocalDate,
        lookaheadDays: Int,
        zoneId: ZoneId,
    ): List<WidgetDeadlineItem> = try {
        val columns = tableColumns(db, "deadlines")
        if (columns.isEmpty()) return emptyList()
        val windowEndUtc = today
            .plusDays((lookaheadDays - 1).coerceAtLeast(0).toLong())
            .atTime(23, 59, 59, 999_000_000)
            .atZone(zoneId)
            .toInstant()
            .atOffset(ZoneOffset.UTC)
            .format(DateTimeFormatter.ISO_INSTANT)

        val archiveFilter = if (columns.contains("archived_at") && columns.contains("archive_hidden")) {
            " AND (archived_at IS NULL OR archive_hidden = 0)"
        } else {
            ""
        }
        val sql = "SELECT id, subject, title, due_at FROM deadlines " +
            "WHERE deleted_at IS NULL AND completed_at IS NULL$archiveFilter AND due_at <= ? " +
            "ORDER BY due_at ASC LIMIT 20"

        buildList {
            db.rawQuery(sql, arrayOf(windowEndUtc)).use { cursor ->
                while (cursor.moveToNext()) {
                    val instant = parseInstant(cursor.getString(3)) ?: continue
                    add(
                        WidgetDeadlineItem(
                            id = cursor.getString(0),
                            subject = cursor.getString(1) ?: "",
                            title = cursor.getString(2) ?: "",
                            dueAtMillis = instant.toEpochMilli(),
                            dueAtLocal = instant.atZone(zoneId).toLocalDateTime(),
                        ),
                    )
                }
            }
        }
    } catch (_: Exception) {
        emptyList()
    }

    private fun tableColumns(db: SQLiteDatabase, table: String): Set<String> = buildSet {
        db.rawQuery("PRAGMA table_info($table)", null).use { cursor ->
            val idx = cursor.getColumnIndex("name")
            while (cursor.moveToNext()) {
                if (idx >= 0) add(cursor.getString(idx))
            }
        }
    }

    internal fun computeNextRefreshAtMillis(
        nowMillis: Long,
        zoneId: ZoneId,
        todaySessions: List<WidgetSessionItem>,
        upcomingDeadlines: List<WidgetDeadlineItem>,
    ): Long {
        val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        val midnightMillis = today.plusDays(1)
            .atStartOfDay(zoneId)
            .plusSeconds(5)
            .toInstant()
            .toEpochMilli()
        val candidates = buildList {
            add(midnightMillis)
            for (s in todaySessions) {
                val startTrigger = s.startMillis + 2_000L
                val endTrigger = s.endMillis + 2_000L
                if (startTrigger > nowMillis) add(startTrigger)
                if (endTrigger > nowMillis) add(endTrigger)
            }
            for (d in upcomingDeadlines) {
                val dueTrigger = d.dueAtMillis + 2_000L
                if (dueTrigger > nowMillis) add(dueTrigger)
            }
        }
        val minTrigger = candidates.minOrNull() ?: midnightMillis
        return maxOf(minTrigger, nowMillis + 5_000L)
    }

    internal fun computeSeriesKey(
        id: String,
        kind: String,
        linkedCourseKey: String?,
        recurrenceSeriesId: String?,
        courseCode: String,
        courseName: String,
        section: String,
    ): String {
        if (kind == "exam") return "exam|$id"
        if (!linkedCourseKey.isNullOrEmpty()) return linkedCourseKey
        if (!recurrenceSeriesId.isNullOrEmpty()) return "recurrence:$recurrenceSeriesId"
        val code = normalizeKeyPart(courseCode)
        val sec = normalizeKeyPart(section)
        val identity = if (code.isNotEmpty() && !code.startsWith("manual|")) {
            "code:$code"
        } else {
            "name:${normalizeKeyPart(courseName)}"
        }
        return "$identity|section:$sec"
    }

    private fun normalizeKeyPart(value: String): String =
        value.trim().lowercase().replace(Regex("\\s+"), " ")

    private fun parseTeachers(raw: String?): List<String> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val v = arr.optString(i).trim()
                    if (v.isNotEmpty()) add(v)
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun parseLocalDateTime(raw: String?, zoneId: ZoneId): LocalDateTime? {
        if (raw.isNullOrBlank()) return null
        return try {
            LocalDateTime.parse(raw)
        } catch (_: Exception) {
            try {
                OffsetDateTime.parse(raw).atZoneSameInstant(zoneId).toLocalDateTime()
            } catch (_: Exception) {
                try {
                    Instant.parse(raw).atZone(zoneId).toLocalDateTime()
                } catch (_: Exception) {
                    null
                }
            }
        }
    }

    private fun parseInstant(raw: String?): Instant? {
        if (raw.isNullOrBlank()) return null
        return try {
            Instant.parse(raw)
        } catch (_: Exception) {
            try {
                OffsetDateTime.parse(raw).toInstant()
            } catch (_: Exception) {
                try {
                    LocalDateTime.parse(raw).atZone(ZoneId.systemDefault()).toInstant()
                } catch (_: Exception) {
                    null
                }
            }
        }
    }
}
