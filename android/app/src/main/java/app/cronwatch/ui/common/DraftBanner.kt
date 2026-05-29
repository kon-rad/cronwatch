package app.cronwatch.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import app.cronwatch.service.CaptureJob
import app.cronwatch.service.CaptureQueue
import app.cronwatch.service.JobStatus
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import dagger.hilt.android.lifecycle.HiltViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class DraftBannerViewModel @Inject constructor(val queue: CaptureQueue) : ViewModel()

@Composable
fun DraftBanner() {
    val vm: DraftBannerViewModel = hiltViewModel()
    val jobs by vm.queue.jobs.collectAsState()
    val drafts = jobs.filter { it.status == JobStatus.error }
    if (drafts.isEmpty()) return

    var expanded by remember { mutableStateOf(false) }
    var discardTarget by remember { mutableStateOf<CaptureJob?>(null) }

    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.md)
            .padding(bottom = Spacing.sm)
            .clip(RoundedCornerShape(Radius.md))
            .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
            .background(Palette.amberSoft),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Icon(Icons.Outlined.WarningAmber, contentDescription = null, tint = Palette.danger)
            Text(
                text = "${drafts.size} draft${if (drafts.size == 1) "" else "s"} waiting",
                style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = "Retry all",
                style = CwType.caption.copy(color = Palette.danger, fontWeight = FontWeight.SemiBold),
                modifier = Modifier
                    .padding(horizontal = Spacing.sm)
                    .clickable { vm.queue.retryAll() },
            )
            Icon(
                if (expanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore,
                contentDescription = null,
                tint = Palette.muted,
            )
        }
        if (expanded) {
            for (draft in drafts) {
                HorizontalDivider(color = Palette.border, thickness = 0.5.dp)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.md, vertical = Spacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            text = formatTime(draft.createdAt),
                            style = CwType.caption.copy(color = Palette.muted),
                        )
                        Text(
                            text = draft.error ?: "Couldn't process entry",
                            style = CwType.caption.copy(color = Palette.ink),
                            maxLines = 2,
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        Text(
                            text = "Retry",
                            style = CwType.caption.copy(
                                color = Palette.danger,
                                fontWeight = FontWeight.SemiBold,
                            ),
                            modifier = Modifier.clickable { vm.queue.retry(draft.id) },
                        )
                        Text(
                            text = "Discard",
                            style = CwType.caption.copy(color = Palette.muted),
                            modifier = Modifier.clickable { discardTarget = draft },
                        )
                    }
                }
            }
        }
    }

    val target = discardTarget
    if (target != null) {
        AlertDialog(
            onDismissRequest = { discardTarget = null },
            title = { Text("Discard draft?") },
            text = { Text("The recording will be deleted and cannot be recovered.") },
            confirmButton = {
                TextButton(onClick = {
                    vm.queue.discard(target.id)
                    discardTarget = null
                }) { Text("Discard") }
            },
            dismissButton = {
                TextButton(onClick = { discardTarget = null }) { Text("Cancel") }
            },
        )
    }
}

private fun formatTime(epochMs: Long): String {
    val fmt = SimpleDateFormat("h:mm a", Locale.getDefault())
    return fmt.format(Date(epochMs))
}
