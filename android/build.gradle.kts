allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val debugAbi = providers.gradleProperty("komet.debugAbi").get()
val debugTargetPlatform =
    when (debugAbi) {
        "armeabi-v7a" -> "android-arm"
        "arm64-v8a" -> "android-arm64"
        "x86" -> "android-x86"
        "x86_64" -> "android-x64"
        else -> error("Unsupported komet.debugAbi: $debugAbi")
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

gradle.projectsEvaluated {
    subprojects {
        tasks.matching {
            it.name.startsWith("cargokitCargoBuild") && it.name.endsWith("Debug")
        }.configureEach {
            javaClass.methods
                .firstOrNull { method ->
                    method.name == "setTargetPlatforms" && method.parameterCount == 1
                }
                ?.invoke(this, listOf(debugTargetPlatform))
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
