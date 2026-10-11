package com.must.orbit.orbit

import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom
import java.util.Random

/** Tasks are generated once; retries and state reads never reshuffle them. */
internal object OrbitStrongTasks {
    fun arithmeticAnswer(q: JSONObject): Int = when(q.optString("operator", if(q.optBoolean("subtract")) "subtract" else "add")) {
        "multiply" -> q.getInt("a") * q.getInt("b")
        "subtract" -> q.getInt("a") - q.getInt("b")
        else -> q.getInt("a") + q.getInt("b")
    }
    private fun arithmetic(settings: JSONObject, random: Random): JSONObject {
        val difficulty=settings.optString("arithmeticDifficulty", "medium")
        val operation=random.nextInt(if(difficulty=="simple") 2 else 3)
        val multiply=operation==2
        var a=if(difficulty=="hard" && !multiply) 100+random.nextInt(900) else 10+random.nextInt(if(difficulty=="simple") 80 else 90)
        var b=when {
            difficulty=="simple" -> 1+random.nextInt(9)
            difficulty=="hard" && !multiply -> 100+random.nextInt(900)
            difficulty=="hard" -> 10+random.nextInt(90)
            multiply -> 2+random.nextInt(8)
            else -> 10+random.nextInt(90)
        }
        if(operation==1 && a<b) { val temp=a; a=b; b=temp }
        val q=JSONObject().put("type","arithmetic").put("a",a).put("b",b)
            .put("operator",if(multiply) "multiply" else if(operation==1) "subtract" else "add").put("subtract",operation==1)
        val count=when(settings.optString("arithmeticAnswerMode","input")) { "choice3" -> 3; "choice6" -> 6; else -> 0 }
        val values=mutableListOf<Int>()
        if(count>0) {
            val answer=arithmeticAnswer(q); values.add(answer)
            val spread=maxOf(6,answer/8)
            repeat(50) {
                if(values.size<count) {
                    val candidate=answer+(if(random.nextBoolean()) 1 else -1)*(1+random.nextInt(spread))
                    if(candidate>=0 && candidate !in values) values.add(candidate)
                }
            }
            var delta=1
            while(values.size<count) { val candidate=answer+delta++; if(candidate !in values) values.add(candidate) }
            java.util.Collections.shuffle(values,random)
        }
        return q.put("choices",JSONArray(values))
    }
    fun create(settings: JSONObject, random: Random = SecureRandom()): JSONArray {
        val mode=settings.optString("dismissTask","arithmetic")
        val rounds=settings.optInt(when(mode) { "sequence" -> "sequenceRounds"; "mixed" -> "mixedRounds"; else -> "arithmeticRounds" },2).coerceIn(1,10)
        val count=settings.optInt("sequenceNumberCount",6).coerceIn(4,25)
        return JSONArray().apply {
            repeat(rounds) {
                val sequence=mode=="sequence" || (mode=="mixed" && random.nextBoolean())
                if(sequence) {
                    val numbers=(1..count).toMutableList(); java.util.Collections.shuffle(numbers,random)
                    put(JSONObject().put("type","sequence").put("numberCount",count).put("numbers",JSONArray(numbers)))
                } else put(arithmetic(settings,random))
            }
        }
    }
    fun initialize(state: JSONObject, tasks: JSONArray) {
        state.put("tasks",tasks).put("taskIndex",0).put("taskProgress",0)
        val questions=JSONArray()
        for(i in 0 until tasks.length()) if(tasks.getJSONObject(i).getString("type")=="arithmetic") questions.put(tasks.getJSONObject(i))
        state.put("questions",questions)
        state.put("numbers",tasks.getJSONObject(0).optJSONArray("numbers") ?: JSONArray())
    }
    fun answer(state: JSONObject, input: Int) {
        val tasks=state.getJSONArray("tasks")
        val index=state.getInt("taskIndex")
        if(index !in 0 until tasks.length()) return
        val task=tasks.getJSONObject(index)
        val sequence=task.getString("type")=="sequence"
        val step=state.optInt("taskProgress")
        val expected=if(sequence) step+1 else arithmeticAnswer(task)
        val choices=task.optJSONArray("choices")
        val offered=sequence || choices==null || choices.length()==0 || (0 until choices.length()).any { choices.getInt(it)==input }
        val correct=input==expected && offered
        state.put("wrong",!correct)
        if(!correct) return
        state.put("progress",state.optInt("progress")+1)
        if(sequence && step+1<task.getInt("numberCount")) state.put("taskProgress",step+1)
        else {
            state.put("taskIndex",index+1).put("taskProgress",0)
            if(index+1==tasks.length()) state.put("phase","completed")
            else state.put("numbers",tasks.getJSONObject(index+1).optJSONArray("numbers") ?: JSONArray())
        }
    }
}
