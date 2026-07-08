class AppConstants {
  AppConstants._();

  static const String appName = 'Deen';

  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration splashMinDuration = Duration(milliseconds: 800);

  static const int networkTimeoutSeconds = 15;

  static const String bookmarksBoxName = 'bookmarks_box';
  static const String settingsBoxName = 'settings_box';
  static const String apiCacheBoxName =
      'api_cache_box'; // new — generic response cache
}
