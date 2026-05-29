package app.cronwatch.ui.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import app.cronwatch.service.CaptureQueue
import app.cronwatch.service.ToastBus
import app.cronwatch.service.ToastEvent
import app.cronwatch.service.ToastKind
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import javax.inject.Inject

@HiltViewModel
class ToastHostViewModel @Inject constructor(
    val bus: ToastBus,
    val captureQueue: CaptureQueue,
) : ViewModel()

@Composable
fun ToastHost() {
    val vm: ToastHostViewModel = hiltViewModel()
    val current: MutableState<ToastEvent?> = remember { mutableStateOf(null) }

    LaunchedEffect(Unit) {
        vm.bus.events.collect { ev ->
            current.value = ev
            if (ev.durationMs > 0) {
                delay(ev.durationMs)
                if (current.value?.id == ev.id) current.value = null
            }
        }
    }

    val event = current.value
    Box(
        Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
    ) {
        AnimatedVisibility(
            visible = event != null,
            enter = slideInVertically { -it } + fadeIn(),
            exit = slideOutVertically { -it } + fadeOut(),
        ) {
            val ev = event ?: return@AnimatedVisibility
            val bg = when (ev.kind) {
                ToastKind.INFO -> Palette.ink
                ToastKind.SUCCESS -> Palette.amber
                ToastKind.ERROR -> Palette.danger
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(Radius.md))
                    .background(bg)
                    .padding(horizontal = Spacing.md, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Text(
                    text = ev.message,
                    style = CwType.body.copy(color = Palette.white, fontWeight = FontWeight.SemiBold),
                    modifier = Modifier.weight(1f),
                )
                if (ev.actionLabel != null) {
                    Text(
                        text = ev.actionLabel,
                        style = CwType.body.copy(
                            color = Palette.white,
                            fontWeight = FontWeight.SemiBold,
                            textDecoration = TextDecoration.Underline,
                        ),
                        modifier = Modifier.clickable {
                            ev.actionId?.let { vm.captureQueue.retry(it) }
                            current.value = null
                        },
                    )
                }
            }
        }
    }
}
