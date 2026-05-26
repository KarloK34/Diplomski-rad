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

    // Plugins like tflite_flutter pin sourceCompatibility/targetCompatibility
    // to JVM 11 inside their own build.gradle.kts; KGP now follows the system
    // JDK so Kotlin defaults to 17/21. The mismatch fails the build under
    // strict KGP. Override every Android subproject AFTER its own evaluation
    // so the unified target wins.
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        extensions.findByType(
            org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java
        )?.compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
