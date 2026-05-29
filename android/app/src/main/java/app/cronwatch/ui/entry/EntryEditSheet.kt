package app.cronwatch.ui.entry

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.cronwatch.model.Entry
import app.cronwatch.service.AuthService
import app.cronwatch.service.EntriesService
import app.cronwatch.theme.Categories
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import app.cronwatch.util.TimeUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar
import javax.inject.Inject

@HiltViewModel
class EntryEditViewModel @Inject constructor(
    val auth: AuthService,
    val entries: EntriesService,
) : ViewModel() {
    val today: StateFlow<List<Entry>> = auth.user
        .flatMapLatest { entries.subscribeToday(it?.uid ?: "stub-user") }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    suspend fun save(
        id: String,
        baseIso: String,
        category: String,
        note: String,
        startMin: Int,
        endMin: Int,
    ) {
        val base = TimeUtils.parseIso(baseIso)
        val startDate = TimeUtils.withMinutesOfDay(base, startMin)
        val endDate = TimeUtils.withMinutesOfDay(base, kotlin.math.max(endMin, startMin + 15))
        entries.updateEntry(
            uid = auth.currentUid(),
            id = id,
            category = category,
            note = note,
            startTime = TimeUtils.toIso(startDate),
            endTime = TimeUtils.toIso(endDate),
        )
    }

    suspend fun delete(id: String) {
        entries.deleteEntry(auth.currentUid(), id)
    }
}

@Composable
fun EntryEditSheet(entryId: String, onDismiss: () -> Unit) {
    val vm: EntryEditViewModel = hiltViewModel()
    val today by vm.today.collectAsState()
    val entry = today.firstOrNull { it.id == entryId }
    val scope = rememberCoroutineScope()
    var confirmDelete by remember { mutableStateOf(false) }

    if (entry == null) {
        Column(
            Modifier.fillMaxSize().background(Palette.bg).statusBarsPadding(),
        ) {
            Header(title = "Edit entry", saveEnabled = false, onCancel = onDismiss, onSave = {})
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Entry not found.", style = CwType.caption.copy(color = Palette.muted))
            }
        }
        return
    }

    var category by remember(entry.id) { mutableStateOf(entry.category) }
    var note by remember(entry.id) { mutableStateOf(entry.note) }
    var startMin by remember(entry.id) { mutableIntStateOf(minutesOf(entry.startTime)) }
    var endMin by remember(entry.id) { mutableIntStateOf(minutesOf(entry.endTime)) }

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding(),
    ) {
        Header(
            title = "Edit entry",
            saveEnabled = true,
            onCancel = onDismiss,
            onSave = {
                scope.launch {
                    vm.save(entry.id, entry.startTime, category.ifBlank { entry.category }, note.trim(), startMin, endMin)
                    onDismiss()
                }
            },
        )
        Column(
            Modifier
                .fillMaxSize()
                .padding(Spacing.md)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text("CATEGORY", style = CwType.caption.copy(color = Palette.muted))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                for (c in Categories.all) {
                    val selected = c.key == category
                    Row(
                        Modifier
                            .clip(RoundedCornerShape(Radius.pill))
                            .border(
                                1.dp,
                                if (selected) Palette.amber else Palette.border,
                                RoundedCornerShape(Radius.pill),
                            )
                            .background(if (selected) Palette.amber.copy(alpha = 0.10f) else Palette.white)
                            .clickable { category = c.key }
                            .padding(horizontal = Spacing.md, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                    ) {
                        Box(Modifier.size(6.dp).clip(CircleShape).background(c.color))
                        Text(c.label, style = CwType.body.copy(color = Palette.ink))
                    }
                }
            }

            Text("NOTE", style = CwType.caption.copy(color = Palette.muted))
            BasicTextField(
                value = note,
                onValueChange = { note = it },
                textStyle = CwType.body.copy(color = Palette.ink),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 72.dp)
                    .clip(RoundedCornerShape(Radius.md))
                    .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
                    .background(Palette.white)
                    .padding(horizontal = Spacing.md, vertical = Spacing.sm),
                decorationBox = { inner ->
                    if (note.isEmpty()) {
                        Text("What did you do?", style = CwType.body.copy(color = Palette.muted))
                    }
                    inner()
                },
            )

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                Stepper(
                    label = "START",
                    value = TimeUtils.formatTimeOfDay(startMin),
                    onMinus = { startMin = TimeUtils.snapTo15((startMin - 15).coerceAtLeast(0)) },
                    onPlus = {
                        startMin = TimeUtils.snapTo15((startMin + 15).coerceAtMost(TimeUtils.MIN_PER_DAY - 15))
                        if (startMin >= endMin) endMin = startMin + 15
                    },
                    modifier = Modifier.weight(1f),
                )
                Stepper(
                    label = "END",
                    value = TimeUtils.formatTimeOfDay(endMin),
                    onMinus = { endMin = TimeUtils.snapTo15((endMin - 15).coerceAtLeast(startMin + 15)) },
                    onPlus = { endMin = TimeUtils.snapTo15((endMin + 15).coerceAtMost(TimeUtils.MIN_PER_DAY)) },
                    modifier = Modifier.weight(1f),
                )
            }

            Row(
                Modifier.clickable { confirmDelete = true }.padding(top = Spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            ) {
                Icon(Icons.Outlined.Delete, contentDescription = null, tint = Palette.danger)
                Text("Delete entry", style = CwType.body.copy(color = Palette.danger))
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete entry?") },
            text = { Text("This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    scope.launch { vm.delete(entry.id); onDismiss() }
                }) { Text("Delete") }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun Header(title: String, saveEnabled: Boolean, onCancel: () -> Unit, onSave: () -> Unit) {
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
    Row(
        Modifier.fillMaxWidth().padding(Spacing.md),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Cancel", style = CwType.body.copy(color = Palette.muted), modifier = Modifier.clickable(onClick = onCancel))
        Text(title, style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold))
        Text(
            "Save",
            style = CwType.body.copy(
                color = if (saveEnabled) Palette.amber else Palette.muted,
                fontWeight = FontWeight.SemiBold,
            ),
            modifier = Modifier.clickable(enabled = saveEnabled, onClick = onSave),
        )
    }
}

@Composable
private fun Stepper(label: String, value: String, onMinus: () -> Unit, onPlus: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        Text(label, style = CwType.caption.copy(color = Palette.muted), modifier = Modifier.padding(bottom = 4.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(Radius.md))
                .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
                .background(Palette.white)
                .padding(horizontal = Spacing.md, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Text(value, style = CwType.body.copy(color = Palette.ink), modifier = Modifier.weight(1f))
            StepButton(icon = Icons.Outlined.Remove, onClick = onMinus)
            StepButton(icon = Icons.Outlined.Add, onClick = onPlus)
        }
    }
}

@Composable
private fun StepButton(icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Box(
        Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(Palette.borderSoft)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Palette.ink, modifier = Modifier.size(16.dp))
    }
}

private fun minutesOf(iso: String): Int {
    val cal = Calendar.getInstance().apply { time = TimeUtils.parseIso(iso) }
    return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
}
