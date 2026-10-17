package com.must.orbit.orbit

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

object OrbitUpdateInspector {
    @Suppress("DEPRECATION")
    fun inspect(context: Context, path: String): Map<String, Any> {
        val root = File(context.getExternalFilesDir(null),"updates").canonicalFile
        val file = File(path).canonicalFile
        require(file.parentFile == root && file.isFile && file.extension == "apk") { "Invalid update package" }
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val archive = context.packageManager.getPackageArchiveInfo(file.path,flags) ?: error("Invalid APK")
        val current = context.packageManager.getPackageInfo(context.packageName,flags)
        val abis = ZipFile(file).use { zip -> zip.entries().asSequence().map { it.name }.filter { it.startsWith("lib/") && it.endsWith("/libflutter.so") }.map { it.split('/')[1] }.toSet() }
        return validate(context.packageName,archive,current,abis,Build.SUPPORTED_ABIS)
    }

    @Suppress("DEPRECATION")
    internal fun validate(packageName: String, archive: PackageInfo, current: PackageInfo,
                          abis: Set<String>, supportedAbis: Array<String>): Map<String, Any> {
        require(archive.packageName == packageName) { "Wrong application package" }
        fun signatures(info: PackageInfo): Set<String> {
            val values = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
            return values?.map { signature -> MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) } }?.toSet() ?: emptySet()
        }
        val installed = signatures(current)
        require(installed.isNotEmpty() && signatures(archive) == installed) { "APK signing certificate differs" }
        require(abis.isNotEmpty() && supportedAbis.any { it in abis }) { "Unsupported architecture" }
        val code = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
        val installedCode = if (Build.VERSION.SDK_INT >= 28) current.longVersionCode else current.versionCode.toLong()
        return mapOf("versionName" to (archive.versionName ?: ""),"versionCode" to code,"installedVersionCode" to installedCode,"abis" to abis.toList())
    }
}
