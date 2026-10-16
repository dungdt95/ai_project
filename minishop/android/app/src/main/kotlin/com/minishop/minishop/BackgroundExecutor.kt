package com.minishop.minishop

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.UiThread
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.view.FlutterCallbackInformation

/// Runs the Dart callback registered via `PluginUtilities.getCallbackHandle`
/// in a headless [FlutterEngine] so notifications can be processed without
/// the app's UI running. Mirrors the pattern used by plugins like
/// workmanager / android_alarm_manager_plus for background isolate startup.
object BackgroundExecutor {
    private var engine: FlutterEngine? = null

    fun executeNotification(context: Context, packageName: String, text: String) {
        val prefs = context.getSharedPreferences(Constants.PREFS_NAME, Context.MODE_PRIVATE)
        val handle = prefs.getLong(Constants.KEY_CALLBACK_HANDLE, -1L)
        if (handle == -1L) return // app never opened yet to register the callback handle

        Handler(Looper.getMainLooper()).post {
            runOnMainThread(context, handle, packageName, text)
        }
    }

    @UiThread
    private fun runOnMainThread(context: Context, handle: Long, packageName: String, text: String) {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(context)
        }
        loader.ensureInitializationComplete(context, null)

        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle) ?: return
        val newEngine = FlutterEngine(context)
        GeneratedPluginRegistrant.registerWith(newEngine)

        val dartBundlePath = loader.findAppBundlePath()
        newEngine.dartExecutor.executeDartCallback(
            DartExecutor.DartCallback(context.assets, dartBundlePath, callbackInfo)
        )

        val channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, Constants.BG_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialized" -> {
                    channel.invokeMethod(
                        "onNotificationPosted",
                        mapOf("packageName" to packageName, "text" to text)
                    )
                    result.success(null)
                }
                "done" -> {
                    result.success(null)
                    newEngine.destroy()
                    if (engine === newEngine) engine = null
                }
                else -> result.notImplemented()
            }
        }

        engine = newEngine
    }
}
