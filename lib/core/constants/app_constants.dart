class AppConstants {
  AppConstants._();

  static const String appName = 'Deen';
  // App version used to be hardcoded here. It's now read at runtime from
  // the actual installed build via AppInfoService
  // (core/app_info/app_info_service.dart), which wraps package_info_plus —
  // so it can never drift out of sync with pubspec.yaml / the Android
  // versionName again. See appVersionNameProvider / appDisplayVersionProvider.

  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);

  static const int networkTimeoutSeconds = 15;

  /// Set once the user has passed the Welcome screen — either by logging
  /// in/signing up, or by choosing "Continue as guest". After this, Splash
  /// goes straight to Home instead of showing Welcome again. Permissions are
  /// no longer part of this gate — they're requested contextually in place,
  /// right where each feature needs them.
  static const String authGateSeenKey = 'auth_gate_seen';

  // Persisted signed-in identity (the auth backend is still a stub; these keep
  // the session across launches once it starts returning real sessions).
  /// Set once the App Open ad has been shown; it is never shown again.
  static const String appOpenAdShownKey = 'app_open_ad_shown';

  static const String authUserIdKey = 'auth_user_id';
  static const String authEmailKey = 'auth_email';
  static const String authNameKey = 'auth_name';
  static const String authPhotoUrlKey = 'auth_photo_url';

  static const String themeModeKey = 'theme_mode';
  static const String prayerReminderPrefsKey = 'prayer_reminder_prefs';
  static const String remindersEnabledKey = 'prayer_reminders_enabled';
  static const String dndEnabledKey = 'prayer_dnd_enabled';
  static const String dndDurationModeKey = 'prayer_dnd_duration_mode';
  static const String dndPresetMinutesKey = 'prayer_dnd_preset_minutes';
  static const String dndCustomMinutesKey = 'prayer_dnd_custom_minutes';
  static const String dndPrayersKey = 'prayer_dnd_prayers';
  static const String dndDurationsKey = 'prayer_dnd_durations';
  static const String bookmarksBoxName = 'bookmarks_box';
  static const String recentActivityBoxName = 'recent_activity_box';
  static const String settingsBoxName = 'settings_box';
  static const String dailyContentBoxName = 'daily_content_box';
  static const String dailyNotificationEnabledKey = 'daily_notification_enabled';
  static const String reliabilityPromptedAtKey = 'reliability_prompted_at';
  static const String apiCacheBoxName =
      'api_cache_box'; // new — generic response cache

  /// Hosted legal documents, opened in the device browser via url_launcher
  /// (Settings → Privacy Policy / Terms & Conditions). Keep these in sync
  /// with whatever is actually published at these URLs.
  static const String privacyPolicyUrl =
      'https://legal-sites.dgexpense.com/deen-app/privacy_policy.html';
  static const String termsAndConditionsUrl =
      'https://legal-sites.dgexpense.com/deen-app/terms_and_conditions.html';
}
