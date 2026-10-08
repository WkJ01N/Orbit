package com.must.orbit.orbit

import android.content.Context
import android.app.NotificationManager
import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom

/** The native process owns absolute deadlines and validates answers. */
object OrbitStrongSession {
    private val random = SecureRandom()
    private val terminal = setOf("completed", "unconfirmed", "emergency")
    fun isActive(s: JSONObject?): Boolean = s != null && s.optString("phase") !in terminal && System.currentTimeMillis() < s.optLong("expiresAt")
    private fun questions(): JSONArray = JSONArray().apply {
        repeat(2) { put(JSONObject().apply { put("a", 10 + random.nextInt(80)); put("b", 1 + random.nextInt(9)); put("subtract", random.nextBoolean()) }) }
    }
    private fun numbers(): JSONArray { val list=(1..6).toMutableList(); java.util.Collections.shuffle(list,random); return JSONArray(list) }
    fun start(context: Context, record: OrbitReminderRecord): JSONObject? = OrbitReminderStore.mutateStrong(context) { old ->
        val key = "${record.alarmId}:${record.fireAtMillis}"
        val records = old?.optJSONArray("records")
        if (records != null && (0 until records.length()).any { val r=records.getJSONObject(it); "${r.getInt("alarmId")}:${r.getLong("fireAtMillis")}"==key }) return@mutateStrong old
        if (isActive(old)) { records!!.put(record.toJson()); return@mutateStrong old }
        val now=System.currentTimeMillis()
        val settings=JSONObject(record.metadata).optJSONObject("strong") ?: JSONObject()
        val length=settings.optInt("durationSeconds",30).coerceIn(5,300)*1000L
        JSONObject().apply {
            put("id",key); put("startedAt",now); put("expiresAt",now+length*3+30000)
            put("duration",length); put("round",1); put("roundEnd",now+length); put("nextRoundAt",0)
            put("settings",settings); put("records",JSONArray().put(record.toJson()))
            put("phase","ringing"); put("opened",false); put("progress",0); put("questions",questions()); put("numbers",numbers())
        }
    }
    private fun advance(s: JSONObject, now: Long): JSONObject {
        if (s.optString("phase") in terminal) return s
        if (now>=s.getLong("expiresAt")) { s.put("phase","unconfirmed"); return s }
        if (now>=s.getLong("roundEnd") && s.optLong("nextRoundAt")==0L) {
            if (s.getInt("round")>=3) { s.put("phase","unconfirmed"); return s }
            s.put("nextRoundAt",s.getLong("roundEnd")+15000)
        }
        val deadline=if(s.optString("phase")=="task") s.optLong("answerDeadline") else if(s.optString("phase")=="ready") s.optLong("prepareDeadline") else 0L
        val timedOut=deadline>0 && now>=deadline
        if(timedOut) s.put("phase","timeout")
        if(s.optLong("nextRoundAt")>0 && (now>=s.getLong("nextRoundAt") || timedOut)) {
            s.put("round",s.getInt("round")+1); s.put("roundEnd",minOf(now+s.getLong("duration"),s.getLong("expiresAt"))); s.put("nextRoundAt",0)
        }
        return s
    }
    fun state(context: Context): JSONObject? = OrbitReminderStore.mutateStrong(context) { s -> s?.let { advance(it,System.currentTimeMillis()) } }
    fun open(context: Context): JSONObject? = OrbitReminderStore.mutateStrong(context) { value ->
        val s=value?.let { advance(it,System.currentTimeMillis()) } ?: return@mutateStrong null
        if(isActive(s) && !s.optBoolean("opened")) {
            s.put("opened",true); s.put("phase","ready")
            s.put("prepareDeadline",minOf(System.currentTimeMillis()+s.getJSONObject("settings").optInt("prepareSeconds",15).coerceIn(5,60)*1000L,s.getLong("expiresAt")))
        }
        s
    }
    fun leave(context: Context): JSONObject? = OrbitReminderStore.mutateStrong(context) { value ->
        val s=value?.let { advance(it,System.currentTimeMillis()) } ?: return@mutateStrong null
        if(isActive(s) && s.optString("phase") in setOf("ready","task")) {
            s.put("phase","timeout")
            if(s.optLong("nextRoundAt")>0) {
                s.put("round",s.getInt("round")+1); s.put("roundEnd",minOf(System.currentTimeMillis()+s.getLong("duration"),s.getLong("expiresAt"))); s.put("nextRoundAt",0)
            }
        }
        s
    }
    fun stopTests(context: Context) {
        val result=OrbitReminderStore.mutateStrong(context) { s ->
            if(s==null) return@mutateStrong null
            val records=s.optJSONArray("records") ?: return@mutateStrong s
            val retained=JSONArray()
            for(i in 0 until records.length()) { val r=records.getJSONObject(i); if(r.optString("payload")!="test_strong_reminder") retained.put(r) }
            s.put("records",retained)
            if(retained.length()==0) s.put("phase","emergency")
            s
        }
        if(result?.optString("phase")=="emergency") OrbitStrongReminderService.stop(context)
    }
    fun begin(context: Context): JSONObject? = OrbitReminderStore.mutateStrong(context) { value ->
        val s=value?.let { advance(it,System.currentTimeMillis()) } ?: return@mutateStrong null
        if(isActive(s) && s.optString("phase")!="task") {
            s.put("phase","task"); s.put("answerDeadline",minOf(System.currentTimeMillis()+s.getJSONObject("settings").optInt("answerSeconds",30).coerceIn(10,120)*1000L,s.getLong("expiresAt")))
        }
        s
    }
    fun answer(context: Context, input: Int): JSONObject? {
        val result=OrbitReminderStore.mutateStrong(context) { value ->
            val s=value?.let { advance(it,System.currentTimeMillis()) } ?: return@mutateStrong null
            if(s.optString("phase")!="task") return@mutateStrong s
            val progress=s.getInt("progress")
            val sequence=s.getJSONObject("settings").optString("dismissTask")=="sequence"
            val expected=if(sequence) progress%6+1 else s.getJSONArray("questions").getJSONObject(progress).let { if(it.getBoolean("subtract")) it.getInt("a")-it.getInt("b") else it.getInt("a")+it.getInt("b") }
            s.put("wrong",input!=expected)
            if(input==expected) {
                s.put("progress",progress+1)
                if(sequence && progress==5) s.put("numbers",numbers())
                if(progress+1>=if(sequence) 12 else 2) s.put("phase","completed")
            }
            s
        }
        if(result?.optString("phase")=="completed") finish(context,result)
        return result
    }
    fun emergency(context: Context): JSONObject? {
        val s=OrbitReminderStore.mutateStrong(context) { it?.put("phase","emergency") }
        if(s!=null) finish(context,s)
        return s
    }
    private fun finish(context: Context, s: JSONObject) {
        val records=s.getJSONArray("records")
        for(i in 0 until records.length()) {
            val record=OrbitReminderRecord.fromJson(records.getJSONObject(i)); val meta=JSONObject(record.metadata)
            val rule=meta.optString("ruleId")
            if(rule.isNotEmpty() && rule!="null") OrbitReminderLedger.acknowledge(context,rule,meta.optString("sessionId"))
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(record.notificationId)
        }
        OrbitStrongReminderService.stop(context)
    }
    fun shouldPlay(s: JSONObject): Boolean = isActive(s) && s.optString("phase") !in setOf("ready","task") && System.currentTimeMillis()<s.getLong("roundEnd")
}
