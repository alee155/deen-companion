import 'package:deen_companion/features/asma_ul_husna/data/models/asma_daily_model.dart';
import 'package:deen_companion/features/asma_ul_husna/data/models/asma_name_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/names_fixtures.dart';

void main() {
  group('AsmaNameModel', () {
    test('parses, converts, round-trips', () {
      final m = AsmaNameModel.fromJson(asmaNameJson(n: 5));
      expect(m.toEntity().number, 5);
      expect(m.toEntity().transliteration, 'Ar-Rahman');
      expect(m.toJson(), asmaNameJson(n: 5));
    });

    test('missing/mistyped fields throw', () {
      expect(
        () => AsmaNameModel.fromJson(asmaNameJson()..remove('meaning')),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => AsmaNameModel.fromJson(asmaNameJson()..['number'] = '1'),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('AsmaDailyModel', () {
    test('parses nested names and round-trips', () {
      final m = AsmaDailyModel.fromJson(asmaDailyJson(day: 3));
      expect(m.dayNumber, 3);
      expect(m.names, hasLength(2));
      expect(m.toJson(), asmaDailyJson(day: 3));
      final e = m.toEntity();
      expect(e.names.last.number, 2);
      expect(e.weeklyCompletion, '14 of 99');
    });

    test('empty names list is valid; missing names throws', () {
      expect(
        AsmaDailyModel.fromJson(
          asmaDailyJson()..['names'] = [],
        ).toEntity().names,
        isEmpty,
      );
      expect(
        () => AsmaDailyModel.fromJson(asmaDailyJson()..remove('names')),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
