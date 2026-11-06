package ap.sitra.luz.clinica

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ap.sitra.luz.clinica/galeria"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "guardarImagenEnGaleria") {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                        ?: "SITRA_LUZ_${System.currentTimeMillis()}.jpg"
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Ruta de imagen vacía", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedUri = guardarEnMediaStore(filePath, fileName)
                        result.success(savedUri)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun guardarEnMediaStore(filePath: String, fileName: String): String {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("El archivo de origen no existe: $filePath")
        }
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/SITRA_Luz"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("No se pudo crear registro en MediaStore")
        resolver.openOutputStream(uri)?.use { outStream ->
            FileInputStream(sourceFile).use { inStream ->
                inStream.copyTo(outStream)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri.toString()
    }
}

