plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}

allprojects {
    repositories {
        // 🚀 PRIORITY MIRRORS (Must be at the top)
        maven { url = uri("https://dl.cloudsmith.io/public/arthenica/ffmpeg-kit/maven/") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://jitpack.io") }
        
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

// 🛠️ Industrial Patch (V2): Safe Namespace injection
subprojects {
    val patchNamespace = Action<Project> {
        if (hasProperty("android")) {
            val android = extensions.getByName("android")
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                if (getNamespace.invoke(android) == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, group.toString())
                }
            } catch (e: Exception) { }
        }
    }

    if (state.executed) {
        patchNamespace.execute(this)
    } else {
        afterEvaluate { patchNamespace.execute(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
