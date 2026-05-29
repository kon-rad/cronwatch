package app.cronwatch.nav

object Routes {
    const val SignIn = "sign-in"
    const val Tabs = "tabs"
    const val TabOverview = "tab/overview"
    const val TabToday = "tab/today"
    const val TabList = "tab/list"
    const val TabProfile = "tab/profile"
    const val Capture = "capture"
    const val Paywall = "paywall"
    fun entryEdit(id: String) = "entry/edit/$id"
    fun entryView(id: String) = "entry/view/$id"
    const val EntryEditPattern = "entry/edit/{id}"
    const val EntryViewPattern = "entry/view/{id}"
}
