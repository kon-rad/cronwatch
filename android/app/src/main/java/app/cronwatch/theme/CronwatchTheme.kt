package app.cronwatch.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val CwColorScheme = lightColorScheme(
    primary = Palette.amber,
    onPrimary = Palette.white,
    secondary = Palette.amber,
    onSecondary = Palette.white,
    background = Palette.bg,
    onBackground = Palette.ink,
    surface = Palette.white,
    onSurface = Palette.ink,
    surfaceVariant = Palette.borderSoft,
    onSurfaceVariant = Palette.muted,
    outline = Palette.border,
    error = Palette.danger,
)

@Composable
fun CronwatchTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = CwColorScheme,
        typography = cwTypography,
        content = content,
    )
}
