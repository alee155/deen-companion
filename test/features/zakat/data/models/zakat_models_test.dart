import 'package:deen_companion/features/zakat/data/models/zakat_calculation_model.dart';
import 'package:deen_companion/features/zakat/data/models/zakat_info_model.dart';
import 'package:deen_companion/features/zakat/data/models/zakat_nisab_model.dart';
import 'package:deen_companion/features/zakat/domain/entities/zakat_calculation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_fixtures.dart';

void main() {
  group('ZakatCalculateRequestModel.toJson', () {
    ZakatCalculateRequestModel req({double? gold, double? silver}) =>
        ZakatCalculateRequestModel(
          goldPricePerGram: gold,
          silverPricePerGram: silver,
          nisabStandard: 'silver',
          cash: 1,
          goldGrams: 2,
          silverGrams: 3,
          stocks: 4,
          businessGoods: 5,
          otherInvestments: 6,
          liabilities: 7,
        );

    test('omits price keys when null so the server uses live prices', () {
      final j = req().toJson();
      expect(j.containsKey('gold_price_per_gram'), isFalse);
      expect(j.containsKey('silver_price_per_gram'), isFalse);
    });

    test('includes provided prices and all snake_case amount keys', () {
      final j = req(gold: 65.5, silver: 0.8).toJson();
      expect(j['gold_price_per_gram'], 65.5);
      expect(j['silver_price_per_gram'], 0.8);
      expect(j, containsPair('nisab_standard', 'silver'));
      expect(j['business_goods'], 5);
      expect(j['other_investments'], 6);
      expect(j['gold_grams'], 2);
      expect(j['liabilities'], 7);
    });

    test('a price of 0 is still sent (only null is omitted)', () {
      expect(req(gold: 0).toJson()['gold_price_per_gram'], 0);
    });
  });

  group('ZakatCalculateResponseModel', () {
    test('parses numbers; ints from JSON become doubles', () {
      final m = ZakatCalculateResponseModel.fromJson(calcJson());
      expect(m.zakatDue, 412.51);
      expect(m.breakdown.cash, 10000.0);
      expect(m.breakdown.cash, isA<double>());
      expect(m.nisabGoldGrams, 87);
      expect(m.breakdown.netZakatableWealth, 16500.5);
      expect(m.rate, '2.5%');
    });

    test('toEntity maps standard strings: silver -> silver, anything else -> gold', () {
      expect(
        ZakatCalculateResponseModel.fromJson(calcJson(standard: 'silver')).toEntity().nisabStandard,
        NisabStandard.silver,
      );
      expect(
        ZakatCalculateResponseModel.fromJson(calcJson(standard: 'gold')).toEntity().nisabStandard,
        NisabStandard.gold,
      );
      expect(
        ZakatCalculateResponseModel.fromJson(calcJson(standard: 'platinum')).toEntity().nisabStandard,
        NisabStandard.gold,
      );
    });

    test('below-nisab result keeps aboveNisab=false and the zero due', () {
      final j = calcJson(above: false)..['zakat_due'] = 0;
      final e = ZakatCalculateResponseModel.fromJson(j).toEntity();
      expect(e.aboveNisab, isFalse);
      expect(e.zakatDue, 0);
    });

    test('fractional gram thresholds (API drift) fail loudly, not silently', () {
      final j = calcJson()..['nisab_gold_grams'] = 87.48;
      expect(() => ZakatCalculateResponseModel.fromJson(j), throwsA(isA<TypeError>()));
    });

    test('missing breakdown / null above_nisab throw', () {
      expect(
        () => ZakatCalculateResponseModel.fromJson(calcJson()..remove('breakdown')),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => ZakatCalculateResponseModel.fromJson(calcJson()..['above_nisab'] = null),
        throwsA(isA<TypeError>()),
      );
    });

    test('breakdown entity preserves every field', () {
      final b = ZakatCalculateResponseModel.fromJson(calcJson()).toEntity().breakdown;
      expect(b.goldValue, 5000.5);
      expect(b.businessGoods, 2500);
      expect(b.grossWealth - b.liabilities, b.netZakatableWealth);
    });
  });

  group('Agriculture', () {
    test('request json', () {
      expect(
        const ZakatAgricultureRequestModel(value: 5000.25, waterSource: 'irrigation').toJson(),
        {'value': 5000.25, 'water_source': 'irrigation'},
      );
    });

    test('response water source mapping', () {
      expect(
        ZakatAgricultureResponseModel.fromJson(agriJson(water: 'irrigation')).toEntity().waterSource,
        WaterSource.irrigation,
      );
      expect(
        ZakatAgricultureResponseModel.fromJson(agriJson(water: 'rain')).toEntity().waterSource,
        WaterSource.rain,
      );
      expect(
        ZakatAgricultureResponseModel.fromJson(agriJson(water: 'mixed')).toEntity().waterSource,
        WaterSource.rain,
      );
    });

    test('values parsed as doubles; missing field throws', () {
      final m = ZakatAgricultureResponseModel.fromJson(agriJson());
      expect(m.value, 1000.0);
      expect(m.zakatDue, 100.0);
      expect(
        () => ZakatAgricultureResponseModel.fromJson(agriJson()..remove('rate')),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('ZakatInfoModel', () {
    test('parses nested nisab/rate and lists', () {
      final m = ZakatInfoModel.fromJson(infoJson());
      expect(m.nisabGold.grams, 87);
      expect(m.nisabSilver.grams, 612);
      expect(m.rateAgricultureIrrigated, '5%');
      expect(m.conditions, ['a', 'b']);
      expect(m.nonZakatableAssets, ['house']);
    });

    test('round trip via toJson', () {
      final m = ZakatInfoModel.fromJson(infoJson());
      expect(ZakatInfoModel.fromJson(m.toJson()).toJson(), m.toJson());
      expect(m.toJson(), infoJson());
    });

    test('empty lists are fine; a null list throws', () {
      final j = infoJson()..['conditions'] = <String>[];
      expect(ZakatInfoModel.fromJson(j).conditions, isEmpty);
      expect(
        () => ZakatInfoModel.fromJson(infoJson()..['conditions'] = null),
        throwsA(isA<TypeError>()),
      );
    });

    test('missing nisab block throws', () {
      expect(
        () => ZakatInfoModel.fromJson(infoJson()..remove('nisab')),
        throwsA(isA<TypeError>()),
      );
    });

    test('toEntity carries all fields', () {
      final e = ZakatInfoModel.fromJson(infoJson()).toEntity();
      expect(e.definition, 'def');
      expect(e.nisabGold.description, 'g');
      expect(e.hawl, 'one year');
      expect(e.source, 'src');
    });
  });

  group('ZakatNisabModel', () {
    test('monetary_value is optional (null when prices not supplied)', () {
      final m = ZakatNisabModel.fromJson(nisabJson());
      expect(m.gold.monetaryValue, 6000.5);
      expect(m.silver.monetaryValue, isNull);
      expect(m.zakatRate, '2.5%');
    });

    test('integer monetary value coerces to double', () {
      expect(ZakatNisabModel.fromJson(nisabJson(goldValue: 6000)).gold.monetaryValue, 6000.0);
    });

    test('string monetary value throws', () {
      expect(() => ZakatNisabModel.fromJson(nisabJson(goldValue: '6000')), throwsA(isA<TypeError>()));
    });

    test('toEntity', () {
      final e = ZakatNisabModel.fromJson(nisabJson()).toEntity();
      expect(e.gold.thresholdGrams, 87);
      expect(e.silver.thresholdGrams, 612);
      expect(e.note, 'n');
    });
  });
}
