package com.devsouq.deen_companion.app.dnd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms the DND schedule from the native cache, with no Flutter engine.
 *
 * Alarms are wiped on reboot and app update; they are also invalidated when
 * the exact-alarm permission changes, and a clock/timezone change makes the
 * cached wall-clock times stale, so those re-arm too.
 */
class DndBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            ACTION_EXACT_ALARM_PERMISSION_CHANGED -> DndScheduler.rearm(context)
        }
    }

    private companion object {
        const val ACTION_EXACT_ALARM_PERMISSION_CHANGED =
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
    }
}
