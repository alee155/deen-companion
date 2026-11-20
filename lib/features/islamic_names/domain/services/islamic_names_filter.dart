import '../../../../shared/domain/urdu_search.dart';
import '../entities/islamic_name.dart';

class IslamicNamesFilter {
  IslamicNamesFilter._();

  /// The origins as the source spells them (English), whatever language is
  /// shown: the filter works on these, so a choice survives a language change.
  static List<String> uniqueOrigins(List<IslamicName> names) {
    final origins = names.map((n) => n.englishOrigin).toSet().toList();
    origins.sort();
    return origins;
  }

  static List<IslamicName> apply(
    List<IslamicName> names, {
    String genderFilter = 'all',
    Set<String> originFilters = const {},
    String query = '',
  }) {
    final q = query.toLowerCase();
    // Urdu is typed and spelled several ways, so it is compared folded.
    final qn = hasUrduScript(query) ? normalizeUrdu(query) : '';
    return names.where((n) {
      if (genderFilter != 'all' && n.gender != genderFilter) return false;
      if (originFilters.isNotEmpty &&
          !originFilters.contains(n.englishOrigin)) {
        return false;
      }
      if (query.isEmpty) return true;
      // Both what is shown and the source's English, so either can be typed.
      bool hit(String field) =>
          field.toLowerCase().contains(q) ||
          (qn.isNotEmpty && normalizeUrdu(field).contains(qn));
      return hit(n.name) ||
          hit(n.englishName) ||
          hit(n.arabic) ||
          hit(n.meaning) ||
          hit(n.englishMeaning) ||
          hit(n.note) ||
          hit(n.englishNote);
    }).toList();
  }

  /// The Urdu alphabet in its own order, for sorting and grouping Urdu names.
  static const _urduOrder = 'ابپتٹثجچحخدڈذرڑزژسشصضطظعغفقکگلمنوہءیے';

  static int _urduRank(String letter) {
    final folded = normalizeUrdu(letter);
    final i = _urduOrder.indexOf(folded.isEmpty ? letter : folded[0]);
    return i < 0 ? _urduOrder.length : i;
  }

  static String _urduInitial(String name) {
    final folded = normalizeUrdu(name);
    return folded.isEmpty ? '#' : folded[0];
  }

  static Map<String, List<IslamicName>> groupAlphabetically(
    List<IslamicName> names,
  ) {
    final urdu = names.isNotEmpty && names.every((n) => n.urdu);
    final sorted = [...names];
    if (urdu) {
      sorted.sort((a, b) {
        final byLetter = _urduRank(
          _urduInitial(a.name),
        ).compareTo(_urduRank(_urduInitial(b.name)));
        return byLetter != 0
            ? byLetter
            : normalizeUrdu(a.name).compareTo(normalizeUrdu(b.name));
      });
    } else {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    final map = <String, List<IslamicName>>{};
    for (final n in sorted) {
      final letter = urdu
          ? _urduInitial(n.name)
          : (n.name.isNotEmpty ? n.name[0].toUpperCase() : '#');
      map.putIfAbsent(letter, () => []).add(n);
    }
    return map;
  }
}
