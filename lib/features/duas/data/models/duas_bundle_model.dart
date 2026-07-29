import '../../domain/entities/duas_bundle.dart';
import 'dua_category_model.dart';
import 'dua_model.dart';

class DuasBundleModel {
  final int total;
  final List<DuaCategoryModel> categories;
  final List<DuaModel> duas;

  const DuasBundleModel({
    required this.total,
    required this.categories,
    required this.duas,
  });

  factory DuasBundleModel.fromJson(Map<String, dynamic> json) {
    return DuasBundleModel(
      total: json['total'] as int,
      categories: (json['categories'] as List)
          .map((e) => DuaCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      duas: (json['duas'] as List)
          .map((e) => DuaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'categories': categories.map((c) => c.toJson()).toList(),
    'duas': duas.map((d) => d.toJson()).toList(),
  };

  DuasBundle toEntity() => DuasBundle(
    categories: categories.map((c) => c.toEntity()).toList(),
    duas: duas.map((d) => d.toEntity()).toList(),
  );
}
