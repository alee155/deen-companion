import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/zakat/data/datasources/zakat_remote_datasource.dart';
import 'package:deen_companion/features/zakat/data/models/zakat_calculation_model.dart';
import 'package:deen_companion/features/zakat/data/models/zakat_info_model.dart';
import 'package:deen_companion/features/zakat/data/models/zakat_nisab_model.dart';
import 'package:deen_companion/features/zakat/data/repositories/zakat_repository_impl.dart';
import 'package:deen_companion/features/zakat/domain/entities/zakat_calculation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';
import '../../_fixtures.dart';

class _MockRemote extends Mock implements ZakatRemoteDataSource {}

class _FakeReq extends Fake implements ZakatCalculateRequestModel {}

class _FakeAgri extends Fake implements ZakatAgricultureRequestModel {}

void main() {
  late _MockRemote remote;
  late PaStorage storage;
  late PaNetwork network;
  late ZakatRepositoryImpl repo;

  setUpAll(() {
    initFlavorForTests();
    registerFallbackValue(_FakeReq());
    registerFallbackValue(_FakeAgri());
  });

  setUp(() {
    remote = _MockRemote();
    storage = PaStorage();
    network = PaNetwork();
    repo = ZakatRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storage.cache,
      networkInfo: network,
    );
  });

  Failure failure<T>(Result<T> r) => (r as Error<T>).failure;
  T data<T>(Result<T> r) => (r as Success<T>).data;

  group('info caching', () {
    test('fetch caches; fresh cache (<90d) avoids network', () async {
      when(() => remote.getInfo()).thenAnswer((_) async => ZakatInfoModel.fromJson(infoJson()));
      expect(repo.getCachedInfo(), isNull);
      await repo.fetchAndCacheInfo();
      expect(repo.getCachedInfo()!.hawl, 'one year');
      await repo.fetchAndCacheInfo();
      verify(() => remote.getInfo()).called(1);
    });

    test('forceRefresh and >90d staleness both refetch', () async {
      when(() => remote.getInfo()).thenAnswer((_) async => ZakatInfoModel.fromJson(infoJson()));
      storage.seed('zakat_info', infoJson(), age: const Duration(days: 91));
      await repo.fetchAndCacheInfo();
      await repo.fetchAndCacheInfo(forceRefresh: true);
      verify(() => remote.getInfo()).called(2);
    });

    test('offline: stale cache served, otherwise NetworkFailure', () async {
      network.connected = false;
      expect(failure(await repo.fetchAndCacheInfo()), isA<NetworkFailure>());
      storage.seed('zakat_info', infoJson(), age: const Duration(days: 400));
      expect(data(await repo.fetchAndCacheInfo()).source, 'src');
    });

    test('server error: cache fallback or ServerFailure(message)', () async {
      when(() => remote.getInfo()).thenThrow(const ServerException('oops'));
      final f = failure(await repo.fetchAndCacheInfo());
      expect(f.message, 'oops');
      storage.seed('zakat_info', infoJson(), age: const Duration(days: 400));
      expect(data(await repo.fetchAndCacheInfo()).source, 'src');
    });

    test('unexpected error -> UnexpectedFailure', () async {
      when(() => remote.getInfo()).thenThrow(TypeError());
      expect(failure(await repo.fetchAndCacheInfo()), isA<UnexpectedFailure>());
    });
  });

  group('fetchNisab (never cached: prices change)', () {
    test('forwards prices and maps entity', () async {
      when(
        () => remote.getNisab(
          goldPricePerGram: any(named: 'goldPricePerGram'),
          silverPricePerGram: any(named: 'silverPricePerGram'),
        ),
      ).thenAnswer((_) async => ZakatNisabModel.fromJson(nisabJson()));
      final n = data(await repo.fetchNisab(goldPricePerGram: 70, silverPricePerGram: 0.9));
      expect(n.gold.monetaryValue, 6000.5);
      verify(() => remote.getNisab(goldPricePerGram: 70, silverPricePerGram: 0.9)).called(1);
    });

    test('offline / server / unexpected', () async {
      network.connected = false;
      expect(failure(await repo.fetchNisab()), isA<NetworkFailure>());
      network.connected = true;
      when(
        () => remote.getNisab(
          goldPricePerGram: any(named: 'goldPricePerGram'),
          silverPricePerGram: any(named: 'silverPricePerGram'),
        ),
      ).thenThrow(const ServerException());
      expect(failure(await repo.fetchNisab()), isA<ServerFailure>());
      when(
        () => remote.getNisab(
          goldPricePerGram: any(named: 'goldPricePerGram'),
          silverPricePerGram: any(named: 'silverPricePerGram'),
        ),
      ).thenThrow(StateError('x'));
      expect(failure(await repo.fetchNisab()), isA<UnexpectedFailure>());
    });
  });

  group('calculate: request construction', () {
    ZakatCalculateRequestModel? sent;

    setUp(() {
      sent = null;
      when(() => remote.calculate(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.single as ZakatCalculateRequestModel;
        return ZakatCalculateResponseModel.fromJson(calcJson());
      });
    });

    test('amounts of categories that are switched off are zeroed', () async {
      await repo.calculate(
        const ZakatCalculationInput(
          cash: 1000,
          goldGrams: 50,
          silverGrams: 400,
          stocks: 300,
          businessGoods: 200,
          otherInvestments: 100,
          liabilities: 250,
        ),
      );
      final j = sent!.toJson();
      for (final k in ['cash', 'gold_grams', 'silver_grams', 'stocks', 'business_goods', 'other_investments', 'liabilities']) {
        expect(j[k], 0, reason: k);
      }
    });

    test('only enabled categories carry their value', () async {
      await repo.calculate(
        const ZakatCalculationInput(
          includeCash: true,
          cash: 1000.75,
          includeGold: true,
          goldGrams: 50.5,
          silverGrams: 400,
          includeLiabilities: true,
          liabilities: 250,
          stocks: 999,
        ),
      );
      final j = sent!.toJson();
      expect(j['cash'], 1000.75);
      expect(j['gold_grams'], 50.5);
      expect(j['silver_grams'], 0);
      expect(j['stocks'], 0);
      expect(j['liabilities'], 250);
    });

    test('every include flag maps to its own field', () async {
      await repo.calculate(
        const ZakatCalculationInput(
          includeCash: true, cash: 1,
          includeGold: true, goldGrams: 2,
          includeSilver: true, silverGrams: 3,
          includeStocks: true, stocks: 4,
          includeBusinessGoods: true, businessGoods: 5,
          includeOtherInvestments: true, otherInvestments: 6,
          includeLiabilities: true, liabilities: 7,
        ),
      );
      final j = sent!.toJson();
      expect([j['cash'], j['gold_grams'], j['silver_grams'], j['stocks'], j['business_goods'], j['other_investments'], j['liabilities']],
          [1, 2, 3, 4, 5, 6, 7]);
    });

    test('nisab standard and optional prices are forwarded', () async {
      await repo.calculate(
        const ZakatCalculationInput(
          nisabStandard: NisabStandard.silver,
          goldPricePerGram: 70,
        ),
      );
      final j = sent!.toJson();
      expect(j['nisab_standard'], 'silver');
      expect(j['gold_price_per_gram'], 70);
      expect(j.containsKey('silver_price_per_gram'), isFalse);
    });

    test('default standard is gold', () async {
      await repo.calculate(const ZakatCalculationInput());
      expect(sent!.toJson()['nisab_standard'], 'gold');
    });

    test('result is mapped to the entity', () async {
      final r = data(await repo.calculate(const ZakatCalculationInput()));
      expect(r.zakatDue, 412.51);
      expect(r.nisabStandard, NisabStandard.gold);
    });
  });

  group('calculate / agriculture: failures', () {
    test('offline short-circuits before the datasource', () async {
      network.connected = false;
      expect(failure(await repo.calculate(const ZakatCalculationInput())), isA<NetworkFailure>());
      expect(failure(await repo.calculateAgriculture(100, WaterSource.rain)), isA<NetworkFailure>());
      verifyNever(() => remote.calculate(any()));
      verifyNever(() => remote.calculateAgriculture(any()));
    });

    test('server errors keep their message; null message uses default', () async {
      when(() => remote.calculate(any())).thenThrow(const ServerException('bad input'));
      expect(failure(await repo.calculate(const ZakatCalculationInput())).message, 'bad input');
      when(() => remote.calculateAgriculture(any())).thenThrow(const ServerException());
      expect(
        failure(await repo.calculateAgriculture(1, WaterSource.rain)).message,
        const ServerFailure().message,
      );
    });

    test('unexpected errors', () async {
      when(() => remote.calculate(any())).thenThrow(StateError('x'));
      expect(failure(await repo.calculate(const ZakatCalculationInput())), isA<UnexpectedFailure>());
      when(() => remote.calculateAgriculture(any())).thenThrow(StateError('x'));
      expect(failure(await repo.calculateAgriculture(1, WaterSource.rain)), isA<UnexpectedFailure>());
    });
  });

  group('calculateAgriculture', () {
    test('sends the water source string and value', () async {
      ZakatAgricultureRequestModel? sent;
      when(() => remote.calculateAgriculture(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.single as ZakatAgricultureRequestModel;
        return ZakatAgricultureResponseModel.fromJson(agriJson(water: 'irrigation'));
      });
      final r = data(await repo.calculateAgriculture(2500.5, WaterSource.irrigation));
      expect(sent!.toJson(), {'value': 2500.5, 'water_source': 'irrigation'});
      expect(r.waterSource, WaterSource.irrigation);
      await repo.calculateAgriculture(1, WaterSource.rain);
      expect(sent!.waterSource, 'rain');
    });
  });
}
