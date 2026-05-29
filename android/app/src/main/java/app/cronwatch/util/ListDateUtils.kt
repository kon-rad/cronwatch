package app.cronwatch.util

import java.text.SimpleDateFormat
import java.util.Locale

data class RowDateTime(val dateLine: String, val timeLine: String)

object ListDateUtils {
    fun formatRowDateTime(iso: String): RowDateTime {
        return try {
            val d = TimeUtils.parseIso(iso)
            val dateFmt = SimpleDateFormat("MMM d", Locale.getDefault())
            val timeFmt = SimpleDateFormat("h:mm a", Locale.getDefault())
            RowDateTime(dateFmt.format(d), timeFmt.format(d))
        } catch (_: Exception) {
            RowDateTime("", "")
        }
    }
}
