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
    // Callback ANTES de evaluationDependsOn para que se registre antes de
    // que el subproyecto se evalúe. Fuerza compileSdk >=34 en plugins con
    // compileSdk viejo fijado (p.ej. app_links 3.x).
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            try {
                androidExt.javaClass.methods
                    .firstOrNull { it.name == "compileSdkVersion" && it.parameterTypes.size == 1 }
                    ?.invoke(androidExt, 36)
            } catch (_: Exception) {
                logger.warn("No se pudo forzar compileSdk para ${project.name}")
            }
        }
    }
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
