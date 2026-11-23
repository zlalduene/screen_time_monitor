package com.demo.screen_time_monitor

import android.app.AppOpsManager
import android.app.NotificationManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.PowerManager
import android.util.Base64
import android.util.LruCache
import java.io.ByteArrayOutputStream

/**
 * 应用使用时长与权限状态查询。
 */
object MonitorRepository {

    private val iconCache = LruCache<String, String>(64)

    // ---------------------------------------------------------------- 权限

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            } else {
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            }
        } catch (t: Throwable) {
            AppOpsManager.MODE_DEFAULT
        }
        if (mode == AppOpsManager.MODE_ALLOWED) return true
        if (mode != AppOpsManager.MODE_DEFAULT) return false
        // 部分 ROM 会返回 MODE_DEFAULT，这里用一次真实查询兜底判断。
        return try {
            val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            !manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, end - 60_000, end).isNullOrEmpty()
        } catch (t: Throwable) {
            false
        }
    }

    fun hasNotificationAccess(context: Context): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.areNotificationsEnabled()
    }

    fun ignoresBatteryOptimizations(context: Context): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun permissionStatus(context: Context): Map<String, Any?> = mapOf(
        "usage" to hasUsageAccess(context),
        "notification" to hasNotificationAccess(context),
        "battery" to ignoresBatteryOptimizations(context),
        "sdk" to Build.VERSION.SDK_INT
    )

    // ------------------------------------------------------------ 应用使用

    /** 今日各应用前台使用时长，按使用时长倒序。 */
    fun todayAppUsage(context: Context, limit: Int = 15): List<Map<String, Any?>> {
        if (!hasUsageAccess(context)) return emptyList()

        val now = System.currentTimeMillis()
        val start = ScreenTimeline.todayStart(now)
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats: List<UsageStats> = try {
            manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, now) ?: emptyList()
        } catch (t: Throwable) {
            emptyList()
        }

        val packageManager = context.packageManager
        val totals = HashMap<String, Long>()
        for (stat in stats) {
            val packageName = stat.packageName ?: continue
            if (packageName == context.packageName) continue
            val time = stat.totalTimeInForeground
            if (time <= 0) continue
            totals[packageName] = maxOf(totals[packageName] ?: 0L, time)
        }

        val result = ArrayList<Map<String, Any?>>()
        for ((packageName, totalMs) in totals) {
            val appInfo = try {
                packageManager.getApplicationInfo(packageName, 0)
            } catch (t: Throwable) {
                null
            } ?: continue
            if (packageManager.getLaunchIntentForPackage(packageName) == null) continue

            val label = try {
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (t: Throwable) {
                packageName
            }
            result.add(
                mapOf(
                    "package" to packageName,
                    "label" to label,
                    "ms" to totalMs,
                    "icon" to loadIconBase64(context, packageName)
                )
            )
        }
        return result.sortedByDescending { (it["ms"] as? Long) ?: 0L }.take(limit)
    }

    private fun loadIconBase64(context: Context, packageName: String): String? {
        iconCache.get(packageName)?.let { return it }
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            val encoded = drawableToBase64(context, drawable)
            if (encoded != null) iconCache.put(packageName, encoded)
            encoded
        } catch (t: Throwable) {
            null
        }
    }

    private fun drawableToBase64(context: Context, drawable: Drawable): String? = try {
        val size = (56 * context.resources.displayMetrics.density).toInt().coerceIn(56, 192)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bitmap.recycle()
        Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    } catch (t: Throwable) {
        null
    }
}
