package com.devsouq.deen_companion.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by AlarmManager at the scheduled instant. This is the crux of the
 * whole feature: it must work with zero live Dart isolate, so the
 * foreground/background branch below is the only place Flutter is ever
 * consulted, and only opportunistically.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER_NAME) ?: return
        val reminderType = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_TYPE) ?: "atTime"
        val epochMillis = intent.getLongExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, System.currentTimeMillis())
        val label = intent.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: prayerName
        val isSnooze = intent.getBooleanExtra(AlarmScheduler.EXTRA_IS_SNOOZE, false)

        if (AppForegroundTracker.isForeground) {
            val delivered = AlarmMethodChannelHandler.emitAlarmFired(prayerName, reminderType, epochMillis, label)
            if (delivered) return
            // No live event sink (stale flag or engine not attached yet) —
            // fall through to the native path so the alarm is never
            // silently dropped.
        }

        val serviceIntent = Intent(context, PrayerAlarmService::class.java).apply {
            putExtra(AlarmScheduler.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AlarmScheduler.EXTRA_REMINDER_TYPE, reminderType)
            putExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, epochMillis)
            putExtra(AlarmScheduler.EXTRA_LABEL, label)
            putExtra(AlarmScheduler.EXTRA_IS_SNOOZE, isSnooze)
        }
        context.startForegroundService(serviceIntent)
    }
}
