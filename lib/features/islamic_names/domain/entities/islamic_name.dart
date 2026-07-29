class IslamicName {
  final int id;
  final String name;
  final String arabic;
  final String gender;
  final String meaning;
  final String origin;
  final String?
  root; // nullable — non-Arabic names (Ibrahim, Musa, etc.) have no root
  final String note;

  const IslamicName({
    required this.id,
    required this.name,
    required this.arabic,
    required this.gender,
    required this.meaning,
    required this.origin,
    this.root,
    required this.note,
  });
}
