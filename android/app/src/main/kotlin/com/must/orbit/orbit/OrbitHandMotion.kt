package com.must.orbit.orbit

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import kotlin.math.sqrt

/** Foreground-only, low-rate motion context. No recording or persistence. */
class OrbitHandMotion(context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler, SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val channel = EventChannel(messenger, "com.must.orbit.orbit/hand_motion")
    private val gravity = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gyro = manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    private var sink: EventChannel.EventSink? = null
    private var foreground = false
    private var listening = false
    private var gravityZ: Float? = null
    private var angularSpeed: Double? = null
    private var lastSent = 0L

    init { channel.setStreamHandler(this) }

    fun resume() { foreground = true; sync() }
    fun pause() { foreground = false; sync() }
    fun dispose() {
        sink = null
        foreground = false
        sync()
        channel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        sync()
    }
    override fun onCancel(arguments: Any?) { sink = null; sync() }

    private fun sync() {
        val wanted = foreground && sink != null
        if (wanted == listening) return
        listening = wanted
        gravityZ = null
        angularSpeed = null
        lastSent = 0L
        if (!wanted) { manager.unregisterListener(this); return }
        // 30 Hz requires no high-sampling-rate or body-sensor permission.
        try {
            gravity?.let { manager.registerListener(this, it, 33_333) }
            gyro?.let { manager.registerListener(this, it, 33_333) }
        } catch (_: SecurityException) {
            manager.unregisterListener(this)
            sink?.success(emptyMap<String, Any>())
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!listening) return
        when (event.sensor.type) {
            Sensor.TYPE_GRAVITY -> gravityZ = event.values[2]
            Sensor.TYPE_ACCELEROMETER -> {
                gravityZ = gravityZ?.let { it * .85f + event.values[2] * .15f }
                    ?: event.values[2]
            }
            Sensor.TYPE_GYROSCOPE -> {
                val v = event.values
                angularSpeed = sqrt((v[0]*v[0] + v[1]*v[1] + v[2]*v[2]).toDouble())
            }
        }
        val now = SystemClock.elapsedRealtime()
        if (now - lastSent < 33) return
        lastSent = now
        sink?.success(mapOf("gravityZ" to gravityZ, "angularSpeed" to angularSpeed))
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
