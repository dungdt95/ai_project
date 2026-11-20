package com.dtd.doctruyen

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dtd.doctruyen/system")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "openTtsSettings" -> result.success(openTtsSettings())
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "setKeepAwake" -> {
                    setKeepAwake(call.arguments == true)
                    result.success(null)
                }
                "getInitialSharedFile" -> result.success(consumeSharedFile(intent))
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val shared = consumeSharedFile(intent)
        if (shared != null) channel?.invokeMethod("sharedFile", shared)
    }

    private fun openTtsSettings(): Boolean {
        val candidates = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(Settings.ACTION_VOICE_INPUT_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (i in candidates) {
            try {
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }

    private var wakeLock: PowerManager.WakeLock? = null

    private fun setKeepAwake(on: Boolean) {
        if (on) {
            if (wakeLock?.isHeld == true) return
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "doctruyen:tts").apply {
                setReferenceCounted(false)
                acquire(6 * 60 * 60 * 1000L)
            }
        } else {
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
        }
    }

    override fun onDestroy() {
        setKeepAwake(false)
        super.onDestroy()
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Trả `true` nếu đã có quyền (hoặc không cần); chờ người dùng chọn rồi mới trả lời. */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            val r = pendingPermissionResult
            pendingPermissionResult = null
            r?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        }
    }

    /** Chép tệp từ intent VIEW/SEND vào cache và trả {path, name}; chỉ xử lý một lần. */
    private fun consumeSharedFile(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        }
        if (uri == null) return null
        intent.action = null
        return try {
            var name = "shared"
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && c.moveToFirst()) name = c.getString(idx) ?: name
            }
            if (name == "shared") name = uri.lastPathSegment?.substringAfterLast("/") ?: name
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val safe = name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            val out = File(dir, safe)
            val copied = contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { input.copyTo(it) }
                true
            } ?: false
            if (copied) mapOf("path" to out.absolutePath, "name" to name) else null
        } catch (e: Exception) {
            null
        }
    }
}
