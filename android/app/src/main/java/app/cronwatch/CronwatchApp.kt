package app.cronwatch

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import app.cronwatch.service.AuthService
import app.cronwatch.service.CaptureQueue
import app.cronwatch.service.FirebaseBootstrap
import app.cronwatch.service.RevenueCatService
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class CronwatchApp : Application(), Configuration.Provider {
    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var firebase: FirebaseBootstrap
    @Inject lateinit var auth: AuthService
    @Inject lateinit var revenueCat: RevenueCatService
    @Inject lateinit var captureQueue: CaptureQueue

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        firebase.configureIfPossible(this)
        auth.startListening()
        revenueCat.configureIfNeeded()
        captureQueue.hydrate()
    }
}
