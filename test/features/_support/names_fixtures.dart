Map<String, dynamic> asmaNameJson({int n = 1}) => {
  'number': n,
  'arabic': 'الرحمن',
  'transliteration': 'Ar-Rahman',
  'english': 'The Most Gracious',
  'meaning': 'Gracious',
};

Map<String, dynamic> asmaDailyJson({int day = 1}) => {
  'day_number': day,
  'day_name': 'Monday',
  'names': [asmaNameJson(n: 1), asmaNameJson(n: 2)],
  'count': 2,
  'suggestion': 'Recite 100x',
  'weekly_completion': '14 of 99',
};

Map<String, dynamic> islamicNameJson({
  int id = 1,
  String name = 'Aisha',
  String arabic = 'عائشة',
  String gender = 'female',
  String meaning = 'Alive',
  String origin = 'Arabic',
  String? root = 'ع-ي-ش',
  String note = 'Wife of the Prophet',
}) => {
  'id': id,
  'name': name,
  'arabic': arabic,
  'gender': gender,
  'meaning': meaning,
  'origin': origin,
  'root': root,
  'note': note,
};
