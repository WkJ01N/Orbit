package com.must.orbit.orbit

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.os.Process
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[32])
@LooperMode(LooperMode.Mode.PAUSED)
class OrbitDeadlineStrongSessionTest {
    private lateinit var context: Context
    @Before fun setUp(){
        context=ApplicationProvider.getApplicationContext();context.deleteDatabase("orbit_native_reminders.db")
        context.getSharedPreferences("orbit_native_reminders",Context.MODE_PRIVATE).edit().clear().commit()
        OrbitReminderStore.updateMetadata(context,mapOf("app_visible_pid" to null))
    }
    @After fun tearDown(){context.deleteDatabase("orbit_native_reminders.db")}
    private fun record(id:Int=4000001, at:Long=System.currentTimeMillis()) = OrbitReminderRecord(
        id,id,at,"Project","Tomorrow",null,"deadline:task-$id","Orbit","Orbit",true,
        JSONObject().put("acknowledgementMode","openApp").put("deadlineId","task-$id").put("leadMinutes",60)
            .put("strong",JSONObject().put("enabled",true).put("durationSeconds",30)).toString())
    private fun course()=record(31).copy(payload="course",metadata=JSONObject().put("strong",JSONObject().put("enabled",true)).toString())
    private fun foreground(visible:Boolean){
        val manager=context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        shadowOf(manager).setProcesses(listOf(ActivityManager.RunningAppProcessInfo("Orbit",Process.myPid(),arrayOf(context.packageName)).apply {importance=ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND}))
        OrbitDeadlineStrongSession.visibility(context,visible)
    }
    @Test fun openingConfirmsAllTriggeredDeadlinesWithoutChangingCourseChallenge(){
        val c=OrbitStrongSession.start(context,course())!!;OrbitStrongSession.open(context);OrbitStrongSession.begin(context)
        val before=OrbitStrongSession.state(context).toString()
        OrbitDeadlineStrongSession.start(context,record());OrbitDeadlineStrongSession.start(context,record(4000002))
        val events=OrbitDeadlineStrongSession.open(context).getJSONArray("events")
        assertEquals(2,events.length());assertFalse(OrbitDeadlineStrongSession.anyActive(context))
        assertEquals(before,OrbitStrongSession.state(context).toString());assertEquals(c.getLong("expiresAt"),OrbitStrongSession.state(context)!!.getLong("expiresAt"))
        assertEquals(2,OrbitDeadlineStrongSession.open(context).getJSONArray("events").length())
    }
    @Test fun confirmedDuplicateDoesNotRingAfterReceiptIsHandledOrProcessReadsFreshState(){
        val r=record();val first=OrbitDeadlineStrongSession.start(context,r)
        val event=OrbitDeadlineStrongSession.open(context).getJSONArray("events").getJSONObject(0)
        OrbitDeadlineStrongSession.eventsHandled(context,setOf(event.getString("id")))
        val duplicate=OrbitDeadlineStrongSession.start(context,r)
        assertFalse(OrbitDeadlineStrongSession.active(duplicate));assertEquals(first.getLong("expiresAt"),duplicate.getLong("expiresAt"))
        assertEquals(0,OrbitDeadlineStrongSession.open(context).getJSONArray("events").length())
    }
    @Test fun foregroundDeliveryProducesReceiptWithoutPostingNotificationOrStartingPlayer(){
        foreground(true)
        assertTrue(OrbitReminderManager.postNotification(context,record()))
        assertFalse(OrbitDeadlineStrongSession.anyActive(context))
        assertEquals(1,OrbitDeadlineStrongSession.open(context).getJSONArray("events").length())
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        assertNull(shadowOf(manager).getNotification(4000001))
    }
    @Test fun hiddenOrStaleForegroundMarkerDoesNotConfirmReminder(){
        foreground(false);assertTrue(OrbitDeadlineStrongSession.active(OrbitDeadlineStrongSession.start(context,record())))
        OrbitReminderStore.updateMetadata(context,mapOf("app_visible_pid" to "999999"))
        assertFalse(OrbitDeadlineStrongSession.foreground(context))
        assertTrue(OrbitDeadlineStrongSession.active(OrbitDeadlineStrongSession.start(context,record(4000002))))
    }
    @Test fun independentDeadlinesKeepTheirOwnExpiryAndThreeAbsoluteRingingRounds(){
        val now=System.currentTimeMillis()
        val pause=OrbitDeadlineStrongSession.start(context,record(at=now-30000));assertEquals(1,pause.getInt("round"));assertFalse(OrbitDeadlineStrongSession.shouldPlay(pause))
        val second=OrbitDeadlineStrongSession.start(context,record(4000002,now-45000));assertEquals(2,second.getInt("round"));assertTrue(OrbitDeadlineStrongSession.shouldPlay(second))
        val third=OrbitDeadlineStrongSession.start(context,record(4000003,now-90000));assertEquals(3,third.getInt("round"));assertTrue(OrbitDeadlineStrongSession.shouldPlay(third))
        val expired=OrbitDeadlineStrongSession.start(context,record(4000004,now-120000));assertFalse(OrbitDeadlineStrongSession.active(expired));assertEquals("unconfirmed",expired.getString("phase"))
        assertEquals(now+90000,pause.getLong("expiresAt"));assertEquals(now+75000,second.getLong("expiresAt"))
    }
    @Test fun editingOrDeletingCancelsOnlyInvalidActiveDeadlineInstances(){
        OrbitStrongSession.start(context,course());val before=OrbitStrongSession.state(context).toString()
        val a=record();val b=record(4000002);OrbitDeadlineStrongSession.start(context,a);OrbitDeadlineStrongSession.start(context,b)
        OrbitDeadlineStrongSession.reconcile(context,setOf("task-4000001:60:${a.fireAtMillis}"))
        val states=OrbitDeadlineStrongSession.states(context)
        assertEquals(1,states.count(OrbitDeadlineStrongSession::active));assertEquals("cancelled",states.single {it.getString("id").startsWith("4000002:")}.getString("phase"))
        assertEquals(before,OrbitStrongSession.state(context).toString());assertEquals(0,OrbitDeadlineStrongSession.open(context).getJSONArray("events").length()-1)
    }
    @Test fun deadlineNotificationExplainsOpenAppWithoutCourseQuestionWording(){
        val n=OrbitReminderManager.buildNotification(context,record())!!
        assertTrue(n.extras.getCharSequence("android.text").toString().contains("open Orbit to stop"))
        assertEquals("Open Orbit",n.actions.single().title.toString())
    }
}
