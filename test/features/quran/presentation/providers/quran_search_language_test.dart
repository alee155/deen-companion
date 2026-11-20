import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/quran/domain/entities/search_result.dart';
import 'package:deen_companion/features/quran/domain/repositories/quran_repository.dart';
import 'package:deen_companion/features/quran/presentation/providers/quran_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../core/fake_storage.dart';

class _Repo extends Mock implements QuranRepository {}

void main() {
  late _Repo repo;
  late FakeStorage storage;

  setUp(() {
    repo = _Repo();
    storage = FakeStorage();
    when(
      () => repo.search(any(), translation: any(named: 'translation')),
    ).thenAnswer((_) async => const Success(<SearchResult>[]));
  });

  Future<void> searchFor(String query, {required String language}) async {
    storage.boxes[AppConstants.settingsBoxName] = {
      'reader_translation_language': language,
    };
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        quranRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    await c.read(quranSearchNotifierProvider.notifier).search(query);
  }

  test('English chosen: always the English search, as before', () async {
    await searchFor('mercy', language: 'english');
    await searchFor('رحمت', language: 'english');
    verify(() => repo.search('mercy')).called(1);
    verify(() => repo.search('رحمت')).called(1);
    verifyNever(() => repo.search(any(), translation: 'urdu'));
  });

  test('Urdu chosen and Urdu typed: searches the Urdu translation', () async {
    await searchFor('رحمت', language: 'urdu');
    verify(() => repo.search('رحمت', translation: 'urdu')).called(1);
  });

  test(
    'Urdu chosen but a Latin query: still the English-matching search',
    () async {
      await searchFor('mercy', language: 'urdu');
      verify(() => repo.search('mercy')).called(1);
      verifyNever(() => repo.search(any(), translation: 'urdu'));
    },
  );
}
