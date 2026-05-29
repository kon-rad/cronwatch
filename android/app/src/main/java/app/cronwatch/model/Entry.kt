package app.cronwatch.model

import kotlinx.serialization.Serializable

@Serializable
enum class EntrySource { voice, text }

@Serializable
data class Entry(
    val id: String,
    val captureId: String,
    val category: String,
    val note: String,
    val startTime: String,
    val endTime: String,
    val source: EntrySource,
    val transcript: String? = null,
    val createdAt: String,
)

@Serializable
data class CapturedEntryDraft(
    val category: String,
    val note: String,
    val startTime: String,
    val endTime: String,
)

data class Capture(
    val captureId: String,
    val source: EntrySource,
    val transcript: String?,
    val createdAt: String,
    val blocks: List<Entry>,
)
