class IslamicName {
  final int id;

  /// What is shown, in the reader's language: the name as written in Latin
  /// letters, or in Urdu script when the reader chose Urdu.
  final String name;
  final String arabic;
  final String gender;
  final String meaning;
  final String origin;
  final String?
  root; // nullable — non-Arabic names (Ibrahim, Musa, etc.) have no root
  final String note;

  /// [name], [meaning], [origin] and [note] are Urdu. A [note] that is empty
  /// then means there is no Urdu for it (see [hasNote]), not that there is no
  /// note.
  final bool urdu;

  /// The source's own English, whatever is shown. What is saved to Favorites,
  /// what is searched, and what the origin filter works on.
  final String englishName;
  final String englishMeaning;
  final String englishOrigin;
  final String englishNote;

  const IslamicName({
    required this.id,
    required this.name,
    required this.arabic,
    required this.gender,
    required this.meaning,
    required this.origin,
    this.root,
    required this.note,
    this.urdu = false,
    String? englishName,
    String? englishMeaning,
    String? englishOrigin,
    String? englishNote,
  }) : englishName = englishName ?? name,
       englishMeaning = englishMeaning ?? meaning,
       englishOrigin = englishOrigin ?? origin,
       englishNote = englishNote ?? note;

  /// Whether the source has a note for this name at all.
  bool get hasNote => englishNote.isNotEmpty;

  /// This name in Urdu. A missing meaning or note stays empty so the screen
  /// can say so; a missing name or origin keeps the English one.
  IslamicName inUrdu({
    String? name,
    String? meaning,
    String? origin,
    String? note,
  }) => IslamicName(
    id: id,
    name: name ?? this.name,
    arabic: arabic,
    gender: gender,
    meaning: meaning ?? '',
    origin: origin ?? this.origin,
    root: root,
    note: note ?? '',
    urdu: true,
    englishName: englishName,
    englishMeaning: englishMeaning,
    englishOrigin: englishOrigin,
    englishNote: englishNote,
  );
}
