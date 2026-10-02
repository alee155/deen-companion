import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/entities/asma_daily.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/entities/asma_name.dart';
import 'package:deen_companion/features/asma_ul_husna/domain/repositories/asma_ul_husna_repository.dart';
import 'package:deen_companion/features/asma_ul_husna/presentation/providers/asma_ul_husna_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements AsmaUlHusnaRepository {}

AsmaName name(int n) => AsmaName(
  number: n,
  arabic: 'a',
  transliteration: 't',
  english: 'e',
  meaning: 'm',
);

void main() {
  late MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getCachedAllNames()).thenReturn(null);
    container = ProviderContainer(
      overrides: [asmaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  group('AsmaAllNamesNotifier', () {
    test('serves cache then fresh list', () async {
      when(() => repo.getCachedAllNames()).thenReturn([name(1)]);
      when(
        () => repo.fetchAndCacheAllNames(),
      ).thenAnswer((_) async => Success([name(1), name(2)]));

      final sizes = <int>[];
      container.listen(asmaAllNamesNotifierProvider, (_, n) {
        if (n.hasValue) sizes.add(n.value!.length);
      }, fireImmediately: true);
      await pumpEventQueue();

      expect(sizes, [1, 2]);
    });

    test('no cache + failure surfaces Failure', () async {
      when(
        () => repo.fetchAndCacheAllNames(),
      ).thenAnswer((_) async => const Error(NetworkFailure()));
      final sub = container.listen(asmaAllNamesNotifierProvider, (_, _) {});
      await pumpEventQueue();
      expect(sub.read().error, isA<NetworkFailure>());
    });
  });

  group('AsmaDailyNotifier', () {
    const daily = AsmaDaily(
      dayNumber: 2,
      dayName: 'Tue',
      names: [],
      count: 0,
      suggestion: 's',
      weeklyCompletion: 'w',
    );

    test('passes the day number to the repository', () async {
      when(
        () => repo.fetchDailyNames(2),
      ).thenAnswer((_) async => const Success(daily));
      expect(
        (await container.read(asmaDailyNotifierProvider(2).future)).dayName,
        'Tue',
      );
    });

    test('failure is thrown as the Failure', () async {
      when(
        () => repo.fetchDailyNames(any()),
      ).thenAnswer((_) async => const Error(ServerFailure('x')));
      await expectLater(
        container.read(asmaDailyNotifierProvider(1).future),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('AsmaSearchNotifier', () {
    test('blank resets to null without searching', () async {
      await container.read(asmaSearchNotifierProvider.notifier).search('  ');
      expect(container.read(asmaSearchNotifierProvider).value, isNull);
      verifyNever(() => repo.search(any()));
    });

    test('trims and returns results', () async {
      when(
        () => repo.search('mercy'),
      ).thenAnswer((_) async => Success([name(1)]));
      await container
          .read(asmaSearchNotifierProvider.notifier)
          .search(' mercy ');
      expect(container.read(asmaSearchNotifierProvider).value, hasLength(1));
    });

    test('failure -> AsyncError(Failure)', () async {
      when(
        () => repo.search(any()),
      ).thenAnswer((_) async => const Error(NetworkFailure()));
      await container.read(asmaSearchNotifierProvider.notifier).search('a');
      expect(
        container.read(asmaSearchNotifierProvider).error,
        isA<NetworkFailure>(),
      );
    });
  });
}
