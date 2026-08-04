package com.devsouq.deen_companion.app.alarm

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.devsouq.deen_companion.app.R
import java.util.Date

/**
 * Full-screen ring UI shown over the lock screen when a prayer alarm fires
 * while the app is backgrounded or killed. Deliberately plain native
 * Views/XML, not Flutter — this has to draw on the very first frame with no
 * VM warm-up, at exactly the moment the device may have just woken up.
 */
class AlarmActivity : Activity() {
    private var prayerName: String = "Prayer"
    private var reminderType: String = "atTime"
    private var epochMillis: Long = System.currentTimeMillis()
    private var label: String = ""
    private var isSnooze: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }

        setContentView(R.layout.activity_alarm)
        readExtras(intent)
        bindViews()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readExtras(intent)
        bindViews()
    }

    private fun readExtras(intent: Intent) {
        prayerName = intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER_NAME) ?: "Prayer"
        reminderType = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_TYPE) ?: "atTime"
        epochMillis = intent.getLongExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, System.currentTimeMillis())
        label = intent.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: prayerName
        isSnooze = intent.getBooleanExtra(AlarmScheduler.EXTRA_IS_SNOOZE, false)
    }

    private fun bindViews() {
        findViewById<TextView>(R.id.alarmPrayerName).text = displayName(prayerName)
        findViewById<TextView>(R.id.alarmTime).text = DateFormat.format("h:mm a", Date(epochMillis))
        findViewById<TextView>(R.id.alarmMessage).text = getString(R.string.alarm_motivational_message)
        findViewById<TextView>(R.id.alarmSubtitle).text = when {
            isSnooze -> "Snoozed reminder"
            reminderType == "before" -> "Coming up"
            else -> "Time to pray"
        }

        findViewById<Button>(R.id.alarmSnoozeButton).setOnClickListener {
            sendServiceAction(PrayerAlarmService.ACTION_SNOOZE)
            finish()
        }
        findViewById<Button>(R.id.alarmDismissButton).setOnClickListener {
            sendServiceAction(PrayerAlarmService.ACTION_DISMISS)
            finish()
        }
    }

    private fun sendServiceAction(action: String) {
        val intent = Intent(this, PrayerAlarmService::class.java).apply {
            this.action = action
            putExtra(AlarmScheduler.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AlarmScheduler.EXTRA_REMINDER_TYPE, reminderType)
            putExtra(AlarmScheduler.EXTRA_EPOCH_MILLIS, epochMillis)
            putExtra(AlarmScheduler.EXTRA_LABEL, label)
        }
        startService(intent)
    }

    private fun displayName(prayer: String): String = when (prayer.lowercase()) {
        "fajr" -> "Fajr"
        "dhuhr" -> "Dhuhr"
        "asr" -> "Asr"
        "maghrib" -> "Maghrib"
        "isha" -> "Isha"
        else -> prayer
    }

    // Must be dismissed/snoozed explicitly, matching real alarm-clock
    // behavior — the back gesture/button does nothing here.
    @Suppress("MissingSuperCall", "DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {}
}
