package app.cronwatch

object AppEnvironment {
    val firebaseProjectId: String? get() = BuildConfig.FIREBASE_PROJECT_ID.ifBlankNull()
    val firebaseApiKey: String? get() = BuildConfig.FIREBASE_API_KEY.ifBlankNull()
    val firebaseAppId: String? get() = BuildConfig.FIREBASE_APP_ID.ifBlankNull()
    val firebaseSenderId: String? get() = BuildConfig.FIREBASE_SENDER_ID.ifBlankNull()
    val firebaseStorageBucket: String? get() = BuildConfig.FIREBASE_STORAGE_BUCKET.ifBlankNull()
    val googleWebClientId: String? get() = BuildConfig.GOOGLE_WEB_CLIENT_ID.ifBlankNull()
    val captureProxyUrl: String? get() = BuildConfig.CAPTURE_PROXY_URL.ifBlankNull()
    val revenueCatApiKey: String? get() = BuildConfig.REVENUECAT_API_KEY_ANDROID.ifBlankNull()

    private fun String.ifBlankNull(): String? = takeIf { it.isNotBlank() }
}
