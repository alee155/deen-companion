package com.devsouq.deen_companion.app.dnd

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Arms and cancels the start/end alarms that drive [DndController]. */
object DndScheduler {
    const val ACTION_START = "com.devsouq.deen_companion.app.dnd.START"
    const val ACTION_END = "com.devsouq.deen_companion.app.dnd.END"
    const val EXTRA_PRAYER_NAME = "prayer_name"
    const val EXTRA_START_MILLIS = "start_millis"
    const val EXTRA_END_MILLIS = "end_millis"

    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    /**
     * Exact when Android allows it (SCHEDULE_EXACT_ALARM on 12+, which Android
     * 14+ no longer grants by default); otherwise an inexact-but-Doze-tolerant
     * alarm, which can land a few minutes late rather than not at all. The
     * permission can also be revoked between the check and the call, so a
     * SecurityException falls back instead of losing the window.
     */
    private fun arm(context: Context, triggerAt: Long, pi: PendingIntent) {
        val am = context.getSystemService(AlarmManager::class.java)
        if (canScheduleExact(context)) {
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                return
            } catch (_: SecurityException) {
                // fall through to the inexact alarm
            }
        }
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
    }

    fun scheduleStart(context: Context, entry: DndEntry) {
        val intent = Intent(context, DndReceiver::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_PRAYER_NAME, entry.prayerName)
            putExtra(EXTRA_START_MILLIS, entry.startMillis)
            putExtra(EXTRA_END_MILLIS, entry.endMillis)
        }
        arm(context, entry.startMillis, PendingIntent.getBroadcast(context, entry.requestCode, intent, FLAGS))
    }

    fun scheduleEnd(context: Context, endMillis: Long) {
        val intent = Intent(context, DndReceiver::class.java).apply { action = ACTION_END }
        arm(context, endMillis, PendingIntent.getBroadcast(context, DndStore.END_REQUEST_CODE, intent, FLAGS))
    }

    fun cancelEnd(context: Context) {
        cancel(context, DndStore.END_REQUEST_CODE, ACTION_END)
    }

    fun cancelAllStarts(context: Context, entries: List<DndEntry>) {
        entries.forEach { cancel(context, it.requestCode, ACTION_START) }
    }

    private fun cancel(context: Context, requestCode: Int, action: String) {
        val intent = Intent(context, DndReceiver::class.java).apply { this.action = action }
        val pi = PendingIntent.getBroadcast(context, requestCode, intent, FLAGS)
        context.getSystemService(AlarmManager::class.java).cancel(pi)
        pi.cancel()
    }

    /**
     * Re-creates every alarm that should still exist, from the native cache
     * alone. Used after boot/app update (which wipe alarms) and by the periodic
     * backstop worker. Also catches up on a window that should have started
     * while the phone was off or the alarm was missed.
     */
    fun rearm(context: Context) {
        val store = DndStore(context)
        val now = System.currentTimeMillis()

        if (store.ownsDnd) {
            if (store.activeEndMillis > now) scheduleEnd(context, store.activeEndMillis)
            else DndController.endIfDue(context, force = true)
        }

        store.loadSchedule().forEach { entry ->
            when {
                entry.startMillis > now -> scheduleStart(context, entry)
                entry.endMillis > now && entry.startMillis > store.lastStartedMillis ->
                    DndController.start(context, entry)
            }
        }
    }
}
