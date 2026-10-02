import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/daily_content/data/daily_content_store.dart';
import 'package:deen_companion/features/daily_content/domain/daily_content_selector.dart';
import 'package:deen_companion/features/daily_content/domain/daily_notification_config.dart';
import 'package:deen_companion/features/daily_content/domain/entities/daily_content.dart';
import 'package:deen_companion/features/daily_content/domain/notification_text.dart';
import 'package:deen_companion/features/daily_content/domain/repositories/daily_content_repository.dart';
import 'package:deen_companion/features/daily_content/presentation/providers/daily_content_providers.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';

const _ayah = DailyAyah(
  surahNumber: 1,
  surahNameEnglish: 'Al-Fatihah',
  surahNameArabic: 'ا',
  ayahNumber: 2,
  arabic: 'a',
  translation: 'Praise be to God.',
);
const _hadith = Hadith(
  id: 'h',
  collection: 'nawawi',
  collectionName: 'Forty Hadith',
  hadithNumber: 3,
  arabic: 'a',
  english: 'e',
  grade: 'Sahih',
);

DailyContent content(String key) =>
    DailyContent(dateKey: key, ayah: _ayah, hadith: _hadith);

class FakeRepo implements DailyContentRepository {
  final Map<String, DailyContent> cache = {};
  Result<DailyContent>? fetchResult;
  final fetched = <String>[];

  @override
  DailyContent? getCached(String dateKey) => cache[dateKey];

  @override
  Future<Result<DailyContent>> fetch(String dateKey) async {
    fetched.add(dateKey);
    return fetchResult ?? Success(content(dateKey));
  }

  @override
  Future<void> pruneBefore(String dateKey) async {}
}

void main() {
  late InMemoryStorageService storage;
  late FakeRepo repo;
  late ProviderContainer container;
  late DailyContentStore store;

  setUp(() {
    storage = InMemoryStorageService();
    repo = FakeRepo();
    store = DailyContentStore(storage);
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        dailyContentRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  test('config provider defaults to production config', () {
    expect(
      container.read(dailyNotificationConfigProvider),
      same(DailyNotificationConfig.production),
    );
  });

  group('dailyNotificationEnabledProvider', () {
    const box = AppConstants.settingsBoxName;
    const key = AppConstants.dailyNotificationEnabledKey;

    test('defaults to on', () {
      expect(container.read(dailyNotificationEnabledProvider), isTrue);
    });

    test('reads a persisted off value', () {
      storage.boxes[box] = {key: false};
      final c = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(c.dispose);
      expect(c.read(dailyNotificationEnabledProvider), isFalse);
    });

    test('set updates state and persists', () async {
      await container
          .read(dailyNotificationEnabledProvider.notifier)
          .set(false);
      expect(container.read(dailyNotificationEnabledProvider), isFalse);
      expect(storage.get<bool>(box, key), isFalse);
      await container.read(dailyNotificationEnabledProvider.notifier).set(true);
      expect(storage.get<bool>(box, key), isTrue);
    });
  });

  group('dailyContentProvider', () {
    test('returns content on success', () async {
      final c = await container.read(dailyContentProvider('2025-01-01').future);
      expect(c.dateKey, '2025-01-01');
    });

    test('throws the Failure on error', () async {
      repo.fetchResult = const Error(NetworkFailure());
      await expectLater(
        container.read(dailyContentProvider('2025-01-01').future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('notificationHistoryProvider', () {
    Future<void> seed() async {
      await store.writeDelivered([
        const DeliveredNotification(
          id: 'a',
          dateKey: '2025-01-01',
          deliveredAtMillis: 1000,
        ),
        const DeliveredNotification(
          id: 'b',
          dateKey: '2025-01-02',
          deliveredAtMillis: 3000,
        ),
        const DeliveredNotification(
          id: 'c',
          dateKey: '2025-01-03',
          deliveredAtMillis: 2000,
          debug: true,
        ),
      ]);
    }

    test('empty with no deliveries', () {
      expect(container.read(notificationHistoryProvider), isEmpty);
      expect(container.read(unreadNotificationCountProvider), 0);
    });

    test('sorted newest first with title and unread flags', () async {
      await seed();
      await store.writeReadIds({'a'});
      final list = container.read(notificationHistoryProvider);
      expect(list.map((r) => r.id), ['b', 'c', 'a']);
      expect(list.firstWhere((r) => r.id == 'a').read, isTrue);
      expect(list.firstWhere((r) => r.id == 'b').read, isFalse);
      expect(list.firstWhere((r) => r.id == 'c').debug, isTrue);
      expect(list.first.title, DailyNotificationConfig.production.title);
      expect(container.read(unreadNotificationCountProvider), 2);
    });

    test('preview uses cached content, else the fallback text', () async {
      await seed();
      repo.cache['2025-01-02'] = content('2025-01-02');
      final list = container.read(notificationHistoryProvider);
      expect(
        list.firstWhere((r) => r.id == 'b').preview,
        DailyNotificationText.preview(content('2025-01-02')),
      );
      expect(
        list.firstWhere((r) => r.id == 'a').preview,
        DailyNotificationText.fallback,
      );
    });

    test('markRead persists, refreshes and is idempotent', () async {
      await seed();
      final n = container.read(notificationHistoryProvider.notifier);
      container.read(notificationHistoryProvider);
      await n.markRead('b');
      expect(store.readIds(), {'b'});
      expect(container.read(unreadNotificationCountProvider), 2);
      await n.markRead('b');
      expect(store.readIds(), {'b'});
    });

    test('markAllRead marks everything including previously read', () async {
      await seed();
      await store.writeReadIds({'zzz'});
      container.read(notificationHistoryProvider);
      await container.read(notificationHistoryProvider.notifier).markAllRead();
      expect(store.readIds(), {'zzz', 'a', 'b', 'c'});
      expect(container.read(unreadNotificationCountProvider), 0);
    });

    test('refresh re-reads the store', () async {
      expect(container.read(notificationHistoryProvider), isEmpty);
      await seed();
      container.read(notificationHistoryProvider.notifier).refresh();
      expect(container.read(notificationHistoryProvider), hasLength(3));
    });
  });

  group('dateKeyForNotificationId', () {
    test('uses the stored slot day first', () async {
      await store.writeSlots([
        const NotificationSlot(
          id: 'debug-123',
          dateKey: '2025-07-07',
          epochMillis: 1,
          debug: true,
        ),
      ]);
      expect(dateKeyForNotificationId(store, 'debug-123'), '2025-07-07');
    });

    test('a date-shaped id maps to itself', () {
      expect(dateKeyForNotificationId(store, '2025-02-03'), '2025-02-03');
    });

    test('unknown, non-date id falls back to today', () {
      final today = DailyContentSelector.dateKey(DateTime.now());
      expect(dateKeyForNotificationId(store, 'whatever'), today);
    });

    test('slot takes priority over date-shaped id', () async {
      await store.writeSlots([
        const NotificationSlot(
          id: '2025-02-03',
          dateKey: '2025-02-04',
          epochMillis: 1,
        ),
      ]);
      expect(dateKeyForNotificationId(store, '2025-02-03'), '2025-02-04');
    });
  });
}
