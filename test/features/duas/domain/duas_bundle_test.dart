import 'package:deen_companion/features/duas/data/models/duas_bundle_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_support/dua_fixtures.dart';

void main() {
  group('DuasBundle.byCategory', () {
    final bundle = DuasBundleModel.fromJson(bundleJson()).toEntity();

    test('returns only duas of that category, preserving order', () {
      expect(bundle.byCategory('morning').map((d) => d.id), [1, 2]);
      expect(bundle.byCategory('evening').map((d) => d.id), [3]);
    });

    test('unknown category yields an empty list', () {
      expect(bundle.byCategory('nope'), isEmpty);
    });

    test('match is case-sensitive and exact', () {
      expect(bundle.byCategory('Morning'), isEmpty);
      expect(bundle.byCategory('morn'), isEmpty);
    });

    test('returns a fresh list each call', () {
      final a = bundle.byCategory('morning');
      a.clear();
      expect(bundle.byCategory('morning'), hasLength(2));
    });
  });
}
