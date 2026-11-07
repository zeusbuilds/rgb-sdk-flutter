plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Each packaged ABI must contain Flutter and both wallet engines.
fun selectRgbExampleNativeAbis(targetPlatforms: String): Set<String> {
    val platformAbis = mapOf(
        "android-arm" to "armeabi-v7a",
        "android-arm64" to "arm64-v8a",
        "android-x64" to "x86_64",
    )
    val platforms = targetPlatforms.split(",")
    require(platforms.all { it in platformAbis }) {
        "SDK example received an unsupported Flutter target-platform."
    }
    val selected = platforms.map { platformAbis.getValue(it) }
        .filter { it in setOf("arm64-v8a", "x86_64") }.toSet()
    require(selected.isNotEmpty()) {
        "The dual-engine SDK example requires android-arm64 or android-x64; RGB_L1 has no 32-bit runtime."
    }
    return selected
}

val rgbExampleSelectedNativeAbis = selectRgbExampleNativeAbis(
    providers.gradleProperty("target-platform").orElse("android-arm64,android-x64").get(),
)
val rgbExampleExcludedNativeAbis = setOf("armeabi-v7a", "x86", "arm64-v8a", "x86_64") - rgbExampleSelectedNativeAbis

android {
    namespace = "com.utexo.rgb_sdk_flutter_example"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.utexo.rgb_sdk_flutter_example"
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk { abiFilters.addAll(rgbExampleSelectedNativeAbis) }
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    packaging {
        jniLibs { excludes.addAll(rgbExampleExcludedNativeAbis.map { "**/$it/**" }) }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
