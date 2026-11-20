/// Which language Quran and Hadith translations are shown in. Arabic is
/// always the source text; this only chooses the translation under it.
enum TranslationLanguage {
  english,
  urdu;

  String get label => switch (this) {
    TranslationLanguage.english => 'English',
    TranslationLanguage.urdu => 'Urdu',
  };

  /// The language's own name, shown beside [label].
  String get nativeLabel => switch (this) {
    TranslationLanguage.english => 'English',
    TranslationLanguage.urdu => 'اردو',
  };

  /// What is shown in place of a translation that this language doesn't have.
  /// Never the other language's text: a reader who chose Urdu isn't handed
  /// English as if it were the same thing.
  String get unavailableMessage => switch (this) {
    TranslationLanguage.english => 'Translation is not available',
    TranslationLanguage.urdu => 'Urdu translation is not available',
  };

  /// The same message in Urdu, for surfaces that are written in Urdu (the
  /// daily notification).
  static const String urduUnavailableInUrdu = 'اردو ترجمہ دستیاب نہیں ہے';

  static TranslationLanguage parse(String? value) =>
      TranslationLanguage.values.firstWhere(
        (l) => l.name == value,
        orElse: () => TranslationLanguage.english,
      );
}
