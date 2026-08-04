# Keep rules for the release build. Minification is currently disabled in
# build.gradle.kts, but these rules are kept accurate so enabling it later
# doesn't silently break the native prayer-alarm pipeline — every class here
# is only ever instantiated by the Android framework (manifest entries,
# WorkManager, PendingIntents), never from Kotlin/Dart code R8 can see.

-keep class com.devsouq.deen_companion.app.DeenCompanionApplication { *; }
-keep class com.devsouq.deen_companion.app.MainActivity { *; }
-keep class com.devsouq.deen_companion.app.alarm.** { *; }

# Flutter embedding + plugin registration happen reflectively.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# just_audio_background / audio_service run as a manifest-declared service.
-keep class com.ryanheise.audioservice.** { *; }

# WorkManager instantiates workers by class name.
-keep class * extends androidx.work.ListenableWorker { *; }
