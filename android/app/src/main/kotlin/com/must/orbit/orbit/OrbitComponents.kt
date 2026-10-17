package com.must.orbit.orbit

import android.app.Activity
import android.os.Build
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

object OrbitComponents {
    fun attach(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.must.orbit.orbit/components").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "processAbi" -> {
                        val abis = if (Process.is64Bit()) Build.SUPPORTED_64_BIT_ABIS else Build.SUPPORTED_32_BIT_ABIS
                        result.success(abis.firstOrNull { it in listOf("arm64-v8a", "armeabi-v7a", "x86_64") })
                    }
                    "loadVideo" -> {
                        val root = File(activity.filesDir, "components").canonicalFile
                        val dir = File(call.argument<String>("directory") ?: "").canonicalFile
                        require(dir.parentFile == root && dir.name.matches(Regex("video-android-(arm64-v8a|armeabi-v7a|x86_64)-[0-9]+-[a-f0-9]{12}")))
                        val library = File(dir, "libmpv.so").canonicalFile
                        require(library.parentFile == dir && library.isFile)
                        require(library.setReadOnly()) { "Cannot protect runtime file" }
                        System.load(library.absolutePath)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("component_load", error.message ?: "Component unavailable", null)
            }
        }
    }
}
