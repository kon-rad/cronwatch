package app.cronwatch.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Schedule
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import app.cronwatch.service.AuthService
import app.cronwatch.service.ToastBus
import app.cronwatch.service.ToastKind
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SignInViewModel @Inject constructor(
    val auth: AuthService,
    val toastBus: ToastBus,
) : ViewModel()

@Composable
fun SignInScreen(onSignedIn: () -> Unit) {
    val vm: SignInViewModel = hiltViewModel()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val user by vm.auth.user.collectAsState()
    var loading by remember { mutableStateOf(false) }

    LaunchedEffect(user) {
        if (user != null) onSignedIn()
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .windowInsetsPadding(WindowInsets.statusBars)
            .windowInsetsPadding(WindowInsets.navigationBars),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .weight(1f),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Palette.amber),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Schedule,
                        contentDescription = null,
                        tint = Palette.white,
                    )
                }
                Text(
                    text = "Cronwatch",
                    style = CwType.title.copy(
                        color = Palette.ink,
                        fontSize = 32.sp,
                        lineHeight = 38.sp,
                    ),
                    modifier = Modifier.padding(top = Spacing.md),
                )
                Text(
                    text = "Speak your time. See your day.",
                    style = CwType.body.copy(color = Palette.muted),
                    modifier = Modifier.padding(top = Spacing.xs),
                )
            }
        }
        Column(
            Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            GoogleButton(loading = loading) {
                if (loading) return@GoogleButton
                loading = true
                scope.launch {
                    runCatching { vm.auth.signInWithGoogle(context) }
                        .onFailure {
                            vm.toastBus.show(
                                message = it.message ?: "Sign-in failed",
                                kind = ToastKind.ERROR,
                            )
                        }
                    loading = false
                }
            }
            Text(
                text = buildLegal(),
                style = CwType.caption.copy(color = Palette.muted, textAlign = TextAlign.Center),
                modifier = Modifier.fillMaxWidth().padding(top = Spacing.sm),
            )
        }
    }
}

@Composable
private fun GoogleButton(loading: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Radius.md))
            .background(Palette.white)
            .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
            .clickable(enabled = !loading, onClick = onClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(color = Palette.ink, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
        } else {
            Text(
                text = "G",
                style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold),
            )
            Text(
                text = "  Continue with Google",
                style = CwType.body.copy(color = Palette.ink),
            )
        }
    }
}

private fun buildLegal(): String =
    "By continuing you agree to our Terms and Privacy."
