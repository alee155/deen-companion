import 'dua.dart';
import 'dua_category.dart';

class DuasBundle {
  final List<DuaCategory> categories;
  final List<Dua> duas;

  const DuasBundle({required this.categories, required this.duas});

  List<Dua> byCategory(String categoryId) =>
      duas.where((d) => d.category == categoryId).toList();
}
