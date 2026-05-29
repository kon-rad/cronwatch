package app.cronwatch.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import app.cronwatch.model.Entitlement
import app.cronwatch.service.AuthService
import app.cronwatch.service.RevenueCatService
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    val auth: AuthService,
    val revenueCat: RevenueCatService,
) : ViewModel()

@Composable
fun ProfileScreen(onOpenPaywall: () -> Unit, onSignedOut: () -> Unit) {
    val vm: ProfileViewModel = hiltViewModel()
    val user by vm.auth.user.collectAsState()
    val entitlement by vm.revenueCat.entitlement.collectAsState()
    val scope = rememberCoroutineScope()
    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { vm.revenueCat.refreshEntitlement() }

    val initials = (user?.displayName ?: user?.email ?: "C")
        .split(Regex("\\s+"))
        .mapNotNull { it.firstOrNull()?.toString() }
        .joinToString("")
        .take(2)
        .uppercase()

    val planLabel = when (entitlement) {
        Entitlement.weekly -> "Weekly plan"
        Entitlement.yearly -> "Yearly plan"
        Entitlement.free -> "Free plan"
    }
    val planSub = if (entitlement == Entitlement.free) "No active subscription" else "Renews automatically"

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Palette.muted),
                contentAlignment = Alignment.Center,
            ) {
                Text(initials.ifBlank { "C" }, style = CwType.body.copy(color = Palette.white, fontWeight = FontWeight.SemiBold))
            }
            Column(Modifier.weight(1f)) {
                Text(user?.displayName ?: "Cronwatch user", style = CwType.title.copy(color = Palette.ink))
                if (!user?.email.isNullOrBlank()) {
                    Text(user!!.email!!, style = CwType.caption.copy(color = Palette.muted), modifier = Modifier.padding(top = 2.dp))
                }
            }
        }

        SectionLabel("SUBSCRIPTION")
        Card {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(Spacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Column(Modifier.weight(1f)) {
                    Text(planLabel, style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold))
                    Text(planSub, style = CwType.caption.copy(color = Palette.muted), modifier = Modifier.padding(top = 2.dp))
                }
                Box(
                    Modifier
                        .clip(RoundedCornerShape(Radius.md))
                        .background(Palette.amber)
                        .clickable(onClick = onOpenPaywall)
                        .padding(horizontal = Spacing.md, vertical = 10.dp),
                ) {
                    Text(
                        if (entitlement == Entitlement.free) "Upgrade" else "Manage",
                        style = CwType.body.copy(color = Palette.white, fontWeight = FontWeight.SemiBold),
                    )
                }
            }
        }

        SectionLabel("ACCOUNT")
        Card {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { confirmSignOut = true }
                    .padding(horizontal = Spacing.md, vertical = 14.dp),
            ) {
                Text("Sign out", style = CwType.body.copy(color = Palette.ink), modifier = Modifier.weight(1f))
            }
            HorizontalDivider(color = Palette.border, thickness = 0.5.dp)
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { confirmDelete = true }
                    .padding(horizontal = Spacing.md, vertical = 14.dp),
            ) {
                Text("Delete account", style = CwType.body.copy(color = Palette.ink), modifier = Modifier.weight(1f))
            }
        }

        SectionLabel("ABOUT")
        Card {
            AboutRow("Version", trailing = "1.0.0")
            HorizontalDivider(color = Palette.border, thickness = 0.5.dp)
            AboutRow("Source on GitHub")
            HorizontalDivider(color = Palette.border, thickness = 0.5.dp)
            AboutRow("Privacy")
            HorizontalDivider(color = Palette.border, thickness = 0.5.dp)
            AboutRow("Terms")
        }

        Text(
            "MADE QUIETLY · CRONWATCH",
            style = CwType.caption.copy(color = Palette.muted, textAlign = TextAlign.Center),
            modifier = Modifier.fillMaxWidth().padding(top = Spacing.xl, bottom = 160.dp),
        )
    }

    if (confirmSignOut) {
        AlertDialog(
            onDismissRequest = { confirmSignOut = false },
            title = { Text("Sign out?") },
            confirmButton = {
                TextButton(onClick = {
                    confirmSignOut = false
                    scope.launch { vm.auth.signOut(); onSignedOut() }
                }) { Text("Sign out") }
            },
            dismissButton = { TextButton(onClick = { confirmSignOut = false }) { Text("Cancel") } },
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete account?") },
            text = { Text("This permanently removes your entries. This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    scope.launch { vm.auth.signOut(); onSignedOut() }
                }) { Text("Delete") }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        style = CwType.caption.copy(color = Palette.muted),
        modifier = Modifier.padding(top = Spacing.lg, bottom = Spacing.sm),
    )
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Radius.md))
            .border(1.dp, Palette.border, RoundedCornerShape(Radius.md))
            .background(Palette.white),
    ) { content() }
}

@Composable
private fun AboutRow(label: String, trailing: String? = null) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.md, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = CwType.body.copy(color = Palette.ink), modifier = Modifier.weight(1f))
        if (trailing != null) {
            Text(trailing, style = CwType.body.copy(color = Palette.muted))
        }
    }
}
