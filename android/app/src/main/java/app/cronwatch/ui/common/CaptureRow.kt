package app.cronwatch.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFeatureSetting
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.cronwatch.model.Capture
import app.cronwatch.model.Entry
import app.cronwatch.theme.Categories
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Spacing
import app.cronwatch.util.ListDateUtils
import app.cronwatch.util.TimeUtils

private val tabular = FontFeatureSetting("tnum")

@Composable
fun CaptureRow(capture: Capture, onClick: () -> Unit) {
    val first = capture.blocks.firstOrNull()
    val row = first?.let { ListDateUtils.formatRowDateTime(it.startTime) }

    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(Palette.bg)
            .padding(horizontal = Spacing.md, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                text = snippet(capture).ifBlank { "—" },
                style = CwType.caption.copy(color = Palette.ink),
                maxLines = 2,
                modifier = Modifier.weight(1f),
            )
            if (row != null) {
                Column(horizontalAlignment = Alignment.End) {
                    Text(row.dateLine, style = CwType.caption.copy(color = Palette.muted))
                    Text(
                        row.timeLine,
                        style = CwType.caption.copy(color = Palette.muted),
                    )
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(start = Spacing.xs)) {
            for (block in capture.blocks) {
                BlockLine(block)
            }
        }
    }
    HorizontalDivider(color = Palette.border, thickness = 0.5.dp)
}

@Composable
private fun BlockLine(block: Entry) {
    val dur = TimeUtils.entryDurationMin(block)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Box(
            Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(Categories.colorFor(block.category)),
        )
        Text(
            text = Categories.labelFor(block.category),
            style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
        )
        if (block.note.isNotBlank()) {
            Text(
                text = "  ·  ${block.note}",
                style = CwType.body.copy(color = Palette.muted),
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )
        } else {
            Box(Modifier.weight(1f))
        }
        Text(
            text = "${TimeUtils.formatTimeFromIso(block.startTime)} · ${TimeUtils.formatDuration(dur)}",
            style = CwType.caption.copy(color = Palette.muted),
        )
    }
}

private fun snippet(capture: Capture): String {
    val text = (capture.transcript ?: capture.blocks.firstOrNull()?.note ?: "").trim()
    return if (text.length <= 150) text else text.take(150).trimEnd() + "…"
}
