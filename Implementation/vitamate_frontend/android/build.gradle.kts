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

    // Flutter's integration_test plugin requests old AndroidX test artifacts
    // with dynamic versions. Pin them so normal app builds are reproducible and
    // do not require Maven metadata when the artifacts are already cached.
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            when (requested.group to requested.name) {
                "androidx.test" to "runner" -> useVersion("1.2.0")
                "androidx.test" to "rules" -> useVersion("1.2.0")
                "androidx.test.espresso" to "espresso-core" -> useVersion("3.2.0")
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
