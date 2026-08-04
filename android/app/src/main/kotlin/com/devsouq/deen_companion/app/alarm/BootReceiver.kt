package com.devsouq.deen_companion.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * AlarmManager alarms are wiped on reboot and on app updates — this
 * re-arms everything still in the future from the native-side cache alone,
 * no Dart/network involved.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }

        val store = AlarmScheduleStore(context)
        val now = System.currentTimeMillis()
        store.loadSchedule()
            .filter { it.epochMillis > now }
            .forEach { entry -> AlarmScheduler.scheduleAlarm(context, entry) }
    }
}
