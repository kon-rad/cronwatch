package app.cronwatch.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.cronwatch.model.Entry
import app.cronwatch.theme.Categories
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import app.cronwatch.util.TimeUtils
import kotlinx.coroutines.delay
import java.util.Calendar
import java.util.Date

private const val PX_PER_MIN = 1.4f
private val TIME_COL_WIDTH = 56.dp

@Composable
fun TodayGrid(entries: List<Entry>, onOpenEntry: (String) -> Unit) {
    val scroll = rememberScrollState()
    val dayHeight = (24 * 60 * PX_PER_MIN).dp

    var nowMin by remember { mutableIntStateOf(currentMinuteOfDay()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            nowMin = currentMinuteOfDay()
        }
    }
    LaunchedEffect(Unit) {
        val target = ((nowMin * PX_PER_MIN) - 200f).coerceAtLeast(0f).toInt()
        scroll.scrollTo(target)
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .verticalScroll(scroll),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(dayHeight)
                .padding(horizontal = Spacing.md),
        ) {
            for (h in 0..23) {
                val top = (h * 60 * PX_PER_MIN).dp
                Text(
                    text = "${h.toString().padStart(2, '0')}:00",
                    style = CwType.caption.copy(color = Palette.muted),
                    modifier = Modifier
                        .offset(y = top)
                        .width(TIME_COL_WIDTH)
                        .padding(top = 2.dp),
                )
            }
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(start = TIME_COL_WIDTH),
            ) {
                DottedDividers()
                for (e in entries) {
                    EntryBlock(e, onClick = { onOpenEntry(e.id) })
                }
                NowLine(nowMin)
            }
        }
        Box(Modifier.height(160.dp).offset(y = dayHeight))
    }
}

@Composable
private fun EntryBlock(entry: Entry, onClick: () -> Unit) {
    val startMin = TimeUtils.minutesSinceMidnight(entry.startTime)
    val durMin = TimeUtils.entryDurationMin(entry)
    val top = (startMin * PX_PER_MIN).dp
    val height = (durMin * PX_PER_MIN - 2f).coerceAtLeast(28f).dp
    val color = Categories.colorFor(entry.category)
    val bg = Categories.pillBackgroundFor(entry.category)

    Column(
        Modifier
            .offset(y = top)
            .padding(start = Spacing.sm, end = Spacing.xs)
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(Radius.md))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(horizontal = Spacing.sm, vertical = 6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Box(Modifier.size(6.dp).clip(CircleShape).background(color))
            Text(
                text = Categories.labelFor(entry.category),
                style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
                maxLines = 1,
            )
            if (entry.note.isNotBlank()) {
                Text(
                    text = "  ·  ${entry.note}",
                    style = CwType.body.copy(color = Palette.muted),
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
            } else {
                Box(Modifier.weight(1f))
            }
            Text(
                text = TimeUtils.formatDuration(durMin),
                style = CwType.caption.copy(color = Palette.muted),
            )
        }
        if (height > 56.dp) {
            Text(
                text = TimeUtils.formatTimeFromIso(entry.startTime),
                style = CwType.caption.copy(color = Palette.muted),
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun NowLine(nowMin: Int) {
    val top = (nowMin * PX_PER_MIN).dp
    Row(
        Modifier
            .fillMaxWidth()
            .offset(y = top)
            .padding(start = (-10).dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(Palette.amber))
        Box(
            Modifier
                .weight(1f)
                .height(1.dp)
                .background(Palette.amber),
        )
    }
}

@Composable
private fun DottedDividers() {
    Box(
        Modifier
            .fillMaxSize()
            .drawBehind {
                val ticks = 24 * 4
                val px15 = (15 * PX_PER_MIN).dp.toPx()
                for (q in 0..ticks) {
                    val y = q * px15
                    val color = if (q % 4 == 0) Palette.border else Palette.borderSoft
                    drawLine(
                        color = color,
                        start = Offset(0f, y),
                        end = Offset(this.size.width, y),
                        strokeWidth = 1f,
                    )
                }
            },
    )
}

private fun currentMinuteOfDay(): Int {
    val cal = Calendar.getInstance().apply { time = Date() }
    return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
}
