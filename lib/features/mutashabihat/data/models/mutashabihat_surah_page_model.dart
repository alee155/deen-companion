import '../../domain/entities/mutashabihat_surah_page.dart';
import 'mutashabihat_entry_model.dart';

class MutashabihatSurahPageModel {
  final int surah;
  final String surahNameArabic;
  final String surahNameEnglish;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final List<MutashabihatEntryModel> entries;

  const MutashabihatSurahPageModel({
    required this.surah,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.entries,
  });

  factory MutashabihatSurahPageModel.fromJson(Map<String, dynamic> json) {
    return MutashabihatSurahPageModel(
      surah: json['surah'] as int,
      surahNameArabic: json['surah_name_arabic'] as String,
      surahNameEnglish: json['surah_name_english'] as String,
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['total_pages'] as int,
      entries: (json['verses'] as List)
          .map(
            (e) => MutashabihatEntryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'surah': surah,
    'surah_name_arabic': surahNameArabic,
    'surah_name_english': surahNameEnglish,
    'total': total,
    'page': page,
    'limit': limit,
    'total_pages': totalPages,
    'verses': entries.map((e) => e.toJson()).toList(),
  };

  MutashabihatSurahPage toEntity() => MutashabihatSurahPage(
    surah: surah,
    surahNameArabic: surahNameArabic,
    surahNameEnglish: surahNameEnglish,
    total: total,
    page: page,
    limit: limit,
    totalPages: totalPages,
    entries: entries.map((e) => e.toEntity()).toList(),
  );
}
