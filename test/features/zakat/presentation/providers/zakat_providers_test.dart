import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/zakat/domain/entities/zakat_calculation.dart';
import 'package:deen_companion/features/zakat/domain/entities/zakat_info.dart';
import 'package:deen_companion/features/zakat/domain/entities/zakat_nisab.dart';
import 'package:deen_companion/features/zakat/domain/repositories/zakat_repository.dart';
import 'package:deen_companion/features/zakat/presentation/providers/zakat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _breakdown = ZakatBreakdown(
  cash: 1, goldValue: 0, silverValue: 0, stocks: 0, businessGoods: 0,
  otherInvestments: 0, grossWealth: 1, liabilities: 0, netZakatableWealth: 1,
);
const _result = ZakatCalculationResult(
  zakatDue: 25, aboveNisab: true, nisabStandard: NisabStandard.gold,
  nisabValue: 100, nisabGoldGrams: 87, nisabSilverGrams: 612,
  rate: '2.5%', breakdown: _breakdown, note: 'n',
);
const _agri = AgricultureZakatResult(
  value: 100, waterSource: WaterSource.rain, rate: '10%', zakatDue: 10, note: 'n',
);
const _info = ZakatInfo(
  definition: 'd',
  nisabGold: ZakatNisabInfo(grams: 87, description: 'g'),
  nisabSilver: ZakatNisabInfo(grams: 612, description: 's'),
  nisabNote: 'n', rateGeneral: '2.5%', rateAgricultureRain: '10%',
  rateAgricultureIrrigated: '5%', conditions: [], eligibleRecipients: [],
  zakatableAssets: [], nonZakatableAssets: [], hawl: 'h', disclaimer: 'd', source: 's',
);

class _Repo implements ZakatRepository {
  Result<ZakatCalculationResult> calc = const Success(_result);
  Result<AgricultureZakatResult> agri = const Success(_agri);
  Result<ZakatInfo> info = const Success(_info);
  ZakatInfo? cached;
  ZakatCalculationInput? lastInput;
  (double, WaterSource)? lastAgri;

  @override
  ZakatInfo? getCachedInfo() => cached;
  @override
  Future<Result<ZakatInfo>> fetchAndCacheInfo({bool forceRefresh = false}) async => info;
  @override
  Future<Result<ZakatNisab>> fetchNisab({double? goldPricePerGram, double? silverPricePerGram}) async =>
      const Error(NetworkFailure());
  @override
  Future<Result<ZakatCalculationResult>> calculate(ZakatCalculationInput input) async {
    lastInput = input;
    return calc;
  }

  @override
  Future<Result<AgricultureZakatResult>> calculateAgriculture(double value, WaterSource w) async {
    lastAgri = (value, w);
    return agri;
  }
}

void main() {
  late _Repo repo;
  ProviderContainer make() {
    repo = _Repo();
    final c = ProviderContainer(overrides: [zakatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    return c;
  }

  group('ZakatCalculatorNotifier', () {
    test('starts with null data', () async {
      final c = make();
      expect(await c.read(zakatCalculatorNotifierProvider.future), isNull);
    });

    test('calculate success -> AsyncData(result) and forwards the input', () async {
      final c = make();
      const input = ZakatCalculationInput(includeCash: true, cash: 1000);
      await c.read(zakatCalculatorNotifierProvider.notifier).calculate(input);
      expect(c.read(zakatCalculatorNotifierProvider).value, _result);
      expect(identical(repo.lastInput, input), isTrue);
    });

    test('calculate failure -> AsyncError holding the Failure', () async {
      final c = make();
      repo.calc = const Error(NetworkFailure());
      await c.read(zakatCalculatorNotifierProvider.notifier).calculate(const ZakatCalculationInput());
      final s = c.read(zakatCalculatorNotifierProvider);
      expect(s.hasError, isTrue);
      expect(s.error, isA<NetworkFailure>());
    });

    test('reset clears a previous result and error', () async {
      final c = make();
      final n = c.read(zakatCalculatorNotifierProvider.notifier);
      await n.calculate(const ZakatCalculationInput());
      n.reset();
      expect(c.read(zakatCalculatorNotifierProvider).value, isNull);
      repo.calc = const Error(ServerFailure());
      await n.calculate(const ZakatCalculationInput());
      n.reset();
      expect(c.read(zakatCalculatorNotifierProvider).hasError, isFalse);
    });

    test('goes through AsyncLoading while calculating', () async {
      final c = make();
      final states = <AsyncValue<ZakatCalculationResult?>>[];
      c.listen(zakatCalculatorNotifierProvider, (_, n) => states.add(n), fireImmediately: false);
      await c.read(zakatCalculatorNotifierProvider.future);
      await c.read(zakatCalculatorNotifierProvider.notifier).calculate(const ZakatCalculationInput());
      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.value, _result);
    });
  });

  group('AgricultureZakatNotifier', () {
    test('success passes value and water source', () async {
      final c = make();
      await c.read(agricultureZakatNotifierProvider.notifier).calculate(750.5, WaterSource.irrigation);
      expect(c.read(agricultureZakatNotifierProvider).value, _agri);
      expect(repo.lastAgri, (750.5, WaterSource.irrigation));
    });

    test('failure becomes AsyncError', () async {
      final c = make();
      repo.agri = const Error(ServerFailure());
      await c.read(agricultureZakatNotifierProvider.notifier).calculate(1, WaterSource.rain);
      expect(c.read(agricultureZakatNotifierProvider).error, isA<ServerFailure>());
    });
  });

  group('ZakatInfoNotifier', () {
    test('cache then fresh', () async {
      final c = make();
      repo.cached = _info;
      expect(await c.read(zakatInfoNotifierProvider.future), _info);
    });

    test('failure with no cache is an error', () async {
      final c = make();
      repo.info = const Error(NetworkFailure());
      await expectLater(c.read(zakatInfoNotifierProvider.future), throwsA(isA<NetworkFailure>()));
    });
  });
}
