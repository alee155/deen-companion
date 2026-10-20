import 'entities/favorite_item.dart';

/// The favorites that match [type] (all types when null) and [query] (matched
/// against title and subtitle, case-insensitively), newest first.
List<FavoriteItem> filterFavorites(
  List<FavoriteItem> all, {
  FavoriteContentType? type,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return all
      .where(
        (item) =>
            (type == null || item.type == type) &&
            (q.isEmpty ||
                item.title.toLowerCase().contains(q) ||
                (item.subtitle ?? '').toLowerCase().contains(q)),
      )
      .toList()
    ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
}

/// How many favorites each content type has, in the enum's order and only for
/// types that have at least one.
Map<FavoriteContentType, int> countFavoritesByType(List<FavoriteItem> all) {
  final counts = <FavoriteContentType, int>{};
  for (final type in FavoriteContentType.values) {
    final n = all.where((item) => item.type == type).length;
    if (n > 0) counts[type] = n;
  }
  return counts;
}
