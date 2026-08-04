package com.devsouq.deen_companion.app.alarm

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.devsouq.deen_companion.app.DeenCompanionApplication

/**
 * Runs while a prayer alarm is ringing in the background/killed case: holds
 * a wake lock, loops the ringtone, and posts the full-screen-intent
 * notification that the OS uses to launch [AlarmActivity] over the lock
 * screen. Also handles Snooze/Dismiss actions tapped from that notification
 * or from the Activity itself — both are pure native Intent calls, no
 * Dart/MethodChannel involved.
 */
class PrayerAlarmService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISMISS -> {
                teardown()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                val prayerName = intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER_NAME)
                val reminderType = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_TYPE) ?: "atTime"
                val label = intent.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: prayerName ?: "Prayer"
                val epochMillis = intent.getLongExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, System.currentTimeMillis())
                teardown()
                if (prayerName != null) {
                    AlarmScheduler.scheduleSnooze(this, prayerName, reminderType, label, epochMillis)
                }
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val prayerName = intent?.getStringExtra(AlarmScheduler.EXTRA_PRAYER_NAME) ?: "Prayer"
        val reminderType = intent?.getStringExtra(AlarmScheduler.EXTRA_REMINDER_TYPE) ?: "atTime"
        val epochMillis = intent?.getLongExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, System.currentTimeMillis())
            ?: System.currentTimeMillis()
        val label = intent?.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: prayerName
        val isSnooze = intent?.getBooleanExtra(AlarmScheduler.EXTRA_IS_SNOOZE, false) ?: false

        acquireWakeLock()
        startForeground(NOTIFICATION_ID, buildNotification(prayerName, reminderType, epochMillis, label, isSnooze))
        playRingtone()

        return START_STICKY
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "deen_companion:prayer_alarm",
        ).apply {
            setReferenceCounted(false)
            acquire(10 * 60 * 1000L) // 10-minute safety cap in case teardown is ever missed
        }
    }

    private fun playRingtone() {
        val store = AlarmScheduleStore(this)
        val customUri = store.ringtoneUri

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            isLooping = true
        }

        val uriToPlay: Uri = try {
            if (customUri != null) {
                Uri.parse(customUri)
            } else {
                RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getValidRingtoneUri(this)
            }
        } catch (e: Exception) {
            RingtoneManager.getValidRingtoneUri(this)
        }

        try {
            mediaPlayer?.setDataSource(this, uriToPlay)
            mediaPlayer?.prepare()
            mediaPlayer?.start()
        } catch (e: Exception) {
            // Custom ringtone failed (revoked permission, source app
            // uninstalled) — fall back to the system default rather than
            // ringing silently.
            try {
                mediaPlayer?.reset()
                mediaPlayer?.setDataSource(this, RingtoneManager.getValidRingtoneUri(this))
                mediaPlayer?.prepare()
                mediaPlayer?.start()
            } catch (e2: Exception) {
                // Truly nothing left to fall back to — give up silently
                // rather than crash the service.
            }
        }
    }

    private fun buildNotification(
        prayerName: String,
        reminderType: String,
        epochMillis: Long,
        label: String,
        isSnooze: Boolean,
    ): Notification {
        val fullScreenIntent = Intent(this, AlarmActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION,
            )
            putExtra(AlarmScheduler.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AlarmScheduler.EXTRA_REMINDER_TYPE, reminderType)
            putExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, epochMillis)
            putExtra(AlarmScheduler.EXTRA_LABEL, label)
            putExtra(AlarmScheduler.EXTRA_IS_SNOOZE, isSnooze)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val dismissIntent = Intent(this, PrayerAlarmService::class.java).apply { action = ACTION_DISMISS }
        val dismissPendingIntent = PendingIntent.getService(
            this,
            1,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val snoozeIntent = Intent(this, PrayerAlarmService::class.java).apply {
            action = ACTION_SNOOZE
            putExtra(AlarmScheduler.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AlarmScheduler.EXTRA_REMINDER_TYPE, reminderType)
            putExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, epochMillis)
            putExtra(AlarmScheduler.EXTRA_LABEL, label)
        }
        val snoozePendingIntent = PendingIntent.getService(
            this,
            2,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, DeenCompanionApplication.ALARM_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (isSnooze) "Snoozed reminder" else "Prayer reminder")
            .setContentText(label)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(0, "Snooze", snoozePendingIntent)
            .addAction(0, "Dismiss", dismissPendingIntent)
            .setAutoCancel(false)
            .build()
    }

    private fun teardown() {
        mediaPlayer?.let { player ->
            try {
                if (player.isPlaying) player.stop()
            } catch (e: Exception) {
                // already stopped/released — nothing to do
            }
            player.release()
        }
        mediaPlayer = null

        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null

        getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    companion object {
        const val ACTION_DISMISS = "com.devsouq.deen_companion.app.alarm.ACTION_DISMISS"
        const val ACTION_SNOOZE = "com.devsouq.deen_companion.app.alarm.ACTION_SNOOZE"
        const val NOTIFICATION_ID = 4201
    }
}
