package com.demo.screen_time_monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 开机 / 应用升级后重新拉起前台服务。 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> ScreenEventService.start(context)
        }
    }
}
