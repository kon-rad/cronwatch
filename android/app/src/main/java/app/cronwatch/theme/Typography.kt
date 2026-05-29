package app.cronwatch.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

object CwType {
    val title = TextStyle(
        fontFamily = FontFamily.Default,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        fontWeight = FontWeight.SemiBold,
    )
    val body = TextStyle(
        fontFamily = FontFamily.Default,
        fontSize = 15.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.Medium,
    )
    val caption = TextStyle(
        fontFamily = FontFamily.Default,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        fontWeight = FontWeight.Medium,
    )
}

internal val cwTypography = Typography(
    titleLarge = CwType.title,
    bodyLarge = CwType.body,
    labelSmall = CwType.caption,
)
