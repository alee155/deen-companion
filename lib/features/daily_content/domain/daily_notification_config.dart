/// Everything about *when* and *how much* the daily notification schedules.
/// The one place to change timing — nothing else hardcodes it.
class DailyNotificationConfig {
  /// Delay after Fajr at which the notification fires.
  final Duration offsetAfterFajr;

  /// How many days ahead to arm. The native side survives reboots on its own
  /// and the window is refreshed on every app open, so this only bounds how
  /// long the notification keeps coming if the app is never opened.
  final int windowDays;

  final String title;

  const DailyNotificationConfig({
    required this.offsetAfterFajr,
    required this.windowDays,
    required this.title,
  });

  static const production = DailyNotificationConfig(
    offsetAfterFajr: Duration(minutes: 20),
    windowDays: 7,
    title: 'Ayat & Hadith of the Day',
  );
}
