package app.cronwatch.service

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
enum class JobStatus { queued, running, error }

@Serializable
data class CaptureJob(
    val id: String,
    val uid: String,
    val uri: String,
    val status: JobStatus,
    val error: String? = null,
    val createdAt: Long,
)

@Singleton
class CaptureQueue @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val storeFile: File by lazy {
        File(context.filesDir, "capture-queue.json").also { it.parentFile?.mkdirs() }
    }

    private val capturesDir: File by lazy {
        File(context.filesDir, "captures").also { it.mkdirs() }
    }

    private val _jobs = MutableStateFlow<List<CaptureJob>>(emptyList())
    val jobs: StateFlow<List<CaptureJob>> = _jobs.asStateFlow()

    private val json = Json { prettyPrint = false; ignoreUnknownKeys = true }

    @Volatile private var hydrated = false

    @Synchronized
    fun hydrate() {
        if (hydrated) return
        hydrated = true
        val text = runCatching { if (storeFile.exists()) storeFile.readText() else null }.getOrNull()
        if (text.isNullOrBlank()) return
        val parsed = runCatching { json.decodeFromString<List<CaptureJob>>(text) }.getOrNull() ?: return
        // running jobs at boot couldn't have completed; treat as queued.
        _jobs.value = parsed.map { if (it.status == JobStatus.running) it.copy(status = JobStatus.queued) else it }
        if (_jobs.value.any { it.status == JobStatus.queued }) scheduleWorker()
    }

    fun enqueue(uid: String, sourceUri: String): String {
        val id = nextId()
        val destFile = persistAudio(id, sourceUri)
        val job = CaptureJob(
            id = id, uid = uid,
            uri = destFile.absolutePath,
            status = JobStatus.queued,
            createdAt = System.currentTimeMillis(),
        )
        update { it + job }
        scheduleWorker()
        return id
    }

    fun discard(jobId: String) {
        val current = _jobs.value
        val target = current.firstOrNull { it.id == jobId } ?: return
        runCatching { File(target.uri).takeIf { it.exists() }?.delete() }
        update { it.filterNot { j -> j.id == jobId } }
    }

    fun retry(jobId: String) {
        update { it.map { j -> if (j.id == jobId && j.status == JobStatus.error) j.copy(status = JobStatus.queued, error = null) else j } }
        scheduleWorker()
    }

    fun retryAll() {
        update { it.map { j -> if (j.status == JobStatus.error) j.copy(status = JobStatus.queued, error = null) else j } }
        if (_jobs.value.any { it.status == JobStatus.queued }) scheduleWorker()
    }

    internal fun nextQueuedJob(): CaptureJob? = _jobs.value.firstOrNull { it.status == JobStatus.queued }

    internal fun markRunning(jobId: String) {
        update { it.map { j -> if (j.id == jobId) j.copy(status = JobStatus.running, error = null) else j } }
    }

    internal fun complete(jobId: String) {
        val current = _jobs.value
        val target = current.firstOrNull { it.id == jobId }
        if (target != null) {
            runCatching { File(target.uri).takeIf { it.exists() }?.delete() }
        }
        update { it.filterNot { j -> j.id == jobId } }
    }

    internal fun fail(jobId: String, message: String) {
        update { it.map { j -> if (j.id == jobId) j.copy(status = JobStatus.error, error = message) else j } }
    }

    @Synchronized
    private fun update(transform: (List<CaptureJob>) -> List<CaptureJob>) {
        val next = transform(_jobs.value)
        _jobs.value = next
        runCatching { storeFile.writeText(json.encodeToString(next)) }
    }

    private fun nextId(): String =
        "j_${System.currentTimeMillis()}_${(0..0xfffff).random().toString(36)}"

    private fun persistAudio(jobId: String, sourceUri: String): File {
        val src = File(sourceUri)
        val ext = src.extension.ifBlank { "m4a" }
        val dest = File(capturesDir, "$jobId.$ext")
        if (dest.exists()) dest.delete()
        runCatching {
            if (src.exists()) src.copyTo(dest, overwrite = true)
            else dest.writeBytes(ByteArray(0))
        }
        return dest
    }

    private fun scheduleWorker() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val req = OneTimeWorkRequestBuilder<CaptureWorker>()
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_WORK_NAME,
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            req,
        )
    }

    companion object {
        const val UNIQUE_WORK_NAME = "cronwatch-capture-queue"
    }
}
