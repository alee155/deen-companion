package com.devsouq.deen_companion.app.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.devsouq.deen_companion.app.MainActivity

/**
 * Single source of truth for arming/cancelling native alarms. Used by the
 * MethodChannel handler (fresh schedule pushes), [BootReceiver] and
 * [AlarmSyncWorker] (re-arm from cache), and snooze handling — so there is
 * exactly one place that calls [AlarmManager.setAlarmClock].
 */
object AlarmScheduler {
    const val EXTRA_PRAYER_NAME = "prayer_name"
    const val EXTRA_REMINDER_TYPE = "reminder_type"
    const val EXTRA_EPOCH_MILLIS = "epoch_millis"
    const val EXTRA_LABEL = "label"
    const val EXTRA_REQUEST_CODE = "request_code"
    const val EXTRA_IS_SNOOZE = "is_snooze"

    private const val PENDING_INTENT_FLAGS =
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    /**
     * setAlarmClock — not setExactAndAllowWhileIdle/setExact — because it's
     * the one exact-alarm API that's fully exempt from both Doze throttling
     * and the SCHEDULE_EXACT_ALARM permission regime (API 31+), and it
     * shows the alarm-clock glyph in the status bar: an honest "your prayer
     * alarm is armed" signal that matches the feature's own premise.
     */
    fun scheduleAlarm(context: Context, entry: AlarmEntry, isSnooze: Boolean = false) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val operationIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(EXTRA_PRAYER_NAME, entry.prayerName)
            putExtra(EXTRA_REMINDER_TYPE, entry.reminderType)
            putExtra(EXTRA_EPOCH_MILLIS, entry.epochMillis)
            putExtra(EXTRA_LABEL, entry.label)
            putExtra(EXTRA_REQUEST_CODE, entry.requestCode)
            putExtra(EXTRA_IS_SNOOZE, isSnooze)
        }
        val operationPendingIntent = PendingIntent.getBroadcast(
            context, entry.requestCode, operationIntent, PENDING_INTENT_FLAGS,
        )

        // Tapping the status-bar alarm-clock icon reopens the app.
        val showIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val showPendingIntent = PendingIntent.getActivity(
            context, entry.requestCode, showIntent, PENDING_INTENT_FLAGS,
        )

        val alarmClockInfo = AlarmManager.AlarmClockInfo(entry.epochMillis, showPendingIntent)
        alarmManager.setAlarmClock(alarmClockInfo, operationPendingIntent)
    }

    fun cancelAlarm(context: Context, requestCode: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(context, requestCode, intent, PENDING_INTENT_FLAGS)
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    fun cancelAll(context: Context, entries: List<AlarmEntry>) {
        entries.forEach { cancelAlarm(context, it.requestCode) }
    }

    /**
     * Arms a one-shot snooze alarm [AlarmScheduleStore.snoozeMinutes] from
     * now, clamped so it can never fire after the next already-scheduled
     * entry (e.g. a snoozed Maghrib reminder must not ring after Isha has
     * started). Returns false if there's no sensible time left to snooze
     * into. Shared by the native ring screen's Snooze button and the
     * in-app foreground banner's Snooze button — the one place this logic
     * needs to live.
     */
    fun scheduleSnooze(
        context: Context,
        prayerName: String,
        reminderType: String,
        label: String,
        currentEpochMillis: Long,
    ): Boolean {
        val store = AlarmScheduleStore(context)
        var triggerAt = System.currentTimeMillis() + store.snoozeMinutes * 60_000L

        val nextEntry = store.loadSchedule()
            .filter { it.epochMillis > currentEpochMillis }
            .minByOrNull { it.epochMillis }
        if (nextEntry != null && triggerAt >= nextEntry.epochMillis) {
            triggerAt = nextEntry.epochMillis - 60_000L
        }
        if (triggerAt <= System.currentTimeMillis()) return false

        val requestCode = AlarmScheduleStore.SNOOZE_REQUEST_CODE_BASE + (prayerName.hashCode() and 0xFFF)
        val entry = AlarmEntry(
            prayerName = prayerName,
            reminderType = reminderType,
            epochMillis = triggerAt,
            label = "Snoozed: $label",
            requestCode = requestCode,
        )
        scheduleAlarm(context, entry, isSnooze = true)
        return true
    }
}
