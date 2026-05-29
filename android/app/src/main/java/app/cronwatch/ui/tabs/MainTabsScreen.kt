package app.cronwatch.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.ListAlt
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import app.cronwatch.theme.Palette
import app.cronwatch.ui.common.FloatingMicButton

private enum class Tab { Overview, Today, List, Profile }

@Composable
fun MainTabsScreen(
    onOpenCapture: () -> Unit,
    onOpenEntryView: (String) -> Unit,
    onOpenEntryEdit: (String) -> Unit,
    onOpenPaywall: () -> Unit,
    onSignedOut: () -> Unit,
) {
    var tab by rememberSaveable { mutableStateOf(Tab.Today) }

    Scaffold(
        containerColor = Palette.bg,
        bottomBar = {
            NavigationBar(containerColor = Palette.bg) {
                val itemColors = NavigationBarItemDefaults.colors(
                    selectedIconColor = Palette.amber,
                    unselectedIconColor = Palette.muted,
                    indicatorColor = Color.Transparent,
                )
                NavigationBarItem(
                    selected = tab == Tab.Overview,
                    onClick = { tab = Tab.Overview },
                    icon = { Icon(Icons.Outlined.Home, contentDescription = "Overview") },
                    colors = itemColors,
                )
                NavigationBarItem(
                    selected = tab == Tab.Today,
                    onClick = { tab = Tab.Today },
                    icon = { Icon(Icons.Outlined.CalendarToday, contentDescription = "Today") },
                    colors = itemColors,
                )
                NavigationBarItem(
                    selected = tab == Tab.List,
                    onClick = { tab = Tab.List },
                    icon = { Icon(Icons.Outlined.ListAlt, contentDescription = "List") },
                    colors = itemColors,
                )
                NavigationBarItem(
                    selected = tab == Tab.Profile,
                    onClick = { tab = Tab.Profile },
                    icon = { Icon(Icons.Outlined.Person, contentDescription = "Profile") },
                    colors = itemColors,
                )
            }
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Palette.bg),
        ) {
            when (tab) {
                Tab.Overview -> OverviewScreen()
                Tab.Today -> TodayScreen(onOpenEntry = onOpenEntryEdit)
                Tab.List -> ListScreen(onOpenCapture = onOpenEntryView)
                Tab.Profile -> ProfileScreen(onOpenPaywall = onOpenPaywall, onSignedOut = onSignedOut)
            }
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 20.dp, bottom = 20.dp),
            ) {
                FloatingMicButton(onClick = onOpenCapture)
            }
        }
    }
}
