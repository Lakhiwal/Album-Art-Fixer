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
    if (project.path != ":app" && !project.state.executed) {
        project.evaluationDependsOn(":app")
    }

    fun configureAndroidProject() {
        if (project.extensions.findByName("android") != null) {
            project.extensions.configure<com.android.build.api.dsl.CommonExtension> {
                compileSdk = 37
                buildToolsVersion = "36.0.0"
            }
        }
    }

    if (project.state.executed) {
        configureAndroidProject()
    } else {
        project.afterEvaluate {
            configureAndroidProject()
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
