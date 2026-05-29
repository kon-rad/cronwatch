package app.cronwatch.service

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AudioRecorder @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    @Volatile private var recorder: MediaRecorder? = null
    @Volatile private var currentFile: File? = null

    val isRecording: Boolean get() = recorder != null

    fun start(): File {
        if (recorder != null) error("AudioRecorder is already running")
        val dir = File(context.cacheDir, "recordings").apply { mkdirs() }
        val out = File(dir, "rec_${System.currentTimeMillis()}.m4a")

        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION") MediaRecorder()
        }
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioEncodingBitRate(96_000)
        r.setAudioSamplingRate(44_100)
        r.setOutputFile(out.absolutePath)
        r.prepare()
        r.start()
        recorder = r
        currentFile = out
        return out
    }

    /** Stops recording and returns the produced file, or null if not recording. */
    fun stop(): File? {
        val r = recorder ?: return null
        try {
            r.stop()
        } catch (_: Exception) {
            // stop() can throw RuntimeException if no audio was captured. Silently ignore.
        }
        r.release()
        recorder = null
        val f = currentFile
        currentFile = null
        return f
    }

    fun cancel() {
        recorder?.let { r ->
            try { r.stop() } catch (_: Exception) {}
            r.release()
        }
        recorder = null
        currentFile?.delete()
        currentFile = null
    }
}
