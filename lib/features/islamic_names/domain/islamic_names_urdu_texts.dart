import 'dart:convert';

import 'entities/islamic_name.dart';

/// The Urdu for the Islamic names: each name written in Urdu, its meaning and
/// its note, and the origins.
///
/// The source has English only and the set is fixed, so the Urdu ships with the
/// app, keyed by the name's id: offline, instant, the same for everyone.
class IslamicNamesUrduTexts {
  final Map<int, ({String name, String meaning, String note})> _names;
  final Map<String, String> _origins;

  const IslamicNamesUrduTexts._(this._names, this._origins);

  /// No Urdu at all: every meaning and note then reads as not available.
  static const empty = IslamicNamesUrduTexts._({}, {});

  factory IslamicNamesUrduTexts.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final names = <int, ({String name, String meaning, String note})>{};
    (json['names'] as Map<String, dynamic>? ?? const {}).forEach((key, value) {
      final id = int.tryParse(key);
      if (id == null) return;
      final m = value as Map<String, dynamic>;
      names[id] = (
        name: ((m['name'] as String?) ?? '').trim(),
        meaning: ((m['meaning'] as String?) ?? '').trim(),
        note: ((m['note'] as String?) ?? '').trim(),
      );
    });
    final origins = <String, String>{
      for (final e
          in (json['origins'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: (e.value as String).trim(),
    };
    return IslamicNamesUrduTexts._(names, origins);
  }

  String? _nonEmpty(String? s) => s == null || s.isEmpty ? null : s;

  String? nameOf(int id) => _nonEmpty(_names[id]?.name);
  String? meaningOf(int id) => _nonEmpty(_names[id]?.meaning);
  String? noteOf(int id) => _nonEmpty(_names[id]?.note);

  /// The Urdu for an origin as the source spells it ("Arabic"), or null.
  String? originOf(String englishOrigin) => _nonEmpty(_origins[englishOrigin]);

  IslamicName name(IslamicName n) => n.inUrdu(
    name: nameOf(n.id),
    meaning: meaningOf(n.id),
    origin: originOf(n.englishOrigin),
    // A name the source has no note for needs no note in Urdu either.
    note: n.hasNote ? noteOf(n.id) : null,
  );

  List<IslamicName> names(List<IslamicName> list) => [
    for (final n in list) name(n),
  ];
}
