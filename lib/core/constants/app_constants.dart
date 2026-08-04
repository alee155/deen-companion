class AppConstants {
  AppConstants._();

  static const String appName = 'Deen';
  static const String appVersion =
      '1.0.0'; // keep in sync with pubspec.yaml's version — swap for package_info_plus if you want this to read automatically

  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration splashMinDuration = Duration(milliseconds: 800);

  static const int networkTimeoutSeconds = 15;
  static const String onboardingCompletedKey = 'onboarding_completed';

  /// Set once the startup permission screen has been shown, so it isn't
  /// re-presented on every launch — features prompt in place after that.
  static const String permissionFlowSeenKey = 'permission_flow_seen';

  static const String themeModeKey = 'theme_mode';
  static const String remindersEnabledKey = 'prayer_reminders_enabled';
  static const String bookmarksBoxName = 'bookmarks_box';
  static const String recentActivityBoxName = 'recent_activity_box';
  static const String settingsBoxName = 'settings_box';
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
