package app.cronwatch.ui.entry

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.cronwatch.model.Capture
import app.cronwatch.model.Entry
import app.cronwatch.service.AuthService
import app.cronwatch.service.EntriesService
import app.cronwatch.service.ToastBus
import app.cronwatch.service.ToastKind
import app.cronwatch.theme.Categories
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Spacing
import app.cronwatch.util.DurationUtils
import app.cronwatch.util.TimeUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class EntryViewViewModel @Inject constructor(
    val auth: AuthService,
    val entries: EntriesService,
    val toastBus: ToastBus,
) : ViewModel() {
    private val _capture = MutableStateFlow<Capture?>(null)
    val capture: StateFlow<Capture?> = _capture.asStateFlow()
    private val _notFound = MutableStateFlow(false)
    val notFound: StateFlow<Boolean> = _notFound.asStateFlow()

    fun load(captureId: String) {
        viewModelScope.launch {
            try {
                val c = entries.getCapture(auth.currentUid(), captureId)
                if (c == null) _notFound.value = true else _capture.value = c
            } catch (t: Throwable) {
                _notFound.value = true
                toastBus.show(t.message ?: "Failed to load entry", ToastKind.ERROR)
            }
        }
    }
}

@Composable
fun EntryViewSheet(captureId: String, onDismiss: () -> Unit) {
    val vm: EntryViewViewModel = hiltViewModel()
    val capture by vm.capture.collectAsState()
    val notFound by vm.notFound.collectAsState()

    LaunchedEffect(captureId) { vm.load(captureId) }

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding(),
    ) {
        Box(
            Modifier
                .padding(top = Spacing.sm)
                .fillMaxWidth(),
            contentAlignment = Alignment.TopCenter,
        ) {
            Box(
                Modifier
                    .size(width = 36.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Palette.border),
            )
        }

        if (notFound) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Entry not found.", style = CwType.caption.copy(color = Palette.muted))
            }
            return@Column
        }

        val c = capture
        Row(
            Modifier.fillMaxWidth().padding(Spacing.md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Done", style = CwType.body.copy(color = Palette.muted), modifier = Modifier.clickable(onClick = onDismiss))
            Text(
                if ((c?.blocks?.size ?: 0) > 1) "Capture" else "Entry",
                style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
            )
            Box(Modifier.size(22.dp))
        }

        if (c == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {}
            return@Column
        }

        Column(
            Modifier
                .fillMaxSize()
                .padding(Spacing.md)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            c.blocks.firstOrNull()?.let { first ->
                Text(formatLongDate(first.startTime), style = CwType.caption.copy(color = Palette.muted))
            }
            Column(
                Modifier.padding(top = Spacing.sm),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                for (block in c.blocks) BlockDetail(block)
            }
            val transcript = c.transcript ?: c.blocks.firstOrNull()?.note
            if (!transcript.isNullOrBlank() && (c.transcript != null || c.blocks.size == 1)) {
                Text(
                    transcript,
                    style = CwType.body.copy(color = Palette.ink),
                    modifier = Modifier.padding(top = Spacing.md),
                )
            }
        }
    }
}

@Composable
private fun BlockDetail(block: Entry) {
    val durationMs = TimeUtils.parseIso(block.endTime).time - TimeUtils.parseIso(block.startTime).time
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(
            Modifier
                .padding(top = 6.dp)
                .size(10.dp)
                .clip(CircleShape)
                .background(Categories.colorFor(block.category)),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                Categories.labelFor(block.category),
                style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
            )
            if (block.note.isNotBlank()) {
                Text(block.note, style = CwType.caption.copy(color = Palette.muted), maxLines = 2)
            }
            Text(
                "${TimeUtils.formatTimeFromIso(block.startTime)} — " +
                    "${TimeUtils.formatTimeFromIso(block.endTime)} · " +
                    DurationUtils.formatDurationHuman(durationMs),
                style = CwType.caption.copy(color = Palette.muted),
            )
        }
    }
}

private fun formatLongDate(iso: String): String {
    val d = TimeUtils.parseIso(iso)
    val fmt = SimpleDateFormat("MMMM d, yyyy", Locale.getDefault())
    return fmt.format(d)
}
