import 'package:equatable/equatable.dart';

enum RecentActivityType {
  surah,
  hadith,
  dua,
  asmaName,
  islamicName,
  juz;

  String get label {
    switch (this) {
      case RecentActivityType.surah:
        return 'Surah';
      case RecentActivityType.hadith:
        return 'Hadith';
      case RecentActivityType.dua:
        return 'Dua';
      case RecentActivityType.asmaName:
        return 'Names of Allah';
      case RecentActivityType.islamicName:
        return 'Islamic Name';
      case RecentActivityType.juz:
        return 'Juz';
    }
  }
}

/// A single recently-viewed item. Only the 5 most recent activities are
/// ever kept — see [RecentActivityRepository.logActivity].
class RecentActivityItem extends Equatable {
  final String id;
  final RecentActivityType type;
  final String referenceId;
  final String title;
  final String? subtitle;
  final String route;
  final DateTime viewedAt;

  const RecentActivityItem({
    required this.id,
    required this.type,
    required this.referenceId,
    required this.title,
    this.subtitle,
    required this.route,
    required this.viewedAt,
  });

  static String buildId(RecentActivityType type, String referenceId) =>
      '${type.name}:$referenceId';

  @override
  List<Object?> get props => [id, type, referenceId, title, subtitle, route, viewedAt];
}
