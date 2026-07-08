class ApiEndpoints {
  ApiEndpoints._();
  // ─────────────────────────────────────────────
  // UmmahAPI — Islamic Calendar
  // ─────────────────────────────────────────────
  static const String todayHijri = '$_ummahBase/today-hijri';

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

  static const String islamicMonths = '$_ummahBase/islamic-months';
  static const String islamicEvents = '$_ummahBase/islamic-events';
  // ─────────────────────────────────────────────
  // UmmahAPI — Duas
  // We fetch the full bundle (categories + all duas) once and cache it
  // long-term, then filter by category client-side — the dataset is
  // small (126 items) and static, so a separate network call per
  // category tap would be unnecessary. Endpoints below kept for
  // completeness/future use even though category browsing bypasses them.
  // ─────────────────────────────────────────────
  static const String duas = '$_ummahBase/duas';
  static const String duasCategories = '$_ummahBase/duas/categories';
  static String duasCategory(String id) => '$_ummahBase/duas/category/$id';
  static String duasSearch(String query) => Uri.parse(
    '$_ummahBase/duas/search',
  ).replace(queryParameters: {'q': query}).toString();
  // ─────────────────────────────────────────────
  // UmmahAPI — Hadith
  // ─────────────────────────────────────────────
  static const String hadithCollections = '$_ummahBase/hadith/collections';

  static String hadithPage(String collection, int page) =>
      '$_ummahBase/hadith/$collection?page=$page';

  static String hadithByNumber(String collection, int number) =>
      '$_ummahBase/hadith/$collection/$number';

  static const String hadithRandom = '$_ummahBase/hadith/random';

  static String hadithSearch(
    String query, {
    String? collection,
    int limit = 25,
  }) {
    final params = <String, String>{
      'q': query,
      if (collection != null) 'collection': collection,
      'limit': '$limit',
    };
    return Uri.parse(
      '$_ummahBase/hadith/search',
    ).replace(queryParameters: params).toString();
  }

  // ─────────────────────────────────────────────
  // Aladhan — prayer times & Islamic calendar
  // https://aladhan.com/prayer-times-api
  // ─────────────────────────────────────────────
  static const String _aladhanBase = 'https://api.aladhan.com/v1';

  static String timingsByTimestamp(int unixTimestamp) =>
      '$_aladhanBase/timings/$unixTimestamp';

  // ─────────────────────────────────────────────
  // UmmahAPI — Quran, and future services (hadith, duas, etc.)
  // https://ummahapi.com
  // ─────────────────────────────────────────────
  static const String _ummahBase = 'https://ummahapi.com/api';

  static const String quranMeta = '$_ummahBase/quran';
  static const String quranSurahs = '$_ummahBase/quran/surahs';

  static String quranSurahDetail(
    int number, {
    String? script,
    String? translation,
    int? reciter,
  }) {
    final query = <String, String>{
      if (script != null) 'script': script,
      if (translation != null) 'translation': translation,
      if (reciter != null) 'reciter': '$reciter',
    };
    final uri = Uri.parse(
      '$_ummahBase/quran/surah/$number',
    ).replace(queryParameters: query.isEmpty ? null : query);
    return uri.toString();
  }

  static String quranAyah(int surah, int ayah, {String? script}) {
    final query = script != null ? {'script': script} : null;
    final uri = Uri.parse(
      '$_ummahBase/quran/surah/$surah/ayah/$ayah',
    ).replace(queryParameters: query);
    return uri.toString();
  }

  static String quranSearch(String query, {String? translation, int? limit}) {
    final params = <String, String>{
      'q': query,
      if (translation != null) 'translation': translation,
      if (limit != null) 'limit': '$limit',
    };
    return Uri.parse(
      '$_ummahBase/quran/search',
    ).replace(queryParameters: params).toString();
  }

  static String quranJuz(int number) => '$_ummahBase/quran/juz/$number';

  static String quranMushafPage(int number) => '$_ummahBase/quran/page/$number';
}
