package app.cronwatch.service

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import javax.inject.Inject
import javax.inject.Singleton

enum class ToastKind { INFO, SUCCESS, ERROR }

data class ToastEvent(
    val id: String,
    val message: String,
    val kind: ToastKind,
    val durationMs: Long,
    val actionLabel: String? = null,
    val actionId: String? = null,
)

@Singleton
class ToastBus @Inject constructor() {
    private val _events = MutableSharedFlow<ToastEvent>(
        replay = 0,
        extraBufferCapacity = 16,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events: SharedFlow<ToastEvent> = _events.asSharedFlow()

    fun show(
        message: String,
        kind: ToastKind = ToastKind.INFO,
        durationMs: Long = 3_000,
        actionLabel: String? = null,
        actionId: String? = null,
    ) {
        val id = "t_${System.currentTimeMillis()}_${(0..0xffff).random().toString(16)}"
        _events.tryEmit(
            ToastEvent(
                id = id,
                message = message,
                kind = kind,
                durationMs = durationMs,
                actionLabel = actionLabel,
                actionId = actionId,
            ),
        )
    }
}
