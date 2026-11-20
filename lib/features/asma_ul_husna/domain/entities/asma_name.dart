class AsmaName {
  final int number;
  final String arabic;
  final String transliteration;

  /// The short epithet ("The Most Merciful"), in the reader's language.
  final String english;

  /// What is shown, in the reader's language. In Urdu this is the Urdu
  /// meaning, or empty when there is none: never the English (see [urdu]).
  final String meaning;

  /// [english] and [meaning] are Urdu (the reader chose Urdu).
  final bool urdu;

  /// The source's own English, whatever is shown. What is saved to Favorites
  /// and Recent, so those stay right if the language is changed later.
  final String englishEpithet;
  final String englishMeaning;

  const AsmaName({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.english,
    required this.meaning,
    this.urdu = false,
    String? englishEpithet,
    String? englishMeaning,
  }) : englishEpithet = englishEpithet ?? english,
       englishMeaning = englishMeaning ?? meaning;

  /// This Name in Urdu. A missing meaning stays empty so the screen can say
  /// so; a missing epithet keeps the English one.
  AsmaName inUrdu({String? epithet, String? meaning}) => AsmaName(
    number: number,
    arabic: arabic,
    transliteration: transliteration,
    english: epithet ?? english,
    meaning: meaning ?? '',
    urdu: true,
    englishEpithet: englishEpithet,
    englishMeaning: englishMeaning,
  );
}
