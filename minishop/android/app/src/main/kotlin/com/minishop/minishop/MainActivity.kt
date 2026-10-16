package com.minishop.minishop

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.ACCESS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessGranted" -> {
                        val enabled = NotificationManagerCompat.getEnabledListenerPackages(this)
                            .contains(packageName)
                        result.success(enabled)
                    }
                    "openNotificationAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(null)
                    }
                    "setCallbackHandle" -> {
                        val handle = (call.argument<Number>("handle"))?.toLong()
                        if (handle == null) {
                            result.error("invalid_handle", "Missing handle argument", null)
                        } else {
                            getSharedPreferences(Constants.PREFS_NAME, MODE_PRIVATE)
                                .edit()
                                .putLong(Constants.KEY_CALLBACK_HANDLE, handle)
                                .apply()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
