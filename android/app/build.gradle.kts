import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { input ->
        keystoreProperties.load(input)
    }
}
val releaseStoreFile = keystoreProperties
    .getProperty("storeFile")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?.let { rootProject.file(it) }

android {
    namespace = "com.sarbaa.cbk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.sarbaa.cbk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && releaseStoreFile != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = releaseStoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                project.file("proguard-rules.pro"),
            )

            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

val verifyReleaseOptimization by tasks.registering {
    group = "verification"
    description = "Verifies that the release build uses R8 and the project ProGuard rules."

    val releaseBuildType = android.buildTypes.getByName("release")
    val customProguardFile = layout.projectDirectory.file("proguard-rules.pro")
    val minifyEnabled = releaseBuildType.isMinifyEnabled
    val shrinkResources = releaseBuildType.isShrinkResources
    val proguardFiles = releaseBuildType.proguardFiles

    doLast {
        check(minifyEnabled) {
            "Release builds must enable minification."
        }
        check(shrinkResources) {
            "Release builds must enable resource shrinking."
        }
        check(customProguardFile.asFile.isFile) {
            "Release builds require ${customProguardFile.asFile}."
        }
        check(customProguardFile.asFile in proguardFiles) {
            "Release builds must attach ${customProguardFile.asFile} to their ProGuard configuration."
        }
    }
}

val verifyReleaseSigning by tasks.registering {
    group = "verification"
    description = "Fails when production Android signing is incomplete."

    doLast {
        check(keystorePropertiesFile.isFile) {
            "Release signing requires the ignored android/key.properties file."
        }

        val requiredProperties = listOf(
            "storeFile",
            "storePassword",
            "keyAlias",
            "keyPassword",
        )
        val missingProperties = requiredProperties.filter { value ->
            keystoreProperties[value]?.toString()?.isBlank() != false
        }
        check(missingProperties.isEmpty()) {
            "Release signing is missing: ${missingProperties.joinToString()}"
        }

        val storePath = keystoreProperties.getProperty("storeFile")
        check(releaseStoreFile?.isFile == true) {
            "Release signing keystore does not exist. Relative storeFile paths resolve from ${rootProject.projectDir}: $storePath"
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(verifyReleaseSigning)
}

flutter {
    source = "../.."
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
