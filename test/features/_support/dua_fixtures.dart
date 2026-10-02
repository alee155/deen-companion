Map<String, dynamic> duaJson({int id = 1, String category = 'morning'}) => {
  'id': id,
  'category': category,
  'title': 'Dua $id',
  'arabic': 'اللهم',
  'transliteration': 'Allahumma',
  'translation': 'O Allah',
  'source': 'Bukhari',
  'repeat': 3,
};

Map<String, dynamic> duaCategoryJson({String id = 'morning', int count = 2}) =>
    {
      'id': id,
      'name': 'Morning',
      'description': 'Morning duas',
      'count': count,
    };

Map<String, dynamic> bundleJson() => {
  'total': 3,
  'categories': [duaCategoryJson(), duaCategoryJson(id: 'evening', count: 1)],
  'duas': [duaJson(id: 1), duaJson(id: 2), duaJson(id: 3, category: 'evening')],
};

Map<String, dynamic> duaSearchJson() => {
  'query': 'morning',
  'results_count': 1,
  'results': [duaJson(id: 9)],
};
