package app.cronwatch.service

import app.cronwatch.AppEnvironment
import app.cronwatch.model.CapturedEntryDraft
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.DataOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

data class CaptureResult(
    val transcript: String,
    val drafts: List<CapturedEntryDraft>,
)

@Singleton
class CaptureService @Inject constructor(
    private val auth: AuthService,
) {
    private val json = Json { ignoreUnknownKeys = true }

    private fun proxyBase(): String? {
        val raw = AppEnvironment.captureProxyUrl ?: return null
        return raw.trimEnd('/')
    }

    private fun deviceTimezone(): String =
        TimeZone.getDefault().id ?: "UTC"

    private fun isoNow(now: Date): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return fmt.format(now)
    }

    suspend fun captureFromAudio(audioFile: File, now: Date = Date()): CaptureResult =
        withContext(Dispatchers.IO) {
            val base = proxyBase()
            val token = auth.idToken()
            if (base == null || token == null) {
                delay(600)
                return@withContext stubResult(audioFile.name)
            }
            val boundary = "----CronwatchBoundary${System.currentTimeMillis()}"
            val url = URL("$base/capture")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                connectTimeout = 30_000
                readTimeout = 120_000
            }
            try {
                DataOutputStream(conn.outputStream).use { out ->
                    writeFormField(out, boundary, "now", isoNow(now))
                    writeFormField(out, boundary, "tz", deviceTimezone())
                    writeFileField(out, boundary, "audio", audioFile, mimeForExt(audioFile.extension))
                    out.writeBytes("--$boundary--\r\n")
                    out.flush()
                }
                if (conn.responseCode !in 200..299) {
                    val err = conn.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                    throw RuntimeException("Capture failed (${conn.responseCode})${if (err.isNotBlank()) ": $err" else ""}")
                }
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val obj = json.parseToJsonElement(body).jsonObject
                val transcript = obj["transcript"]?.jsonPrimitive?.contentOrNull
                    ?: error("Capture response missing transcript")
                val drafts = parseDrafts(obj["drafts"]?.jsonArray ?: JsonArray(emptyList()))
                CaptureResult(transcript, drafts)
            } finally {
                conn.disconnect()
            }
        }

    suspend fun captureFromText(text: String, now: Date = Date()): List<CapturedEntryDraft> =
        withContext(Dispatchers.IO) {
            val trimmed = text.trim()
            require(trimmed.isNotEmpty()) { "Empty entry text" }
            val base = proxyBase()
            val token = auth.idToken()
            if (base == null || token == null) {
                delay(500)
                return@withContext listOf(
                    CapturedEntryDraft(
                        category = "deep",
                        note = trimmed,
                        startTime = isoNow(now),
                        endTime = isoNow(now),
                    ),
                )
            }
            val payload = """{"transcript":${jsonString(trimmed)},"now":${jsonString(isoNow(now))},"tz":${jsonString(deviceTimezone())}}"""
            val conn = (URL("$base/structure").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 30_000
                readTimeout = 60_000
            }
            try {
                conn.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
                if (conn.responseCode !in 200..299) {
                    val err = conn.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                    throw RuntimeException("Structure failed (${conn.responseCode})${if (err.isNotBlank()) ": $err" else ""}")
                }
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val obj = json.parseToJsonElement(body).jsonObject
                parseDrafts(obj["drafts"]?.jsonArray ?: JsonArray(emptyList()))
            } finally {
                conn.disconnect()
            }
        }

    private fun stubResult(filename: String): CaptureResult {
        val nowIso = isoNow(Date())
        return CaptureResult(
            transcript = "deep work on the auth refactor from 9 to 10:30",
            drafts = listOf(
                CapturedEntryDraft(
                    category = "deep",
                    note = "stubbed capture",
                    startTime = nowIso,
                    endTime = nowIso,
                ),
            ),
        )
    }

    private fun parseDrafts(arr: JsonArray): List<CapturedEntryDraft> {
        if (arr.isEmpty()) error("Capture response had no drafts")
        return arr.map { el ->
            val o = el.jsonObject
            CapturedEntryDraft(
                category = o["category"]?.jsonPrimitive?.contentOrNull.orEmpty(),
                note = o["note"]?.jsonPrimitive?.contentOrNull.orEmpty(),
                startTime = o["startTime"]?.jsonPrimitive?.contentOrNull.orEmpty(),
                endTime = o["endTime"]?.jsonPrimitive?.contentOrNull.orEmpty(),
            )
        }
    }

    private fun writeFormField(out: DataOutputStream, boundary: String, name: String, value: String) {
        out.writeBytes("--$boundary\r\n")
        out.writeBytes("Content-Disposition: form-data; name=\"$name\"\r\n\r\n")
        out.write(value.toByteArray(Charsets.UTF_8))
        out.writeBytes("\r\n")
    }

    private fun writeFileField(
        out: DataOutputStream,
        boundary: String,
        name: String,
        file: File,
        mime: String,
    ) {
        out.writeBytes("--$boundary\r\n")
        out.writeBytes("Content-Disposition: form-data; name=\"$name\"; filename=\"${file.name}\"\r\n")
        out.writeBytes("Content-Type: $mime\r\n\r\n")
        file.inputStream().use { it.copyTo(out) }
        out.writeBytes("\r\n")
    }

    private fun mimeForExt(ext: String): String = when (ext.lowercase(Locale.US)) {
        "wav" -> "audio/wav"
        "mp3" -> "audio/mpeg"
        "webm" -> "audio/webm"
        "ogg" -> "audio/ogg"
        "caf" -> "audio/x-caf"
        else -> "audio/m4a"
    }

    private fun jsonString(s: String): String {
        val sb = StringBuilder(s.length + 2).append('"')
        for (c in s) {
            when (c) {
                '"' -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '\b' -> sb.append("\\b")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                else -> if (c.code < 0x20) sb.append(String.format("\\u%04x", c.code)) else sb.append(c)
            }
        }
        return sb.append('"').toString()
    }
}
