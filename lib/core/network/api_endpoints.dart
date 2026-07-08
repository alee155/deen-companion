class ApiEndpoints {
  ApiEndpoints._();

  // ============================================================
  // Base URLs
  // ============================================================

  /// UmmahAPI
  static const String _ummahBase = 'https://ummahapi.com/api';

  /// Aladhan Prayer Times API
  static const String _aladhanBase = 'https://api.aladhan.com/v1';

  static String qibla({required double lat, required double lng}) {
    return Uri.parse(
      '$_ummahBase/qibla',
    ).replace(queryParameters: {'lat': '$lat', 'lng': '$lng'}).toString();
  }

  static const String asmaUlHusna = '$_ummahBase/asma-ul-husna';
  static String asmaUlHusnaByNumber(int number) =>
      '$_ummahBase/asma-ul-husna/$number';
  static String asmaUlHusnaSearch(String query) => Uri.parse(
    '$_ummahBase/asma-ul-husna/search',
  ).replace(queryParameters: {'q': query}).toString();
  static String asmaUlHusnaDaily(int day) =>
      '$_ummahBase/asma-ul-husna/daily/$day';
  // ============================================================
  // Quran
  // ============================================================

  static const String quranMeta = '$_ummahBase/quran';
  static const String quranSurahs = '$_ummahBase/quran/surahs';

  static String quranSurahDetail(
    int number, {
    String? script,
    String? translation,
    int? reciter,
  }) {
    final params = <String, String>{
      if (script != null) 'script': script,
      if (translation != null) 'translation': translation,
      if (reciter != null) 'reciter': '$reciter',
    };

    return Uri.parse(
      '$_ummahBase/quran/surah/$number',
    ).replace(queryParameters: params.isEmpty ? null : params).toString();
  }

  static String quranAyah(int surah, int ayah, {String? script}) {
    return Uri.parse('$_ummahBase/quran/surah/$surah/ayah/$ayah')
        .replace(queryParameters: script == null ? null : {'script': script})
        .toString();
  }

  static String quranSearch(String query, {String? translation, int? limit}) {
    return Uri.parse('$_ummahBase/quran/search')
        .replace(
          queryParameters: {
            'q': query,
            if (translation != null) 'translation': translation,
            if (limit != null) 'limit': '$limit',
          },
        )
        .toString();
  }

  static String quranJuz(int number) => '$_ummahBase/quran/juz/$number';

  static String quranMushafPage(int number) => '$_ummahBase/quran/page/$number';

  // ─────────────────────────────────────────────
  // UmmahAPI — Zakat
  // ─────────────────────────────────────────────
  static const String zakatInfo = '$_ummahBase/zakat/info';

  static String zakatNisab({
    double? goldPricePerGram,
    double? silverPricePerGram,
  }) {
    final params = <String, String>{
      if (goldPricePerGram != null) 'gold_price_per_gram': '$goldPricePerGram',
      if (silverPricePerGram != null)
        'silver_price_per_gram': '$silverPricePerGram',
    };
    return Uri.parse(
      '$_ummahBase/zakat/nisab',
    ).replace(queryParameters: params.isEmpty ? null : params).toString();
  }

  static const String zakatCalculate = '$_ummahBase/zakat/calculate'; // POST
  static const String zakatAgriculture =
      '$_ummahBase/zakat/agriculture'; // POST
  // ============================================================
  // Prayer Times (Aladhan)
  // ============================================================

  static String timingsByTimestamp(int unixTimestamp) =>
      '$_aladhanBase/timings/$unixTimestamp';

  // ============================================================
  // Islamic Calendar
  // ============================================================

  static const String todayHijri = '$_ummahBase/today-hijri';
  static const String islamicMonths = '$_ummahBase/islamic-months';
  static const String islamicEvents = '$_ummahBase/islamic-events';

  static String hijriDate({
    required int year,
    required int month,
    required int day,
  }) {
    return Uri.parse('$_ummahBase/hijri-date')
        .replace(
          queryParameters: {'year': '$year', 'month': '$month', 'day': '$day'},
        )
        .toString();
  }

  static String gregorianDate({
    required int year,
    required int month,
    required int day,
  }) {
    return Uri.parse('$_ummahBase/gregorian-date')
        .replace(
          queryParameters: {'year': '$year', 'month': '$month', 'day': '$day'},
        )
        .toString();
  }

  // ============================================================
  // Duas
  // ============================================================

  /// The complete duas bundle is fetched once and cached locally.
  /// Since the dataset is small and rarely changes, category filtering
  /// is performed on the client instead of making additional requests.

  static const String duas = '$_ummahBase/duas';
  static const String duasCategories = '$_ummahBase/duas/categories';

  static String duasCategory(String id) => '$_ummahBase/duas/category/$id';

  static String duasSearch(String query) {
    return Uri.parse(
      '$_ummahBase/duas/search',
    ).replace(queryParameters: {'q': query}).toString();
  }

  // ============================================================
  // Hadith
  // ============================================================

  static const String hadithCollections = '$_ummahBase/hadith/collections';

  static const String hadithRandom = '$_ummahBase/hadith/random';

  static String hadithPage(String collection, int page) =>
      '$_ummahBase/hadith/$collection?page=$page';

  static String hadithByNumber(String collection, int number) =>
      '$_ummahBase/hadith/$collection/$number';

  static String hadithSearch(
    String query, {
    String? collection,
    int limit = 25,
  }) {
    return Uri.parse('$_ummahBase/hadith/search')
        .replace(
          queryParameters: {
            'q': query,
            if (collection != null) 'collection': collection,
            'limit': '$limit',
          },
        )
        .toString();
  }
}
