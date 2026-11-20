class Dua {
  final int id;
  final String category;

  /// What is shown. In the reader's language: for Urdu this is the Urdu title.
  final String title;
  final String arabic;
  final String transliteration;

  /// What is shown. In Urdu this is the Urdu translation, or empty when there
  /// is none: never the English (see [urdu]).
  final String translation;
  final String source;
  final int repeat;

  /// [title] and [translation] are Urdu (the reader chose Urdu).
  final bool urdu;

  /// The source's own English, whatever is shown. What is saved to Favorites
  /// and Recent, so those stay right if the language is changed later.
  final String englishTitle;
  final String englishTranslation;

  const Dua({
    required this.id,
    required this.category,
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.source,
    required this.repeat,
    this.urdu = false,
    String? englishTitle,
    String? englishTranslation,
  }) : englishTitle = englishTitle ?? title,
       englishTranslation = englishTranslation ?? translation;

  /// This dua in Urdu. A missing translation stays empty so the screen can say
  /// so; a missing title keeps the English name.
  Dua inUrdu({String? title, String? translation}) => Dua(
    id: id,
    category: category,
    title: title ?? this.title,
    arabic: arabic,
    transliteration: transliteration,
    translation: translation ?? '',
    source: source,
    repeat: repeat,
    urdu: true,
    englishTitle: englishTitle,
    englishTranslation: englishTranslation,
  );
}
