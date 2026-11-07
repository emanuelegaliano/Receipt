package it.manu.receipt_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

// FragmentActivity: serve a BiometricPrompt per mostrare la richiesta dell'impronta.
class MainActivity : FlutterFragmentActivity() {
    // Risposta in attesa del ritorno da "Installa app sconosciute".
    private var pendingSettings: MethodChannel.Result? = null

    private val installSettings =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            pendingSettings?.success(canInstall())
            pendingSettings = null
        }

    private fun canInstall() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Sblocco con l'impronta (lib/security/app_lock.dart): la chiave dei
        // dati è cifrata con una chiave AES del Keystore che Android lascia
        // usare solo subito dopo un'impronta riconosciuta.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "receipt/biometric").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(
                    BiometricManager.from(this).canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS,
                )
                "seal" -> seal(call, result)
                "unseal" -> unseal(call, result)
                "forget" -> {
                    keyStore().deleteEntry(BIOMETRIC_KEY)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Aggiornamenti dell'app (lib/update/updater.dart): versione installata,
        // permesso di installare app e apertura dell'installer di sistema con
        // l'APK già scaricato e verificato.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "receipt/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "version" -> result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                "canInstall" -> result.success(canInstall())
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(true)
                    } else {
                        pendingSettings?.success(canInstall())
                        pendingSettings = result
                        installSettings.launch(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                        )
                    }
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "path mancante", null)
                    } else {
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                        startActivity(
                            Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // Link esterni (la pagina del quadro del giorno su metmuseum.org): li
        // apre il browser. Solo https.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "receipt/links").setMethodCallHandler { call, result ->
            val url = call.argument<String>("url")
            when {
                call.method != "open" -> result.notImplemented()
                url == null || !url.startsWith("https://") -> result.error("INVALID_ARG", "url non valido", null)
                else -> try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(null)
                } catch (e: android.content.ActivityNotFoundException) {
                    result.error("NO_BROWSER", e.message, null)
                }
            }
        }
    }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    /// Una chiave nuova a ogni attivazione dell'impronta. Android la cancella
    /// da solo se si aggiunge o si toglie un'impronta.
    private fun newBiometricKey(): SecretKey {
        keyStore().deleteEntry(BIOMETRIC_KEY)
        val spec = KeyGenParameterSpec.Builder(BIOMETRIC_KEY, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                } else {
                    @Suppress("DEPRECATION")
                    setUserAuthenticationValidityDurationSeconds(-1)
                }
            }
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(spec)
            generateKey()
        }
    }

    /// Restituisce iv (12 byte) + testo cifrato.
    private fun seal(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data") ?: return result.error("INVALID_ARG", "data mancante", null)
        val cipher = try {
            Cipher.getInstance(AES_GCM).apply { init(Cipher.ENCRYPT_MODE, newBiometricKey()) }
        } catch (e: Exception) {
            return result.error("failed", e.message, null)
        }
        authenticate(call, cipher, result) { it.iv + it.doFinal(data) }
    }

    private fun unseal(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data") ?: return result.error("INVALID_ARG", "data mancante", null)
        if (data.size <= 12) return result.error("invalidated", "dati non validi", null)
        val cipher = try {
            val key = keyStore().getKey(BIOMETRIC_KEY, null) as SecretKey?
                ?: return result.error("invalidated", "chiave assente", null)
            Cipher.getInstance(AES_GCM).apply { init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, data, 0, 12)) }
        } catch (e: KeyPermanentlyInvalidatedException) {
            keyStore().deleteEntry(BIOMETRIC_KEY)
            return result.error("invalidated", e.message, null)
        } catch (e: Exception) {
            return result.error("failed", e.message, null)
        }
        authenticate(call, cipher, result) { it.doFinal(data, 12, data.size - 12) }
    }

    /// Mostra la richiesta dell'impronta e, se riconosciuta, usa [cipher].
    /// Annullare non è un errore: risponde null.
    private fun authenticate(call: MethodCall, cipher: Cipher, result: MethodChannel.Result, use: (Cipher) -> ByteArray) {
        var answered = false
        fun answer(block: () -> Unit) {
            if (!answered) {
                answered = true
                block()
            }
        }
        val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                val c = auth.cryptoObject?.cipher ?: return answer { result.error("failed", "cipher mancante", null) }
                answer {
                    try {
                        result.success(use(c))
                    } catch (e: Exception) {
                        result.error("failed", e.message, null)
                    }
                }
            }

            override fun onAuthenticationError(code: Int, message: CharSequence) {
                when (code) {
                    BiometricPrompt.ERROR_NEGATIVE_BUTTON, BiometricPrompt.ERROR_USER_CANCELED, BiometricPrompt.ERROR_CANCELED ->
                        answer { result.success(null) }
                    else -> answer { result.error("failed", message.toString(), null) }
                }
            }
        })
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Receipt")
            .setSubtitle(call.argument<String>("reason") ?: "")
            .setNegativeButtonText(call.argument<String>("cancel") ?: "")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .build()
        prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
    }

    companion object {
        private const val BIOMETRIC_KEY = "receipt_data_key"
        private const val AES_GCM = "AES/GCM/NoPadding"
    }
}
