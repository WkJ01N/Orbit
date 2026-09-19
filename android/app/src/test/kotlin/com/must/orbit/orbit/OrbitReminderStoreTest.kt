package com.must.orbit.orbit

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [32])
class OrbitReminderStoreTest {
    private lateinit var context: Context

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        context.deleteDatabase("orbit_native_reminders.db")
        context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @After fun tearDown() {
        context.deleteDatabase("orbit_native_reminders.db")
        context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun migratesLegacyConfigEvenIfRecordsWereAlreadyMigrated() {
        context.openOrCreateDatabase("orbit_native_reminders.db", Context.MODE_PRIVATE, null).use {
            it.execSQL("CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)")
            it.execSQL("INSERT INTO metadata VALUES('migrated','1')")
        }
        context.getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE).edit()
            .putString("database_path", "/legacy/ledger.db")
            .putString("channel_name", "Legacy channel")
            .putString("strong_degraded", "legacy_error").commit()
        val migrated = OrbitReminderStore.metadata(context)
        assertEquals("/legacy/ledger.db", migrated["database_path"])
        assertEquals("Legacy channel", migrated["channel_name"])
        assertEquals("legacy_error", migrated["strong_degraded"])
        OrbitReminderStore.updateMetadata(context, mapOf("strong_degraded" to null))
        assertNull(OrbitReminderStore.metadata(context)["strong_degraded"])
    }

    @Test fun freshConnectionsSeeUpdatesWithoutReadingCachedPreferences() {
        OrbitReminderStore.metadata(context) // one-time migration
        val reader = object : ContextWrapper(context) {
            override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
                throw AssertionError("Runtime must use SQLite")
        }
        OrbitReminderStore.updateMetadata(context, mapOf("database_path" to "/new/ledger.db", "schedule_failure" to "delivery:test"))
        assertEquals("/new/ledger.db", OrbitReminderStore.metadata(reader)["database_path"])
        OrbitReminderStore.updateMetadata(reader, mapOf("schedule_failure" to null, "channel_name" to "Updated"))
        val updated = OrbitReminderStore.metadata(context)
        assertNull(updated["schedule_failure"])
        assertEquals("Updated", updated["channel_name"])
    }

    @Test fun diagnosticsAreBoundedAndContainOnlyExplicitFields() {
        for (index in 0 until 70) {
            OrbitReminderStore.appendDiagnostic(context, "stage_$index", index, "reason")
        }

        val events = OrbitReminderStore.diagnostics(context, 64)
        assertEquals(64, events.size)
        assertEquals("stage_69", events.first()["stage"])
        assertEquals("stage_6", events.last()["stage"])
        assertEquals(setOf("timestamp", "stage", "alarmId", "reason"), events.first().keys)
    }
}
