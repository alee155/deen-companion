/// Picks the Ayat and Hadith for a given day — purely from the date, with
/// no network. Same date, same content: that is what lets a notification
/// scheduled days ahead, its history entry and the screen it opens all
/// agree without storing anything but the date.
class DailyContentSelector {
  DailyContentSelector._();

  /// Curated, widely-known verses (surah, ayah) that read well on their own.
  /// Appending is safe; reordering changes which verse lands on which day.
  static const List<(int, int)> _verses = [
    (2, 255),
    (2, 286),
    (2, 152),
    (2, 153),
    (2, 156),
    (2, 186),
    (2, 201),
    (2, 216),
    (2, 45),
    (2, 177),
    (3, 8),
    (3, 139),
    (3, 159),
    (3, 173),
    (3, 185),
    (3, 190),
    (4, 36),
    (4, 103),
    (5, 8),
    (6, 162),
    (7, 56),
    (7, 199),
    (8, 2),
    (9, 51),
    (10, 57),
    (10, 62),
    (11, 88),
    (12, 87),
    (13, 11),
    (13, 28),
    (14, 7),
    (15, 99),
    (16, 90),
    (16, 97),
    (16, 128),
    (17, 23),
    (17, 24),
    (17, 80),
    (18, 10),
    (18, 46),
    (20, 14),
    (20, 114),
    (21, 87),
    (21, 107),
    (23, 1),
    (24, 35),
    (25, 63),
    (25, 74),
    (29, 45),
    (29, 69),
    (31, 17),
    (33, 41),
    (33, 56),
    (39, 10),
    (39, 53),
    (40, 60),
    (41, 34),
    (42, 43),
    (49, 10),
    (49, 13),
    (51, 56),
    (55, 13),
    (57, 4),
    (59, 22),
    (59, 23),
    (64, 11),
    (65, 2),
    (65, 3),
    (94, 5),
    (94, 6),
    (93, 3),
    (103, 3),
    (112, 1),
  ];

  /// Nawawi's 40 Hadith (the collection holds 42 entries) — short, authentic
  /// and foundational, so a daily rotation never lands on a long narration.
  static const String hadithCollection = 'nawawi';
  static const int _hadithCount = 42;

  static final DateTime _epoch = DateTime.utc(2024, 1, 1);

  static int _dayIndex(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).difference(_epoch).inDays;

  static (int surah, int ayah) ayahFor(DateTime date) =>
      _verses[_dayIndex(date) % _verses.length];

  static int hadithNumberFor(DateTime date) =>
      _dayIndex(date) % _hadithCount + 1;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Inverse of [dateKey]; null when [value] isn't a plain 'yyyy-MM-dd'.
  static DateTime? parseDateKey(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    return DateTime.tryParse(value);
  }
}
