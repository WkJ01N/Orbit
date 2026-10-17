package com.must.orbit.orbit

import android.content.pm.PackageInfo
import android.content.pm.Signature
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [27])
class OrbitUpdateInspectorTest {
    @Suppress("DEPRECATION")
    private fun info(name: String = "com.must.orbit.orbit", code: Int = 31, signature: Byte = 1) = PackageInfo().apply {
        packageName = name
        versionName = "1.6.1"
        versionCode = code
        signatures = arrayOf(Signature(byteArrayOf(signature,2,3)))
    }
    @Test fun acceptsMatchingIdentityAndReportsTheActualVersion() {
        val result = OrbitUpdateInspector.validate("com.must.orbit.orbit",info(code=30),info(),setOf("arm64-v8a"),arrayOf("arm64-v8a"))
        assertEquals(30L,result["versionCode"])
        assertEquals(31L,result["installedVersionCode"])
    }
    @Test fun rejectsWrongPackageSignatureAndArchitecture() {
        for (archive in listOf(info(name="other.package"),info(signature=9))) {
            assertThrows(IllegalArgumentException::class.java) {
                OrbitUpdateInspector.validate("com.must.orbit.orbit",archive,info(),setOf("arm64-v8a"),arrayOf("arm64-v8a"))
            }
        }
        assertThrows(IllegalArgumentException::class.java) {
            OrbitUpdateInspector.validate("com.must.orbit.orbit",info(),info(),setOf("x86_64"),arrayOf("arm64-v8a"))
        }
    }
}
