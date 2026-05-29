package app.cronwatch.ui.capture

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.cronwatch.model.EntrySource
import app.cronwatch.service.AudioRecorder
import app.cronwatch.service.AuthService
import app.cronwatch.service.CaptureQueue
import app.cronwatch.service.CaptureService
import app.cronwatch.service.EntriesService
import app.cronwatch.service.ToastBus
import app.cronwatch.service.ToastKind
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import app.cronwatch.ui.common.Waveform
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

private enum class Phase { Idle, Recording, Structuring, Saved }

@HiltViewModel
class CaptureViewModel @Inject constructor(
    val auth: AuthService,
    val recorder: AudioRecorder,
    val captureService: CaptureService,
    val entries: EntriesService,
    val queue: CaptureQueue,
    val toastBus: ToastBus,
) : ViewModel() {
    val phase = MutableStateFlow(Phase.Idle)
    val isRecording: Boolean get() = recorder.isRecording

    fun beginRecording() {
        if (phase.value != Phase.Idle) return
        runCatching { recorder.start() }
            .onSuccess { phase.value = Phase.Recording }
            .onFailure {
                toastBus.show(it.message ?: "Could not start recording", ToastKind.ERROR)
            }
    }

    fun finishRecording(onAfter: () -> Unit) {
        if (phase.value != Phase.Recording) return
        val file = recorder.stop()
        val uid = auth.currentUid()
        if (file != null && file.exists() && file.length() > 0) {
            queue.enqueue(uid, file.absolutePath)
            toastBus.show("Processing entry…", ToastKind.INFO, durationMs = 1500)
        }
        phase.value = Phase.Idle
        onAfter()
    }

    fun saveText(text: String, onDone: () -> Unit) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        phase.value = Phase.Structuring
        viewModelScope.launch {
            try {
                val drafts = captureService.captureFromText(trimmed)
                entries.createCaptureEntries(
                    uid = auth.currentUid(),
                    drafts = drafts,
                    source = EntrySource.text,
                    transcript = trimmed,
                )
                phase.value = Phase.Saved
                delay(600)
                onDone()
            } catch (t: Throwable) {
                toastBus.show(t.message ?: "Save failed", ToastKind.ERROR)
                phase.value = Phase.Idle
            }
        }
    }
}

@Composable
fun CaptureSheet(onDismiss: () -> Unit) {
    val vm: CaptureViewModel = hiltViewModel()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val phase by vm.phase.collectAsState()
    var typed by remember { mutableStateOf("") }
    var permGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED,
        )
    }
    val askMic = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        permGranted = it
    }
    LaunchedEffect(Unit) {
        if (!permGranted) askMic.launch(Manifest.permission.RECORD_AUDIO)
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding()
            .imePadding(),
    ) {
        Box(
            Modifier
                .padding(top = Spacing.sm)
                .fillMaxWidth(),
            contentAlignment = Alignment.TopCenter,
        ) {
            Box(
                Modifier
                    .size(width = 36.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Palette.border),
            )
        }
        Row(
            Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Cancel", style = CwType.body.copy(color = Palette.muted), modifier = Modifier.clickable(onClick = onDismiss))
            Text(
                if (phase == Phase.Saved) "Logged." else "New entry",
                style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
            )
            val saveEnabled = typed.trim().isNotEmpty() && phase == Phase.Idle
            Text(
                "Save",
                style = CwType.body.copy(
                    color = if (saveEnabled) Palette.amber else Palette.muted,
                    fontWeight = FontWeight.SemiBold,
                ),
                modifier = Modifier.clickable(enabled = saveEnabled) {
                    vm.saveText(typed, onDismiss)
                },
            )
        }

        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = Spacing.md),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (phase == Phase.Idle) {
                Text(
                    "Hold to record, or type below.",
                    style = CwType.body.copy(color = Palette.muted, textAlign = TextAlign.Center),
                )
                Column(
                    Modifier.padding(top = Spacing.md),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text("TRY SAYING", style = CwType.caption.copy(color = Palette.muted))
                    Text(
                        "“Just worked on the report for 30 minutes”",
                        style = CwType.caption.copy(color = Palette.ink, textAlign = TextAlign.Center),
                    )
                    Text(
                        "“9 to 10 was a meeting, gym from 1 to 2”",
                        style = CwType.caption.copy(color = Palette.ink, textAlign = TextAlign.Center),
                    )
                    Text(
                        "“Last hour: 30 min email, 30 min deep work”",
                        style = CwType.caption.copy(color = Palette.ink, textAlign = TextAlign.Center),
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "One recording can capture multiple time slots.",
                        style = CwType.caption.copy(color = Palette.muted, textAlign = TextAlign.Center),
                    )
                }
            } else {
                Text(
                    when (phase) {
                        Phase.Recording -> "Listening…"
                        Phase.Structuring -> "Saving…"
                        Phase.Saved -> "Logged."
                        else -> ""
                    },
                    style = CwType.body.copy(color = Palette.muted),
                )
            }

            Box(Modifier.height(36.dp).fillMaxWidth().padding(top = Spacing.lg), contentAlignment = Alignment.Center) {
                AnimatedVisibility(visible = phase == Phase.Recording) {
                    Waveform()
                }
                if (phase != Phase.Recording) {
                    Text(
                        "............",
                        style = CwType.caption.copy(color = Palette.muted),
                    )
                }
            }

            Box(
                Modifier
                    .padding(top = Spacing.md)
                    .size(88.dp)
                    .clip(CircleShape)
                    .background(Palette.amber)
                    .pointerInput(permGranted, phase) {
                        if (!permGranted || phase == Phase.Structuring || phase == Phase.Saved) return@pointerInput
                        awaitPointerEventScope {
                            val first = awaitFirstDown(requireUnconsumed = false)
                            vm.beginRecording()
                            try {
                                while (true) {
                                    val ev = awaitPointerEvent()
                                    if (ev.changes.all { !it.pressed }) break
                                }
                            } finally {
                                vm.finishRecording { onDismiss() }
                            }
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                if (phase == Phase.Structuring) {
                    CircularProgressIndicator(color = Palette.white, strokeWidth = 2.dp)
                } else {
                    Icon(Icons.Filled.Mic, contentDescription = "Hold to record", tint = Palette.white)
                }
            }
            Text(
                "HOLD TO RECORD",
                style = CwType.caption.copy(color = Palette.muted),
                modifier = Modifier.padding(top = Spacing.sm),
            )
        }

        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.md, vertical = Spacing.sm)
                .clip(RoundedCornerShape(Radius.md))
                .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
                .background(Palette.white)
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            BasicTextField(
                value = typed,
                onValueChange = { typed = it },
                singleLine = true,
                enabled = phase == Phase.Idle,
                textStyle = CwType.body.copy(color = Palette.ink),
                modifier = Modifier.weight(1f),
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = androidx.compose.foundation.text.KeyboardActions(onSend = {
                    if (typed.trim().isNotEmpty()) vm.saveText(typed, onDismiss)
                }),
                decorationBox = { inner ->
                    if (typed.isEmpty()) {
                        Text("Or type an entry…", style = CwType.body.copy(color = Palette.muted))
                    }
                    inner()
                },
            )
            if (typed.trim().isNotEmpty()) {
                Icon(
                    Icons.Filled.Send,
                    contentDescription = "Send",
                    tint = Palette.amber,
                    modifier = Modifier.clickable { vm.saveText(typed, onDismiss) },
                )
            }
        }
    }
}
