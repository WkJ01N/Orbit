package com.must.orbit.orbit

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Random

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [32])
class OrbitStrongTasksTest {
    @Test fun difficultyAndChoicesAreValidAndStable() {
        for (difficulty in listOf("simple", "medium", "hard")) for (mode in listOf("input", "choice3", "choice6")) {
            val settings=JSONObject().put("arithmeticDifficulty",difficulty).put("arithmeticAnswerMode",mode).put("arithmeticRounds",10)
            val operations=mutableSetOf<String>()
            for(seed in 0L..20L) {
                val tasks=OrbitStrongTasks.create(settings,Random(seed))
                for(i in 0 until tasks.length()) {
                    val q=tasks.getJSONObject(i);val a=q.getInt("a");val b=q.getInt("b");val op=q.getString("operator");operations.add(op)
                    if(difficulty=="simple") { assertTrue(a in 10..89);assertTrue(b in 1..9);assertNotEquals("multiply",op) }
                    else if(difficulty=="hard" && op!="multiply") { assertTrue(a in 100..999);assertTrue(b in 100..999) }
                    else { assertTrue(a in 10..99);assertTrue(b in if(difficulty=="medium" && op=="multiply") 2..9 else 10..99) }
                    val answer=OrbitStrongTasks.arithmeticAnswer(q);assertTrue(answer>=0)
                    val choices=q.getJSONArray("choices");val values=(0 until choices.length()).map { choices.getInt(it) }
                    assertEquals(when(mode){"choice3"->3;"choice6"->6;else->0},values.size)
                    assertEquals(values.size,values.toSet().size)
                    if(values.isNotEmpty()) assertTrue(answer in values)
                }
            }
            assertEquals(if(difficulty=="simple") setOf("add","subtract") else setOf("add","subtract","multiply"),operations)
        }
    }
    @Test fun allSequenceAndRoundBoundariesCompleteOnlyAfterLastAnswer() {
        for(count in listOf(4,6,25)) for(rounds in listOf(1,2,10)) {
            val settings=JSONObject().put("dismissTask","sequence").put("sequenceNumberCount",count).put("sequenceRounds",rounds)
            val state=JSONObject().put("phase","task").put("progress",0)
            val tasks=OrbitStrongTasks.create(settings,Random(5));OrbitStrongTasks.initialize(state,tasks)
            assertEquals(rounds,tasks.length())
            for(round in 0 until rounds) {
                val q=tasks.getJSONObject(round);val values=q.getJSONArray("numbers")
                assertEquals((1..count).toSet(),(0 until values.length()).map { values.getInt(it) }.toSet())
                for(n in 1..count) {
                    val saved=tasks.toString();OrbitStrongTasks.answer(state,n+100)
                    assertEquals(round,state.getInt("taskIndex"));assertEquals(n-1,state.getInt("taskProgress"));assertEquals(saved,tasks.toString())
                    OrbitStrongTasks.answer(state,n)
                    assertEquals(if(round==rounds-1 && n==count) "completed" else "task",state.getString("phase"))
                }
            }
            assertEquals(count*rounds,state.getInt("progress"))
        }
    }
    @Test fun mixedTasksSurvivePersistenceAndWrongAnswers() {
        val types=mutableSetOf<String>()
        for(seed in 0L..40L) {
            val settings=JSONObject().put("dismissTask","mixed").put("mixedRounds",10).put("sequenceNumberCount",25).put("arithmeticAnswerMode","choice6")
            var state=JSONObject().put("phase","task").put("progress",0).put("answerDeadline",123456)
            OrbitStrongTasks.initialize(state,OrbitStrongTasks.create(settings,Random(seed)))
            val tasks=state.getJSONArray("tasks");assertEquals(10,tasks.length())
            for(index in 0 until tasks.length()) {
                val q=tasks.getJSONObject(index);val type=q.getString("type");types.add(type)
                val inputs=if(type=="sequence") (1..25).toList() else listOf(OrbitStrongTasks.arithmeticAnswer(q))
                for(input in inputs) {
                    state=JSONObject(state.toString());val snapshot=state.getJSONArray("tasks").toString()
                    OrbitStrongTasks.answer(state,-1);assertEquals(index,state.getInt("taskIndex"));assertEquals(snapshot,state.getJSONArray("tasks").toString())
                    OrbitStrongTasks.answer(state,input);assertEquals(123456,state.getInt("answerDeadline"))
                }
            }
            assertEquals("completed",state.getString("phase"))
        }
        assertEquals(setOf("sequence","arithmetic"),types)
    }
    @Test fun defaultsAndMalformedCountsAreBounded() {
        assertEquals(2,OrbitStrongTasks.create(JSONObject()).length())
        for(value in listOf(-100,100)) {
            val tasks=OrbitStrongTasks.create(JSONObject().put("dismissTask","sequence").put("sequenceRounds",value).put("sequenceNumberCount",value))
            assertEquals(if(value<0) 1 else 10,tasks.length())
            assertEquals(if(value<0) 4 else 25,tasks.getJSONObject(0).getInt("numberCount"))
        }
    }
}
