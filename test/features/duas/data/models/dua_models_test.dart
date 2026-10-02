import 'package:deen_companion/features/duas/data/models/dua_category_model.dart';
import 'package:deen_companion/features/duas/data/models/dua_model.dart';
import 'package:deen_companion/features/duas/data/models/dua_search_response_model.dart';
import 'package:deen_companion/features/duas/data/models/duas_bundle_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/dua_fixtures.dart';

void main() {
  test('DuaModel parses, converts to entity and round-trips', () {
    final model = DuaModel.fromJson(duaJson(id: 5));
    expect(model.repeat, 3);
    expect(model.toJson(), duaJson(id: 5));
    final e = model.toEntity();
    expect(e.id, 5);
    expect(e.transliteration, 'Allahumma');
  });

  test('DuaModel rejects missing or mistyped fields', () {
    expect(
      () => DuaModel.fromJson(duaJson()..remove('title')),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => DuaModel.fromJson(duaJson()..['repeat'] = '3'),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => DuaModel.fromJson(duaJson()..['id'] = null),
      throwsA(isA<TypeError>()),
    );
  });

  test('DuaCategoryModel parses and round-trips', () {
    final m = DuaCategoryModel.fromJson(duaCategoryJson(count: 7));
    expect(m.toEntity().count, 7);
    expect(m.toJson(), duaCategoryJson(count: 7));
    expect(
      () => DuaCategoryModel.fromJson({'id': 'x'}),
      throwsA(isA<TypeError>()),
    );
  });

  test('DuasBundleModel parses nested lists and round-trips', () {
    final m = DuasBundleModel.fromJson(bundleJson());
    expect(m.total, 3);
    expect(m.categories, hasLength(2));
    expect(m.toJson(), bundleJson());
    final e = m.toEntity();
    expect(e.duas, hasLength(3));
    expect(e.categories.last.id, 'evening');
  });

  test('DuasBundleModel with empty lists is valid', () {
    final e = DuasBundleModel.fromJson({
      'total': 0,
      'categories': [],
      'duas': [],
    }).toEntity();
    expect(e.duas, isEmpty);
    expect(e.byCategory('anything'), isEmpty);
  });

  test('DuaSearchResponseModel parses results', () {
    final m = DuaSearchResponseModel.fromJson(duaSearchJson());
    expect(m.resultsCount, 1);
    expect(m.results.single.id, 9);
    expect(
      () => DuaSearchResponseModel.fromJson({'query': 'x', 'results_count': 0}),
      throwsA(isA<TypeError>()),
    );
  });
}
