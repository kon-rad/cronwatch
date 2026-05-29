package app.cronwatch.service

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import app.cronwatch.AppEnvironment
import app.cronwatch.model.AppUser
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthService @Inject constructor(
    private val bootstrap: FirebaseBootstrap,
) {
    private val _user = MutableStateFlow<AppUser?>(null)
    val user: StateFlow<AppUser?> = _user.asStateFlow()

    private val _ready = MutableStateFlow(false)
    val ready: StateFlow<Boolean> = _ready.asStateFlow()

    private val stubUser = AppUser(
        uid = "stub-user",
        email = "emma@cronwatch.app",
        displayName = "Emma Mori",
        photoURL = null,
    )

    fun startListening() {
        val auth = bootstrap.authOrNull()
        if (auth == null) {
            _ready.value = true
            return
        }
        auth.addAuthStateListener { fa ->
            _user.value = fa.currentUser?.let { fu ->
                AppUser(
                    uid = fu.uid,
                    email = fu.email,
                    displayName = fu.displayName,
                    photoURL = fu.photoUrl?.toString(),
                )
            }
            _ready.value = true
        }
    }

    suspend fun signInWithGoogle(context: Context): AppUser {
        val auth = bootstrap.authOrNull()
        val webClientId = AppEnvironment.googleWebClientId
        if (auth == null || webClientId == null) {
            delay(250)
            _user.value = stubUser
            return stubUser
        }
        val credentialManager = CredentialManager.create(context)
        val option = GetGoogleIdOption.Builder()
            .setServerClientId(webClientId)
            .setFilterByAuthorizedAccounts(false)
            .setAutoSelectEnabled(true)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val response = credentialManager.getCredential(context, request)
        val cred = response.credential
        if (cred !is CustomCredential || cred.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw IllegalStateException("Unexpected credential type from Google: ${cred.type}")
        }
        val googleIdToken = GoogleIdTokenCredential.createFrom(cred.data).idToken
        val firebaseCred = GoogleAuthProvider.getCredential(googleIdToken, null)
        val result = auth.signInWithCredential(firebaseCred).await()
        val fu = result.user ?: throw IllegalStateException("Firebase returned no user")
        return AppUser(
            uid = fu.uid,
            email = fu.email,
            displayName = fu.displayName,
            photoURL = fu.photoUrl?.toString(),
        ).also { _user.value = it }
    }

    suspend fun signOut() {
        bootstrap.authOrNull()?.signOut()
        _user.value = null
    }

    suspend fun idToken(): String? {
        val auth = bootstrap.authOrNull() ?: return null
        val current = auth.currentUser ?: return null
        return current.getIdToken(false).await().token
    }

    fun currentUid(): String = _user.value?.uid ?: "stub-user"
}
