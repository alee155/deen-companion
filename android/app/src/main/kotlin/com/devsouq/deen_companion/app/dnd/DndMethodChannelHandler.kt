package com.devsouq.deen_companion.app.dnd

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Dart/native boundary for the prayer DND feature. */
object DndMethodChannelHandler {
    private const val CHANNEL = "com.devsouq.deen_companion.app/prayer_dnd"

    fun configure(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(context, call, result) }
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushSchedule" -> pushSchedule(context, call, result)
            "cancelAll" -> {
                cancelAll(context)
                result.success(null)
            }
            "hasPolicyAccess" -> result.success(DndController.hasPolicyAccess(context))
            "openPolicyAccessSettings" -> {
                context.startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }
            "canScheduleExactAlarms" -> result.success(DndScheduler.canScheduleExact(context))
            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.startActivity(
                        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            .setData(Uri.parse("package:${context.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun cancelAll(context: Context) {
        val store = DndStore(context)
        DndScheduler.cancelAllStarts(context, store.loadSchedule())
        store.saveSchedule(emptyList())
        // Turning the feature off while we're holding DND on must hand the phone back.
        DndController.endIfDue(context, force = true)
    }

    private fun pushSchedule(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val raw = (call.arguments as? Map<*, *>)?.get("entries") as? List<*> ?: emptyList<Any>()
        val store = DndStore(context)
        DndScheduler.cancelAllStarts(context, store.loadSchedule())

        val now = System.currentTimeMillis()
        val entries = raw.mapNotNull { item ->
            val m = item as? Map<*, *> ?: return@mapNotNull null
            val name = m["prayerName"] as? String ?: return@mapNotNull null
            val start = (m["startMillis"] as? Number)?.toLong() ?: return@mapNotNull null
            val end = (m["endMillis"] as? Number)?.toLong() ?: return@mapNotNull null
            if (start <= now || end <= start) return@mapNotNull null
            name to (start to end)
        }.mapIndexed { i, (name, span) ->
            DndEntry(name, span.first, span.second, DndStore.START_REQUEST_CODE_BASE + i)
        }

        entries.forEach { DndScheduler.scheduleStart(context, it) }
        store.saveSchedule(entries)
        result.success(entries.size)
    }
}
