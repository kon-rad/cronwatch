package app.cronwatch.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.cronwatch.model.Capture
import app.cronwatch.model.Entry
import app.cronwatch.service.AuthService
import app.cronwatch.service.EntriesService
import app.cronwatch.service.Page
import app.cronwatch.theme.CwType
import app.cronwatch.theme.Palette
import app.cronwatch.theme.Spacing
import app.cronwatch.ui.common.CaptureRow
import app.cronwatch.ui.common.DraftBanner
import com.google.firebase.firestore.DocumentSnapshot
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val PAGE_SIZE = 50

@HiltViewModel
class ListViewModel @Inject constructor(
    private val auth: AuthService,
    private val entries: EntriesService,
) : ViewModel() {
    val headPage: StateFlow<Page> = auth.user
        .flatMapLatest { entries.subscribeFirstPage(it?.uid ?: "stub-user", PAGE_SIZE) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), Page(emptyList(), null, false))

    private val _tail = MutableStateFlow<List<Entry>>(emptyList())
    val tail: StateFlow<List<Entry>> = _tail

    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading

    private var tailCursor: DocumentSnapshot? = null
    private var hasMore: Boolean = true

    fun loadMore() {
        val head = headPage.value
        val cursor = tailCursor ?: head.cursor
        if (_loading.value || !hasMore || cursor == null) return
        viewModelScope.launch {
            _loading.value = true
            try {
                val uid = auth.user.value?.uid ?: "stub-user"
                val next = entries.loadMore(uid, cursor, PAGE_SIZE)
                _tail.value = _tail.value + next.entries
                tailCursor = next.cursor ?: cursor
                hasMore = next.hasMore
            } finally {
                _loading.value = false
            }
        }
    }

    val captures: StateFlow<List<Capture>> =
        combine(headPage, _tail) { head, tail -> entries.groupByCapture(head.entries + tail) }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

@Composable
fun ListScreen(onOpenCapture: (String) -> Unit) {
    val vm: ListViewModel = hiltViewModel()
    val captures by vm.captures.collectAsState()
    val loading by vm.loading.collectAsState()
    val state = rememberLazyListState()

    val shouldLoadMore by remember {
        derivedStateOf {
            val last = state.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val total = state.layoutInfo.totalItemsCount
            total > 0 && last >= total - 4
        }
    }
    LaunchedEffect(shouldLoadMore) { if (shouldLoadMore) vm.loadMore() }

    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.bg)
            .statusBarsPadding(),
    ) {
        Box(
            Modifier
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        ) {
            Text("Entries", style = CwType.title.copy(color = Palette.ink))
        }
        LazyColumn(state = state, modifier = Modifier.fillMaxSize()) {
            item { DraftBanner() }
            if (captures.isEmpty()) {
                item {
                    Box(
                        Modifier
                            .fillMaxSize()
                            .padding(Spacing.xl),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            "No entries yet.",
                            style = CwType.body.copy(color = Palette.muted),
                        )
                    }
                }
            } else {
                items(captures, key = { it.captureId }) { capture ->
                    CaptureRow(capture, onClick = { onOpenCapture(capture.captureId) })
                }
            }
            if (loading) {
                item {
                    Box(
                        Modifier
                            .fillMaxSize()
                            .padding(Spacing.md),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(color = Palette.muted, strokeWidth = 2.dp)
                    }
                }
            }
        }
    }
}
