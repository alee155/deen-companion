package com.devsouq.deen_companion.app.dnd

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** One planned DND window: starts at [startMillis], ends at [endMillis]. */
data class DndEntry(
    val prayerName: String,
    val startMillis: Long,
    val endMillis: Long,
    val requestCode: Int,
)

/**
 * Native-side source of truth for the rolling DND schedule and for whether
 * *we* (rather than the user) switched Do Not Disturb on. That ownership flag
 * is what lets us restore the phone afterwards without ever undoing a DND the
 * user turned on themselves.
 */
class DndStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveSchedule(entries: List<DndEntry>) {
        val array = JSONArray()
        entries.forEach { e ->
            array.put(
                JSONObject().apply {
                    put("prayerName", e.prayerName)
                    put("startMillis", e.startMillis)
                    put("endMillis", e.endMillis)
                    put("requestCode", e.requestCode)
                },
            )
        }
        prefs.edit().putString(KEY_SCHEDULE, array.toString()).apply()
    }

    fun loadSchedule(): List<DndEntry> {
        val raw = prefs.getString(KEY_SCHEDULE, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                DndEntry(
                    prayerName = o.getString("prayerName"),
                    startMillis = o.getLong("startMillis"),
                    endMillis = o.getLong("endMillis"),
                    requestCode = o.getInt("requestCode"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** True while DND is on because this app turned it on. */
    var ownsDnd: Boolean
        get() = prefs.getBoolean(KEY_OWNS_DND, false)
        set(value) {
            prefs.edit().putBoolean(KEY_OWNS_DND, value).apply()
        }

    /** When the currently-active window should end; meaningful only while [ownsDnd]. */
    var activeEndMillis: Long
        get() = prefs.getLong(KEY_ACTIVE_END, 0L)
        set(value) {
            prefs.edit().putLong(KEY_ACTIVE_END, value).apply()
        }

    /** Start time of the latest window already applied, so catch-up never re-applies one. */
    var lastStartedMillis: Long
        get() = prefs.getLong(KEY_LAST_STARTED, 0L)
        set(value) {
            prefs.edit().putLong(KEY_LAST_STARTED, value).apply()
        }

    companion object {
        private const val PREFS_NAME = "prayer_dnd_prefs"
        private const val KEY_SCHEDULE = "schedule_json"
        private const val KEY_OWNS_DND = "owns_dnd"
        private const val KEY_ACTIVE_END = "active_end_millis"
        private const val KEY_LAST_STARTED = "last_started_millis"

        // Disjoint from the prayer-alarm request codes (0.. and 100_000..).
        const val START_REQUEST_CODE_BASE = 200_000
        const val END_REQUEST_CODE = 299_999
    }
}
