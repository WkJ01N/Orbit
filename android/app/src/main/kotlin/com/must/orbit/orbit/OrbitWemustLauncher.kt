package com.must.orbit.orbit

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Package-scoped public intents only; launching does not attest page arrival. */
object OrbitWemustLauncher {
    private const val targetPackage = "cn.doocom.wemustcampus"
    // Inferred from the 1.13.1 manifest and bundled services.json. Device QA pending.
    private const val timetableUri = "wmstud://must.edu.mo/services/S-WM-CLASS-TIMETABLE-APP"

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.must.orbit.orbit/wemust").setMethodCallHandler { call, result ->
            if (call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
            try {
                @Suppress("DEPRECATION")
                activity.packageManager.getPackageInfo(targetPackage, 0)
            } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
                result.success("notInstalled")
                return@setMethodCallHandler
            }
            if (call.argument<Boolean>("timetable") != false) {
                val link = Intent(Intent.ACTION_VIEW, Uri.parse(timetableUri))
                    .setPackage(targetPackage)
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                try {
                    activity.startActivity(link)
                    result.success("linkLaunched")
                    return@setMethodCallHandler
                } catch (_: ActivityNotFoundException) {
                    // Older WeMust releases may not expose the service deep link.
                } catch (_: SecurityException) {
                    // Protected activities cannot be reached by requesting a permission.
                }
            }
            try {
                val launcher = activity.packageManager.getLaunchIntentForPackage(targetPackage)
                if (launcher == null) { result.success("failed") }
                else { activity.startActivity(launcher); result.success("appLaunched") }
            } catch (_: Exception) { result.success("failed") }
        }
    }
}
