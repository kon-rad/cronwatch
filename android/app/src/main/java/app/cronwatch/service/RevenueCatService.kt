package app.cronwatch.service

import android.app.Activity
import android.content.Context
import app.cronwatch.AppEnvironment
import app.cronwatch.model.Entitlement
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.interfaces.LogInCallback
import com.revenuecat.purchases.interfaces.PurchaseCallback
import com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback
import com.revenuecat.purchases.models.StoreProduct
import com.revenuecat.purchases.models.StoreTransaction
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

@Singleton
class RevenueCatService @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val entitlementId = "pro"

    private val _entitlement = MutableStateFlow(Entitlement.free)
    val entitlement: StateFlow<Entitlement> = _entitlement.asStateFlow()

    @Volatile private var configured = false

    fun configureIfNeeded() {
        if (configured) return
        val apiKey = AppEnvironment.revenueCatApiKey ?: return
        Purchases.logLevel = LogLevel.WARN
        Purchases.configure(PurchasesConfiguration.Builder(context, apiKey).build())
        configured = true
    }

    suspend fun refreshEntitlement(): Entitlement {
        configureIfNeeded()
        if (!configured) return Entitlement.free.also { _entitlement.value = it }
        val info = awaitCustomerInfo()
        return entitlementFrom(info).also { _entitlement.value = it }
    }

    suspend fun restore(): Entitlement {
        configureIfNeeded()
        if (!configured) return Entitlement.free.also { _entitlement.value = it }
        val info: CustomerInfo? = suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.restorePurchases(object : ReceiveCustomerInfoCallback {
                override fun onReceived(customerInfo: CustomerInfo) { cont.resume(customerInfo) }
                override fun onError(error: PurchasesError) { cont.resume(null) }
            })
        }
        return entitlementFrom(info).also { _entitlement.value = it }
    }

    fun identify(uid: String) {
        configureIfNeeded()
        if (!configured) return
        Purchases.sharedInstance.logIn(uid, object : LogInCallback {
            override fun onReceived(customerInfo: CustomerInfo, created: Boolean) {
                _entitlement.value = entitlementFrom(customerInfo)
            }
            override fun onError(error: PurchasesError) {}
        })
    }

    suspend fun purchase(activity: Activity, product: StoreProduct): Entitlement {
        configureIfNeeded()
        if (!configured) return Entitlement.free
        val info: CustomerInfo? = suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.purchase(
                com.revenuecat.purchases.PurchaseParams.Builder(activity, product).build(),
                object : PurchaseCallback {
                    override fun onCompleted(t: StoreTransaction, customerInfo: CustomerInfo) {
                        cont.resume(customerInfo)
                    }
                    override fun onError(error: PurchasesError, userCancelled: Boolean) {
                        cont.resume(null)
                    }
                },
            )
        }
        return entitlementFrom(info).also { _entitlement.value = it }
    }

    private suspend fun awaitCustomerInfo(): CustomerInfo? =
        suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.getCustomerInfo(object : ReceiveCustomerInfoCallback {
                override fun onReceived(customerInfo: CustomerInfo) { cont.resume(customerInfo) }
                override fun onError(error: PurchasesError) { cont.resume(null) }
            })
        }

    private fun entitlementFrom(info: CustomerInfo?): Entitlement {
        val active = info?.entitlements?.active?.get(entitlementId) ?: return Entitlement.free
        val id = active.productIdentifier.lowercase()
        return when {
            "year" in id -> Entitlement.yearly
            "week" in id -> Entitlement.weekly
            else -> Entitlement.yearly
        }
    }
}
