import '../../domain/entities/favorite_item.dart';

class FavoriteItemModel {
  final String id;
  final String type;
  final String referenceId;
  final String title;
  final String? subtitle;
  final String route;
  final String savedAt;

  const FavoriteItemModel({
    required this.id,
    required this.type,
    required this.referenceId,
    required this.title,
    this.subtitle,
    required this.route,
    required this.savedAt,
  });

  factory FavoriteItemModel.fromEntity(FavoriteItem entity) {
    return FavoriteItemModel(
      id: entity.id,
      type: entity.type.name,
      referenceId: entity.referenceId,
      title: entity.title,
      subtitle: entity.subtitle,
      route: entity.route,
      savedAt: entity.savedAt.toIso8601String(),
    );
  }

  FavoriteItem toEntity() {
    return FavoriteItem(
      id: id,
      type: FavoriteContentType.values.firstWhere((t) => t.name == type),
      referenceId: referenceId,
      title: title,
      subtitle: subtitle,
      route: route,
      savedAt: DateTime.parse(savedAt),
    );
  }

  factory FavoriteItemModel.fromJson(Map<String, dynamic> json) {
    return FavoriteItemModel(
      id: json['id'] as String,
      type: json['type'] as String,
      referenceId: json['referenceId'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      route: json['route'] as String,
      savedAt: json['savedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'referenceId': referenceId,
    'title': title,
    'subtitle': subtitle,
    'route': route,
    'savedAt': savedAt,
  };
}
