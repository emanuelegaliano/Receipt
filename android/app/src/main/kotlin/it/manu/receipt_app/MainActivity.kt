package it.manu.receipt_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FragmentActivity: serve a local_auth per mostrare la richiesta dell'impronta.
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
}
