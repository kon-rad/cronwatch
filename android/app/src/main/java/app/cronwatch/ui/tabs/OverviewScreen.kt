package app.cronwatch.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import app.cronwatch.ui.common.CategoryDot
import app.cronwatch.ui.common.Donut
import app.cronwatch.ui.common.DonutSlice
import app.cronwatch.util.TimeUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import java.util.Calendar
import java.util.Date
import javax.inject.Inject
import kotlin.math.max

private const val STREAK_DAYS = 21

@HiltViewModel
class OverviewViewModel @Inject constructor(
    auth: AuthService,
    entries: EntriesService,
) : ViewModel() {
    val today: StateFlow<List<Entry>> = auth.user
        .flatMapLatest { entries.subscribeToday(it?.uid ?: "stub-user") }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val streakWindow: StateFlow<List<Entry>> = auth.user
        .flatMapLatest {
            val to = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 23); set(Calendar.MINUTE, 59)
                set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999)
            }.time
            val from = Calendar.getInstance().apply {
                time = to
                add(Calendar.DAY_OF_YEAR, -(STREAK_DAYS - 1))
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.time
            entries.subscribeRange(it?.uid ?: "stub-user", from, to)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

@Composable
fun OverviewScreen() {
    val vm: OverviewViewModel = hiltViewModel()
    val today by vm.today.collectAsState()
    val streakEntries by vm.streakWindow.collectAsState()

    val slices = buildSlices(today)
    val tracked = slices.sumOf { it.minutes }
    val distinct = today.map { it.category }.toSet().size
    val top = slices.maxByOrNull { it.minutes }
    val (dayFlags, streak) = computeStreak(streakEntries, STREAK_DAYS)

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
    ) {
        Text("Overview", style = CwType.title.copy(color = Palette.ink))
        Text(
            text = "How you've been spending your time",
            style = CwType.caption.copy(color = Palette.muted),
            modifier = Modifier.padding(top = 2.dp),
        )

        Row(
            Modifier
                .fillMaxWidth()
                .padding(top = Spacing.md)
                .clip(RoundedCornerShape(Radius.md))
                .background(Palette.white)
                .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
                .padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Box(
                Modifier.size(120.dp),
                contentAlignment = Alignment.Center,
            ) {
                Donut(slices = slices, size = 120.dp, thickness = 16.dp)
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = distinct.toString(),
                        style = CwType.title.copy(color = Palette.ink),
                    )
                    Text(
                        text = "CATEGORIES",
                        style = CwType.caption.copy(color = Palette.muted),
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text("TODAY", style = CwType.caption.copy(color = Palette.muted))
                Text(
                    text = TimeUtils.formatDuration(tracked),
                    style = CwType.title.copy(
                        color = Palette.ink,
                        fontSize = 28.sp,
                        lineHeight = 34.sp,
                    ),
                )
                Text(
                    text = "tracked of 24h",
                    style = CwType.caption.copy(color = Palette.muted),
                    modifier = Modifier.padding(top = 2.dp),
                )
                if (top != null) {
                    Row(
                        Modifier
                            .padding(top = Spacing.sm)
                            .clip(RoundedCornerShape(Radius.pill))
                            .background(Palette.borderSoft)
                            .padding(horizontal = Spacing.sm, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                    ) {
                        CategoryDot(top.category)
                        Text(
                            text = "Most: ${Categories.labelFor(top.category)}",
                            style = CwType.caption.copy(color = Palette.ink),
                        )
                    }
                }
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .padding(top = Spacing.lg, bottom = Spacing.sm),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("THIS WEEK · DAILY AVERAGE", style = CwType.caption.copy(color = Palette.muted))
            Text("0h/day", style = CwType.caption.copy(color = Palette.muted))
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for (c in Categories.all) {
                BarRow(category = c.key, hours = 0f, maxHours = 1f)
            }
        }

        Text(
            "TRACKING STREAK",
            style = CwType.caption.copy(color = Palette.muted),
            modifier = Modifier.padding(top = Spacing.lg),
        )
        Column(
            Modifier
                .fillMaxWidth()
                .padding(top = Spacing.sm)
                .clip(RoundedCornerShape(Radius.md))
                .background(Palette.white)
                .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
                .padding(Spacing.md),
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    "$streak ${if (streak == 1) "day" else "days"}",
                    style = CwType.title.copy(color = Palette.ink, fontSize = 24.sp, lineHeight = 30.sp),
                )
                Text(
                    "last $STREAK_DAYS days",
                    style = CwType.caption.copy(color = Palette.muted),
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            Row(
                Modifier.padding(top = Spacing.sm),
                horizontalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                for (on in dayFlags) {
                    Box(
                        Modifier
                            .weight(1f)
                            .height(28.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(if (on) Palette.amber else Palette.border),
                    )
                }
            }
        }
        Box(Modifier.height(160.dp))
    }
}

@Composable
private fun BarRow(category: String, hours: Float, maxHours: Float) {
    val widthFraction = if (hours <= 0f) 0f else max(0.02f, hours / maxHours)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        CategoryDot(category)
        Text(
            text = Categories.labelFor(category),
            style = CwType.body.copy(color = Palette.ink),
            modifier = Modifier.width(80.dp),
        )
        Box(
            Modifier
                .weight(1f)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(Palette.borderSoft),
        ) {
            if (widthFraction > 0f) {
                Box(
                    Modifier
                        .fillMaxWidth(widthFraction)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(Categories.colorFor(category)),
                )
            }
        }
        Text(
            text = "%.1fh".format(hours),
            style = CwType.caption.copy(color = Palette.muted, textAlign = TextAlign.End),
            modifier = Modifier.width(36.dp),
        )
    }
}

private fun buildSlices(entries: List<Entry>): List<DonutSlice> {
    val map = linkedMapOf<String, Int>()
    for (e in entries) {
        map[e.category] = (map[e.category] ?: 0) + TimeUtils.entryDurationMin(e)
    }
    return map.map { (k, v) -> DonutSlice(k, v) }
}

private fun computeStreak(entries: List<Entry>, days: Int): Pair<List<Boolean>, Int> {
    val today = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
    val flags = mutableListOf<Boolean>()
    for (i in (days - 1) downTo 0) {
        val dayStart = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -i) }
        val dayEnd = (dayStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
        val covered = coveredMs(entries, dayStart.timeInMillis, dayEnd.timeInMillis)
        flags.add(covered >= dayEnd.timeInMillis - dayStart.timeInMillis)
    }
    var streak = 0
    for (i in flags.indices.reversed()) {
        if (!flags[i]) break
        streak++
    }
    return flags to streak
}

private fun coveredMs(entries: List<Entry>, dayStart: Long, dayEnd: Long): Long {
    val intervals = entries.mapNotNull { e ->
        val s = max(TimeUtils.parseIso(e.startTime).time, dayStart)
        val en = minOf(TimeUtils.parseIso(e.endTime).time, dayEnd)
        if (en > s) s to en else null
    }.sortedBy { it.first }
    var total = 0L
    var curStart = -1L
    var curEnd = -1L
    for ((s, e) in intervals) {
        if (s > curEnd) {
            if (curEnd > curStart) total += curEnd - curStart
            curStart = s; curEnd = e
        } else if (e > curEnd) curEnd = e
    }
    if (curEnd > curStart) total += curEnd - curStart
    return total
}
