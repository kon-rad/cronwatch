package app.cronwatch.ui.paywall

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.GridOn
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import app.cronwatch.service.RevenueCatService
import app.cronwatch.service.ToastBus
import app.cronwatch.service.ToastKind
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Radius
import app.cronwatch.theme.Spacing
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

private enum class Plan { Yearly, Weekly }

@HiltViewModel
class PaywallViewModel @Inject constructor(
    val revenueCat: RevenueCatService,
    val toastBus: ToastBus,
) : ViewModel()

@Composable
fun PaywallSheet(onDismiss: () -> Unit) {
    val vm: PaywallViewModel = hiltViewModel()
    val scope = rememberCoroutineScope()
    var plan by remember { mutableStateOf(Plan.Yearly) }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding(),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(Spacing.lg)
                .verticalScroll(rememberScrollState()),
        ) {
            Text(
                "Track your time without thinking about it.",
                style = CwType.title.copy(color = Palette.ink, fontSize = 26.sp, lineHeight = 32.sp),
                modifier = Modifier.padding(end = 28.dp, top = Spacing.lg),
            )
            Text(
                "Voice in. Structured time out.",
                style = CwType.body.copy(color = Palette.muted),
                modifier = Modifier.padding(top = Spacing.sm),
            )

            Column(
                Modifier.padding(top = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Feature(
                    Icons.Outlined.Mic,
                    "Voice capture",
                    "Hold the button, speak naturally. Cronwatch turns it into a structured entry.",
                )
                Feature(
                    Icons.Outlined.GridOn,
                    "15-minute grid",
                    "Your day at a glance — every block accounted for, nothing fudged.",
                )
                Feature(
                    Icons.Outlined.Lock,
                    "Private by default",
                    "Your entries stay on-device. No analytics, no ads, no resold data.",
                )
            }

            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(top = Spacing.xl),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                PlanCard(
                    selected = plan == Plan.Yearly,
                    badge = "Best value · 20% off",
                    title = "Yearly",
                    price = "\$40",
                    unit = "/yr",
                    sub = "\$3.33/month",
                    onClick = { plan = Plan.Yearly },
                    modifier = Modifier.weight(1f),
                )
                PlanCard(
                    selected = plan == Plan.Weekly,
                    badge = null,
                    title = "Weekly",
                    price = "\$4",
                    unit = "/wk",
                    sub = "Try a week",
                    onClick = { plan = Plan.Weekly },
                    modifier = Modifier.weight(1f),
                )
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(top = Spacing.xl)
                    .clip(RoundedCornerShape(Radius.md))
                    .background(Palette.amber)
                    .clickable {
                        vm.toastBus.show("Purchase is not wired in this build", ToastKind.INFO)
                        onDismiss()
                    }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "Start subscription",
                    style = CwType.body.copy(color = Palette.white, fontWeight = FontWeight.SemiBold),
                )
            }

            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(top = Spacing.md),
                horizontalArrangement = Arrangement.Center,
            ) {
                Text("Cancel anytime · ", style = CwType.caption.copy(color = Palette.muted))
                Text(
                    "Restore purchases",
                    style = CwType.caption.copy(color = Palette.muted, textDecoration = TextDecoration.Underline),
                    modifier = Modifier.clickable {
                        scope.launch { vm.revenueCat.restore() }
                    },
                )
                Text(" · ", style = CwType.caption.copy(color = Palette.muted))
                Text(
                    "Terms",
                    style = CwType.caption.copy(color = Palette.muted, textDecoration = TextDecoration.Underline),
                )
            }
        }

        Icon(
            Icons.Filled.Close,
            contentDescription = "Close",
            tint = Palette.muted,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(Spacing.md)
                .size(20.dp)
                .clickable(onClick = onDismiss),
        )
    }
}

@Composable
private fun Feature(icon: ImageVector, title: String, sub: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(Radius.sm))
                .background(Palette.borderSoft),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = Palette.ink, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = CwType.body.copy(color = Palette.ink, fontWeight = FontWeight.SemiBold))
            Text(
                sub,
                style = CwType.caption.copy(color = Palette.muted),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun PlanCard(
    selected: Boolean,
    badge: String?,
    title: String,
    price: String,
    unit: String,
    sub: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .clip(RoundedCornerShape(Radius.md))
            .border(
                1.dp,
                if (selected) Palette.amber else Palette.border,
                RoundedCornerShape(Radius.md),
            )
            .background(if (selected) Palette.amber.copy(alpha = 0.08f) else Palette.white)
            .clickable(onClick = onClick)
            .padding(Spacing.md),
    ) {
        if (badge != null) {
            Box(
                Modifier
                    .clip(RoundedCornerShape(Radius.sm))
                    .background(Palette.amber.copy(alpha = 0.18f))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Text(
                    badge,
                    style = CwType.caption.copy(color = Palette.amber, fontWeight = FontWeight.SemiBold),
                )
            }
        }
        Text(
            title,
            style = CwType.caption.copy(color = Palette.muted),
            modifier = Modifier.padding(top = if (badge != null) 6.dp else 0.dp),
        )
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(price, style = CwType.title.copy(color = Palette.ink))
            Text(unit, style = CwType.caption.copy(color = Palette.muted))
        }
        Text(sub, style = CwType.caption.copy(color = Palette.muted))
    }
}
