Map<String, dynamic> verseRefJson({
  String key = '2:1',
  int surah = 2,
  int ayah = 1,
}) => {
  'verse_key': key,
  'surah': surah,
  'ayah': ayah,
  'surah_name_arabic': 'البقرة',
  'surah_name_english': 'Al-Baqarah',
  'arabic': 'الم',
  'translation': 'Alif Lam Mim',
};

Map<String, dynamic> entryJson({String key = '2:1', int similar = 2}) => {
  ...verseRefJson(key: key),
  'similar_verses': [
    for (var i = 0; i < similar; i++)
      verseRefJson(key: '3:${i + 1}', surah: 3, ayah: i + 1),
  ],
};

Map<String, dynamic> infoJson() => {
  'description': 'Similar verses',
  'total_entries': 1000,
  'total_pairs': 2500,
  'surahs_involved': 110,
  'source': 'Dataset',
  'attribution': 'Credit',
};

Map<String, dynamic> surahPageJson({
  int surah = 2,
  int page = 1,
  int totalPages = 2,
  int count = 2,
}) => {
  'surah': surah,
  'surah_name_arabic': 'البقرة',
  'surah_name_english': 'Al-Baqarah',
  'total': 40,
  'page': page,
  'limit': 20,
  'total_pages': totalPages,
  'verses': [
    for (var i = 0; i < count; i++) entryJson(key: '$surah:${page * 100 + i}'),
  ],
};
