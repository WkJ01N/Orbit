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
        context
            .getSharedPreferences("orbit_native_reminders", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @After
    fun tearDown() {
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
