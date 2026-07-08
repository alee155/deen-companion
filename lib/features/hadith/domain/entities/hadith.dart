class Hadith {
  final String id;
  final String collection;
  final String collectionName;
  final int hadithNumber;
  final String arabic;
  final String english;
  final String grade;

  const Hadith({
    required this.id,
    required this.collection,
    required this.collectionName,
    required this.hadithNumber,
    required this.arabic,
    required this.english,
    required this.grade,
  });
}
