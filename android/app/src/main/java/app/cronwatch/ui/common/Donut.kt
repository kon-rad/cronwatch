package app.cronwatch.ui.common

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.cronwatch.theme.Categories

data class DonutSlice(val category: String, val minutes: Int)

@Composable
fun Donut(
    slices: List<DonutSlice>,
    size: Dp = 132.dp,
    thickness: Dp = 18.dp,
) {
    Canvas(Modifier.size(size)) {
        val total = slices.sumOf { it.minutes }.coerceAtLeast(1)
        val strokePx = thickness.toPx()
        val diameter = this.size.minDimension - strokePx
        val topLeft = Offset(strokePx / 2f, strokePx / 2f)
        val arcSize = Size(diameter, diameter)
        var start = -90f
        for (sl in slices) {
            val sweep = 360f * (sl.minutes.toFloat() / total.toFloat())
            drawArc(
                color = Categories.colorFor(sl.category),
                startAngle = start,
                sweepAngle = sweep,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokePx),
            )
            start += sweep
        }
    }
}
