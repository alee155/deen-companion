package com.devsouq.deen_companion.app.alarm

/**
 * Whole-process foreground state, kept in sync by a [androidx.lifecycle.ProcessLifecycleOwner]
 * observer registered in `DeenCompanionApplication`. Read synchronously from
 * [AlarmReceiver] at the moment an alarm fires — independent of any specific
 * Activity or whether the Flutter engine has attached yet.
 */
object AppForegroundTracker {
    @Volatile
    var isForeground: Boolean = false
}
