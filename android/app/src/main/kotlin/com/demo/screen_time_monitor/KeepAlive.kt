package com.demo.screen_time_monitor

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * 保活兜底：
 * 1. 任务从最近列表被划掉后，延迟重新拉起前台服务；
 * 2. 每 15 分钟一次的看门狗闹钟，即便进程被杀也能把服务拉回来。
 *
 * 注意：被系统「强行停止」（force-stop）或部分厂商的清理策略结束后，
 * 闹钟与广播都会被清除，只能靠用户把应用加入自启动 / 电池白名单解决。
 */
class KeepAliveReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            KeepAlive.ACTION_RESTART -> ScreenEventService.start(context)
            KeepAlive.ACTION_WATCHDOG -> {
                ScreenEventService.start(context)
                KeepAlive.scheduleWatchdog(context)
            }
        }
    }
}

object KeepAlive {
    const val ACTION_RESTART = "com.demo.screen_time_monitor.action.RESTART"
    const val ACTION_WATCHDOG = "com.demo.screen_time_monitor.action.WATCHDOG"

    private const val REQUEST_RESTART = 2001
    private const val REQUEST_WATCHDOG = 2002
    private const val WATCHDOG_INTERVAL_MS = 15L * 60L * 1000L
    private const val RESTART_DELAY_MS = 1500L

    fun scheduleRestart(context: Context) {
        val pending = pendingIntent(context, ACTION_RESTART, REQUEST_RESTART)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            manager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + RESTART_DELAY_MS,
                pending
            )
        } catch (t: Throwable) {
            // 忽略
        }
    }

    fun scheduleWatchdog(context: Context) {
        val pending = pendingIntent(context, ACTION_WATCHDOG, REQUEST_WATCHDOG)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            manager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + WATCHDOG_INTERVAL_MS,
                pending
            )
        } catch (t: Throwable) {
            // 忽略
        }
    }

    private fun pendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, KeepAliveReceiver::class.java).setAction(action)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}
