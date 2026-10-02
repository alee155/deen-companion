Map<String, dynamic> surahJson({
  int number = 1,
  String english = 'Al-Fatihah',
}) => {
  'number': number,
  'name_arabic': 'الفاتحة',
  'name_english': english,
  'name_translation': 'The Opener',
  'revelation_place': 'Makkah',
  'verses_count': 7,
  'bismillah_pre': false,
  'audio': {'reciters_available': 3, 'example_audio': 'https://a/$number.mp3'},
};

Map<String, dynamic> metaJson({int surahs = 114}) => {
  'total_surahs': surahs,
  'total_verses': 6236,
  'total_juzs': 30,
  'total_pages': 604,
  'text_type': 'uthmani',
  'translations_available': ['sahih_international', 'pickthall'],
  'reciters': [
    {'id': 1, 'name': 'Alafasy', 'style': 'Murattal'},
  ],
};

Map<String, dynamic> juzJson({int number = 1}) => {
  'juz_number': number,
  'total_verses': 2,
  'verses': [
    {
      'verse_key': '1:1',
      'surah_name': 'Al-Fatihah',
      'ayah': 1,
      'arabic': 'بسم',
      'transliteration': 'bismi',
      'translations': {'sahih_international': 'In the name'},
    },
    {
      'verse_key': '1:2',
      'surah_name': 'Al-Fatihah',
      'ayah': 2,
      'arabic': 'الحمد',
      'transliteration': 'alhamdu',
      'translations': <String, String>{},
    },
  ],
};

Map<String, dynamic> wordJson(int pos, int line, {String key = '1:1'}) => {
  'position': pos,
  'text_uthmani': 'w$pos',
  'text_uthmani_tajweed': '<t>w$pos</t>',
  'line_number': line,
  'char_type_name': 'word',
  'verse_key': key,
};

Map<String, dynamic> pageJson({int page = 1}) => {
  'page': page,
  'total_pages': 604,
  'lines_per_page': 15,
  'words': [wordJson(1, 1), wordJson(2, 1), wordJson(3, 2)],
};

Map<String, dynamic> searchResultJson({String key = '2:255'}) => {
  'verse_key': key,
  'surah_number': 2,
  'surah_name': 'Al-Baqarah',
  'ayah': 255,
  'arabic': 'الله لا إله إلا هو',
  'transliteration': 'allahu',
  'translation': 'Allah - there is no deity',
  'matched_in': 'translation',
  'translation_source': 'sahih_international',
};

Map<String, dynamic> searchResponseJson() => {
  'query': 'throne',
  'searched_in': ['translation'],
  'results_count': 1,
  'limit': 25,
  'results': [searchResultJson()],
};

Map<String, dynamic> envelope(Object? data) => {
  'success': true,
  'service': 'ummah',
  'data': data,
};
