package com.devsouq.deen_companion.app.alarm

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Periodic insurance backstop (~12h): re-arms whatever remains valid in the
 * native-side cache. Does NOT touch the network or spin up Flutter — its
 * only job is to catch any missed opportunistic reschedule (app open,
 * settings change, boot), not to fetch fresh prayer times itself.
 */
class AlarmSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val store = AlarmScheduleStore(applicationContext)
        val now = System.currentTimeMillis()
        store.loadSchedule()
            .filter { it.epochMillis > now }
            .forEach { entry -> AlarmScheduler.scheduleAlarm(applicationContext, entry) }
        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "prayer_alarm_sync_backstop"

        fun schedulePeriodic(context: Context) {
            val request = PeriodicWorkRequestBuilder<AlarmSyncWorker>(12, TimeUnit.HOURS).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }
    }
}
