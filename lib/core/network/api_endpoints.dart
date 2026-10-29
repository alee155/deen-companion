class ApiEndpoints {
  ApiEndpoints._();

  // ============================================================
  // Base URLs
  // ============================================================

  /// UmmahAPI
  static const String _ummahBase = 'https://ummahapi.com/api';

  /// Deen Companion backend (auth, groups)
  static const String deenHost = 'deencompanion.dgexpense.com';
  static const String _deenBase = 'https://$deenHost/api';

  /// Socket.IO namespace for live group events. Outside `/api`; the token goes
  /// in the handshake `auth` object, never in the URL.
  static const String realtime = 'https://$deenHost/realtime';

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
  static const String mutashabihat = '$_ummahBase/quran/mutashabihat';
  static const String mutashabihatRandom =
      '$_ummahBase/quran/mutashabihat/random';

  static String mutashabihatBySurah(int surah, {int page = 1, int limit = 20}) {
    return Uri.parse(
      '$_ummahBase/quran/mutashabihat/$surah',
    ).replace(queryParameters: {'page': '$page', 'limit': '$limit'}).toString();
  }

  static String mutashabihatByAyah(int surah, int ayah) =>
      '$_ummahBase/quran/mutashabihat/$surah/$ayah';

  static const String islamicNamesAll = '$_ummahBase/names?page=1&limit=210';
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
      'script': ?script,
      'translation': ?translation,
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
            'translation': ?translation,
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
    final date =
        '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
    return Uri.parse(
      '$_ummahBase/hijri-date',
    ).replace(queryParameters: {'date': date}).toString();
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
            'collection': ?collection,
            'limit': '$limit',
          },
        )
        .toString();
  }

  // ============================================================
  // Deen Companion backend
  // ============================================================

  static const String health = '$_deenBase/health';
  static const String authRegister = '$_deenBase/auth/register';
  static const String authLogin = '$_deenBase/auth/login';
  static const String authResendOtp = '$_deenBase/auth/resend-otp';
  static const String authForgotPassword = '$_deenBase/auth/forgot-password';
  static const String authResetPassword = '$_deenBase/auth/reset-password';
  static const String authMe = '$_deenBase/auth/me';
  // Prayer times served by the backend. Guest routes need no token (they take
  // an X-Device-Id header instead); the account routes use the Bearer token.
  static const String guestPrayerTimes = '$_deenBase/prayer-times';
  static const String guestPrayerTimesMonth = '$_deenBase/prayer-times/month';
  static const String prayerCities = '$_deenBase/prayer-times/cities';
  static const String prayerMethods = '$_deenBase/prayer-times/methods';
  static const String accountPrayerTimes = '$_deenBase/prayers/times';
  static const String accountPrayerTimesMonth =
      '$_deenBase/prayers/times/month';
  static const String prayerLocation = '$_deenBase/prayers/location';
  static const String prayerCurrent = '$_deenBase/prayers/current';
  static const String prayerLogs = '$_deenBase/prayers/logs';
  static String prayerLog(String id) =>
      '$_deenBase/prayers/logs/${Uri.encodeComponent(id)}';

  /// `POST` — opens a snap once per viewer, only while the window is open.
  static String prayerLogView(String id) =>
      '$_deenBase/prayers/logs/${Uri.encodeComponent(id)}/view';
  static const String prayerLogsRange = '$_deenBase/prayers/logs/range';
  static const String pointsRules = '$_deenBase/points/rules';
  static const String groups = '$_deenBase/groups';
  static String group(String id) => '$_deenBase/groups/$id';
  static String invitePreview(String token) =>
      '$_deenBase/invites/${Uri.encodeComponent(token)}';
  static String inviteJoin(String token) =>
      '$_deenBase/invites/${Uri.encodeComponent(token)}/join';
  static String groupAvatar(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/avatar';
  static String groupSummary(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/summary';
  static String groupMember(String groupId, String userId) =>
      '$_deenBase/groups/$groupId/members/$userId';
  static String groupLeave(String groupId) =>
      '$_deenBase/groups/$groupId/leave';
  static String groupPrayers(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/prayers';
  static String groupStreakRule(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/streak-rule';
  static String groupStreaks(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/streaks';
  static const String myStreaks = '$_deenBase/users/me/streaks';
  static const String myStatsSummary = '$_deenBase/users/me/stats/summary';
  static const String myStatsDaily = '$_deenBase/users/me/stats/daily';
  static const String myStatsTrend = '$_deenBase/users/me/stats/trend';
  static String groupStatsOverview(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/stats/overview';
  static String groupStatsMembers(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/stats/members';
  static String groupStatsMember(String id, String userId) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/stats/members/'
      '${Uri.encodeComponent(userId)}';
  static String groupStatsAttention(String id) =>
      '$_deenBase/groups/${Uri.encodeComponent(id)}/stats/attention';
  static String groupInvite(String id) => '$_deenBase/groups/$id/invite';
  static String groupInviteReset(String id) =>
      '$_deenBase/groups/$id/invite/reset';
  static const String authAccount = '$_deenBase/auth/account';
  static const String authVerifyEmail = '$_deenBase/auth/verify-email';
  static const String myProfile = '$_deenBase/users/me';
  static const String myAvatar = '$_deenBase/users/me/avatar';
  static const String myTimezone = '$_deenBase/users/me/timezone';
  static const String myPoints = '$_deenBase/users/me/points';
}
