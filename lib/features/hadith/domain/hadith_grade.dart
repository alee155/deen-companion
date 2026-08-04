/// Authenticity grading, parsed out of the free-text `grade` string the API
/// returns ("Sahih", "Hasan", "Da'if", "Sahih (Al-Albani)", …).
///
/// Kept in the domain layer because it's a property of the hadith, not of any
/// one screen — the reader, the search results and the detail view all need
/// the same reading of it, and the UI layer maps the result to a colour.
enum HadithGrade {
  sahih,
  hasan,
  daif,
  unknown;

  static HadithGrade parse(String? raw) {
    if (raw == null) return HadithGrade.unknown;
    final value = raw.toLowerCase();
    // Ordered most- to least-authentic: a string like "Sahih" wins over the
    // substring match for a weaker grade if both somehow appear.
    if (value.contains('sahih') || value.contains('صحيح')) {
      return HadithGrade.sahih;
    }
    if (value.contains('hasan') || value.contains('حسن')) {
      return HadithGrade.hasan;
    }
    if (value.contains("da'if") ||
        value.contains('daif') ||
        value.contains('dhaif') ||
        value.contains('weak') ||
        value.contains('ضعيف')) {
      return HadithGrade.daif;
    }
    return HadithGrade.unknown;
  }

  String get label => switch (this) {
    HadithGrade.sahih => 'Sahih',
    HadithGrade.hasan => 'Hasan',
    HadithGrade.daif => "Da'if",
    HadithGrade.unknown => 'Ungraded',
  };
}
