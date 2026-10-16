package com.dtdung.bybrowser

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var saf: SafPlugin? = null
    private var intentChannel: MethodChannel? = null

    /** URI nhận từ "Mở bằng…" chưa được Dart lấy. */
    private var pendingUri: Uri? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleViewIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleViewIntent(intent)
        // App đang chạy: báo ngay cho Dart.
        pendingUri?.let { uri ->
            intentChannel?.invokeMethod("onOpen", uri.toString())
            pendingUri = null
        }
    }

    private fun handleViewIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        // Quyền từ ACTION_VIEW thường chỉ tạm thời; thử persist, không được thì thôi.
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
        }
        pendingUri = uri
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        saf = SafPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dtdung.bybrowser/intent").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingOpen" -> {
                        result.success(pendingUri?.toString())
                        pendingUri = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        saf?.dispose()
        saf = null
        intentChannel?.setMethodCallHandler(null)
        intentChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (saf?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}
