package com.must.orbit.orbit

import android.content.Context
import android.content.res.Configuration
import org.json.JSONObject
import java.io.File

data class OrbitWidgetPalette(
    val surface: Int,
    val surfaceContainer: Int,
    val onSurface: Int,
    val onSurfaceVariant: Int,
    val primary: Int,
    val primaryContainer: Int,
    val onPrimaryContainer: Int,
    val outlineVariant: Int,
    val error: Int,
    val errorContainer: Int,
    val onErrorContainer: Int,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("surface", surface)
        put("surfaceContainer", surfaceContainer)
        put("onSurface", onSurface)
        put("onSurfaceVariant", onSurfaceVariant)
        put("primary", primary)
        put("primaryContainer", primaryContainer)
        put("onPrimaryContainer", onPrimaryContainer)
        put("outlineVariant", outlineVariant)
        put("error", error)
        put("errorContainer", errorContainer)
        put("onErrorContainer", onErrorContainer)
    }

    companion object {
        val defaultLight = OrbitWidgetPalette(
            surface = 0xFFF4FBFB.toInt(),
            surfaceContainer = 0xFFE8F1F0.toInt(),
            onSurface = 0xFF161D1C.toInt(),
            onSurfaceVariant = 0xFF3F4947.toInt(),
            primary = 0xFF006A63.toInt(),
            primaryContainer = 0xFF9EF2E8.toInt(),
            onPrimaryContainer = 0xFF00201E.toInt(),
            outlineVariant = 0xFFBEC9C6.toInt(),
            error = 0xFFBA1A1A.toInt(),
            errorContainer = 0xFFFFDAD6.toInt(),
            onErrorContainer = 0xFF410002.toInt(),
        )

        val defaultDark = OrbitWidgetPalette(
            surface = 0xFF101817.toInt(),
            surfaceContainer = 0xFF1B2524.toInt(),
            onSurface = 0xFFDDE4E2.toInt(),
            onSurfaceVariant = 0xFFBEC9C6.toInt(),
            primary = 0xFF6DD8CD.toInt(),
            primaryContainer = 0xFF00504A.toInt(),
            onPrimaryContainer = 0xFF9EF2E8.toInt(),
            outlineVariant = 0xFF3F4947.toInt(),
            error = 0xFFFFB4AB.toInt(),
            errorContainer = 0xFF93000A.toInt(),
            onErrorContainer = 0xFFFFDAD6.toInt(),
        )

        fun fromJson(json: JSONObject?, fallback: OrbitWidgetPalette): OrbitWidgetPalette {
            if (json == null) return fallback
            return OrbitWidgetPalette(
                surface = json.optInt("surface", fallback.surface),
                surfaceContainer = json.optInt("surfaceContainer", fallback.surfaceContainer),
                onSurface = json.optInt("onSurface", fallback.onSurface),
                onSurfaceVariant = json.optInt("onSurfaceVariant", fallback.onSurfaceVariant),
                primary = json.optInt("primary", fallback.primary),
                primaryContainer = json.optInt("primaryContainer", fallback.primaryContainer),
                onPrimaryContainer = json.optInt("onPrimaryContainer", fallback.onPrimaryContainer),
                outlineVariant = json.optInt("outlineVariant", fallback.outlineVariant),
                error = json.optInt("error", fallback.error),
                errorContainer = json.optInt("errorContainer", fallback.errorContainer),
                onErrorContainer = json.optInt("onErrorContainer", fallback.onErrorContainer),
            )
        }
    }
}

data class OrbitWidgetConfig(
    val databasePath: String? = null,
    val localeTag: String? = null,
    val themeMode: String = "system",
    val themeStyle: String = "standard",
    val backgroundOpacity: Int = 92,
    val showDeadlines: Boolean = true,
    val deadlineLookaheadDays: Int = 3,
    val paletteLight: OrbitWidgetPalette = OrbitWidgetPalette.defaultLight,
    val paletteDark: OrbitWidgetPalette = OrbitWidgetPalette.defaultDark,
    val courseColorsLight: Map<String, Int> = emptyMap(),
    val courseColorsDark: Map<String, Int> = emptyMap(),
) {
    fun toJson(): JSONObject = JSONObject().apply {
        if (databasePath != null) put("databasePath", databasePath)
        if (localeTag != null) put("localeTag", localeTag)
        put("themeMode", themeMode)
        put("themeStyle", themeStyle)
        put("backgroundOpacity", backgroundOpacity.coerceIn(35, 100))
        put("showDeadlines", showDeadlines)
        put("deadlineLookaheadDays", normalizeLookaheadDays(deadlineLookaheadDays))
        put("paletteLight", paletteLight.toJson())
        put("paletteDark", paletteDark.toJson())
        put("courseColorsLight", JSONObject(courseColorsLight.mapValues { it.value }))
        put("courseColorsDark", JSONObject(courseColorsDark.mapValues { it.value }))
    }

    companion object {
        fun normalizeLookaheadDays(value: Int): Int = when (value) {
            1, 3, 7 -> value
            else -> 3
        }

        fun fromJson(json: JSONObject?): OrbitWidgetConfig {
            if (json == null) return OrbitWidgetConfig()
            return OrbitWidgetConfig(
                databasePath = json.optString("databasePath", "").takeIf { it.isNotBlank() && it != "null" },
                localeTag = json.optString("localeTag", "").takeIf { it.isNotBlank() && it != "null" },
                themeMode = json.optString("themeMode", "system"),
                themeStyle = json.optString("themeStyle", "standard"),
                backgroundOpacity = json.optInt("backgroundOpacity", 92).coerceIn(35, 100),
                showDeadlines = json.optBoolean("showDeadlines", true),
                deadlineLookaheadDays = normalizeLookaheadDays(json.optInt("deadlineLookaheadDays", 3)),
                paletteLight = OrbitWidgetPalette.fromJson(
                    json.optJSONObject("paletteLight"),
                    OrbitWidgetPalette.defaultLight,
                ),
                paletteDark = OrbitWidgetPalette.fromJson(
                    json.optJSONObject("paletteDark"),
                    OrbitWidgetPalette.defaultDark,
                ),
                courseColorsLight = parseColorMap(json.optJSONObject("courseColorsLight")),
                courseColorsDark = parseColorMap(json.optJSONObject("courseColorsDark")),
            )
        }

        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<*, *>): OrbitWidgetConfig {
            val lightRaw = (map["paletteLight"] as? Map<*, *>)?.let { toIntMap(it) }
            val darkRaw = (map["paletteDark"] as? Map<*, *>)?.let { toIntMap(it) }
            return OrbitWidgetConfig(
                databasePath = (map["databasePath"] as? String)?.takeIf { it.isNotBlank() },
                localeTag = (map["localeTag"] as? String)?.takeIf { it.isNotBlank() },
                themeMode = (map["themeMode"] as? String) ?: "system",
                themeStyle = (map["themeStyle"] as? String) ?: "standard",
                backgroundOpacity = ((map["backgroundOpacity"] as? Number)?.toInt() ?: 92).coerceIn(35, 100),
                showDeadlines = map["showDeadlines"] as? Boolean ?: true,
                deadlineLookaheadDays = normalizeLookaheadDays(
                    (map["deadlineLookaheadDays"] as? Number)?.toInt() ?: 3,
                ),
                paletteLight = if (lightRaw != null) {
                    OrbitWidgetPalette.fromJson(JSONObject(lightRaw), OrbitWidgetPalette.defaultLight)
                } else {
                    OrbitWidgetPalette.defaultLight
                },
                paletteDark = if (darkRaw != null) {
                    OrbitWidgetPalette.fromJson(JSONObject(darkRaw), OrbitWidgetPalette.defaultDark)
                } else {
                    OrbitWidgetPalette.defaultDark
                },
                courseColorsLight = toIntMap(map["courseColorsLight"] as? Map<*, *> ?: emptyMap<Any, Any>()),
                courseColorsDark = toIntMap(map["courseColorsDark"] as? Map<*, *> ?: emptyMap<Any, Any>()),
            )
        }

        private fun toIntMap(source: Map<*, *>): Map<String, Int> = buildMap {
            for ((k, v) in source) {
                val key = k as? String ?: continue
                val num = (v as? Number)?.toInt() ?: continue
                put(key, num)
            }
        }

        private fun parseColorMap(json: JSONObject?): Map<String, Int> {
            if (json == null) return emptyMap()
            return buildMap {
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    put(key, json.optInt(key))
                }
            }
        }
    }
}

object OrbitWidgetStore {
    private const val PREFS_NAME = "orbit_app_widgets"
    private const val KEY_CONFIG = "config_v1"

    private val colorfulLightPalette = intArrayOf(
        0xFF00796B.toInt(),
        0xFF1565C0.toInt(),
        0xFF6A1B9A.toInt(),
        0xFFC62828.toInt(),
        0xFFEF6C00.toInt(),
        0xFF2E7D32.toInt(),
        0xFF00838F.toInt(),
        0xFFAD1457.toInt(),
    )

    private val colorfulDarkPalette = intArrayOf(
        0xFF4DB6AC.toInt(),
        0xFF64B5F6.toInt(),
        0xFFBA68C8.toInt(),
        0xFFEF9A9A.toInt(),
        0xFFFFB74D.toInt(),
        0xFF81C784.toInt(),
        0xFF4DD0E1.toInt(),
        0xFFF48FB1.toInt(),
    )

    fun load(context: Context): OrbitWidgetConfig {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_CONFIG, null) ?: return OrbitWidgetConfig()
        return try {
            OrbitWidgetConfig.fromJson(JSONObject(raw))
        } catch (_: Exception) {
            OrbitWidgetConfig()
        }
    }

    fun save(context: Context, config: OrbitWidgetConfig) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_CONFIG, config.toJson().toString())
            .commit()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    fun resolveDatabasePath(context: Context, config: OrbitWidgetConfig = load(context)): String? {
        val candidates = listOfNotNull(
            config.databasePath,
            OrbitReminderStore.metadata(context)["database_path"],
            File(context.filesDir, "orbit.db").absolutePath,
            context.getDatabasePath("orbit.db").absolutePath,
        )
        return candidates.firstOrNull { path -> path.isNotBlank() && File(path).isFile }
    }

    fun isDark(context: Context, config: OrbitWidgetConfig): Boolean = when (config.themeMode) {
        "dark" -> true
        "light" -> false
        else -> (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    }

    fun paletteFor(context: Context, config: OrbitWidgetConfig): OrbitWidgetPalette =
        if (isDark(context, config)) config.paletteDark else config.paletteLight

    fun resolveCourseColor(
        seriesKey: String,
        courseCode: String,
        courseName: String,
        isDark: Boolean,
        config: OrbitWidgetConfig,
    ): Int {
        val palette = if (isDark) config.paletteDark else config.paletteLight
        val colors = if (isDark) config.courseColorsDark else config.courseColorsLight
        val codeKey = courseCode.trim()
        val nameKey = courseName.trim()
        val override = colors[seriesKey]
            ?: (if (codeKey.isNotEmpty()) colors[codeKey] else null)
            ?: (if (nameKey.isNotEmpty()) colors[nameKey] else null)
        if (override != null) return override
        if (config.themeStyle == "colorful") {
            val hashKey = codeKey.ifEmpty { nameKey }
            val defaults = if (isDark) colorfulDarkPalette else colorfulLightPalette
            return defaults[stableCourseHash(hashKey) % defaults.size]
        }
        return palette.primary
    }

    internal fun stableCourseHash(value: String): Int {
        var hash = 0x811c9dc5.toInt()
        for (i in value.indices) {
            hash = hash xor value[i].code
            hash = (hash * 0x01000193) and 0x7fffffff
        }
        return hash
    }
}
