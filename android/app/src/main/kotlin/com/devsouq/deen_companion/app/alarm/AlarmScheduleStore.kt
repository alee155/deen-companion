package com.devsouq.deen_companion.app.alarm

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** One scheduled reminder — either "10 minutes before" or "at prayer time". */
data class AlarmEntry(
    val prayerName: String,
    val reminderType: String, // "before" | "atTime"
    val epochMillis: Long,
    val label: String,
    val requestCode: Int,
)

/**
 * Native-side source of truth for the rolling alarm schedule, the chosen
 * ringtone, and the snooze length — read by [BootReceiver] and
 * [AlarmSyncWorker] so both can re-arm alarms without any Dart involvement.
 */
class AlarmScheduleStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveSchedule(entries: List<AlarmEntry>) {
        val array = JSONArray()
        entries.forEach { entry ->
            array.put(
                JSONObject().apply {
                    put("prayerName", entry.prayerName)
                    put("reminderType", entry.reminderType)
                    put("epochMillis", entry.epochMillis)
                    put("label", entry.label)
                    put("requestCode", entry.requestCode)
                }
            )
        }
        prefs.edit().putString(KEY_SCHEDULE, array.toString()).apply()
    }

    fun loadSchedule(): List<AlarmEntry> {
        val raw = prefs.getString(KEY_SCHEDULE, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { i ->
                val obj = array.getJSONObject(i)
                AlarmEntry(
                    prayerName = obj.getString("prayerName"),
                    reminderType = obj.getString("reminderType"),
                    epochMillis = obj.getLong("epochMillis"),
                    label = obj.getString("label"),
                    requestCode = obj.getInt("requestCode"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    var ringtoneUri: String?
        get() = prefs.getString(KEY_RINGTONE_URI, null)
        set(value) {
            prefs.edit().putString(KEY_RINGTONE_URI, value).apply()
        }

    var snoozeMinutes: Int
        get() = prefs.getInt(KEY_SNOOZE_MINUTES, DEFAULT_SNOOZE_MINUTES)
        set(value) {
            prefs.edit().putInt(KEY_SNOOZE_MINUTES, value).apply()
        }

    companion object {
        private const val PREFS_NAME = "prayer_alarms_prefs"
        private const val KEY_SCHEDULE = "schedule_json"
        private const val KEY_RINGTONE_URI = "ringtone_uri"
        private const val KEY_SNOOZE_MINUTES = "snooze_minutes"
        const val DEFAULT_SNOOZE_MINUTES = 10

        // Regular rolling-window alarms use request codes starting here;
        // snooze alarms use a disjoint range so a snooze can never collide
        // with (or be silently clobbered by) the next regular reschedule.
        const val REGULAR_REQUEST_CODE_BASE = 0
        const val SNOOZE_REQUEST_CODE_BASE = 100_000
    }
}
