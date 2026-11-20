import '../../../shared/domain/translation_language.dart';
import 'entities/daily_content.dart';

/// Wording of the notification body / history preview, in one place so the
/// system tray and the in-app list always read the same.
class DailyNotificationText {
  DailyNotificationText._();

  static const String fallback = "Today's verse and hadith are ready to read.";

  static const String fallbackUrdu =
      'آج کی آیت اور حدیث پڑھنے کے لیے تیار ہیں۔';

  /// The books' names as Urdu readers know them, by collection key.
  static const Map<String, String> _urduCollectionNames = {
    'bukhari': 'صحیح بخاری',
    'muslim': 'صحیح مسلم',
    'abudawud': 'سنن ابی داؤد',
    'tirmidhi': 'جامع ترمذی',
    'ibnmajah': 'سنن ابن ماجہ',
    'nasai': 'سنن نسائی',
    'malik': 'موطا امام مالک',
    'nawawi': 'اربعین نووی',
    'qudsi': 'احادیثِ قدسیہ',
    'dehlawi': 'اربعین دہلوی',
  };

  /// The collection's Urdu name, or null for a collection we don't know.
  static String? urduCollectionName(String key) => _urduCollectionNames[key];

  static String preview(
    DailyContent? content, {
    TranslationLanguage language = TranslationLanguage.english,
  }) {
    final urdu = language == TranslationLanguage.urdu;
    if (content == null) return urdu ? fallbackUrdu : fallback;
    final hadith = content.hadith;
    // The verse is Urdu when chosen and available; otherwise English, as
    // before. The hadith line carries no translation, only the book and
    // number, so it just takes the Urdu wording of its label and book.
    final translation = content.ayah.translationIn(language);
    // Urdu chosen but this verse has none: say so in the notification rather
    // than quoting the English.
    final verse = urdu && translation.isEmpty
        ? TranslationLanguage.urduUnavailableInUrdu
        : _clip(translation, 90);
    if (!urdu) {
      return '“$verse” — ${content.ayah.verseKey}\n'
          'Hadith: ${hadith.collectionName}, #${hadith.hadithNumber}';
    }
    final book = urduCollectionName(hadith.collection) ?? hadith.collectionName;
    return '“$verse” — ${content.ayah.verseKey}\n'
        'حدیث: $book، #${hadith.hadithNumber}';
  }

  static String _clip(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trimRight()}…';
  }
}
