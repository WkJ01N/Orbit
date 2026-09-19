package com.must.orbit.orbit

import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper

/** All counters and the delayed exit share a lock, including worker completions. */
internal class OrbitReminderProcessLifecycle(
    private val handler: Handler,
    private val terminate: () -> Unit,
) {
    private var tasks = 0
    private var serviceInstances = 0
    private var serviceStarts = 0
    private val exit = Runnable {
        synchronized(this) {
            if (tasks == 0 && serviceInstances == 0 && serviceStarts == 0) terminate()
        }
    }

    @Synchronized fun beginTask() { tasks++; handler.removeCallbacks(exit) }
    @Synchronized fun endTask() { check(tasks > 0); tasks--; exitWhenIdle() }
    @Synchronized fun beginServiceStart() { serviceStarts++; handler.removeCallbacks(exit) }
    @Synchronized fun endServiceStart() {
        if (serviceStarts > 0) serviceStarts--
        exitWhenIdle()
    }
    @Synchronized fun cancelServiceStarts() { serviceStarts = 0; exitWhenIdle() }
    @Synchronized fun serviceCreated() { serviceInstances++; handler.removeCallbacks(exit) }
    @Synchronized fun serviceDestroyed() { check(serviceInstances > 0); serviceInstances--; exitWhenIdle() }
    @Synchronized fun exitWhenIdle() {
        handler.removeCallbacks(exit)
        if (tasks == 0 && serviceInstances == 0 && serviceStarts == 0) handler.postDelayed(exit, 250L)
    }
}

/** Keep the 1.3.2 OriginOS workaround, but never kill a receiver still doing work. */
internal object OrbitReminderProcess {
    private var context: Context? = null
    val lifecycle = OrbitReminderProcessLifecycle(Handler(Looper.getMainLooper())) {
        val app = context ?: return@OrbitReminderProcessLifecycle
        val name = if (Build.VERSION.SDK_INT >= 28) Application.getProcessName() else {
            val manager = app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            manager.runningAppProcesses?.firstOrNull { it.pid == android.os.Process.myPid() }?.processName
        }
        if (name == "${app.packageName}:reminders") {
            OrbitReminderDiagnostics.event("process_exit")
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

    fun beginTask(context: Context) {
        OrbitReminderDiagnostics.attach(context)
        this.context = context.applicationContext
        lifecycle.beginTask()
    }

    fun serviceCreated(context: Context) {
        this.context = context.applicationContext
        lifecycle.serviceCreated()
    }
}
