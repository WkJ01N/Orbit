allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 部分插件（flutter_plugin_android_lifecycle 等）要求 compileSdk >= 36，
// 但插件子項目預設沿用 flutter.compileSdkVersion(34)。此處統一拔高所有
// Android 子項目的 compileSdk，避免 AAR metadata 檢查失敗。
// 注意：必須在 evaluationDependsOn(":app") 之前註冊 afterEvaluate。
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            runCatching {
                androidExt.javaClass
                    .getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(androidExt, 36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
