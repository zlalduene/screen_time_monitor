package com.demo.screen_time_monitor

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import java.util.Calendar
import kotlin.math.max
import kotlin.math.min

/**
 * 亮屏 / 息屏时间线。
 *
 * 数据来源有两份：
 * 1. 前台服务实时写入的本地事件（可靠、长期保存）；
 * 2. Android 9+ 的 UsageEvents（SCREEN_INTERACTIVE / SCREEN_NON_INTERACTIVE），
 *    用于补全服务未运行期间缺失的历史。
 * 两份数据按时间合并并压缩连续同类型事件。
 */
object ScreenTimeline {

    const val ON = 1
    const val OFF = 0

    private const val DAY_MS = 24L * 60L * 60L * 1000L

    fun record(context: Context, type: Int, ts: Long) {
        ScreenEventDb.get(context).recordIfChanged(type, ts)
    }

    fun prune(context: Context) {
        ScreenEventDb.get(context).prune(System.currentTimeMillis() - 30 * DAY_MS)
    }

    fun todayStart(now: Long = System.currentTimeMillis()): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = now
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    /** 返回 [sinceMs, now] 区间内合并后的事件，按时间升序排列。 */
    fun eventsSince(context: Context, sinceMs: Long): List<Pair<Int, Long>> {
        val now = System.currentTimeMillis()
        val raw = ArrayList<Pair<Int, Long>>()
        raw.addAll(ScreenEventDb.get(context).since(sinceMs))
        raw.addAll(readSystemScreenEvents(context, sinceMs, now))
        raw.sortBy { it.second }

        val merged = ArrayList<Pair<Int, Long>>(raw.size)
        for (event in raw) {
            if (merged.isEmpty() || merged.last().first != event.first) {
                merged.add(event)
            }
        }
        return merged
    }

    private fun readSystemScreenEvents(context: Context, sinceMs: Long, untilMs: Long): List<Pair<Int, Long>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return emptyList()
        if (!MonitorRepository.hasUsageAccess(context)) return emptyList()

        val events = ArrayList<Pair<Int, Long>>()
        return try {
            val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val buffer = UsageEvents.Event()
            val cursor = manager.queryEvents(sinceMs, untilMs)
            while (cursor.hasNextEvent()) {
                cursor.getNextEvent(buffer)
                when (buffer.eventType) {
                    UsageEvents.Event.SCREEN_INTERACTIVE -> events.add(ON to buffer.timeStamp)
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE -> events.add(OFF to buffer.timeStamp)
                }
            }
            events
        } catch (t: Throwable) {
            emptyList()
        }
    }

    /**
     * 今日概览：当前状态、本次亮屏时长、本次亮屏距上次息屏的间隔、
     * 今日亮屏次数与累计亮屏时长，以及今日时间轴事件。
     */
    fun overview(context: Context): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val start = todayStart(now)
        // 往回多看一天，才能拿到“昨天息屏 → 今天亮屏”的间隔。
        val events = eventsSince(context, start - DAY_MS)

        var lastOn: Long? = null
        var lastOff: Long? = null
        var onCount = 0
        var onMs = 0L

        var openAt: Long? = null
        var onAtDayStart: Boolean? = null
        val todayEvents = ArrayList<Map<String, Any?>>()

        for (event in events) {
            val type = event.first
            val ts = event.second
            if (ts >= start && onAtDayStart == null) {
                onAtDayStart = openAt != null
            }
            if (type == ON) {
                if (openAt == null) openAt = ts
                lastOn = ts
                if (ts >= start) {
                    onCount++
                    todayEvents.add(mapOf("type" to ON, "ts" to ts))
                }
            } else {
                lastOff = ts
                openAt?.let { opened ->
                    onMs += overlap(opened, ts, start, now)
                    openAt = null
                }
                if (ts >= start) {
                    todayEvents.add(mapOf("type" to OFF, "ts" to ts))
                }
            }
        }
        openAt?.let { opened -> onMs += overlap(opened, now, start, now) }

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val screenOn = powerManager.isInteractive

        val sinceLastOff = if (screenOn && lastOn != null && lastOff != null && lastOff < lastOn) {
            lastOn - lastOff
        } else {
            null
        }
        val sessionMs = if (screenOn && lastOn != null) max(0L, now - lastOn) else null

        return mapOf(
            "screenOn" to screenOn,
            "lastOnAt" to lastOn,
            "lastOffAt" to lastOff,
            "sinceLastOffMs" to sinceLastOff,
            "sessionMs" to sessionMs,
            "todayOnCount" to onCount,
            "todayOnMs" to onMs.coerceAtLeast(0L),
            "todayEvents" to todayEvents,
            "onAtDayStart" to (onAtDayStart ?: false),
            "now" to now
        )
    }

    /** 最近的亮 / 息屏记录，附带“本次亮屏距上次息屏”的间隔。 */
    fun recent(context: Context, limit: Int): List<Map<String, Any?>> {
        val events = eventsSince(context, System.currentTimeMillis() - 7 * DAY_MS)
        val result = ArrayList<Map<String, Any?>>(limit)
        var previousOff: Long? = null

        for (event in events) {
            val type = event.first
            val ts = event.second
            if (type == ON) {
                val gap = previousOff?.takeIf { it < ts }?.let { ts - it }
                result.add(mapOf("type" to ON, "ts" to ts, "gapMs" to gap))
            } else {
                previousOff = ts
                result.add(mapOf("type" to OFF, "ts" to ts, "gapMs" to null))
            }
        }
        return if (result.size <= limit) result.reversed() else result.subList(result.size - limit, result.size).reversed()
    }

    private fun overlap(segmentStart: Long, segmentEnd: Long, rangeStart: Long, rangeEnd: Long): Long =
        max(0L, min(segmentEnd, rangeEnd) - max(segmentStart, rangeStart))
}
