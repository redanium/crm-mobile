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
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker 9.x hard-codes Android API 34. Its Android lifecycle dependency
// now requires API 36, so raise only that library module's compile SDK.
subprojects {
    if (name == "file_picker") {
        afterEvaluate {
            val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
            val compileSdkSetter = androidExtension.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterCount == 1
            }
            if (compileSdkSetter != null) {
                compileSdkSetter.invoke(androidExtension, 36)
            } else {
                androidExtension.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdkVersion" && it.parameterCount == 1
                }?.invoke(androidExtension, "android-36")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
