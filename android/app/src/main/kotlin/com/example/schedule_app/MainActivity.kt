package com.example.schedule_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPinWidget" -> result.success(requestPinWidget())
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestPinWidget(): String {
        Log.i(TAG, "requestPinWidget called")

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return showAndReturn("unsupported_android_version")
        }

        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
        val provider = ComponentName(this, ScheduleWidgetProvider::class.java)

        if (appWidgetManager?.isRequestPinAppWidgetSupported != true) {
            return showAndReturn("launcher_not_supported")
        }

        return try {
            val callbackIntent = Intent(this, WidgetPinnedReceiver::class.java)
            val successCallback = PendingIntent.getBroadcast(
                this,
                1001,
                callbackIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val accepted = appWidgetManager.requestPinAppWidget(provider, null, successCallback)
            Log.i(TAG, "requestPinAppWidget accepted=$accepted")
            if (!accepted) {
                showAndReturn("launcher_rejected")
            } else {
                "accepted"
            }
        } catch (e: IllegalStateException) {
            Log.e(TAG, "requestPinAppWidget illegal state", e)
            showAndReturn("illegal_state")
        } catch (e: RuntimeException) {
            Log.e(TAG, "requestPinAppWidget failed", e)
            showAndReturn("runtime_exception")
        }
    }

    private fun showAndReturn(reason: String): String {
        val message = when (reason) {
            "unsupported_android_version",
            "launcher_rejected",
            "illegal_state" -> "请在桌面小组件列表中添加 Open Schedule"
            "launcher_not_supported" -> "当前桌面不支持快捷添加小卡片"
            else -> "当前桌面无法快捷添加小卡片"
        }
        Log.w(TAG, "requestPinWidget failed: $reason")
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        return reason
    }

    companion object {
        private const val CHANNEL = "open_schedule/widget"
        private const val TAG = "OpenScheduleWidget"
    }
}
