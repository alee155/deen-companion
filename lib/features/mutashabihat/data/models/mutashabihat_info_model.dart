import '../../domain/entities/mutashabihat_info.dart';

class MutashabihatInfoModel {
  final String description;
  final int totalEntries;
  final int totalPairs;
  final int surahsInvolved;
  final String source;
  final String attribution;

  const MutashabihatInfoModel({
    required this.description,
    required this.totalEntries,
    required this.totalPairs,
    required this.surahsInvolved,
    required this.source,
    required this.attribution,
  });

  factory MutashabihatInfoModel.fromJson(Map<String, dynamic> json) {
    return MutashabihatInfoModel(
      description: json['description'] as String,
      totalEntries: json['total_entries'] as int,
      totalPairs: json['total_pairs'] as int,
      surahsInvolved: json['surahs_involved'] as int,
      source: json['source'] as String,
      attribution: json['attribution'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'description': description,
    'total_entries': totalEntries,
    'total_pairs': totalPairs,
    'surahs_involved': surahsInvolved,
    'source': source,
    'attribution': attribution,
  };

  MutashabihatInfo toEntity() => MutashabihatInfo(
    description: description,
    totalEntries: totalEntries,
    totalPairs: totalPairs,
    surahsInvolved: surahsInvolved,
    source: source,
    attribution: attribution,
  );
}
