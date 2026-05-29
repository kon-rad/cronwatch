package app.cronwatch.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.cronwatch.theme.Categories

@Composable
fun CategoryDot(category: String, size: Dp = 6.dp) {
    Box(
        Modifier
            .size(size)
            .clip(CircleShape)
            .background(Categories.colorFor(category)),
    )
}
