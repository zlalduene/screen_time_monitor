package com.demo.screen_time_monitor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * 常驻前台服务：监听亮屏 / 息屏广播并写入本地事件库。
 *
 * 说明：ACTION_SCREEN_ON / ACTION_SCREEN_OFF 只能动态注册，
 * 因此必须有一个长期运行的前台服务来接收。
 */
class ScreenEventService : Service() {

    private var screenReceiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startInForeground()

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON ->
                        ScreenTimeline.record(context, ScreenTimeline.ON, System.currentTimeMillis())
                    Intent.ACTION_SCREEN_OFF ->
                        ScreenTimeline.record(context, ScreenTimeline.OFF, System.currentTimeMillis())
                }
            }
        }
        screenReceiver = receiver

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)

        seedInitialState()
        ScreenTimeline.prune(this)
        KeepAlive.scheduleWatchdog(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        KeepAlive.scheduleWatchdog(this)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // 从最近任务划掉后，延迟把服务重新拉起来。
        KeepAlive.scheduleRestart(this)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        screenReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (t: Throwable) {
                // ignore
            }
        }
        screenReceiver = null
        super.onDestroy()
    }

    /** 服务刚启动时补一条当前状态，保证后续间隔计算有基准。 */
    private fun seedInitialState() {
        val db = ScreenEventDb.get(this)
        if (db.lastEvent() != null) return
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        db.insert(
            if (powerManager.isInteractive) ScreenTimeline.ON else ScreenTimeline.OFF,
            System.currentTimeMillis()
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, "屏幕时间记录", NotificationManager.IMPORTANCE_MIN).apply {
            description = "记录亮屏与息屏时间，常驻通知"
            setShowBadge(false)
            enableVibration(false)
            enableLights(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("屏幕时间记录中")
            .setContentText("正在记录亮屏与息屏时间")
            .setSmallIcon(R.drawable.ic_stat_monitor)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setShowWhen(false)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun startInForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val CHANNEL_ID = "screen_monitor"
        private const val NOTIFICATION_ID = 1101

        fun start(context: Context) {
            val intent = Intent(context, ScreenEventService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
            } catch (t: Throwable) {
                // 后台启动受限时忽略，用户下次打开应用会再次启动。
            }
        }
    }
}
