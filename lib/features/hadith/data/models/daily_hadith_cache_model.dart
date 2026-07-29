import 'hadith_model.dart';

/// Wraps a cached hadith with the calendar date it was fetched for —
/// this is what makes "one random hadith per day" work: the repository
/// compares this date against today rather than using a rolling TTL.
class DailyHadithCacheModel {
  final String date; // 'yyyy-MM-dd'
  final HadithModel hadith;

  const DailyHadithCacheModel({required this.date, required this.hadith});

  factory DailyHadithCacheModel.fromJson(Map<String, dynamic> json) {
    return DailyHadithCacheModel(
      date: json['date'] as String,
      hadith: HadithModel.fromJson(json['hadith'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'hadith': hadith.toJson()};
}
