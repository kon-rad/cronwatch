package app.cronwatch.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Spacing
import app.cronwatch.util.TimeUtils
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.cronwatch.model.Entry
import app.cronwatch.service.AuthService
import app.cronwatch.service.EntriesService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class TodayViewModel @Inject constructor(
    auth: AuthService,
    entries: EntriesService,
) : ViewModel() {
    val today: StateFlow<List<Entry>> =
        auth.user
            .flatMapLatest { entries.subscribeToday(it?.uid ?: "stub-user") }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

@Composable
fun TodayScreen(onOpenEntry: (String) -> Unit) {
    val vm: TodayViewModel = hiltViewModel()
    val entries by vm.today.collectAsState()
    val tracked = TimeUtils.totalTrackedMin(entries)
    val open = (TimeUtils.MIN_PER_DAY - tracked).coerceAtLeast(0)

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding(),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        ) {
            Text(TimeUtils.formatLongDate(), style = CwType.title.copy(color = Palette.ink))
            Row(
                Modifier.padding(top = 2.dp),
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text("${TimeUtils.formatDuration(tracked)} tracked", style = CwType.caption.copy(color = Palette.muted))
                Text("${TimeUtils.formatDuration(open)} open", style = CwType.caption.copy(color = Palette.muted))
            }
        }
        TodayGrid(entries = entries, onOpenEntry = onOpenEntry)
    }
}
