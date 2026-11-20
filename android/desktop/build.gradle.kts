// desktop: luksMusic for Linux desktops, made for the Steam Deck on a piano's music stand (Compose Multiplatform for
// Desktop). Shares :core with the Android app: models, MusicXML, reading drill, Modo Estudo rules and the piano synth.
import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.compose.multiplatform)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

/** Folders shared with the iOS and Android apps, read in place (never copied into this module). */
val sampleScores = rootProject.file("../luksMusic/SampleScores")
val appIcon = rootProject.file("../luksMusic/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

/** The bundled scores under samples/, with an index (a jar can't list its folders), and the icon. */
val bundledResources = tasks.register("bundledResources") {
    val out = layout.buildDirectory.dir("generated/bundled")
    inputs.dir(sampleScores)
    inputs.file(appIcon)
    outputs.dir(out)
    doLast {
        val dir = out.get().asFile
        dir.deleteRecursively()
        val samples = File(dir, "samples").apply { mkdirs() }
        val names = sampleScores.listFiles { f -> f.extension == "musicxml" }.orEmpty().map { it.name }.sorted()
        names.forEach { File(sampleScores, it).copyTo(File(samples, it)) }
        File(samples, "index.txt").writeText(names.joinToString("\n"))
        appIcon.copyTo(File(dir, "icon/luksMusic.png"))
    }
}
sourceSets.main { resources.srcDir(bundledResources) }

dependencies {
    implementation(project(":core"))
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation(compose.materialIconsExtended)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.swing)
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(compose.desktop.uiTestJUnit4)
}

compose.desktop {
    application {
        mainClass = "com.lukstrike.luksmusic.desktop.MainKt"
        jvmArgs += listOf("-Dsun.java2d.uiScale.enabled=true")
        nativeDistributions {
            targetFormats(TargetFormat.AppImage)
            packageName = "luksMusic"
            packageVersion = "1.0.0"
            description = "Piano sight-reading and practice with a MIDI keyboard"
            vendor = "lukstrike"
            modules("java.desktop", "java.prefs", "jdk.unsupported", "java.naming", "jdk.accessibility")
            linux {
                iconFile.set(appIcon)
            }
        }
    }
}

/** Renders the screens at 1280×800 into build/screens (see ScreenshotTest). */
tasks.register<Test>("screenshots") {
    description = "Renders the main screens at the Steam Deck's 1280x800 into build/screens"
    group = "verification"
    testClassesDirs = sourceSets.test.get().output.classesDirs
    classpath = sourceSets.test.get().runtimeClasspath
    filter { includeTestsMatching("*ScreenshotTest*") }
    systemProperty("luksmusic.screens", layout.buildDirectory.dir("screens").get().asFile.absolutePath)
}
tasks.test {
    filter { excludeTestsMatching("*ScreenshotTest*") }
}

/**
 * The Steam Deck package: the self-contained app (its own Java runtime, from createDistributable, which must run on
 * Linux), the menu entry, its installer and the icon, as build/dist/luksMusic-linux-x64.tar.gz. See
 * packaging/build-linux.sh to build it in a Docker container from Windows or macOS.
 */
tasks.register<Tar>("packageDeckTarball") {
    group = "distribution"
    description = "Packs the Linux app image for the Steam Deck into build/dist/luksMusic-linux-x64.tar.gz"
    dependsOn("createDistributable")
    archiveFileName.set("luksMusic-linux-x64.tar.gz")
    destinationDirectory.set(layout.buildDirectory.dir("dist"))
    compression = Compression.GZIP
    into("luksMusic") {
        from(layout.buildDirectory.dir("compose/binaries/main/app/luksMusic"))
        // Explicit modes: the sources may come from a Windows checkout, which has none
        from("packaging/luksMusic.desktop") { filePermissions { unix("rw-r--r--") } }
        from("packaging/install.sh") { filePermissions { unix("rwxr-xr-x") } }
        from(appIcon) { rename { "luksMusic.png" }; filePermissions { unix("rw-r--r--") } }
    }
}
