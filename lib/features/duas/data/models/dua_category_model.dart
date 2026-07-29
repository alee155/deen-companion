import '../../domain/entities/dua_category.dart';

class DuaCategoryModel {
  final String id;
  final String name;
  final String description;
  final int count;

  const DuaCategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.count,
  });

  factory DuaCategoryModel.fromJson(Map<String, dynamic> json) {
    return DuaCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'count': count,
  };

  DuaCategory toEntity() =>
      DuaCategory(id: id, name: name, description: description, count: count);
}
