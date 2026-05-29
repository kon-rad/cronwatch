package app.cronwatch.service

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.io.File

@HiltWorker
class CaptureWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val queue: CaptureQueue,
    private val capture: CaptureService,
    private val entries: EntriesService,
    private val toastBus: ToastBus,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        queue.hydrate()
        while (true) {
            val job = queue.nextQueuedJob() ?: break
            queue.markRunning(job.id)
            try {
                val file = File(job.uri)
                val result = capture.captureFromAudio(file)
                entries.createCaptureEntries(
                    uid = job.uid,
                    drafts = result.drafts,
                    source = app.cronwatch.model.EntrySource.voice,
                    transcript = result.transcript,
                )
                queue.complete(job.id)
                toastBus.show("Entry saved.", ToastKind.SUCCESS, durationMs = 2000)
            } catch (t: Throwable) {
                queue.fail(job.id, t.message ?: t::class.simpleName.orEmpty())
                toastBus.show(
                    message = "Saved as draft — tap Retry",
                    kind = ToastKind.ERROR,
                    durationMs = 4000,
                )
                // Stop processing further jobs this run; user can retry.
                return Result.success()
            }
        }
        return Result.success()
    }
}
