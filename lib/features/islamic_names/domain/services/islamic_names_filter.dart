import '../entities/islamic_name.dart';

class IslamicNamesFilter {
  IslamicNamesFilter._();

  static List<String> uniqueOrigins(List<IslamicName> names) {
    final origins = names.map((n) => n.origin).toSet().toList();
    origins.sort();
    return origins;
  }

  static List<IslamicName> apply(
    List<IslamicName> names, {
    String genderFilter = 'all',
    Set<String> originFilters = const {},
    String query = '',
  }) {
    return names.where((n) {
      if (genderFilter != 'all' && n.gender != genderFilter) return false;
      if (originFilters.isNotEmpty && !originFilters.contains(n.origin))
        return false;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        return n.name.toLowerCase().contains(q) ||
            n.arabic.contains(query) ||
            n.meaning.toLowerCase().contains(q) ||
            n.note.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  static Map<String, List<IslamicName>> groupAlphabetically(
    List<IslamicName> names,
  ) {
    final sorted = [...names]..sort((a, b) => a.name.compareTo(b.name));
    final map = <String, List<IslamicName>>{};
    for (final n in sorted) {
      final letter = n.name.isNotEmpty ? n.name[0].toUpperCase() : '#';
      map.putIfAbsent(letter, () => []).add(n);
    }
    return map;
  }
}
