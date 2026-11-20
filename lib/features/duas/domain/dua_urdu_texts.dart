import 'dart:convert';

import '../../../shared/domain/urdu_search.dart';
import 'entities/dua.dart';
import 'entities/dua_category.dart';
import 'entities/duas_bundle.dart';

/// The Urdu for the duas.
///
/// The duas source has English only, and the set is small and fixed (127
/// duas, 27 categories), so the Urdu ships with the app, keyed by the source's
/// own ids. Offline, instant, and the same for everyone.
class DuaUrduTexts {
  final Map<int, ({String title, String translation})> _duas;
  final Map<String, ({String name, String description})> _categories;

  const DuaUrduTexts._(this._duas, this._categories);

  /// No Urdu at all: every translation then reads as not available.
  static const empty = DuaUrduTexts._({}, {});

  factory DuaUrduTexts.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final duas = <int, ({String title, String translation})>{};
    (json['duas'] as Map<String, dynamic>? ?? const {}).forEach((key, value) {
      final id = int.tryParse(key);
      final m = value as Map<String, dynamic>;
      if (id == null) return;
      duas[id] = (
        title: ((m['title'] as String?) ?? '').trim(),
        translation: ((m['translation'] as String?) ?? '').trim(),
      );
    });
    final categories = <String, ({String name, String description})>{};
    (json['categories'] as Map<String, dynamic>? ?? const {}).forEach((
      key,
      value,
    ) {
      final m = value as Map<String, dynamic>;
      categories[key] = (
        name: ((m['name'] as String?) ?? '').trim(),
        description: ((m['description'] as String?) ?? '').trim(),
      );
    });
    return DuaUrduTexts._(duas, categories);
  }

  /// Whether this dua has an Urdu translation.
  bool hasTranslation(int id) => (_duas[id]?.translation ?? '').isNotEmpty;

  String? titleOf(int id) {
    final t = _duas[id]?.title;
    return t == null || t.isEmpty ? null : t;
  }

  String? translationOf(int id) {
    final t = _duas[id]?.translation;
    return t == null || t.isEmpty ? null : t;
  }

  Dua dua(Dua d) =>
      d.inUrdu(title: titleOf(d.id), translation: translationOf(d.id));

  DuaCategory category(DuaCategory c) {
    final t = _categories[c.id];
    return c.inUrdu(
      name: (t?.name ?? '').isEmpty ? null : t!.name,
      description: (t?.description ?? '').isEmpty ? null : t!.description,
    );
  }

  DuasBundle bundle(DuasBundle b) => DuasBundle(
    categories: [for (final c in b.categories) category(c)],
    duas: [for (final d in b.duas) dua(d)],
  );

  /// Ids of the duas matching [query], best first: every word of the query has
  /// to be in the dua's title, translation or category name; a title match
  /// ranks above a translation-only match.
  List<int> search(String query, {required Map<int, String> categoryOf}) {
    final words = normalize(query).split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return const [];
    final ranked = <(int, int)>[];
    _duas.forEach((id, t) {
      final title = normalize(t.title);
      final categoryName = normalize(_categories[categoryOf[id]]?.name ?? '');
      final all = '$title ${normalize(t.translation)} $categoryName';
      if (!words.every(all.contains)) return;
      ranked.add((
        words.every((w) => '$title $categoryName'.contains(w)) ? 0 : 1,
        id,
      ));
    });
    ranked.sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
    );
    return [for (final r in ranked) r.$2];
  }

  /// See [normalizeUrdu].
  static String normalize(String text) => normalizeUrdu(text);
}
