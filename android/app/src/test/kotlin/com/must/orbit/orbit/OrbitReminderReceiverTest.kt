package com.must.orbit.orbit

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [32])
@LooperMode(LooperMode.Mode.PAUSED)
class OrbitReminderReceiverTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        context.deleteDatabase("orbit_native_reminders.db")
        context
            .getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @After
    fun tearDown() {
        context.deleteDatabase("orbit_native_reminders.db")
        context
            .getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun persistedReminderRoundTripsAllDeliveryFields() {
        val record = reminderRecord(alarmId = 301, notificationId = 401)

        OrbitReminderStore.upsert(context, record)

        assertEquals(record, OrbitReminderStore.get(context, record.alarmId))
    }

    @Test
    fun receiverPostsNotificationAndRemovesDeliveredRecord() {
        val record = reminderRecord(alarmId = 302, notificationId = 402)
        OrbitReminderStore.upsert(context, record)
        val intent = Intent(context, OrbitReminderReceiver::class.java).apply {
            putExtra(OrbitReminderManager.alarmIdExtra, record.alarmId)
        }

        OrbitReminderReceiver().onReceive(context, intent)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = shadowOf(notificationManager).getNotification(record.notificationId)
        assertNotNull(notification)
        assertEquals(
            record.title,
            notification.extras.getString(Notification.EXTRA_TITLE),
        )
        assertEquals(
            record.body,
            notification.extras.getString(Notification.EXTRA_TEXT),
        )
        assertFalse(OrbitReminderStore.load(context).containsKey(record.alarmId))
    }

    @Test
    fun overdueFailedDeliverySurvivesPendingChecksAndRestoresAfterPermissionReturns() {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        shadowOf(manager).setNotificationsEnabled(false)
        val record = reminderRecord(alarmId = 303, notificationId = 403)
        OrbitReminderStore.upsert(context, record)
        OrbitReminderReceiver().onReceive(context, Intent().putExtra(OrbitReminderManager.alarmIdExtra, record.alarmId))
        val retained = OrbitReminderStore.get(context, record.alarmId)!!
        OrbitReminderStore.upsert(context, retained.copy(fireAtMillis = System.currentTimeMillis() - 1000))
        assertEquals(1, OrbitReminderManager.pendingCourseReminderCount(context))
        assertNotNull(OrbitReminderStore.get(context, record.alarmId))
        shadowOf(manager).setNotificationsEnabled(true)
        OrbitReminderManager.restorePersistedReminders(context)
        assertTrue(OrbitReminderStore.get(context, record.alarmId)!!.fireAtMillis > System.currentTimeMillis())
        OrbitReminderReceiver().onReceive(context, Intent().putExtra(OrbitReminderManager.alarmIdExtra, record.alarmId))
        assertNotNull(shadowOf(manager).getNotification(record.notificationId))
        assertFalse(OrbitReminderManager.contains(context, record.alarmId))
    }

    @Test
    fun expiredRetryIsRemovedAndNonRestorableTestsStayNonRestorable() {
        val metadata = org.json.JSONObject().put("deliveryPending", true)
            .put("deliveryPendingSince", System.currentTimeMillis() - 86_400_001).toString()
        OrbitReminderStore.upsert(context, reminderRecord(304, 404).copy(metadata = metadata))
        OrbitReminderStore.upsert(context, reminderRecord(305, 405).copy(restoreOnReboot = false,
            metadata = org.json.JSONObject().put("deliveryPending", true).toString()))
        OrbitReminderManager.restorePersistedReminders(context)
        assertFalse(OrbitReminderManager.contains(context, 304))
        assertFalse(OrbitReminderManager.contains(context, 305))
    }

    @Test
    fun scheduleBatchAndRestoreRespectRollingWindowAndSlideOnDelivery() {
        val total = OrbitReminderManager.maxArmedSystemAlarms + 20
        val base = System.currentTimeMillis() + 60_000
        val records = (1..total).map { index ->
            reminderRecord(alarmId = index, notificationId = index).copy(
                fireAtMillis = base + index * 10_000L,
            )
        }

        val batch = OrbitReminderManager.scheduleBatch(
            context,
            records,
            exactPreferred = true,
            allowInexactFallback = true,
        )
        assertEquals(total, batch.scheduled)
        assertEquals(OrbitReminderManager.maxArmedSystemAlarms, batch.armed)
        assertEquals(0, batch.failed)
        assertEquals("1", OrbitReminderStore.metadata(context)["has_deferred_alarms"])
        assertEquals(total, OrbitReminderManager.pendingCourseReminderCount(context))
        assertTrue(OrbitReminderManager.hasPendingAlarm(context, 1))
        assertTrue(OrbitReminderManager.hasPendingAlarm(context, OrbitReminderManager.maxArmedSystemAlarms))
        assertFalse(OrbitReminderManager.hasPendingAlarm(context, OrbitReminderManager.maxArmedSystemAlarms + 1))

        // Firing alarm #1 removes it and slides the rolling window to arm #301.
        OrbitReminderReceiver().onReceive(
            context,
            Intent(context, OrbitReminderReceiver::class.java).putExtra(
                OrbitReminderManager.alarmIdExtra,
                1,
            ),
        )
        assertTrue(OrbitReminderManager.hasPendingAlarm(context, OrbitReminderManager.maxArmedSystemAlarms + 1))

        // Restore also arms only the earliest maxArmedSystemAlarms reminders.
        OrbitReminderManager.restorePersistedReminders(context)
        assertTrue(OrbitReminderManager.hasPendingAlarm(context, 2))
        assertTrue(OrbitReminderManager.hasPendingAlarm(context, OrbitReminderManager.maxArmedSystemAlarms + 1))
        assertFalse(OrbitReminderManager.hasPendingAlarm(context, OrbitReminderManager.maxArmedSystemAlarms + 2))
    }

    private fun reminderRecord(
        alarmId: Int,
        notificationId: Int,
    ) = OrbitReminderRecord(
        alarmId = alarmId,
        notificationId = notificationId,
        fireAtMillis = System.currentTimeMillis() + 60_000,
        title = "Orbit reminder",
        body = "Course starts soon",
        bigText = "Course starts soon in room A101",
        payload = "course-301",
        channelName = "Course reminders",
        channelDescription = "Orbit course reminder notifications",
        restoreOnReboot = true,
    )
}
