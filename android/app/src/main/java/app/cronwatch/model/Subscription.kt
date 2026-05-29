package app.cronwatch.model

enum class Entitlement { free, weekly, yearly }

data class SubscriptionStatus(
    val entitlement: Entitlement,
    val renewsAt: String?,
)
