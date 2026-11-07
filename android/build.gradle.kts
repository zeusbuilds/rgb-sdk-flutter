import groovy.json.JsonSlurper
import java.security.MessageDigest

val releaseBaselineFile = file("../tool/release_baseline.json")
require(releaseBaselineFile.isFile) {
    "Missing release baseline: ${releaseBaselineFile.absolutePath}"
}
val releaseBaseline = JsonSlurper().parse(releaseBaselineFile) as Map<*, *>
val rlnBaseline = releaseBaseline["rln"] as Map<*, *>
val rlnAndroidBaseline = rlnBaseline["android"] as Map<*, *>
val rlnAndroidCoordinate = rlnAndroidBaseline["mavenCoordinate"] as String
val rlnAndroidRepository = rlnAndroidBaseline["repositoryUrl"] as String?
val rlnAndroidParts = rlnAndroidCoordinate.split(':')
require(rlnAndroidParts.size == 3 && rlnAndroidParts.all { it.isNotBlank() }) {
    "The RLN Android coordinate must pin group, module and version"
}
// An explicit directory supports offline qualification of the exact pinned
// bytes before publication. It cannot bypass the checksum task below.
val rlnAndroidArtifactDirectory = providers.environmentVariable("RGB_SDK_ANDROID_ARTIFACT_DIR")
val rlnAndroidExpectedSha256 = rlnAndroidBaseline["archiveSha256"] as String
val rlnAndroidExpectedSize = (rlnAndroidBaseline["archiveSizeBytes"] as Number).toLong()
val rgbLibBaselineFile = file("../tool/rgb_lib_native_baseline.json")
val rgbLibBaseline = JsonSlurper().parse(rgbLibBaselineFile) as Map<*, *>
val rgbLibAndroid = rgbLibBaseline["android"] as Map<*, *>
val rgbLibVersion = rgbLibBaseline["version"] as String
val rgbLibCoordinate = rgbLibAndroid["mavenCoordinate"] as String
val rgbLibExpectedSize = (rgbLibAndroid["archiveSizeBytes"] as Number).toLong()
val rgbLibExpectedSha256 = rgbLibAndroid["archiveSha256"] as String
val buildRequirements = releaseBaseline["buildRequirements"] as Map<*, *>
val androidBuildRequirements = buildRequirements["android"] as Map<*, *>
val baselineCompileSdk =
    (androidBuildRequirements["compileSdk"] as Number).toInt()
val baselineMinSdk =
    (androidBuildRequirements["minSdk"] as Number).toInt()
val baselineJavaVersion =
    (androidBuildRequirements["javaLanguageVersion"] as Number).toInt()

group = "com.utexo.rgb_sdk_flutter"
version = "0.2.0-beta.3"

buildscript {
    val baseline =
        groovy.json.JsonSlurper().parse(file("../tool/release_baseline.json")) as Map<*, *>
    val requirements = baseline["buildRequirements"] as Map<*, *>
    val androidRequirements = requirements["android"] as Map<*, *>
    val kotlinVersion = androidRequirements["kotlinVersion"] as String
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

// Consumers resolve transitive plugin dependencies in their own repository
// scope. Register this one-module repository for the application as well.
rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        if (rlnAndroidRepository != null) {
            exclusiveContent {
                forRepository {
                    ivy {
                        name = "verifiedRgbSdkNativeArtifact"
                        url = if (rlnAndroidArtifactDirectory.isPresent) {
                            uri(file(rlnAndroidArtifactDirectory.get()))
                        } else {
                            uri(rlnAndroidRepository)
                        }
                        patternLayout {
                            artifact("[artifact]-[revision].[ext]")
                        }
                        metadataSources { artifact() }
                    }
                }
                filter { includeModule(rlnAndroidParts[0], rlnAndroidParts[1]) }
            }
        }
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.utexo.rgb_sdk_flutter"

    compileSdk = baselineCompileSdk

    compileOptions {
        sourceCompatibility = JavaVersion.toVersion(baselineJavaVersion)
        targetCompatibility = JavaVersion.toVersion(baselineJavaVersion)
    }

    kotlinOptions {
        jvmTarget = JavaVersion.toVersion(baselineJavaVersion).toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
        minSdk = baselineMinSdk
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

val rlnNativeArtifact = configurations.create("rlnNativeArtifact") {
    isCanBeConsumed = false
    isCanBeResolved = true
    isTransitive = false
}

val rgbLibNativeArtifact = configurations.create("rgbLibNativeArtifact") {
    isCanBeConsumed = false
    isCanBeResolved = true
    isTransitive = false
}

fun registerNativeArtifactCheck(
    taskName: String,
    artifactConfiguration: Configuration,
    pin: File,
    expectedSize: Long,
    expectedSha256: String
) = tasks.register(taskName) {
    group = "verification"
    description = "Verify the resolved native AAR against ${pin.name}"
    inputs.files(artifactConfiguration)
    inputs.file(pin)
    doLast {
        val artifact = artifactConfiguration.singleFile
        require(artifact.length() == expectedSize) {
            "Native AAR size differs from ${pin.name}"
        }
        val digest = MessageDigest.getInstance("SHA-256")
        artifact.inputStream().use { input ->
            val buffer = ByteArray(1024 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        require(actual == expectedSha256) {
            "Native AAR SHA-256 differs from ${pin.name}"
        }
    }
}

val verifyRlnNativeArtifact = registerNativeArtifactCheck(
    "verifyRlnNativeArtifact", rlnNativeArtifact,
    releaseBaselineFile, rlnAndroidExpectedSize, rlnAndroidExpectedSha256
)
val verifyRgbLibNativeArtifact = registerNativeArtifactCheck(
    "verifyRgbLibNativeArtifact", rgbLibNativeArtifact,
    rgbLibBaselineFile, rgbLibExpectedSize, rgbLibExpectedSha256
)
tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(verifyRlnNativeArtifact, verifyRgbLibNativeArtifact)
}

dependencies {
    add(rgbLibNativeArtifact.name, "$rgbLibCoordinate@aar") {
        version { strictly(rgbLibVersion) }
    }
    // The pinned AAR's classes depend on JNA and Kotlin. The shared
    // dependencies below already provide both.
    implementation("$rgbLibCoordinate@aar") {
        version { strictly(rgbLibVersion) }
    }
    add(rlnNativeArtifact.name, "$rlnAndroidCoordinate@aar") {
        version { strictly(rlnAndroidParts[2]) }
    }
    implementation(if (rlnAndroidRepository == null) rlnAndroidCoordinate else "$rlnAndroidCoordinate@aar") {
        // A host dependency must fail resolution instead of silently selecting
        // native bytes that differ from the SDK's validated release baseline.
        version { strictly(rlnAndroidParts[2]) }
    }
    // Artifact-only SDK distributions retain the upstream AAR's annotation
    // dependency explicitly; Kotlin is supplied by the Flutter plugin host.
    implementation("androidx.annotation:annotation:1.9.1")
    implementation("net.java.dev.jna:jna:5.17.0@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    // Host JVM tests use the real JSON implementation, not Android's throwing stub.
    testImplementation("org.json:json:20240303")
}
