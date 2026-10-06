package com.ficonza.ficonza

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Guardar y abrir archivos con el selector del sistema (Storage Access Framework):
 * el usuario elige dónde (Descargas, Google Drive, etc.) sin pedir permisos.
 * El código Dart que lo usa está en lib/services/export_service.dart.
 */
class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ficonza/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "ficonza")
                        }
                        start(intent, SAVE_REQUEST, result, call.argument<ByteArray>("bytes"))
                    }
                    "open" -> {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        start(intent, OPEN_REQUEST, result, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun start(intent: Intent, request: Int, result: MethodChannel.Result, bytes: ByteArray?) {
        // Si quedó algo pendiente (no debería), se cierra para no dejar a Dart esperando.
        pendingResult?.success(null)
        pendingResult = result
        pendingBytes = bytes
        try {
            startActivityForResult(intent, request)
        } catch (e: ActivityNotFoundException) {
            pendingResult = null
            pendingBytes = null
            result.error("unavailable", "No hay un selector de archivos disponible", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST && requestCode != OPEN_REQUEST) return
        val result = pendingResult ?: return
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == SAVE_REQUEST) false else null)
            return
        }
        try {
            if (requestCode == SAVE_REQUEST) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes ?: ByteArray(0)) }
                result.success(true)
            } else {
                val content = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                result.success(content)
            }
        } catch (e: Exception) {
            result.error("io", e.message ?: e.toString(), null)
        }
    }

    companion object {
        private const val SAVE_REQUEST = 5101
        private const val OPEN_REQUEST = 5102
    }
}
