package app.cronwatch.service

import android.content.Context
import app.cronwatch.AppEnvironment
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.storage.FirebaseStorage
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FirebaseBootstrap @Inject constructor() {
    @Volatile private var configured: Boolean = false

    fun isConfigured(): Boolean = configured

    /** Configures Firebase from BuildConfig values. No-op if any required value is blank. */
    fun configureIfPossible(context: Context): Boolean {
        if (configured) return true
        val projectId = AppEnvironment.firebaseProjectId ?: return false
        val apiKey = AppEnvironment.firebaseApiKey ?: return false
        val appId = AppEnvironment.firebaseAppId ?: return false
        val senderId = AppEnvironment.firebaseSenderId
        val storageBucket = AppEnvironment.firebaseStorageBucket

        if (FirebaseApp.getApps(context).isEmpty()) {
            val options = FirebaseOptions.Builder()
                .setApplicationId(appId)
                .setApiKey(apiKey)
                .setProjectId(projectId)
                .apply {
                    if (!senderId.isNullOrBlank()) setGcmSenderId(senderId)
                    if (!storageBucket.isNullOrBlank()) setStorageBucket(storageBucket)
                }
                .build()
            FirebaseApp.initializeApp(context, options)
        }
        configured = true
        return true
    }

    fun authOrNull(): FirebaseAuth? = if (configured) FirebaseAuth.getInstance() else null
    fun dbOrNull(): FirebaseFirestore? = if (configured) FirebaseFirestore.getInstance() else null
    fun storageOrNull(): FirebaseStorage? = if (configured) FirebaseStorage.getInstance() else null
}
