Map<String, dynamic> hadithJson({
  int n = 1,
  String collection = 'bukhari',
  String english = 'Deeds',
  String grade = 'Sahih',
}) => {
  'id': '$collection:$n',
  'collection': collection,
  'collection_name': 'Sahih al-Bukhari',
  'hadithnumber': n,
  'arabic': 'إنما الأعمال',
  'english': english,
  'grade': grade,
};

Map<String, dynamic> hadithCollectionJson({String key = 'bukhari'}) => {
  'key': key,
  'name': 'Sahih al-Bukhari',
  'arabic_name': 'صحيح البخاري',
  'author': 'Imam al-Bukhari',
  'reliability': 'Sahih',
  'total_hadiths': 7563,
};

Map<String, dynamic> hadithPageJson({
  String collection = 'bukhari',
  int page = 1,
  int totalPages = 3,
  int count = 2,
}) => {
  'collection': collection,
  'collection_name': 'Sahih al-Bukhari',
  'page': page,
  'limit': 50,
  'total': 150,
  'total_pages': totalPages,
  'hadiths': [
    for (var i = 0; i < count; i++) hadithJson(n: (page - 1) * 50 + i + 1),
  ],
};
