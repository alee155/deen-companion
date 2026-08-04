package com.devsouq.deen_companion.app.alarm

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Wires the Dart/native boundary for prayer alarms: one MethodChannel for Dart-initiated calls, one
 * EventChannel for the foreground "alarm fired" notification. Registered from
 * MainActivity.configureFlutterEngine.
 */
object AlarmMethodChannelHandler {
    private const val METHOD_CHANNEL = "com.devsouq.deen_companion.app/prayer_alarms"
    private const val EVENT_CHANNEL = "com.devsouq.deen_companion.app/prayer_alarm_events"
    const val RINGTONE_PICKER_REQUEST_CODE = 9821

    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null

    fun configure(flutterEngine: FlutterEngine, activity: Activity) {
        this.activity = activity

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
                .setMethodCallHandler { call, result -> handleMethod(call, result) }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
                .setStreamHandler(
                        object : EventChannel.StreamHandler {
                            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                                eventSink = sink
                            }

                            override fun onCancel(arguments: Any?) {
                                eventSink = null
                            }
                        },
                )
    }

    fun detach() {
        activity = null
    }

    /** Returns true if an alarm-fired event was actually delivered to Dart. */
    fun emitAlarmFired(
            prayerName: String,
            reminderType: String,
            epochMillis: Long,
            label: String
    ): Boolean {
        val sink = eventSink ?: return false
        return try {
            sink.success(
                    mapOf(
                            "type" to "alarmFired",
                            "prayerName" to prayerName,
                            "reminderType" to reminderType,
                            "scheduledEpochMillis" to epochMillis,
                            "label" to label,
                    ),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != RINGTONE_PICKER_REQUEST_CODE) return false
        val result = pendingRingtoneResult
        pendingRingtoneResult = null

        @Suppress("DEPRECATION")
        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        val act = activity
        if (uri == null || act == null) {
            result?.success(null)
            return true
        }

        val displayName =
                try {
                    RingtoneManager.getRingtone(act, uri)?.getTitle(act)
                } catch (e: Exception) {
                    null
                } ?: "Custom"

        try {
            act.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (e: Exception) {
            // Not all URIs support persistable permissions — harmless if it fails.
        }

        AlarmScheduleStore(act).ringtoneUri = uri.toString()
        result?.success(mapOf("uri" to uri.toString(), "displayName" to displayName))
        return true
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        val context =
                activity
                        ?: run {
                            result.error("NO_ACTIVITY", "Activity not attached", null)
                            return
                        }

        when (call.method) {
            "pushSchedule" -> pushSchedule(context, call, result)
            "cancelAllAlarms" -> {
                val store = AlarmScheduleStore(context)
                AlarmScheduler.cancelAll(context, store.loadSchedule())
                store.saveSchedule(emptyList())
                result.success(null)
            }
            "setRingtone" -> {
                AlarmScheduleStore(context).ringtoneUri = call.arguments as String?
                result.success(null)
            }
            "pickCustomRingtone" -> {
                pendingRingtoneResult = result
                launchRingtonePicker(context, call.arguments as String?)
            }
            "checkFullScreenIntentPermission" -> result.success(canUseFullScreenIntent(context))
            "openFullScreenIntentSettings" -> {
                openFullScreenIntentSettings(context)
                result.success(null)
            }
            "checkIgnoreBatteryOptimizations" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(context.packageName))
            }
            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations(context)
                result.success(null)
            }
            "requestNotificationPermission" -> {
                // The actual runtime prompt is driven by permission_handler
                // on the Dart side; this just exposes the current status.
                result.success(NotificationManagerCompat.from(context).areNotificationsEnabled())
            }
            "snoozeFromBanner" -> {
                handleBannerAction(context, call, isSnooze = true)
                result.success(null)
            }
            "dismissFromBanner" -> {
                // Nothing was ever armed as "current" natively when the app
                // was foregrounded — the alarm simply won't ring again
                // until its next regularly scheduled occurrence.
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pushSchedule(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val args =
                call.arguments as? Map<*, *>
                        ?: run {
                            result.error("BAD_ARGS", "Expected a map", null)
                            return
                        }
        val entriesRaw = args["entries"] as? List<*> ?: emptyList<Any>()
        val snoozeMinutes =
                (args["snoozeMinutes"] as? Number)?.toInt()
                        ?: AlarmScheduleStore.DEFAULT_SNOOZE_MINUTES

        val store = AlarmScheduleStore(context)
        // Cancel everything currently armed before scheduling the fresh set
        // — pushSchedule is always a full cancel-and-replace.
        AlarmScheduler.cancelAll(context, store.loadSchedule())

        val newEntries =
                entriesRaw.mapIndexedNotNull { index, raw ->
                    val map = raw as? Map<*, *> ?: return@mapIndexedNotNull null
                    val prayerName = map["prayerName"] as? String ?: return@mapIndexedNotNull null
                    val epochMillis =
                            (map["epochMillis"] as? Number)?.toLong()
                                    ?: return@mapIndexedNotNull null
                    AlarmEntry(
                            prayerName = prayerName,
                            reminderType = map["reminderType"] as? String ?: "atTime",
                            epochMillis = epochMillis,
                            label = map["label"] as? String ?: prayerName,
                            requestCode = AlarmScheduleStore.REGULAR_REQUEST_CODE_BASE + index,
                    )
                }

        newEntries.forEach { entry -> AlarmScheduler.scheduleAlarm(context, entry) }
        store.saveSchedule(newEntries)
        store.snoozeMinutes = snoozeMinutes

        result.success(newEntries.size)
    }

    private fun handleBannerAction(context: Context, call: MethodCall, isSnooze: Boolean) {
        if (!isSnooze) return
        val args = call.arguments as? Map<*, *> ?: return
        val prayerName = args["prayerName"] as? String ?: return
        val reminderType = args["reminderType"] as? String ?: "atTime"
        val label = args["label"] as? String ?: prayerName
        val epochMillis = (args["epochMillis"] as? Number)?.toLong() ?: System.currentTimeMillis()

        AlarmScheduler.scheduleSnooze(context, prayerName, reminderType, label, epochMillis)
    }

    private fun launchRingtonePicker(activity: Activity, currentUri: String?) {
        val intent =
                Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                    putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    if (currentUri != null) {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUri))
                    }
                }
        activity.startActivityForResult(intent, RINGTONE_PICKER_REQUEST_CODE)
    }

    private fun canUseFullScreenIntent(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.canUseFullScreenIntent()
        } else {
            true
        }
    }

    private fun openFullScreenIntentSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val intent =
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                        data = Uri.parse("package:${context.packageName}")
                    }
            context.startActivity(intent)
        }
    }

    private fun requestIgnoreBatteryOptimizations(context: Context) {
        val intent =
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                }
        context.startActivity(intent)
    }
}
