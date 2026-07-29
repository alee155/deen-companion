import '../../domain/entities/recent_activity_item.dart';

class RecentActivityItemModel {
  final String id;
  final String type;
  final String referenceId;
  final String title;
  final String? subtitle;
  final String route;
  final String viewedAt;

  const RecentActivityItemModel({
    required this.id,
    required this.type,
    required this.referenceId,
    required this.title,
    this.subtitle,
    required this.route,
    required this.viewedAt,
  });

  factory RecentActivityItemModel.fromEntity(RecentActivityItem entity) {
    return RecentActivityItemModel(
      id: entity.id,
      type: entity.type.name,
      referenceId: entity.referenceId,
      title: entity.title,
      subtitle: entity.subtitle,
      route: entity.route,
      viewedAt: entity.viewedAt.toIso8601String(),
    );
  }

  RecentActivityItem toEntity() {
    return RecentActivityItem(
      id: id,
      type: RecentActivityType.values.firstWhere((t) => t.name == type),
      referenceId: referenceId,
      title: title,
      subtitle: subtitle,
      route: route,
      viewedAt: DateTime.parse(viewedAt),
    );
  }

  factory RecentActivityItemModel.fromJson(Map<String, dynamic> json) {
    return RecentActivityItemModel(
      id: json['id'] as String,
      type: json['type'] as String,
      referenceId: json['referenceId'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      route: json['route'] as String,
      viewedAt: json['viewedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'referenceId': referenceId,
    'title': title,
    'subtitle': subtitle,
    'route': route,
    'viewedAt': viewedAt,
  };
}
