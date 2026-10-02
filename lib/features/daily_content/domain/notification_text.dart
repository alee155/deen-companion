import 'entities/daily_content.dart';

/// Wording of the notification body / history preview, in one place so the
/// system tray and the in-app list always read the same.
class DailyNotificationText {
  DailyNotificationText._();

  static const String fallback = "Today's verse and hadith are ready to read.";

  static String preview(DailyContent? content) {
    if (content == null) return fallback;
    final verse = _clip(content.ayah.translation, 90);
    final hadith = content.hadith;
    return '“$verse” — ${content.ayah.verseKey}\n'
        'Hadith: ${hadith.collectionName}, #${hadith.hadithNumber}';
  }

  static String _clip(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trimRight()}…';
  }
}
