package com.demo.screen_time_monitor

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * 亮屏 / 息屏事件的本地存储。
 * type = 1 亮屏，type = 0 息屏，ts 为事件发生的毫秒时间戳。
 */
class ScreenEventDb(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE events (" +
                "_id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "type INTEGER NOT NULL, " +
                "ts INTEGER NOT NULL)"
        )
        db.execSQL("CREATE INDEX idx_events_ts ON events(ts)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    /** 与最后一条事件类型相同则忽略，避免服务重启时写入重复事件。 */
    fun recordIfChanged(type: Int, ts: Long) {
        val last = lastEvent()
        if (last != null && last.first == type) return
        insert(type, ts)
    }

    fun insert(type: Int, ts: Long) {
        val values = ContentValues().apply {
            put("type", type)
            put("ts", ts)
        }
        writableDatabase.insert("events", null, values)
    }

    fun lastEvent(): Pair<Int, Long>? {
        readableDatabase.query(
            "events", arrayOf("type", "ts"),
            null, null, null, null, "ts DESC, _id DESC", "1"
        ).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0) to cursor.getLong(1)
        }
        return null
    }

    fun since(sinceMs: Long): List<Pair<Int, Long>> {
        val events = ArrayList<Pair<Int, Long>>()
        readableDatabase.query(
            "events", arrayOf("type", "ts"),
            "ts >= ?", arrayOf(sinceMs.toString()),
            null, null, "ts ASC, _id ASC"
        ).use { cursor ->
            while (cursor.moveToNext()) {
                events.add(cursor.getInt(0) to cursor.getLong(1))
            }
        }
        return events
    }

    fun prune(beforeMs: Long) {
        writableDatabase.delete("events", "ts < ?", arrayOf(beforeMs.toString()))
    }

    companion object {
        private const val DB_NAME = "screen_events.db"
        private const val DB_VERSION = 1

        @Volatile
        private var instance: ScreenEventDb? = null

        fun get(context: Context): ScreenEventDb =
            instance ?: synchronized(this) {
                instance ?: ScreenEventDb(context).also { instance = it }
            }
    }
}
