package app.cronwatch.ui.root

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.cronwatch.nav.Routes
import app.cronwatch.service.AuthService
import app.cronwatch.service.CaptureQueue
import app.cronwatch.service.RevenueCatService
import app.cronwatch.theme.Palette
import app.cronwatch.ui.auth.SignInScreen
import app.cronwatch.ui.capture.CaptureSheet
import app.cronwatch.ui.common.ToastHost
import app.cronwatch.ui.entry.EntryEditSheet
import app.cronwatch.ui.entry.EntryViewSheet
import app.cronwatch.ui.paywall.PaywallSheet
import app.cronwatch.ui.tabs.MainTabsScreen
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class RootViewModel @Inject constructor(
    val auth: AuthService,
    val revenueCat: RevenueCatService,
    val captureQueue: CaptureQueue,
) : ViewModel()

@Composable
fun RootScreen() {
    val vm: RootViewModel = hiltViewModel()
    val user by vm.auth.user.collectAsState()
    val ready by vm.auth.ready.collectAsState()
    val nav = rememberNavController()

    LaunchedEffect(user?.uid) {
        val uid = user?.uid ?: return@LaunchedEffect
        vm.revenueCat.identify(uid)
        vm.revenueCat.refreshEntitlement()
    }

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        if (!ready) return@Box

        NavHost(
            navController = nav,
            startDestination = if (user == null) Routes.SignIn else Routes.Tabs,
        ) {
            composable(Routes.SignIn) { SignInScreen(onSignedIn = {
                nav.navigate(Routes.Tabs) {
                    popUpTo(Routes.SignIn) { inclusive = true }
                }
            }) }
            composable(Routes.Tabs) {
                MainTabsScreen(
                    onOpenCapture = { nav.navigate(Routes.Capture) },
                    onOpenEntryView = { nav.navigate(Routes.entryView(it)) },
                    onOpenEntryEdit = { nav.navigate(Routes.entryEdit(it)) },
                    onOpenPaywall = { nav.navigate(Routes.Paywall) },
                    onSignedOut = {
                        nav.navigate(Routes.SignIn) {
                            popUpTo(Routes.Tabs) { inclusive = true }
                        }
                    },
                )
            }
            composable(Routes.Capture) {
                CaptureSheet(onDismiss = { nav.popBackStack() })
            }
            composable(Routes.Paywall) {
                PaywallSheet(onDismiss = { nav.popBackStack() })
            }
            composable(
                Routes.EntryEditPattern,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val id = entry.arguments?.getString("id").orEmpty()
                EntryEditSheet(entryId = id, onDismiss = { nav.popBackStack() })
            }
            composable(
                Routes.EntryViewPattern,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val id = entry.arguments?.getString("id").orEmpty()
                EntryViewSheet(captureId = id, onDismiss = { nav.popBackStack() })
            }
        }

        ToastHost()
    }
}
