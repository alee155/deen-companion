package com.devsouq.deen_companion.app.dnd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires at a window's start and end; works with no Flutter engine running. */
class DndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            DndScheduler.ACTION_START -> {
                val end = intent.getLongExtra(DndScheduler.EXTRA_END_MILLIS, 0L)
                // A start alarm that's delivered after its window has fully passed
                // (phone off, heavy Doze) must not switch DND on with nothing to end it.
                if (end <= System.currentTimeMillis()) return
                DndController.start(
                    context,
                    DndEntry(
                        prayerName = intent.getStringExtra(DndScheduler.EXTRA_PRAYER_NAME) ?: return,
                        startMillis = intent.getLongExtra(DndScheduler.EXTRA_START_MILLIS, 0L),
                        endMillis = end,
                        requestCode = 0,
                    ),
                )
            }
            DndScheduler.ACTION_END -> DndController.endIfDue(context)
        }
    }
}
