class DuaCategory {
  final String id;

  /// What is shown, in the reader's language.
  final String name;
  final String description;
  final int count;

  /// The source's English name, whatever is shown. Icons and tints are chosen
  /// from this, so a category looks the same in every language.
  final String englishName;

  /// [name] and [description] are Urdu.
  final bool urdu;

  const DuaCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.count,
    String? englishName,
    this.urdu = false,
  }) : englishName = englishName ?? name;

  DuaCategory inUrdu({String? name, String? description}) => DuaCategory(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    count: count,
    englishName: englishName,
    urdu: true,
  );
}
