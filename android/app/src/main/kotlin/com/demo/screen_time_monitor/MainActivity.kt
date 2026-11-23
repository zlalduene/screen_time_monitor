package com.demo.screen_time_monitor

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val worker = Executors.newSingleThreadExecutor()
    private val prefs by lazy { getSharedPreferences(PREFS, Context.MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 服务启动放到 Flutter 首帧之后（由 Dart 端调用 startMonitor），避免拖慢冷启动。
        requestNotificationPermissionIfNeeded()
        applyRecentsVisibility()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "snapshot" -> runAsync(result) {
                        mapOf(
                            "overview" to ScreenTimeline.overview(this),
                            "apps" to MonitorRepository.todayAppUsage(this),
                            "recent" to ScreenTimeline.recent(this, 20),
                            "permissions" to MonitorRepository.permissionStatus(this),
                            "hideFromRecents" to isHiddenFromRecents()
                        )
                    }

                    "startMonitor" -> {
                        ScreenEventService.start(this)
                        result.success(true)
                    }

                    "setHideFromRecents" -> {
                        val hidden = call.arguments as? Boolean ?: true
                        prefs.edit().putBoolean(KEY_HIDE_FROM_RECENTS, hidden).apply()
                        applyRecentsVisibility()
                        result.success(true)
                    }

                    "openUsageAccess" -> result.success(openUsageAccessSettings())
                    "openNotificationSettings" -> result.success(openAppNotificationSettings())
                    "openBatterySettings" -> result.success(openBatterySettings())
                    "requestIgnoreBattery" -> result.success(requestIgnoreBattery())
                    "requestNotificationPermission" -> {
                        requestNotificationPermissionIfNeeded()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isHiddenFromRecents(): Boolean =
        prefs.getBoolean(KEY_HIDE_FROM_RECENTS, true)

    /** 从最近任务列表隐藏，避免被手滑划掉；隐藏后仍可从通知栏 / 桌面图标进入。 */
    private fun applyRecentsVisibility() {
        try {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val hidden = isHiddenFromRecents()
            val currentTaskId = taskId
            val appTask = manager.appTasks.firstOrNull { it.taskInfo.id == currentTaskId }
                ?: manager.appTasks.firstOrNull()
            appTask?.setExcludeFromRecents(hidden)
        } catch (t: Throwable) {
            // 部分 ROM 不支持，忽略
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            val value: Any?
            try {
                value = block()
            } catch (t: Throwable) {
                runOnUiThread { result.error("monitor_error", t.message ?: "unknown", null) }
                return@execute
            }
            runOnUiThread { result.success(value) }
        }
    }

    private fun openUsageAccessSettings(): Boolean = try {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        true
    } catch (t: Throwable) {
        false
    }

    private fun openAppNotificationSettings(): Boolean = try {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (t: Throwable) {
        false
    }

    private fun openBatterySettings(): Boolean = try {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        true
    } catch (t: Throwable) {
        false
    }

    /** 直接弹系统「忽略电池优化」确认框，比跳列表更省事。 */
    private fun requestIgnoreBattery(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(packageName)) return true
        return try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (t: Throwable) {
            openBatterySettings()
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001
            )
        }
    }

    companion object {
        private const val CHANNEL = "screen_time_monitor/monitor"
        private const val PREFS = "monitor_prefs"
        private const val KEY_HIDE_FROM_RECENTS = "hide_from_recents"
    }
}
