import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/islamic_names/domain/entities/islamic_name.dart';
import 'package:deen_companion/features/islamic_names/domain/repositories/islamic_names_repository.dart';
import 'package:deen_companion/features/islamic_names/presentation/providers/islamic_names_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements IslamicNamesRepository {}

IslamicName name(int id) => IslamicName(
  id: id,
  name: 'n$id',
  arabic: 'a',
  gender: 'male',
  meaning: 'm',
  origin: 'Arabic',
  note: '',
);

void main() {
  late MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getCachedNames()).thenReturn(null);
    container = ProviderContainer(
      overrides: [islamicNamesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('emits fetched names when nothing is cached', () async {
    when(
      () => repo.fetchAndCacheNames(),
    ).thenAnswer((_) async => Success([name(1)]));
    expect(
      await container.read(islamicNamesNotifierProvider.future),
      hasLength(1),
    );
  });

  test('emits cached first, then fresh data', () async {
    when(() => repo.getCachedNames()).thenReturn([name(1)]);
    when(
      () => repo.fetchAndCacheNames(),
    ).thenAnswer((_) async => Success([name(1), name(2)]));

    final sizes = <int>[];
    container.listen(islamicNamesNotifierProvider, (_, n) {
      if (n.hasValue) sizes.add(n.value!.length);
    }, fireImmediately: true);
    await pumpEventQueue();

    expect(sizes, [1, 2]);
  });

  test('no cache + failure: error is the Failure', () async {
    when(
      () => repo.fetchAndCacheNames(),
    ).thenAnswer((_) async => const Error(NetworkFailure()));
    final sub = container.listen(islamicNamesNotifierProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().error, isA<NetworkFailure>());
  });

  test('cached + failure: cached list stays visible', () async {
    when(() => repo.getCachedNames()).thenReturn([name(1)]);
    when(
      () => repo.fetchAndCacheNames(),
    ).thenAnswer((_) async => const Error(ServerFailure()));
    final sub = container.listen(islamicNamesNotifierProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().hasError, isFalse);
    expect(sub.read().value, hasLength(1));
  });
}
