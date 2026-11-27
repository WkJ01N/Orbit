package com.must.orbit.orbit

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

internal enum class OrbitWidgetLocale { EN, ZH_HANS, ZH_HANT }

internal class OrbitWidgetStrings(private val locale: OrbitWidgetLocale) {
    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.US)

    private fun pick(en: String, hans: String, hant: String): String = when (locale) {
        OrbitWidgetLocale.EN -> en
        OrbitWidgetLocale.ZH_HANS -> hans
        OrbitWidgetLocale.ZH_HANT -> hant
    }

    val ongoingBadge: String get() = pick("In progress", "进行中", "進行中")
    val examBadge: String get() = pick("Exam", "考试", "考試")
    val nextClassBadge: String get() = pick("Next class", "下一节", "下一節")
    val upcomingDdlBadge: String get() = pick("DDL", "DDL", "DDL")
    val endedLabel: String get() = pick("Ended", "已结束", "已結束")
    val todayEmptyTitle: String get() = pick("No classes today", "今日无课", "今日無課")
    val todayFinishedTitle: String get() = pick("All done today", "今日课程已结束", "今日課程已結束")
    val todayEmptySubtitle: String get() = pick("Tap to open Orbit", "点击打开 Orbit 查看课表", "點擊開啟 Orbit 檢視課表")
    val ddlSectionHeader: String get() = pick("Upcoming DDLs", "近期 DDL", "近期 DDL")
    val overdueLabel: String get() = pick("Overdue", "已逾期", "已逾期")
    val noLocationFallback: String get() = pick("Room TBA", "地点待定", "地點待定")

    fun formatTime(dt: LocalDateTime): String = dt.format(timeFormatter)

    fun formatTimeRange(start: LocalDateTime, end: LocalDateTime): String =
        "${formatTime(start)} - ${formatTime(end)}"

    fun endsIn(minutes: Long): String {
        val m = minutes.coerceAtLeast(1)
        return if (m < 60) {
            pick("${m}m left", "还剩 $m 分钟", "還剩 $m 分鐘")
        } else {
            val h = m / 60
            val rem = m % 60
            if (rem == 0L) {
                pick("${h}h left", "还剩 $h 小时", "還剩 $h 小時")
            } else {
                pick("${h}h ${rem}m left", "还剩 $h 小时 $rem 分", "還剩 $h 小時 $rem 分")
            }
        }
    }

    fun startsIn(minutes: Long): String {
        val m = minutes.coerceAtLeast(1)
        return if (m < 60) {
            pick("In ${m}m", "$m 分钟后", "$m 分鐘後")
        } else {
            val h = m / 60
            val rem = m % 60
            if (rem == 0L) {
                pick("In ${h}h", "$h 小时后", "$h 小時後")
            } else {
                pick("In ${h}h ${rem}m", "$h 小时 $rem 分后", "$h 小時 $rem 分後")
            }
        }
    }

    fun tomorrowPrefix(summary: String): String =
        pick("Tomorrow: $summary", "明日首节：$summary", "明日首節：$summary")

    fun pendingDeadlinesSummary(count: Int): String =
        pick("$count pending DDLs", "$count 项待完成 DDL", "$count 項待完成 DDL")

    fun headerDate(today: LocalDate): String = when (locale) {
        OrbitWidgetLocale.EN -> today.format(DateTimeFormatter.ofPattern("EEE, MMM d", Locale.ENGLISH))
        OrbitWidgetLocale.ZH_HANS -> "${today.monthValue}月${today.dayOfMonth}日 ${weekdayZh(today.dayOfWeek.value, hant = false)}"
        OrbitWidgetLocale.ZH_HANT -> "${today.monthValue}月${today.dayOfMonth}日 ${weekdayZh(today.dayOfWeek.value, hant = true)}"
    }

    fun headerSummary(totalSessions: Int, remainingSessions: Int, deadlineCount: Int): String {
        val coursePart = when {
            totalSessions == 0 -> pick("No classes today", "今日无课", "今日無課")
            remainingSessions == 0 -> pick("All $totalSessions done", "今日 $totalSessions 节已结束", "今日 $totalSessions 節已結束")
            else -> pick("$remainingSessions/$totalSessions left", "剩余 $remainingSessions/$totalSessions 节", "剩餘 $remainingSessions/$totalSessions 節")
        }
        return if (deadlineCount > 0) {
            "$coursePart · ${pick("$deadlineCount DDL", "$deadlineCount 项 DDL", "$deadlineCount 項 DDL")}"
        } else {
            coursePart
        }
    }

    fun formatDeadlineDue(dueLocal: LocalDateTime, today: LocalDate, nowMillis: Long, dueMillis: Long): String {
        if (dueMillis < nowMillis) return overdueLabel
        val dueDate = dueLocal.toLocalDate()
        val timeText = formatTime(dueLocal)
        return when {
            dueDate == today -> pick("Today $timeText", "今天 $timeText", "今天 $timeText")
            dueDate == today.plusDays(1) -> pick("Tomorrow $timeText", "明天 $timeText", "明天 $timeText")
            else -> "${dueDate.monthValue}/${dueDate.dayOfMonth} $timeText"
        }
    }

    private fun weekdayZh(weekday: Int, hant: Boolean): String = when (weekday) {
        1 -> if (hant) "週一" else "周一"
        2 -> if (hant) "週二" else "周二"
        3 -> if (hant) "週三" else "周三"
        4 -> if (hant) "週四" else "周四"
        5 -> if (hant) "週五" else "周五"
        6 -> if (hant) "週六" else "周六"
        else -> if (hant) "週日" else "周日"
    }

    companion object {
        fun forConfig(config: OrbitWidgetConfig): OrbitWidgetStrings =
            OrbitWidgetStrings(resolveLocale(config.localeTag))

        internal fun resolveLocale(tag: String?): OrbitWidgetLocale {
            val normalized = tag?.trim()?.replace('-', '_')?.lowercase(Locale.US)
            return when {
                normalized == "en" -> OrbitWidgetLocale.EN
                normalized == "zh_hans" -> OrbitWidgetLocale.ZH_HANS
                normalized == "zh_hant" -> OrbitWidgetLocale.ZH_HANT
                else -> {
                    val sys = Locale.getDefault()
                    if (sys.language != "zh") {
                        OrbitWidgetLocale.EN
                    } else if (sys.script.equals("Hans", ignoreCase = true) ||
                        sys.country.equals("CN", ignoreCase = true) ||
                        sys.country.equals("SG", ignoreCase = true)
                    ) {
                        OrbitWidgetLocale.ZH_HANS
                    } else {
                        OrbitWidgetLocale.ZH_HANT
                    }
                }
            }
        }
    }
}
