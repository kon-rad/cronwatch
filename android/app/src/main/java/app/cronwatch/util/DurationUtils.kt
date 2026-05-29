package app.cronwatch.util

import kotlin.math.roundToInt

object DurationUtils {
    fun formatDurationHuman(ms: Long): String {
        if (ms <= 0) return "—"
        val totalMin = (ms / 60_000.0).roundToInt()
        val hours = totalMin / 60
        val mins = totalMin % 60
        if (hours == 0) return "$mins min"
        val hourPart = if (hours == 1) "1 hour" else "$hours hours"
        return if (mins == 0) hourPart else "$hourPart $mins min"
    }
}
