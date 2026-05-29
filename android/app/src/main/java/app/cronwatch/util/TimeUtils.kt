package app.cronwatch.util

import app.cronwatch.model.Entry
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.max
import kotlin.math.round

object TimeUtils {
    const val MIN_PER_DAY = 24 * 60

    private val iso: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    fun parseIso(value: String): Date {
        return try {
            iso.parse(value) ?: Date(0)
        } catch (_: Exception) {
            // Fallback for variants like "...Z" without millis.
            val alt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            alt.parse(value) ?: Date(0)
        }
    }

    fun toIso(date: Date): String = iso.format(date)

    fun minutesSinceMidnight(iso: String): Int {
        val d = parseIso(iso)
        val cal = Calendar.getInstance().apply { time = d }
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }

    fun entryDurationMin(e: Entry): Int {
        val ms = parseIso(e.endTime).time - parseIso(e.startTime).time
        return max(15, round(ms / 60_000.0).toInt())
    }

    fun formatHHMM(date: Date): String {
        val cal = Calendar.getInstance().apply { time = date }
        val hh = cal.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
        val mm = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
        return "$hh:$mm"
    }

    fun formatTimeFromIso(value: String): String = formatHHMM(parseIso(value))

    fun formatDuration(min: Int): String {
        if (min < 60) return "${min}m"
        val h = min / 60
        val m = min % 60
        return if (m == 0) "${h}h" else "${h}h ${m}m"
    }

    fun formatLongDate(date: Date = Date()): String {
        val fmt = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault())
        return fmt.format(date)
    }

    fun totalTrackedMin(entries: List<Entry>): Int =
        entries.sumOf { entryDurationMin(it) }

    fun snapTo15(min: Int): Int = (min / 15.0).let { kotlin.math.round(it).toInt() } * 15

    fun startOfToday(now: Date = Date()): Date {
        val cal = Calendar.getInstance().apply {
            time = now
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        return cal.time
    }

    fun endOfToday(now: Date = Date()): Date {
        val cal = Calendar.getInstance().apply {
            time = now
            set(Calendar.HOUR_OF_DAY, 23); set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999)
        }
        return cal.time
    }

    /** Returns a copy of [base] with hours/minutes from [totalMinutes] and seconds=0. */
    fun withMinutesOfDay(base: Date, totalMinutes: Int): Date {
        val cal = Calendar.getInstance().apply {
            time = base
            set(Calendar.HOUR_OF_DAY, totalMinutes / 60)
            set(Calendar.MINUTE, totalMinutes % 60)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        return cal.time
    }

    /** "9:30 am" style display string. */
    fun formatTimeOfDay(totalMinutes: Int): String {
        val base = withMinutesOfDay(Date(), totalMinutes)
        val fmt = SimpleDateFormat("h:mm a", Locale.getDefault())
        return fmt.format(base).lowercase(Locale.getDefault())
    }
}
