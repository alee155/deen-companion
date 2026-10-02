import 'dart:convert';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:deen_companion/features/favorites/data/models/favorite_item_model.dart';
import 'package:deen_companion/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:deen_companion/features/favorites/domain/entities/favorite_item.dart';
import 'package:deen_companion/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_storage_service.dart';

FavoriteItem item(
  FavoriteContentType type,
  String ref, {
  DateTime? savedAt,
  String? subtitle,
}) => FavoriteItem(
  id: FavoriteItem.buildId(type, ref),
  type: type,
  referenceId: ref,
  title: 'T $ref',
  subtitle: subtitle,
  route: '/r/$ref',
  savedAt: savedAt ?? DateTime.utc(2024, 1, 1),
);

void main() {
  const box = AppConstants.bookmarksBoxName;

  group('FavoriteItem', () {
    test('buildId is type:referenceId', () {
      expect(FavoriteItem.buildId(FavoriteContentType.surah, '36'), 'surah:36');
      expect(
        FavoriteItem.buildId(FavoriteContentType.asmaName, 'x'),
        'asmaName:x',
      );
    });

    test('every type has a distinct non-empty label', () {
      final labels = FavoriteContentType.values.map((t) => t.label).toSet();
      expect(labels, hasLength(FavoriteContentType.values.length));
      expect(labels.every((l) => l.isNotEmpty), isTrue);
    });

    test('value equality', () {
      expect(
        item(FavoriteContentType.dua, '1'),
        item(FavoriteContentType.dua, '1'),
      );
      expect(
        item(FavoriteContentType.dua, '1'),
        isNot(item(FavoriteContentType.dua, '2')),
      );
    });
  });

  group('FavoriteItemModel', () {
    test('entity -> model -> json -> model -> entity round trips', () {
      final e = item(
        FavoriteContentType.hadith,
        'bukhari:1',
        savedAt: DateTime.utc(2025, 5, 6, 7, 8, 9),
        subtitle: 'sub',
      );
      final json = FavoriteItemModel.fromEntity(e).toJson();
      final back = FavoriteItemModel.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      ).toEntity();
      expect(back, e);
    });

    test('null subtitle stays null', () {
      final m = FavoriteItemModel.fromEntity(
        item(FavoriteContentType.juz, '3'),
      );
      expect(m.toJson()['subtitle'], isNull);
      expect(m.toEntity().subtitle, isNull);
    });

    test('fromJson throws on missing required field', () {
      expect(
        () => FavoriteItemModel.fromJson({'id': 'x'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('toEntity throws for unknown type name', () {
      const m = FavoriteItemModel(
        id: 'a',
        type: 'bogus',
        referenceId: 'r',
        title: 't',
        route: '/',
        savedAt: '2024-01-01T00:00:00.000Z',
      );
      expect(m.toEntity, throwsStateError);
    });

    test('toEntity throws for malformed date', () {
      const m = FavoriteItemModel(
        id: 'a',
        type: 'dua',
        referenceId: 'r',
        title: 't',
        route: '/',
        savedAt: 'not a date',
      );
      expect(m.toEntity, throwsFormatException);
    });
  });

  group('FavoritesLocalDataSourceImpl', () {
    late InMemoryStorageService storage;
    late FavoritesLocalDataSourceImpl ds;
    setUp(() {
      storage = InMemoryStorageService();
      ds = FavoritesLocalDataSourceImpl(storage);
    });

    test('add/isFavorite/remove', () async {
      final m = FavoriteItemModel.fromEntity(
        item(FavoriteContentType.dua, '1'),
      );
      expect(ds.isFavorite(m.id), isFalse);
      await ds.add(m);
      expect(ds.isFavorite(m.id), isTrue);
      expect(ds.getAll().single.id, m.id);
      await ds.remove(m.id);
      expect(ds.isFavorite(m.id), isFalse);
      expect(ds.getAll(), isEmpty);
    });

    test('stored value is JSON string keyed by id', () async {
      final m = FavoriteItemModel.fromEntity(
        item(FavoriteContentType.dua, '1'),
      );
      await ds.add(m);
      final raw = storage.get<String>(box, m.id)!;
      expect(jsonDecode(raw)['title'], 'T 1');
    });

    test('adding same id overwrites rather than duplicates', () async {
      final m = FavoriteItemModel.fromEntity(
        item(FavoriteContentType.dua, '1'),
      );
      await ds.add(m);
      await ds.add(m);
      expect(ds.getAll(), hasLength(1));
    });

    test('corrupted stored value throws on getAll', () async {
      await storage.put(box, 'bad', 'not json');
      expect(ds.getAll, throwsFormatException);
    });

    test('watchChanges fires on writes', () async {
      final events = <void>[];
      final sub = ds.watchChanges().listen(events.add);
      await ds.add(
        FavoriteItemModel.fromEntity(item(FavoriteContentType.dua, '1')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      await sub.cancel();
    });
  });

  group('FavoritesRepositoryImpl', () {
    late InMemoryStorageService storage;
    late FavoritesRepositoryImpl repo;
    setUp(() {
      storage = InMemoryStorageService();
      repo = FavoritesRepositoryImpl(FavoritesLocalDataSourceImpl(storage));
    });

    test('getAll sorts newest first', () async {
      await repo.add(
        item(FavoriteContentType.dua, 'old', savedAt: DateTime.utc(2024, 1, 1)),
      );
      await repo.add(
        item(FavoriteContentType.dua, 'new', savedAt: DateTime.utc(2025, 1, 1)),
      );
      await repo.add(
        item(FavoriteContentType.dua, 'mid', savedAt: DateTime.utc(2024, 6, 1)),
      );
      expect(repo.getAll().map((e) => e.referenceId), ['new', 'mid', 'old']);
    });

    test('toggle adds then removes and reports state', () async {
      final i = item(FavoriteContentType.surah, '1');
      expect(await repo.toggle(i), isTrue);
      expect(repo.isFavorite(i.id), isTrue);
      expect(await repo.toggle(i), isFalse);
      expect(repo.isFavorite(i.id), isFalse);
    });

    test('same referenceId in different types does not collide', () async {
      await repo.add(item(FavoriteContentType.surah, '1'));
      await repo.add(item(FavoriteContentType.juz, '1'));
      expect(repo.getAll(), hasLength(2));
    });

    test('remove of unknown id is harmless', () async {
      await repo.remove('nope');
      expect(repo.getAll(), isEmpty);
    });
  });

  group('providers', () {
    late InMemoryStorageService storage;
    late ProviderContainer container;
    setUp(() {
      storage = InMemoryStorageService();
      container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test('notifier emits initial list then updates on toggle/remove', () async {
      final sub = container.listen(favoritesNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await pump();
      expect(container.read(favoritesNotifierProvider).value, isEmpty);

      final i = item(FavoriteContentType.dua, '1');
      await container.read(favoritesNotifierProvider.notifier).toggle(i);
      await pump();
      expect(container.read(favoritesNotifierProvider).value, [i]);
      expect(container.read(isFavoriteProvider(i.id)), isTrue);
      expect(container.read(isFavoriteProvider('other')), isFalse);

      await container.read(favoritesNotifierProvider.notifier).remove(i.id);
      await pump();
      expect(container.read(favoritesNotifierProvider).value, isEmpty);
      expect(container.read(isFavoriteProvider(i.id)), isFalse);
    });

    test('loads pre-existing favorites', () async {
      final i = item(FavoriteContentType.juz, '5');
      await storage.put(
        box,
        i.id,
        jsonEncode(FavoriteItemModel.fromEntity(i).toJson()),
      );
      final sub = container.listen(favoritesNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await pump();
      expect(container.read(favoritesNotifierProvider).value, [i]);
    });
  });
}
