// This file is the root project's build configuration, written in Kotlin DSL (.kts).

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 1. Calculate the desired location for the unified build directory.
// FIX: Using 'val' for Kotlin variable declaration.
val newBuildDir =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

// 2. FIX: Use '.set()' to assign the Directory to the DirectoryProperty in Kotlin DSL.
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // For each subproject, define its dedicated build directory path relative to the unified build directory.
    val newSubprojectBuildDir = newBuildDir.dir(project.name)

    // 3. FIX: Use '.set()' for the subproject's buildDirectory property.
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

// 4. FIX: Use 'tasks.register<Delete>("clean")' for Kotlin DSL task registration.
tasks.register<Delete>("clean") {
    // 5. FIX: Use the KTS function call 'delete()' with parentheses and proper reference.
    delete(rootProject.layout.buildDirectory)
}