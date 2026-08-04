package com.devsouq.deen_companion.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.devsouq.deen_companion.app.alarm.AlarmSyncWorker
import com.devsouq.deen_companion.app.alarm.AppForegroundTracker

class DeenCompanionApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Whole-process foreground tracking, independent of any specific
        // Activity or whether the Flutter engine has attached — read
        // synchronously by AlarmReceiver at the moment an alarm fires.
        ProcessLifecycleOwner.get().lifecycle.addObserver(
            object : DefaultLifecycleObserver {
                override fun onStart(owner: LifecycleOwner) {
                    AppForegroundTracker.isForeground = true
                }

                override fun onStop(owner: LifecycleOwner) {
                    AppForegroundTracker.isForeground = false
                }
            },
        )

        createNotificationChannel()

        // Periodic re-arm-from-cache safety net; a no-op if already
        // scheduled (KEEP policy), so this is safe to call on every launch.
        AlarmSyncWorker.schedulePeriodic(this)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ALARM_CHANNEL_ID,
                "Prayer Alarms",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Full-screen alarm reminders for prayer times"
                setBypassDnd(true)
                enableVibration(true)
                // Silent at the channel level — PrayerAlarmService plays the
                // looping ringtone itself via MediaPlayer on the alarm
                // stream, so a channel sound would otherwise double up.
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val ALARM_CHANNEL_ID = "prayer_alarm_channel"
    }
}
