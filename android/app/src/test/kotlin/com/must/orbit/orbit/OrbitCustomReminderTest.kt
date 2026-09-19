package com.must.orbit.orbit

import android.content.Context
import android.content.ContextWrapper
import android.content.ComponentName
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[32])
@LooperMode(LooperMode.Mode.PAUSED)
class OrbitCustomReminderTest {
    private lateinit var context: Context
    private lateinit var db: SQLiteDatabase
    @Before fun setup() {
        context=ApplicationProvider.getApplicationContext()
        context.deleteDatabase("orbit_native_reminders.db")
        context.deleteDatabase("ledger_test.db")
        val path=context.getDatabasePath("ledger_test.db")
        path.parentFile?.mkdirs()
        db=SQLiteDatabase.openOrCreateDatabase(path,null)
        db.execSQL("CREATE TABLE reminder_delivery(rule_id TEXT,session_id TEXT,acknowledged INTEGER DEFAULT 0,processed_index INTEGER DEFAULT 0,catchup_index INTEGER DEFAULT 0,PRIMARY KEY(rule_id,session_id))")
        db.execSQL("CREATE TABLE reminder_schedule(rule_id TEXT,session_id TEXT,send_index INTEGER,fire_at INTEGER,spec TEXT)")
        context.getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE).edit().clear().putString("database_path",path.path).commit()
    }
    @After fun teardown() {
        db.close();context.deleteDatabase("ledger_test.db");context.deleteDatabase("orbit_native_reminders.db")
        context.getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE).edit().clear().commit()
    }
    private fun record(index: Int=1): OrbitReminderRecord {
        val meta=JSONObject().put("ruleId","r").put("sessionId","s").put("sendIndex",index)
            .put("acknowledgeLabel","Acknowledge").put("stopLabel","Stop")
            .put("strong",JSONObject().put("enabled",true).put("durationSeconds",5).put("soundEnabled",false).put("vibrationEnabled",true))
        return OrbitReminderRecord(3_000_000+index,3_000_000+index,System.currentTimeMillis()+60_000,"Title","Body",null,"s","Reminders","Reminders",true,meta.toString())
    }
    private fun claim(record: OrbitReminderRecord): Boolean =
        OrbitReminderLedger.deliver(context, record) { true } == OrbitReminderDeliveryResult.DELIVERED
    @Test fun claimIsDurableAndDuplicateSequenceIsRejected() {
        assertTrue(claim(record()))
        assertFalse(claim(record()))
        assertTrue(claim(record(2)))
        db.rawQuery("SELECT processed_index FROM reminder_delivery",null).use {it.moveToFirst();assertEquals(2,it.getInt(0))}
    }
    @Test fun acknowledgeRemovesOnlyTheMatchingOccurrenceAndRejectsLaterSends() {
        db.execSQL("INSERT INTO reminder_schedule VALUES('r','s',2,9999999999999,'{}')")
        db.execSQL("INSERT INTO reminder_schedule VALUES('r','another',2,9999999999999,'{}')")
        OrbitReminderStore.upsert(context,record())
        OrbitReminderLedger.acknowledge(context,"r","s")
        assertFalse(claim(record(2)))
        assertNull(OrbitReminderStore.get(context,3_000_001))
        db.rawQuery("SELECT session_id FROM reminder_schedule",null).use {assertEquals(1,it.count);it.moveToFirst();assertEquals("another",it.getString(0))}
    }
    @Test fun notificationContainsSeparateAcknowledgementAndStopActions() {
        val notification=OrbitReminderManager.buildNotification(context,record())!!
        assertEquals(listOf("Acknowledge","Stop"),notification.actions.map {it.title.toString()})
        assertEquals(record().body,notification.extras.getCharSequence(android.app.Notification.EXTRA_BIG_TEXT).toString())
    }
    @Test fun repeatsRegisterOnlyNextSequenceAndRecoveryKeepsLatestMissedOne() {
        fun spec(index: Int, offset: Long): JSONObject {
            val at=java.time.LocalDateTime.now().plusSeconds(offset).toString()
            val record=record(index)
            return JSONObject(record.metadata).put("alarmId",record.alarmId).put("notificationId",record.notificationId)
                .put("title","Title").put("body","Body").put("payload","s").put("fireAt",at).put("originalFireAt",at)
        }
        for((index,offset) in listOf(1 to -60L,2 to -1L,3 to 60L)) {
            db.execSQL("INSERT INTO reminder_schedule VALUES('r','s',?,?,?)",arrayOf<Any>(index,System.currentTimeMillis()+offset*1000,spec(index,offset).toString()))
        }
        OrbitReminderLedger.replenish(context)
        val latest=OrbitReminderStore.load(context).values.single()
        assertEquals(3_000_002,latest.alarmId);assertTrue(latest.title.contains("Catch-up"))
        assertTrue(latest.body.contains("Originally scheduled"));assertTrue(latest.body.contains("not a real-time reminder"))
        assertTrue(claim(latest))
        OrbitReminderStore.remove(context,latest.alarmId)
        OrbitReminderLedger.replenish(context)
        assertEquals(3_000_003,OrbitReminderStore.load(context).values.single().alarmId)
        db.rawQuery("SELECT catchup_index FROM reminder_delivery",null).use {it.moveToFirst();assertEquals(2,it.getInt(0))}
    }
    @Test fun acknowledgementDoesNotStopAnotherRuleStrongReminder() {
        val controller=Robolectric.buildService(OrbitStrongReminderService::class.java).create()
        val intent=Intent(context,OrbitStrongReminderService::class.java).putExtra("record",record().toJson().toString())
        controller.get().onStartCommand(intent,0,1)
        assertFalse(OrbitStrongReminderService.acknowledge(context,"other","s"))
        assertTrue(OrbitStrongReminderService.acknowledge(context,"r","s"))
        controller.destroy()
    }
    @Test fun concurrentStrongDeliveryDoesNotExtendInitialTimeout() {
        val controller=Robolectric.buildService(OrbitStrongReminderService::class.java).create()
        val intent=Intent(context,OrbitStrongReminderService::class.java).putExtra("record",record().toJson().toString())
        controller.startCommand(0,1).get().onStartCommand(intent,0,1)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(3))
        controller.get().onStartCommand(intent,0,2)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        assertTrue(shadowOf(controller.get()).isStoppedBySelf)
        controller.destroy();assertFalse(OrbitStrongReminderService.active)
    }

    @Test fun failedPublishLeavesSequenceAndScheduleAvailableForRetry() {
        db.execSQL("INSERT INTO reminder_schedule VALUES('r','s',1,9999999999999,'{}')")
        assertEquals(OrbitReminderDeliveryResult.RETRY,
            OrbitReminderLedger.deliver(context, record()) { false })
        db.rawQuery("SELECT * FROM reminder_delivery", null).use { assertEquals(0, it.count) }
        db.rawQuery("SELECT * FROM reminder_schedule", null).use { assertEquals(1, it.count) }
        var published = 0
        assertEquals(OrbitReminderDeliveryResult.DELIVERED,
            OrbitReminderLedger.deliver(context, record()) { published++; true })
        assertEquals(OrbitReminderDeliveryResult.SKIPPED,
            OrbitReminderLedger.deliver(context, record()) { published++; true })
        assertEquals(1, published)
    }

    @Test fun thrownPublishDoesNotCommitProcessedIndex() {
        db.execSQL("INSERT INTO reminder_schedule VALUES('r','s',1,9999999999999,'{}')")
        assertThrows(IllegalStateException::class.java) {
            OrbitReminderLedger.deliver(context, record()) { throw IllegalStateException("test") }
        }
        db.rawQuery("SELECT * FROM reminder_schedule", null).use { assertEquals(1, it.count) }
        assertTrue(claim(record()))
    }

    @Test fun unavailableLedgerRetainsNativeReminderAndRegistersRetry() {
        OrbitReminderStore.updateMetadata(context, mapOf("database_path" to "${context.filesDir}/missing.db"))
        val record = record().copy(metadata = JSONObject(record().metadata)
            .put("strong", JSONObject().put("enabled", false)).toString())
        OrbitReminderStore.upsert(context, record)
        OrbitReminderReceiver().onReceive(context, Intent().putExtra(OrbitReminderManager.alarmIdExtra, record.alarmId))
        val retained = OrbitReminderStore.get(context, record.alarmId)!!
        assertTrue(JSONObject(retained.metadata).getBoolean("deliveryPending"))
        assertTrue(OrbitReminderStore.metadata(context)["schedule_failure"]!!.startsWith("delivery:"))
        db.rawQuery("SELECT * FROM reminder_delivery", null).use { assertEquals(0, it.count) }
        val alarms = shadowOf(context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager).scheduledAlarms
        assertTrue(alarms.any { shadowOf(it.operation).savedIntent.getIntExtra(OrbitReminderManager.alarmIdExtra, -1) == record.alarmId })
    }

    @Test fun disabledNotificationsDoNotConsumeCustomSequence() {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        shadowOf(manager).setNotificationsEnabled(false)
        val record = record()
        OrbitReminderStore.upsert(context, record)
        OrbitReminderReceiver().onReceive(context, Intent().putExtra(OrbitReminderManager.alarmIdExtra, record.alarmId))
        assertNotNull(OrbitReminderStore.get(context, record.alarmId))
        db.rawQuery("SELECT * FROM reminder_delivery", null).use { assertEquals(0, it.count) }
        assertNull(shadowOf(manager).getNotification(record.notificationId))
    }

    @Test fun rejectedStrongServiceStartPublishesAudibleNormalFallback() {
        val rejected = object : ContextWrapper(context) {
            override fun startForegroundService(service: Intent): ComponentName? =
                throw IllegalStateException("Title Body private course text")
        }
        val record = record()
        assertTrue(OrbitReminderManager.postNotification(rejected, record))
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notification = shadowOf(manager).getNotification(record.notificationId)!!
        assertNull(notification.group)
        assertEquals(listOf("Acknowledge"), notification.actions.map { it.title.toString() })
        assertEquals("start:IllegalStateException", OrbitReminderStore.metadata(context)["strong_degraded"])
        val logs = org.robolectric.shadows.ShadowLog.getLogsForTag("OrbitReminders")
        assertTrue(logs.any { it.msg.contains("strong_start_failed") })
        assertTrue(logs.none { it.msg.contains("Title") || it.msg.contains("Body") || it.msg.contains("private course text") })
    }

    @Test fun deferredServiceFallbackCanReplaceProcessedDeliveryButRespectsAcknowledgement() {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val record = record()
        assertTrue(claim(record)) // the initial notification was committed before service startup
        shadowOf(manager).setNotificationsEnabled(false)
        OrbitReminderManager.recoverNormalFallback(context, record)
        val retry = OrbitReminderStore.get(context, record.alarmId)!!
        assertTrue(JSONObject(retry.metadata).getBoolean("fallback"))
        assertFalse(JSONObject(retry.metadata).getJSONObject("strong").getBoolean("enabled"))
        shadowOf(manager).setNotificationsEnabled(true)
        OrbitReminderReceiver().onReceive(context, Intent().putExtra(OrbitReminderManager.alarmIdExtra, record.alarmId))
        assertNotNull(shadowOf(manager).getNotification(record.notificationId))
        assertNull(OrbitReminderStore.get(context, record.alarmId))
        OrbitReminderLedger.acknowledge(context, "r", "s")
        var published = false
        assertEquals(OrbitReminderDeliveryResult.SKIPPED,
            OrbitReminderLedger.deliver(context, retry) { published = true; true })
        assertFalse(published)
    }

    @Test fun foregroundPromotionFailureFallsBackAndStopsService() {
        val controller = Robolectric.buildService(OrbitStrongReminderService::class.java).create()
        try {
            shadowOf(controller.get()).setThrowInStartForeground(IllegalStateException("rejected"))
            val record = record()
            val intent = Intent(context, OrbitStrongReminderService::class.java)
                .putExtra("record", record.toJson().toString())
            controller.get().onStartCommand(intent, 0, 1)
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            assertNotNull(shadowOf(manager).getNotification(record.notificationId))
            assertNull(shadowOf(manager).getNotification(record.notificationId).group)
            assertFalse(OrbitStrongReminderService.active)
            assertTrue(shadowOf(controller.get()).isStoppedBySelf)
            assertEquals("foreground:IllegalStateException", OrbitReminderStore.metadata(context)["strong_degraded"])
        } finally { controller.destroy() }
    }
}
