import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

// google-services is applied conditionally below so the build still works
// without a real google-services.json (stub mode).
val hasGoogleServicesJson = file("google-services.json").exists()
if (hasGoogleServicesJson) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun envOrLocal(key: String): String =
    (localProps.getProperty(key) ?: System.getenv(key) ?: "").also { /* may be empty in stub mode */ }

android {
    namespace = "app.cronwatch"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.konradgnat.cronwatch.android"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }

        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"${envOrLocal("FIREBASE_PROJECT_ID")}\"")
        buildConfigField("String", "FIREBASE_API_KEY", "\"${envOrLocal("FIREBASE_API_KEY")}\"")
        buildConfigField("String", "FIREBASE_APP_ID", "\"${envOrLocal("FIREBASE_APP_ID")}\"")
        buildConfigField("String", "FIREBASE_SENDER_ID", "\"${envOrLocal("FIREBASE_MESSAGING_SENDER_ID")}\"")
        buildConfigField("String", "FIREBASE_STORAGE_BUCKET", "\"${envOrLocal("FIREBASE_STORAGE_BUCKET")}\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${envOrLocal("GOOGLE_WEB_CLIENT_ID")}\"")
        buildConfigField("String", "CAPTURE_PROXY_URL", "\"${envOrLocal("CAPTURE_PROXY_URL")}\"")
        buildConfigField("String", "REVENUECAT_API_KEY_ANDROID", "\"${envOrLocal("REVENUECAT_API_KEY_ANDROID")}\"")
    }

    signingConfigs {
        getByName("debug") {
            // Standard debug keystore used by Android Studio. No-op if missing.
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/DEPENDENCIES"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs = listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi",
            "-opt-in=androidx.compose.animation.ExperimentalAnimationApi",
            "-opt-in=androidx.compose.ui.ExperimentalComposeUiApi",
            "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi",
            "-opt-in=kotlinx.serialization.ExperimentalSerializationApi"
        )
    }
}

dependencies {
    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.work.runtime)
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services.auth)
    implementation(libs.androidx.browser)

    implementation(libs.google.id)
    implementation(libs.play.services.auth)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.foundation)
    implementation(libs.compose.animation)
    implementation(libs.compose.runtime)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.hilt.work)
    ksp(libs.hilt.work.compiler)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.auth)
    implementation(libs.firebase.firestore)
    implementation(libs.firebase.storage)

    implementation(libs.revenuecat)

    implementation(libs.media3.exoplayer)
    implementation(libs.media3.ui)

    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.coroutines.play.services)

    implementation(libs.coil.compose)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.espresso.core)
}
