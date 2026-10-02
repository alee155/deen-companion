import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/duas/domain/entities/dua.dart';
import 'package:deen_companion/features/duas/domain/entities/duas_bundle.dart';
import 'package:deen_companion/features/duas/domain/repositories/dua_repository.dart';
import 'package:deen_companion/features/duas/presentation/providers/dua_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements DuaRepository {}

const dua = Dua(
  id: 1,
  category: 'c',
  title: 't',
  arabic: 'a',
  transliteration: 'tr',
  translation: 'x',
  source: 's',
  repeat: 1,
);
const bundle = DuasBundle(categories: [], duas: [dua]);

void main() {
  late MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getCachedBundle()).thenReturn(null);
    container = ProviderContainer(
      overrides: [duaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  group('DuasBundleNotifier', () {
    test('emits fetched bundle', () async {
      when(
        () => repo.fetchAndCacheBundle(),
      ).thenAnswer((_) async => const Success(bundle));
      expect(await container.read(duasBundleNotifierProvider.future), bundle);
    });

    test('shows cached bundle then the fresh one', () async {
      const fresh = DuasBundle(categories: [], duas: []);
      when(() => repo.getCachedBundle()).thenReturn(bundle);
      when(
        () => repo.fetchAndCacheBundle(),
      ).thenAnswer((_) async => const Success(fresh));

      final seen = <DuasBundle>[];
      container.listen(duasBundleNotifierProvider, (_, n) {
        if (n.hasValue) seen.add(n.value!);
      }, fireImmediately: true);
      await pumpEventQueue();

      expect(seen, [bundle, fresh]);
    });

    test(
      'cached + fetch failure keeps cache; no cache + failure errors',
      () async {
        when(
          () => repo.fetchAndCacheBundle(),
        ).thenAnswer((_) async => const Error(NetworkFailure()));

        final sub = container.listen(duasBundleNotifierProvider, (_, _) {});
        await pumpEventQueue();
        expect(sub.read().error, isA<NetworkFailure>());

        when(() => repo.getCachedBundle()).thenReturn(bundle);
        container.invalidate(duasBundleNotifierProvider);
        await pumpEventQueue();
        expect(sub.read().hasError, isFalse);
        expect(sub.read().value, bundle);
      },
    );
  });

  group('DuaSearchNotifier', () {
    test('starts null; blank input never hits the repository', () async {
      expect(container.read(duaSearchNotifierProvider).value, isNull);
      await container.read(duaSearchNotifierProvider.notifier).search('  \n');
      expect(container.read(duaSearchNotifierProvider).value, isNull);
      verifyNever(() => repo.search(any()));
    });

    test('trims query and publishes results', () async {
      when(
        () => repo.search('sleep'),
      ).thenAnswer((_) async => const Success([dua]));
      await container
          .read(duaSearchNotifierProvider.notifier)
          .search(' sleep ');
      expect(container.read(duaSearchNotifierProvider).value, [dua]);
    });

    test('failure becomes AsyncError(Failure)', () async {
      when(
        () => repo.search(any()),
      ).thenAnswer((_) async => const Error(ServerFailure('x')));
      await container.read(duaSearchNotifierProvider.notifier).search('a');
      final s = container.read(duaSearchNotifierProvider);
      expect(s.hasError, isTrue);
      expect((s.error as Failure).message, 'x');
    });

    test('empty results are data([]) not null', () async {
      when(
        () => repo.search(any()),
      ).thenAnswer((_) async => const Success(<Dua>[]));
      await container.read(duaSearchNotifierProvider.notifier).search('a');
      expect(container.read(duaSearchNotifierProvider).value, isEmpty);
    });
  });
}
