package com.devsouq.deen_companion.app.alarm

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.view.View
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
    private var snoozeEnabled: Boolean = true
    private var snoozeMinutes: Int = AlarmScheduleStore.DEFAULT_SNOOZE_MINUTES

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
        playEntrance()
    }

    private val loops = mutableListOf<android.animation.Animator>()

    /**
     * Entrance (logo pops in, text rises) followed by ambient motion that
     * keeps running while the alarm rings: two geometric rings turning in
     * opposite directions, sonar ripples leaving the logo, and a gentle
     * pulse on Dismiss so it reads as the thing to press. All of it is
     * skipped when the system "remove animations" setting is on.
     */
    private fun playEntrance() {
        loadArabicFont()
        val animate = animationsEnabled()

        val logo = findViewById<View>(R.id.alarmLogo)
        if (animate) {
            logo.scaleX = 0.6f
            logo.scaleY = 0.6f
            logo.alpha = 0f
            logo.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(480)
                .setInterpolator(android.view.animation.OvershootInterpolator(1.4f)).start()

            listOf(R.id.alarmSubtitle, R.id.alarmPrayerName, R.id.alarmTime, R.id.alarmMessage)
                .forEachIndexed { i, id ->
                    val v = findViewById<View>(id)
                    v.alpha = 0f
                    v.translationY = 28f
                    v.animate().alpha(1f).translationY(0f).setStartDelay(140L + 70L * i).setDuration(400)
                        .setInterpolator(android.view.animation.DecelerateInterpolator()).start()
                }
        }
        if (!animate) return

        // Counter-rotating rings.
        spin(findViewById(R.id.alarmStarA), 0f, 360f, 48_000)
        spin(findViewById(R.id.alarmStarB), 0f, -360f, 70_000)

        // Sonar ripples: three rings, staggered, expanding and fading.
        listOf(R.id.alarmRipple1, R.id.alarmRipple2, R.id.alarmRipple3).forEachIndexed { i, id ->
            val ring = findViewById<View>(id)
            ring.alpha = 0f
            val set = android.animation.AnimatorSet().apply {
                playTogether(
                    loop(ring, View.SCALE_X, 1f, 2.7f, 3200, i * 1050L),
                    loop(ring, View.SCALE_Y, 1f, 2.7f, 3200, i * 1050L),
                    loop(ring, View.ALPHA, 0.55f, 0f, 3200, i * 1050L),
                )
            }
            set.start()
            loops.add(set)
        }

        // Dismiss: a soft heartbeat.
        val dismiss = findViewById<View>(R.id.alarmDismissButton)
        val pulse = android.animation.ObjectAnimator.ofPropertyValuesHolder(
            dismiss,
            android.animation.PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.035f),
            android.animation.PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.035f),
        ).apply {
            duration = 900
            repeatCount = android.animation.ValueAnimator.INFINITE
            repeatMode = android.animation.ValueAnimator.REVERSE
            interpolator = android.view.animation.AccelerateDecelerateInterpolator()
            startDelay = 900
        }
        pulse.start()
        loops.add(pulse)
    }

    private fun spin(view: View, from: Float, to: Float, durationMs: Long) {
        val a = android.animation.ObjectAnimator.ofFloat(view, View.ROTATION, from, to).apply {
            duration = durationMs
            repeatCount = android.animation.ValueAnimator.INFINITE
            interpolator = android.view.animation.LinearInterpolator()
        }
        a.start()
        loops.add(a)
    }

    private fun loop(
        view: View,
        property: android.util.Property<View, Float>,
        from: Float,
        to: Float,
        durationMs: Long,
        delayMs: Long,
    ) = android.animation.ObjectAnimator.ofFloat(view, property, from, to).apply {
        duration = durationMs
        startDelay = delayMs
        repeatCount = android.animation.ValueAnimator.INFINITE
        interpolator = android.view.animation.DecelerateInterpolator(1.2f)
    }

    private fun animationsEnabled(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.animation.ValueAnimator.areAnimatorsEnabled()
        } else {
            true
        }

    /** The Quran's own typeface, shipped with the Flutter assets. */
    private fun loadArabicFont() {
        try {
            val face = android.graphics.Typeface.createFromAsset(
                assets, "flutter_assets/assets/fonts/AmiriQuran-Regular.ttf",
            )
            findViewById<TextView>(R.id.alarmArabic).typeface = face
        } catch (e: Exception) {
            // Falls back to the system Arabic font.
        }
    }

    override fun onDestroy() {
        loops.forEach { it.cancel() }
        loops.clear()
        super.onDestroy()
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
        snoozeEnabled = intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, true)
        snoozeMinutes = intent.getIntExtra(
            AlarmScheduler.EXTRA_SNOOZE_MINUTES,
            AlarmScheduleStore.DEFAULT_SNOOZE_MINUTES,
        )
    }

    private fun bindViews() {
        findViewById<TextView>(R.id.alarmPrayerName).text = displayName(prayerName)
        findViewById<TextView>(R.id.alarmTime).text = DateFormat.format("h:mm a", Date(epochMillis))
        findViewById<TextView>(R.id.alarmSubtitle).text = when {
            isSnooze -> "Snoozed reminder"
            reminderType == "before" -> "Coming up"
            else -> "Time to pray"
        }

        val snoozeButton = findViewById<Button>(R.id.alarmSnoozeButton)
        // Snooze is a per-prayer preference: hidden when switched off.
        snoozeButton.visibility = if (snoozeEnabled) View.VISIBLE else View.GONE
        snoozeButton.text = "Snooze $snoozeMinutes min"
        snoozeButton.setOnClickListener {
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
            putExtra(AlarmScheduler.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
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
