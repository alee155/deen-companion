import 'dart:convert';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/features/recent_activity/data/datasources/recent_activity_local_datasource.dart';
import 'package:deen_companion/features/recent_activity/data/models/recent_activity_item_model.dart';
import 'package:deen_companion/features/recent_activity/data/repositories/recent_activity_repository_impl.dart';
import 'package:deen_companion/features/recent_activity/domain/entities/recent_activity_item.dart';
import 'package:deen_companion/features/recent_activity/domain/repositories/recent_activity_repository.dart';
import 'package:deen_companion/features/recent_activity/presentation/providers/recent_activity_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_storage_service.dart';

RecentActivityItem act(String ref, {RecentActivityType? type, int day = 1}) =>
    RecentActivityItem(
      id: RecentActivityItem.buildId(type ?? RecentActivityType.surah, ref),
      type: type ?? RecentActivityType.surah,
      referenceId: ref,
      title: 'T$ref',
      route: '/r/$ref',
      viewedAt: DateTime.utc(2025, 1, day),
    );

void main() {
  const box = AppConstants.recentActivityBoxName;

  group('entities', () {
    test('buildId and labels', () {
      expect(RecentActivityItem.buildId(RecentActivityType.juz, '4'), 'juz:4');
      final labels = RecentActivityType.values.map((t) => t.label).toSet();
      expect(labels, hasLength(RecentActivityType.values.length));
    });

    test('maxEntries is 5', () {
      expect(RecentActivityRepository.maxEntries, 5);
    });
  });

  group('RecentActivityItemModel', () {
    test('round trips through JSON', () {
      final e = RecentActivityItem(
        id: 'dua:1',
        type: RecentActivityType.dua,
        referenceId: '1',
        title: 't',
        subtitle: 's',
        route: '/d',
        viewedAt: DateTime.utc(2025, 3, 4, 5, 6),
      );
      final json =
          jsonDecode(jsonEncode(RecentActivityItemModel.fromEntity(e).toJson()))
              as Map<String, dynamic>;
      expect(RecentActivityItemModel.fromJson(json).toEntity(), e);
    });

    test('missing field throws, unknown type throws', () {
      expect(
        () => RecentActivityItemModel.fromJson({'id': 'x'}),
        throwsA(isA<TypeError>()),
      );
      const m = RecentActivityItemModel(
        id: 'a',
        type: 'zzz',
        referenceId: 'r',
        title: 't',
        route: '/',
        viewedAt: '2025-01-01T00:00:00.000Z',
      );
      expect(m.toEntity, throwsStateError);
    });
  });

  group('RecentActivityLocalDataSourceImpl', () {
    late InMemoryStorageService storage;
    late RecentActivityLocalDataSourceImpl ds;
    setUp(() {
      storage = InMemoryStorageService();
      ds = RecentActivityLocalDataSourceImpl(storage);
    });

    RecentActivityItemModel m(String ref) =>
        RecentActivityItemModel.fromEntity(act(ref));

    test('empty by default', () => expect(ds.getAll(), isEmpty));

    test('logActivity inserts most-recent-first', () async {
      await ds.logActivity(m('1'));
      await ds.logActivity(m('2'));
      expect(ds.getAll().map((e) => e.referenceId), ['2', '1']);
    });

    test('re-logging moves item to top without duplicating', () async {
      await ds.logActivity(m('1'));
      await ds.logActivity(m('2'));
      await ds.logActivity(m('3'));
      await ds.logActivity(m('1'));
      expect(ds.getAll().map((e) => e.referenceId), ['1', '3', '2']);
    });

    test('list is capped to 5, dropping the oldest', () async {
      for (var i = 1; i <= 7; i++) {
        await ds.logActivity(m('$i'));
      }
      final ids = ds.getAll().map((e) => e.referenceId).toList();
      expect(ids, ['7', '6', '5', '4', '3']);
    });

    test('same ref with different type are separate entries', () async {
      await ds.logActivity(
        RecentActivityItemModel.fromEntity(
          act('1', type: RecentActivityType.surah),
        ),
      );
      await ds.logActivity(
        RecentActivityItemModel.fromEntity(
          act('1', type: RecentActivityType.juz),
        ),
      );
      expect(ds.getAll(), hasLength(2));
    });

    test('clear empties list', () async {
      await ds.logActivity(m('1'));
      await ds.clear();
      expect(ds.getAll(), isEmpty);
    });

    test('corrupted storage throws on getAll', () async {
      await storage.put(box, 'recent_activity_list', '{not json');
      expect(ds.getAll, throwsFormatException);
    });
  });

  group('repository + provider', () {
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

    test('repository maps models to entities', () async {
      final repo = RecentActivityRepositoryImpl(
        RecentActivityLocalDataSourceImpl(storage),
      );
      await repo.logActivity(act('9'));
      expect(repo.getAll(), [act('9')]);
      await repo.clear();
      expect(repo.getAll(), isEmpty);
    });

    test('notifier streams initial state and updates', () async {
      final sub = container.listen(recentActivityNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await pump();
      expect(container.read(recentActivityNotifierProvider).value, isEmpty);

      final n = container.read(recentActivityNotifierProvider.notifier);
      await n.logActivity(act('1'));
      await pump();
      await n.logActivity(act('2'));
      await pump();
      expect(
        container
            .read(recentActivityNotifierProvider)
            .value!
            .map((e) => e.referenceId),
        ['2', '1'],
      );

      await n.clear();
      await pump();
      expect(container.read(recentActivityNotifierProvider).value, isEmpty);
    });
  });
}
