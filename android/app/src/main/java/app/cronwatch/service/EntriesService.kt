package app.cronwatch.service

import app.cronwatch.model.Capture
import app.cronwatch.model.CapturedEntryDraft
import app.cronwatch.model.Entry
import app.cronwatch.model.EntrySource
import app.cronwatch.util.TimeUtils
import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

data class Page(val entries: List<Entry>, val cursor: DocumentSnapshot?, val hasMore: Boolean)

@Singleton
class EntriesService @Inject constructor(
    private val bootstrap: FirebaseBootstrap,
) {
    // Stub mode in-memory store, shared by all callers (mirrors RN behavior).
    private val stubStore = MutableStateFlow<List<Entry>>(emptyList())

    private fun col(uid: String) =
        bootstrap.dbOrNull()?.collection("users")?.document(uid)?.collection("entries")

    private fun fromSnap(d: DocumentSnapshot): Entry {
        val data = d.data ?: emptyMap()
        val start = (data["startTime"] as? Timestamp)?.toDate() ?: Date(0)
        val end = (data["endTime"] as? Timestamp)?.toDate() ?: Date(0)
        val created = (data["createdAt"] as? Timestamp)?.toDate() ?: Date()
        val srcStr = data["source"] as? String
        return Entry(
            id = d.id,
            captureId = (data["captureId"] as? String)?.ifBlank { null } ?: d.id,
            category = (data["category"] as? String).orEmpty(),
            note = (data["note"] as? String).orEmpty(),
            startTime = TimeUtils.toIso(start),
            endTime = TimeUtils.toIso(end),
            source = if (srcStr == "text") EntrySource.text else EntrySource.voice,
            transcript = data["transcript"] as? String,
            createdAt = TimeUtils.toIso(created),
        )
    }

    private fun newCaptureId(): String =
        "c_${System.currentTimeMillis()}_${(0..0xffff).random().toString(16)}"

    fun subscribeToday(uid: String): Flow<List<Entry>> {
        val c = col(uid) ?: return stubStore.asStateFlow()
        return callbackFlow {
            val q: Query = c
                .whereGreaterThanOrEqualTo("startTime", Timestamp(TimeUtils.startOfToday()))
                .whereLessThanOrEqualTo("startTime", Timestamp(TimeUtils.endOfToday()))
                .orderBy("startTime", Query.Direction.ASCENDING)
            val reg: ListenerRegistration = q.addSnapshotListener { snap, _ ->
                if (snap != null) trySend(snap.documents.map { fromSnap(it) })
            }
            awaitClose { reg.remove() }
        }
    }

    fun subscribeRange(uid: String, from: Date, to: Date): Flow<List<Entry>> {
        val c = col(uid) ?: return stubStore.map { all ->
            all.filter {
                val t = TimeUtils.parseIso(it.startTime).time
                t in from.time..to.time
            }
        }
        return callbackFlow {
            val q = c
                .whereGreaterThanOrEqualTo("startTime", Timestamp(from))
                .whereLessThanOrEqualTo("startTime", Timestamp(to))
                .orderBy("startTime", Query.Direction.ASCENDING)
            val reg = q.addSnapshotListener { snap, _ ->
                if (snap != null) trySend(snap.documents.map { fromSnap(it) })
            }
            awaitClose { reg.remove() }
        }
    }

    fun subscribeFirstPage(uid: String, pageSize: Int): Flow<Page> {
        val c = col(uid) ?: return stubStore.map { all ->
            Page(all.sortedByDescending { it.startTime }.take(pageSize), null, false)
        }
        return callbackFlow {
            val q = c.orderBy("createdAt", Query.Direction.DESCENDING).limit(pageSize.toLong())
            val reg = q.addSnapshotListener { snap, _ ->
                if (snap != null) {
                    val entries = snap.documents.map { fromSnap(it) }
                    val cursor = snap.documents.lastOrNull()
                    trySend(Page(entries, cursor, entries.size >= pageSize))
                }
            }
            awaitClose { reg.remove() }
        }
    }

    suspend fun loadMore(uid: String, cursor: DocumentSnapshot?, pageSize: Int): Page {
        val c = col(uid) ?: return Page(emptyList(), null, false)
        if (cursor == null) return Page(emptyList(), null, false)
        val q = c.orderBy("createdAt", Query.Direction.DESCENDING)
            .startAfter(cursor)
            .limit(pageSize.toLong())
        val snap = q.get().await()
        val entries = snap.documents.map { fromSnap(it) }
        val last = snap.documents.lastOrNull()
        return Page(entries, last, entries.size >= pageSize)
    }

    suspend fun getCapture(uid: String, captureId: String): Capture? {
        val c = col(uid) ?: run {
            val all = stubStore.value.filter { it.captureId == captureId || it.id == captureId }
            return if (all.isEmpty()) null else groupByCapture(all).firstOrNull()
        }
        var blocks = c.whereEqualTo("captureId", captureId).get().await()
            .documents.map { fromSnap(it) }
        if (blocks.isEmpty()) {
            val single = c.document(captureId).get().await()
            if (single.exists()) blocks = listOf(fromSnap(single))
        }
        if (blocks.isEmpty()) return null
        return groupByCapture(blocks).firstOrNull()
    }

    suspend fun createCaptureEntries(
        uid: String,
        drafts: List<CapturedEntryDraft>,
        source: EntrySource,
        transcript: String?,
    ): List<Entry> {
        require(drafts.isNotEmpty()) { "createCaptureEntries called with no drafts" }
        val captureId = newCaptureId()
        val nowIso = TimeUtils.toIso(Date())
        val parsed = drafts.map { d ->
            val s = TimeUtils.parseIso(d.startTime)
            val e = TimeUtils.parseIso(d.endTime)
            require(!e.before(s)) { "Entry endTime is before startTime" }
            Triple(d, s, e)
        }

        val c = col(uid) ?: run {
            val baseTs = System.currentTimeMillis()
            val created = parsed.mapIndexed { i, (d, s, e) ->
                Entry(
                    id = "e${baseTs}_${i}",
                    captureId = captureId,
                    category = d.category,
                    note = d.note,
                    startTime = TimeUtils.toIso(s),
                    endTime = TimeUtils.toIso(e),
                    source = source,
                    transcript = transcript,
                    createdAt = nowIso,
                )
            }
            stubStore.value = stubStore.value + created
            return created
        }

        val batch = c.firestore.batch()
        val created = mutableListOf<Entry>()
        for ((d, s, e) in parsed) {
            val ref = c.document()
            val data = mutableMapOf<String, Any?>(
                "captureId" to captureId,
                "category" to d.category,
                "note" to d.note,
                "startTime" to Timestamp(s),
                "endTime" to Timestamp(e),
                "source" to source.name,
                "transcript" to transcript,
                "createdAt" to FieldValue.serverTimestamp(),
            )
            batch.set(ref, data)
            created.add(
                Entry(
                    id = ref.id,
                    captureId = captureId,
                    category = d.category,
                    note = d.note,
                    startTime = TimeUtils.toIso(s),
                    endTime = TimeUtils.toIso(e),
                    source = source,
                    transcript = transcript,
                    createdAt = nowIso,
                ),
            )
        }
        batch.commit().await()
        return created
    }

    suspend fun updateEntry(
        uid: String,
        id: String,
        category: String? = null,
        note: String? = null,
        startTime: String? = null,
        endTime: String? = null,
    ) {
        val c = col(uid) ?: run {
            stubStore.value = stubStore.value.map { e ->
                if (e.id != id) e else e.copy(
                    category = category ?: e.category,
                    note = note ?: e.note,
                    startTime = startTime ?: e.startTime,
                    endTime = endTime ?: e.endTime,
                )
            }
            return
        }
        val patch = buildMap<String, Any> {
            category?.let { put("category", it) }
            note?.let { put("note", it) }
            startTime?.let { put("startTime", Timestamp(TimeUtils.parseIso(it))) }
            endTime?.let { put("endTime", Timestamp(TimeUtils.parseIso(it))) }
        }
        if (patch.isNotEmpty()) c.document(id).update(patch).await()
    }

    suspend fun deleteEntry(uid: String, id: String) {
        val c = col(uid) ?: run {
            stubStore.value = stubStore.value.filterNot { it.id == id }
            return
        }
        c.document(id).delete().await()
    }

    fun groupByCapture(entries: List<Entry>): List<Capture> {
        val order = mutableListOf<String>()
        val byId = linkedMapOf<String, MutableList<Entry>>()
        for (e in entries) {
            val list = byId.getOrPut(e.captureId) { order.add(e.captureId); mutableListOf() }
            list.add(e)
        }
        return order.map { id ->
            val blocks = byId.getValue(id).sortedBy { it.startTime }
            val first = blocks.first()
            Capture(
                captureId = id,
                source = first.source,
                transcript = blocks.firstOrNull { !it.transcript.isNullOrBlank() }?.transcript,
                createdAt = first.createdAt,
                blocks = blocks,
            )
        }
    }
}
