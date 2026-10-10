package com.example.algeria_pharma_crm_mobile

import io.flutter.embedding.android.FlutterActivity
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crm_visit_proof/uri_reader")
            .setMethodCallHandler { call, result ->
                if (call.method != "readUri") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uriValue = call.argument<String>("uri")
                if (uriValue.isNullOrBlank()) {
                    result.error("invalid_uri", "A document URI is required", null)
                    return@setMethodCallHandler
                }
                try {
                    val bytes = contentResolver.openInputStream(Uri.parse(uriValue))?.use { it.readBytes() }
                        ?: throw IllegalStateException("Could not open scanned document")
                    result.success(bytes)
                } catch (error: Exception) {
                    result.error("read_failed", error.message, null)
                }
            }
    }
}
