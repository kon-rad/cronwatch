package app.cronwatch.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import app.cronwatch.theme.Palette

@Composable
fun FloatingMicButton(onClick: () -> Unit) {
    Box(
        Modifier
            .size(56.dp)
            .shadow(8.dp, CircleShape, ambientColor = Palette.ink, spotColor = Palette.ink)
            .clip(CircleShape)
            .background(Palette.amber)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Outlined.Mic,
            contentDescription = "Capture entry",
            tint = Palette.white,
        )
    }
}
