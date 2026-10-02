package com.devsouq.deen_companion.app.dnd

import android.app.NotificationManager
import android.content.Context

/**
 * The only place that touches the system interruption filter.
 *
 * Uses "alarms only": calls, messages and notifications are silenced, but
 * alarms still ring — so the user's wake-up alarm and Deen's own prayer
 * alarm are never swallowed by this feature.
 */
object DndController {
    private fun manager(context: Context) =
        context.getSystemService(NotificationManager::class.java)

    fun hasPolicyAccess(context: Context): Boolean =
        manager(context).isNotificationPolicyAccessGranted

    /** Applies a scheduled window. Returns true if DND is now on because of us. */
    fun start(context: Context, entry: DndEntry): Boolean {
        val store = DndStore(context)
        val nm = manager(context)
        if (!nm.isNotificationPolicyAccessGranted) return false

        // Mark as handled even if we end up doing nothing, so catch-up
        // (boot / worker) doesn't retry a window that's been dealt with.
        store.lastStartedMillis = maxOf(store.lastStartedMillis, entry.startMillis)

        // Our flag is only trustworthy while the phone is still in the mode we set;
        // if the user switched DND off themselves, start over.
        if (store.ownsDnd && nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALARMS) {
            store.ownsDnd = false
            store.activeEndMillis = 0L
        }

        if (store.ownsDnd) {
            // Back-to-back window: just push the end out.
            store.activeEndMillis = maxOf(store.activeEndMillis, entry.endMillis)
        } else {
            val current = nm.currentInterruptionFilter
            if (current != NotificationManager.INTERRUPTION_FILTER_ALL &&
                current != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
            ) {
                // The user already has their own DND/silent mode on — leave it alone.
                return false
            }
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
            store.ownsDnd = true
            store.activeEndMillis = entry.endMillis
        }
        DndScheduler.scheduleEnd(context, store.activeEndMillis)
        return true
    }

    /**
     * Called when the end alarm fires (or on re-arm/cancel). Turns DND back off only
     * if we turned it on, nothing has extended the window, and the user hasn't
     * already changed the mode themselves.
     */
    fun endIfDue(context: Context, force: Boolean = false) {
        val store = DndStore(context)
        if (!store.ownsDnd) return
        val now = System.currentTimeMillis()

        if (!force) {
            // Extended by a later window — that window's own end alarm will handle it.
            if (store.activeEndMillis > now + TOLERANCE_MS) return
            // A window is about to start right now (until-next-prayer chains
            // windows end-to-start); let it take over instead of flickering off.
            val startsImminently = store.loadSchedule().any {
                it.startMillis in (now - TOLERANCE_MS)..(now + CHAIN_WINDOW_MS)
            }
            if (startsImminently) return
        }

        val nm = manager(context)
        if (nm.isNotificationPolicyAccessGranted &&
            nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALARMS
        ) {
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }
        store.ownsDnd = false
        store.activeEndMillis = 0L
        DndScheduler.cancelEnd(context)
    }

    private const val TOLERANCE_MS = 2_000L
    private const val CHAIN_WINDOW_MS = 60_000L
}
