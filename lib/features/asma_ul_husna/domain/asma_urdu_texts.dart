import 'dart:convert';

import '../../../shared/domain/urdu_search.dart';
import 'entities/asma_daily.dart';
import 'entities/asma_name.dart';

/// The Urdu for the 99 Names (the epithet and the meaning of each).
///
/// The source has English only and the set is fixed, so the Urdu ships with the
/// app, keyed by the Name's number: offline, instant, the same for everyone.
class AsmaUrduTexts {
  final Map<int, ({String epithet, String meaning})> _names;

  const AsmaUrduTexts._(this._names);

  /// No Urdu at all: every meaning then reads as not available.
  static const empty = AsmaUrduTexts._({});

  factory AsmaUrduTexts.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final names = <int, ({String epithet, String meaning})>{};
    (json['names'] as Map<String, dynamic>? ?? const {}).forEach((key, value) {
      final number = int.tryParse(key);
      if (number == null) return;
      final m = value as Map<String, dynamic>;
      names[number] = (
        epithet: ((m['english'] as String?) ?? '').trim(),
        meaning: ((m['meaning'] as String?) ?? '').trim(),
      );
    });
    return AsmaUrduTexts._(names);
  }

  String? epithetOf(int number) {
    final t = _names[number]?.epithet;
    return t == null || t.isEmpty ? null : t;
  }

  String? meaningOf(int number) {
    final t = _names[number]?.meaning;
    return t == null || t.isEmpty ? null : t;
  }

  AsmaName name(AsmaName n) =>
      n.inUrdu(epithet: epithetOf(n.number), meaning: meaningOf(n.number));

  List<AsmaName> names(List<AsmaName> list) => [for (final n in list) name(n)];

  /// Weekday names, Monday = 1 (the source's day numbering).
  static const dayNames = [
    'پیر',
    'منگل',
    'بدھ',
    'جمعرات',
    'جمعہ',
    'ہفتہ',
    'اتوار',
  ];

  /// Short weekday names for the day selector, Monday first.
  static const shortDayNames = [
    'پیر',
    'منگل',
    'بدھ',
    'جمعرات',
    'جمعہ',
    'ہفتہ',
    'اتوار',
  ];

  /// One day's practice: the Names, the weekday and the notes around them, all
  /// in Urdu (the notes are fixed wording in the source, so they are fixed here).
  AsmaDaily daily(AsmaDaily d) {
    final day = d.dayNumber;
    return AsmaDaily(
      dayNumber: day,
      dayName: day >= 1 && day <= 7 ? dayNames[day - 1] : d.dayName,
      names: names(d.names),
      count: d.count,
      suggestion:
          'آج اپنے روزانہ ذکر کے حصے کے طور پر یہ ${d.count} اسماء پڑھیں',
      weeklyCompletion: 'ہفتے بھر میں پڑھ کر تمام 99 اسماء مکمل کریں',
    );
  }

  /// Numbers of the Names matching [query], in order: every word has to be in
  /// the Name's epithet or meaning.
  List<int> search(String query) {
    final words = normalizeUrdu(query).split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return const [];
    final found = <int>[];
    final numbers = _names.keys.toList()..sort();
    for (final n in numbers) {
      final t = _names[n]!;
      final all = '${normalizeUrdu(t.epithet)} ${normalizeUrdu(t.meaning)}';
      if (words.every(all.contains)) found.add(n);
    }
    return found;
  }
}
