import 'mutashabihat_entry.dart';

class MutashabihatSurahPage {
  final int surah;
  final String surahNameArabic;
  final String surahNameEnglish;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final List<MutashabihatEntry> entries;

  const MutashabihatSurahPage({
    required this.surah,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.entries,
  });

  bool get hasMore => page < totalPages;
}
