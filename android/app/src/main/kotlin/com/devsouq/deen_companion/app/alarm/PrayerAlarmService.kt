package com.devsouq.deen_companion.app.alarm

import android.app.Notification
import android.app.NotificationManager
import com.devsouq.deen_companion.app.R
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
import java.io.File
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
                val snoozeMinutes = intent.getIntExtra(
                    AlarmScheduler.EXTRA_SNOOZE_MINUTES,
                    AlarmScheduleStore.DEFAULT_SNOOZE_MINUTES,
                )
                teardown()
                if (prayerName != null) {
                    AlarmScheduler.scheduleSnooze(this, prayerName, reminderType, label, epochMillis, snoozeMinutes)
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
        val snoozeEnabled = intent?.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, true) ?: true
        val snoozeMinutes = intent?.getIntExtra(
            AlarmScheduler.EXTRA_SNOOZE_MINUTES,
            AlarmScheduleStore.DEFAULT_SNOOZE_MINUTES,
        ) ?: AlarmScheduleStore.DEFAULT_SNOOZE_MINUTES

        acquireWakeLock()
        startForeground(
            NOTIFICATION_ID,
            buildNotification(prayerName, reminderType, epochMillis, label, isSnooze, snoozeEnabled, snoozeMinutes),
        )
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

    /**
     * Every prayer alarm plays the bundled azan (a Flutter asset, so it ships
     * in the APK under flutter_assets/) rather than the device ringtone. It
     * is copied once to the cache dir so MediaPlayer can read it by path.
     * Only if that fails (asset missing / storage full) does it fall back to
     * the system alarm sound, so an alarm never rings silently.
     */
    private fun playRingtone() {
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            isLooping = true
        }

        val azan = azanFile()
        try {
            if (azan == null) throw IllegalStateException("azan asset unavailable")
            mediaPlayer?.setDataSource(azan.absolutePath)
            mediaPlayer?.prepare()
            mediaPlayer?.start()
            return
        } catch (e: Exception) {
            mediaPlayer?.reset()
        }

        try {
            val fallback: Uri = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getValidRingtoneUri(this)
            mediaPlayer?.setDataSource(this, fallback)
            mediaPlayer?.prepare()
            mediaPlayer?.start()
        } catch (e: Exception) {
            // Nothing left to fall back to — give up silently rather than
            // crash the service.
        }
    }

    private fun azanFile(): File? {
        val target = File(cacheDir, AZAN_CACHE_NAME)
        if (target.exists() && target.length() > 0) return target
        return try {
            assets.open(AZAN_ASSET_PATH).use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            target
        } catch (e: Exception) {
            target.delete()
            null
        }
    }

    private fun buildNotification(
        prayerName: String,
        reminderType: String,
        epochMillis: Long,
        label: String,
        isSnooze: Boolean,
        snoozeEnabled: Boolean,
        snoozeMinutes: Int,
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
            putExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, snoozeEnabled)
            putExtra(AlarmScheduler.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
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
            putExtra(AlarmScheduler.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
        }
        val snoozePendingIntent = PendingIntent.getService(
            this,
            2,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, DeenCompanionApplication.ALARM_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_logo)
            .setContentTitle(if (isSnooze) "Snoozed reminder" else "Prayer reminder")
            .setContentText(label)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(false)
        // Snooze is a per-prayer preference: no action when it's switched off.
        if (snoozeEnabled) builder.addAction(0, "Snooze ${snoozeMinutes} min", snoozePendingIntent)
        builder.addAction(0, "Dismiss", dismissPendingIntent)
        return builder.build()
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
        private const val AZAN_ASSET_PATH = "flutter_assets/assets/audio/azan_ringtone.mp3"
        private const val AZAN_CACHE_NAME = "azan_ringtone.mp3"
    }
}
