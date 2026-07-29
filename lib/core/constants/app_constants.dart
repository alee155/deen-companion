class AppConstants {
  AppConstants._();

  static const String appName = 'Deen';
  static const String appVersion =
      '1.0.0'; // keep in sync with pubspec.yaml's version — swap for package_info_plus if you want this to read automatically

  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration splashMinDuration = Duration(milliseconds: 800);

  static const int networkTimeoutSeconds = 15;
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String bookmarksBoxName = 'bookmarks_box';
  static const String recentActivityBoxName = 'recent_activity_box';
  static const String settingsBoxName = 'settings_box';
  static const String apiCacheBoxName =
      'api_cache_box'; // new — generic response cache
}
