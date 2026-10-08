package com.must.orbit.orbit

import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [32])
@LooperMode(LooperMode.Mode.PAUSED)
class OrbitStrongSessionTest {
    private lateinit var context: Context
    @Before fun setUp() {
        context=ApplicationProvider.getApplicationContext()
        context.deleteDatabase("orbit_native_reminders.db")
        context.getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE).edit().clear().commit()
    }
    @After fun tearDown() { context.deleteDatabase("orbit_native_reminders.db") }
    private fun record(id: Int=31, task: String="arithmetic", locale: String="en")=OrbitReminderRecord(
        id,id,System.currentTimeMillis(),"Mathematics","A101",null,"course", "Orbit","Orbit",false,
        JSONObject().put("strong",JSONObject().put("enabled",true).put("durationSeconds",30).put("prepareSeconds",15).put("answerSeconds",30).put("dismissTask",task)).put("localeTag",locale).toString(),
    )
    @Test fun duplicateAndSimultaneousRemindersKeepOneFixedDeadline() {
        val r=record(); val s=OrbitStrongSession.start(context,r)!!
        val expiry=s.getLong("expiresAt")
        assertEquals(120000L,expiry-s.getLong("startedAt"))
        assertEquals(expiry,OrbitStrongSession.start(context,r)!!.getLong("expiresAt"))
        assertEquals(1,OrbitStrongSession.state(context)!!.getJSONArray("records").length())
        val merged=OrbitStrongSession.start(context,record(32))!!
        assertEquals(expiry,merged.getLong("expiresAt"));assertEquals(2,merged.getJSONArray("records").length())
    }
    @Test fun openingAndWrongAnswersNeverResetTimers() {
        OrbitStrongSession.start(context,record())
        val ready=OrbitStrongSession.open(context)!!
        assertFalse(OrbitStrongSession.shouldPlay(ready))
        assertEquals(ready.getLong("prepareDeadline"),OrbitStrongSession.open(context)!!.getLong("prepareDeadline"))
        val task=OrbitStrongSession.begin(context)!!;val deadline=task.getLong("answerDeadline")
        assertEquals(deadline,OrbitStrongSession.begin(context)!!.getLong("answerDeadline"))
        val wrong=OrbitStrongSession.answer(context,-1000)!!
        assertTrue(wrong.getBoolean("wrong"));assertEquals(0,wrong.getInt("progress"));assertEquals(deadline,wrong.getLong("answerDeadline"))
        for(i in 0..1) {
            val q=task.getJSONArray("questions").getJSONObject(i)
            OrbitStrongSession.answer(context,q.getInt("a")+if(q.getBoolean("subtract")) -q.getInt("b") else q.getInt("b"))
        }
        assertEquals("completed",OrbitStrongSession.state(context)!!.getString("phase"))
    }
    @Test fun timeoutDuringGapAdvancesRoundWithoutExtendingTotalExpiry() {
        OrbitStrongSession.start(context,record());OrbitStrongSession.open(context)
        val expiry=OrbitStrongSession.state(context)!!.getLong("expiresAt")
        OrbitReminderStore.mutateStrong(context) { it!!.put("prepareDeadline",System.currentTimeMillis()-1).put("roundEnd",System.currentTimeMillis()-1).put("nextRoundAt",System.currentTimeMillis()+14000) }
        val s=OrbitStrongSession.state(context)!!
        assertEquals("timeout",s.getString("phase"));assertEquals(2,s.getInt("round"));assertEquals(expiry,s.getLong("expiresAt"));assertTrue(OrbitStrongSession.shouldPlay(s))
        OrbitStrongSession.begin(context);val deadline=OrbitStrongSession.state(context)!!.getLong("answerDeadline")
        OrbitStrongSession.leave(context);OrbitStrongSession.open(context)
        assertEquals("timeout",OrbitStrongSession.state(context)!!.getString("phase"));assertEquals(deadline,OrbitStrongSession.state(context)!!.getLong("answerDeadline"))
    }
    @Test fun expiredSessionsCannotReopenOrReplayDuplicateNotifications() {
        val r=record();OrbitStrongSession.start(context,r)
        OrbitReminderStore.mutateStrong(context) { it!!.put("expiresAt",System.currentTimeMillis()-1) }
        val s=OrbitStrongSession.open(context)!!
        assertEquals("unconfirmed",s.getString("phase"));assertFalse(OrbitStrongSession.isActive(s))
        assertEquals("unconfirmed",OrbitStrongSession.start(context,r)!!.getString("phase"))
    }
    @Test fun thirdRoundEndsEvenIfPreparationOrTaskWouldLastLonger() {
        OrbitStrongSession.start(context,record());OrbitStrongSession.open(context)
        OrbitReminderStore.mutateStrong(context) { it!!.put("round",3).put("roundEnd",System.currentTimeMillis()-1) }
        assertEquals("unconfirmed",OrbitStrongSession.state(context)!!.getString("phase"))
    }
    @Test fun sequenceRequiresTwoRoundsAndEmergencyStaysUnconfirmed() {
        OrbitStrongSession.start(context,record(task="sequence"));OrbitStrongSession.open(context);OrbitStrongSession.begin(context)
        for(i in 1..6) OrbitStrongSession.answer(context,i)
        val middle=OrbitStrongSession.state(context)!!
        assertEquals("task",middle.getString("phase"));assertEquals(6,middle.getInt("progress"))
        assertEquals((1..6).toSet(),(0..5).map { middle.getJSONArray("numbers").getInt(it) }.toSet())
        assertEquals("emergency",OrbitStrongSession.emergency(context)!!.getString("phase"))
        assertFalse(OrbitStrongSession.isActive(OrbitStrongSession.open(context)))
    }
    @Test fun dismissedNotificationRepostsSameIdAfterTwoSecondsWithoutNewRound() {
        val r=record();val initial=OrbitStrongSession.start(context,r)!!
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(r.notificationId,OrbitReminderManager.buildNotification(context,r));manager.cancel(r.notificationId)
        OrbitReminderActionReceiver().onReceive(context,Intent("strong_dismiss"))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        assertNotNull(shadowOf(manager).getNotification(r.notificationId))
        val next=OrbitStrongSession.state(context)!!
        assertEquals(initial.getLong("expiresAt"),next.getLong("expiresAt"));assertEquals(1,next.getInt("round"))
    }
    @Test fun notificationUsesExplicitTraditionalLocaleEvenForCustomEnglishBody() {
        val n=OrbitReminderManager.buildNotification(context,record(locale="zh-Hant"))!!
        assertTrue(n.extras.getCharSequence("android.text").toString().contains("強提醒"))
        assertEquals("開啟並答題",n.actions.single().title.toString())
    }
}
