package com.must.orbit.orbit

import android.os.Handler
import android.os.Looper
import org.junit.Assert.assertEquals
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
class OrbitReminderProcessTest {
    private lateinit var lifecycle: OrbitReminderProcessLifecycle
    private var exits = 0

    @Before fun setUp() {
        exits = 0
        lifecycle = OrbitReminderProcessLifecycle(Handler(Looper.getMainLooper())) { exits++ }
    }

    private fun advance() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(250))

    @Test fun newerTaskCancelsExitQueuedByPreviousBroadcast() {
        lifecycle.beginTask()
        lifecycle.endTask()
        lifecycle.beginTask()
        advance()
        assertEquals(0, exits)
        lifecycle.endTask()
        advance()
        assertEquals(1, exits)
    }

    @Test fun completingBroadcastCannotKillAnAsyncRecoveryTask() {
        lifecycle.beginTask() // goAsync recovery worker
        lifecycle.beginTask() // reminder received while recovery is running
        lifecycle.endTask()
        advance()
        assertEquals(0, exits)
        lifecycle.endTask()
        advance()
        assertEquals(1, exits)
    }

    @Test fun serviceIsProtectedBetweenCreationAndBecomingActive() {
        lifecycle.beginTask()
        lifecycle.beginServiceStart()
        lifecycle.endTask()
        advance()
        assertEquals(0, exits)
        lifecycle.serviceCreated()
        lifecycle.endServiceStart()
        advance()
        assertEquals(0, exits)
        lifecycle.serviceDestroyed()
        advance()
        assertEquals(1, exits)
    }

    @Test fun oneServiceCommandCannotClearAnotherPendingStart() {
        lifecycle.beginServiceStart()
        lifecycle.beginServiceStart()
        lifecycle.serviceCreated()
        lifecycle.endServiceStart()
        lifecycle.serviceDestroyed()
        advance()
        assertEquals(0, exits)
        lifecycle.endServiceStart()
        advance()
        assertEquals(1, exits)
    }

    @Test fun failedServiceStartEventuallyAllowsExit() {
        lifecycle.beginServiceStart()
        lifecycle.endServiceStart()
        lifecycle.exitWhenIdle()
        advance()
        assertEquals(1, exits)
    }

    @Test fun canceledStartDoesNotLeaveProcessPermanentlyWaitingForACommand() {
        lifecycle.beginServiceStart()
        lifecycle.serviceCreated()
        lifecycle.cancelServiceStarts()
        advance()
        assertEquals(0, exits)
        lifecycle.serviceDestroyed()
        advance()
        assertEquals(1, exits)
    }
}
