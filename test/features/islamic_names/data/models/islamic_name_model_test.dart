import 'package:deen_companion/features/islamic_names/data/models/islamic_name_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/names_fixtures.dart';

void main() {
  test('parses all fields and converts to entity', () {
    final e = IslamicNameModel.fromJson(islamicNameJson()).toEntity();
    expect(e.id, 1);
    expect(e.name, 'Aisha');
    expect(e.arabic, 'عائشة');
    expect(e.gender, 'female');
    expect(e.root, 'ع-ي-ش');
  });

  test('root is optional: null and absent both parse to null', () {
    expect(IslamicNameModel.fromJson(islamicNameJson(root: null)).root, isNull);
    final json = islamicNameJson()..remove('root');
    expect(IslamicNameModel.fromJson(json).toEntity().root, isNull);
  });

  test('toJson keeps a null root and round-trips', () {
    final json = islamicNameJson(root: null);
    expect(IslamicNameModel.fromJson(json).toJson(), json);
    expect(
      IslamicNameModel.fromJson(islamicNameJson()).toJson(),
      islamicNameJson(),
    );
  });

  test('required fields are strict', () {
    expect(
      () => IslamicNameModel.fromJson(islamicNameJson()..remove('note')),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => IslamicNameModel.fromJson(islamicNameJson()..['id'] = '1'),
      throwsA(isA<TypeError>()),
    );
  });
}
